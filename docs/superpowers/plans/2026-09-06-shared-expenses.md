# Shared Expenses Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a second user register their own expenses in `/finance` and let both users mark expenses as shared (split 50/50 by default), see who owes whom, and settle debts, via the AI agent and a small UI.

**Architecture:** Additive data model around the existing `Finance::Expense`: a minimal `Finance::Group` (one per couple, UI assumes exactly one), `Finance::ExpenseShare` rows per participant, and `Finance::Settlement`. "My spending" becomes personal expenses at 100% plus my share of shared ones, centralized in `Finance::SpendingQuery`. Tools gain `shared`/`my_percent`/`paid_by_other` and a `scope` param; a new `RegisterSettlementTool` handles transfers. One screen at `/finance/shared` handles create/join/balance/settle.

**Tech Stack:** Rails 7.1, PostgreSQL, Devise, ruby_llm ~1.13 (`RubyLLM::Tool`), Hotwire/Turbo, Bootstrap 5, Minitest with fixtures.

**Spec:** `docs/superpowers/specs/2026-09-06-shared-expenses-design.md`

## Global Constraints

- **Never break existing data.** Every migration is additive: no column is dropped, renamed or retyped. New columns on existing tables are nullable or have defaults. A `Finance::Expense` with `group_id IS NULL` is personal and behaves exactly as today.
- `payer_id` backfill: `UPDATE finance_expenses SET payer_id = user_id WHERE payer_id IS NULL` inside the migration that adds it.
- Namespacing: finance models under `Finance::`, tables prefixed `finance_`, `self.table_name` set explicitly (existing convention). ruby_llm models (`Chat`, `Message`, `ToolCall`) stay top-level.
- Tools live in `app/tools/`, are plain `RubyLLM::Tool` subclasses, and take `user` in `initialize`.
- Group limit for this iteration: `Finance::Group::MAX_MEMBERS = 2`.
- Ruby style: double quotes, max line length 120, RuboCop config in `.rubocop.yml`. Run `bundle exec rubocop <changed files>` before each commit.
- Commit messages: English, Conventional Commits (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`). **No `Co-Authored-By` or AI signature.**
- Spanish UI copy without accents is the existing convention in views and prompts (e.g. "Graficos", "Categoria"). Keep it consistent.
- Test commands run as `bin/rails test <file>`; fixtures are ERB-enabled YAML in `test/fixtures/`.

---

## File Structure

**Created**

| Path | Responsibility |
|---|---|
| `db/migrate/2026090601_add_name_to_users.rb` | `users.name` |
| `db/migrate/2026090602_create_finance_groups.rb` | `finance_groups` + `finance_group_memberships` |
| `db/migrate/2026090603_add_sharing_to_finance_expenses.rb` | `group_id`, `payer_id` (+ backfill) on `finance_expenses`; `finance_expense_shares` |
| `db/migrate/2026090604_create_finance_settlements.rb` | `finance_settlements` |
| `app/models/finance/group.rb` | Group, invite code, members, `other_member`, `full?` |
| `app/models/finance/group_membership.rb` | Join model |
| `app/models/finance/expense_share.rb` | Per-participant share |
| `app/models/finance/settlement.rb` | Transfer between members |
| `app/services/finance/split_calculator.rb` | Pure calculation of share rows (equal / percent / amount) |
| `app/services/finance/group_balance.rb` | Net per member and debts |
| `app/services/finance/period_resolver.rb` | Period string → date range (replaces 4 copies) |
| `app/services/finance/spending_query.rb` | Aggregations of personal + shares |
| `app/tools/register_settlement_tool.rb` | Agent tool for settlements |
| `app/controllers/finance/shared_controller.rb` | `/finance/shared` show/create/join |
| `app/controllers/finance/settlements_controller.rb` | Saldar button |
| `app/views/finance/shared/show.html.erb` | Shared space screen |
| `test/fixtures/users.yml`, `finance_categories.yml`, `finance_groups.yml`, `finance_group_memberships.yml`, `finance_expenses.yml`, `finance_expense_shares.yml`, `finance_settlements.yml` | Test data |
| `test/models/finance/*_test.rb`, `test/services/finance/*_test.rb`, `test/tools/*_test.rb`, `test/controllers/finance/*_test.rb` | Tests |

**Modified**

| Path | Change |
|---|---|
| `app/models/user.rb` | `name`, `display_name`, groups, `shared_group` |
| `app/models/finance/expense.rb` | group/payer/shares, `visible_to`, `amount_ars_for`, `share_with!`, `unshare!`, `assign_shares!` |
| `app/controllers/application_controller.rb` | Devise permitted `name` |
| `app/views/devise/registrations/new.html.erb`, `edit.html.erb` | `name` input |
| `app/controllers/finance/expenses_controller.rb` | `visible_to`, `SpendingQuery`, `PeriodResolver`, share toggling |
| `app/controllers/finance/charts_controller.rb` | `SpendingQuery`, `PeriodResolver` |
| `app/views/finance/expenses/index.html.erb` | Shared badge, "tu parte", toggle shared, edit share |
| `app/views/finance/shared/_navbar.html.erb` | Link to `/finance/shared` |
| `app/tools/register_expense_tool.rb`, `list_expenses_tool.rb`, `get_balance_tool.rb` | New params |
| `app/jobs/finance/chat_response_job.rb` | Prompt block + new tool |
| `app/assets/stylesheets/components/_finance_chat.scss` | Small styles for badge and shared screen |
| `config/routes.rb` | `shared`, `settlements` |
| `test/test_helper.rb` | `set_fixture_class`, Devise helpers |
| `CLAUDE.md` | Document sharing |

---

### Task 0: Make the test database work locally

The test DB cannot be created today: `bin/rails test` fails with `extension "vector" is not available` because Homebrew's `pgvector` 0.8.1 was built for `postgresql@17`/`@18` while the server running is `postgresql@16`. The dev DB already has the extension so it keeps working.

**Files:** none in repo.

- [ ] **Step 1: Build pgvector for postgresql@16** (run by the human, it changes system state)

```bash
git clone --branch v0.8.1 --depth 1 https://github.com/pgvector/pgvector.git /tmp/pgvector-pg16
cd /tmp/pgvector-pg16
make PG_CONFIG=/opt/homebrew/opt/postgresql@16/bin/pg_config
make install PG_CONFIG=/opt/homebrew/opt/postgresql@16/bin/pg_config
```

Expected: `vector.control` now exists at `/opt/homebrew/opt/postgresql@16/share/postgresql@16/extension/vector.control`.

- [ ] **Step 2: Prepare test DB**

Run: `bin/rails db:test:prepare`
Expected: no error output.

- [ ] **Step 3: Baseline the suite**

Run: `bin/rails test 2>&1 | tail -5`
Expected: prints a `runs, assertions, failures, errors` line. Note any pre-existing failures (there are only skeleton tests for the portfolio; failures there are not part of this plan).

---

### Task 1: User name

**Files:**
- Create: `db/migrate/20260906000001_add_name_to_users.rb`
- Create: `test/fixtures/users.yml`
- Create: `test/models/user_test.rb`
- Modify: `app/models/user.rb`
- Modify: `app/controllers/application_controller.rb`
- Modify: `app/views/devise/registrations/new.html.erb`, `app/views/devise/registrations/edit.html.erb`
- Modify: `test/test_helper.rb`

**Interfaces:**
- Produces: `User#display_name -> String` (name, or local part of email).

- [ ] **Step 1: Test helper with Devise helpers and namespaced fixture classes**

Replace `test/test_helper.rb` with:

```ruby
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    set_fixture_class finance_categories: "Finance::Category",
                      finance_expenses: "Finance::Expense",
                      finance_groups: "Finance::Group",
                      finance_group_memberships: "Finance::GroupMembership",
                      finance_expense_shares: "Finance::ExpenseShare",
                      finance_settlements: "Finance::Settlement"

    fixtures :all
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
  end
end
```

Note: `set_fixture_class` references classes that do not exist until Tasks 2–5. Rails resolves them lazily only when a fixture file with that table name exists, so add fixture files in the same task that creates each model.

- [ ] **Step 2: Users fixture**

`test/fixtures/users.yml`:

```yaml
manu:
  email: manu@example.com
  name: Manu
  encrypted_password: <%= Devise::Encryptor.digest(User, "password123") %>

novia:
  email: novia@example.com
  name: Novia
  encrypted_password: <%= Devise::Encryptor.digest(User, "password123") %>

stranger:
  email: stranger@example.com
  encrypted_password: <%= Devise::Encryptor.digest(User, "password123") %>
```

- [ ] **Step 3: Failing test**

`test/models/user_test.rb`:

```ruby
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "display_name returns name when present" do
    assert_equal "Manu", users(:manu).display_name
  end

  test "display_name falls back to email local part" do
    assert_equal "stranger", users(:stranger).display_name
  end
end
```

- [ ] **Step 4: Run to verify failure**

Run: `bin/rails test test/models/user_test.rb`
Expected: errors about missing column `name` / undefined method `display_name`.

- [ ] **Step 5: Migration**

`db/migrate/20260906000001_add_name_to_users.rb`:

```ruby
class AddNameToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :name, :string
  end
end
```

Run: `bin/rails db:migrate && bin/rails db:test:prepare`

- [ ] **Step 6: Model**

`app/models/user.rb`:

```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :chats, dependent: :destroy
  has_many :finance_expenses, class_name: "Finance::Expense", dependent: :destroy

  def display_name
    name.presence || email.to_s.split("@").first
  end
end
```

- [ ] **Step 7: Devise params and forms**

`app/controllers/application_controller.rb` (replace the whole file, the commented code is dead):

```ruby
class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name])
  end
end
```

In `app/views/devise/registrations/new.html.erb`, inside `<div class="form-inputs">`, add as the first input:

```erb
    <%= f.input :name, required: true, label: "Nombre", input_html: { autocomplete: "name" } %>
```

and make `email` not `autofocus` (move `autofocus: true` to `name`).

In `app/views/devise/registrations/edit.html.erb`, add as the first input inside `form-inputs`:

```erb
    <%= f.input :name, required: false, label: "Nombre" %>
```

- [ ] **Step 8: Run tests**

Run: `bin/rails test test/models/user_test.rb`
Expected: 2 runs, 0 failures.

- [ ] **Step 9: Commit**

```bash
bundle exec rubocop app/models/user.rb app/controllers/application_controller.rb test/test_helper.rb test/models/user_test.rb
git add db/migrate/20260906000001_add_name_to_users.rb db/schema.rb app/models/user.rb app/controllers/application_controller.rb app/views/devise/registrations test/test_helper.rb test/fixtures/users.yml test/models/user_test.rb
git commit -m "feat: add name to users with display_name fallback"
```

---

### Task 2: Groups and memberships

**Files:**
- Create: `db/migrate/20260906000002_create_finance_groups.rb`
- Create: `app/models/finance/group.rb`, `app/models/finance/group_membership.rb`
- Create: `test/fixtures/finance_groups.yml`, `test/fixtures/finance_group_memberships.yml`
- Create: `test/models/finance/group_test.rb`
- Modify: `app/models/user.rb`

**Interfaces:**
- Produces: `Finance::Group` with `members`, `memberships`, `owner`, `invite_code`, `MAX_MEMBERS = 2`, `#full? -> Boolean`, `#member?(user) -> Boolean`, `#other_member(user) -> User | nil`, `#add_member!(user)`; `User#groups`, `User#shared_group -> Finance::Group | nil`.

- [ ] **Step 1: Fixtures**

`test/fixtures/finance_groups.yml`:

```yaml
pareja:
  name: Compartido
  invite_code: ABCD1234
  owner: manu
```

`test/fixtures/finance_group_memberships.yml`:

```yaml
manu_pareja:
  group: pareja
  user: manu

novia_pareja:
  group: pareja
  user: novia
```

- [ ] **Step 2: Failing tests**

`test/models/finance/group_test.rb`:

```ruby
require "test_helper"

module Finance
  class GroupTest < ActiveSupport::TestCase
    test "generates an 8 char uppercase invite code on create" do
      group = Finance::Group.create!(owner: users(:stranger))
      assert_match(/\A[A-Z0-9]{8}\z/, group.invite_code)
    end

    test "creating a group adds the owner as member" do
      group = Finance::Group.create!(owner: users(:stranger))
      assert group.member?(users(:stranger))
    end

    test "other_member returns the other user" do
      assert_equal users(:novia), finance_groups(:pareja).other_member(users(:manu))
      assert_equal users(:manu), finance_groups(:pareja).other_member(users(:novia))
    end

    test "full? when MAX_MEMBERS reached" do
      assert finance_groups(:pareja).full?
      assert_not Finance::Group.create!(owner: users(:stranger)).full?
    end

    test "add_member! refuses when full" do
      assert_raises(ActiveRecord::RecordInvalid) { finance_groups(:pareja).add_member!(users(:stranger)) }
    end

    test "user.shared_group returns the group" do
      assert_equal finance_groups(:pareja), users(:manu).shared_group
      assert_nil users(:stranger).shared_group
    end
  end
end
```

- [ ] **Step 3: Run to verify failure**

Run: `bin/rails test test/models/finance/group_test.rb`
Expected: `uninitialized constant Finance::Group` or table missing.

- [ ] **Step 4: Migration**

`db/migrate/20260906000002_create_finance_groups.rb`:

```ruby
class CreateFinanceGroups < ActiveRecord::Migration[7.1]
  def change
    create_table :finance_groups do |t|
      t.string :name, null: false, default: "Compartido"
      t.string :invite_code, null: false
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :finance_groups, :invite_code, unique: true

    create_table :finance_group_memberships do |t|
      t.references :group, null: false, foreign_key: { to_table: :finance_groups }
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :finance_group_memberships, %i[group_id user_id], unique: true
  end
end
```

Run: `bin/rails db:migrate && bin/rails db:test:prepare`

- [ ] **Step 5: Models**

`app/models/finance/group_membership.rb`:

```ruby
module Finance
  class GroupMembership < ApplicationRecord
    self.table_name = "finance_group_memberships"

    belongs_to :group, class_name: "Finance::Group"
    belongs_to :user

    validates :user_id, uniqueness: { scope: :group_id }
    validate :group_not_full, on: :create

    private

    def group_not_full
      errors.add(:base, "El espacio compartido ya esta completo") if group && group.memberships.count >= Finance::Group::MAX_MEMBERS
    end
  end
end
```

`app/models/finance/group.rb`:

```ruby
module Finance
  class Group < ApplicationRecord
    self.table_name = "finance_groups"

    MAX_MEMBERS = 2

    belongs_to :owner, class_name: "User"
    has_many :memberships, class_name: "Finance::GroupMembership", foreign_key: :group_id, dependent: :destroy
    has_many :members, through: :memberships, source: :user
    has_many :expenses, class_name: "Finance::Expense", foreign_key: :group_id, dependent: :nullify
    has_many :settlements, class_name: "Finance::Settlement", foreign_key: :group_id, dependent: :destroy

    validates :name, presence: true
    validates :invite_code, presence: true, uniqueness: true

    before_validation :generate_invite_code, on: :create
    after_create :add_owner_membership

    def full?
      memberships.count >= MAX_MEMBERS
    end

    def member?(user)
      memberships.exists?(user_id: user.id)
    end

    def other_member(user)
      members.where.not(id: user.id).first
    end

    def add_member!(user)
      memberships.create!(user: user)
    end

    private

    def generate_invite_code
      self.invite_code ||= loop do
        code = SecureRandom.alphanumeric(8).upcase
        break code unless Finance::Group.exists?(invite_code: code)
      end
    end

    def add_owner_membership
      memberships.create!(user: owner)
    end
  end
end
```

The `has_many :expenses` / `:settlements` lines reference classes created in Tasks 3 and 5. They are lazy and only fail if called; leave them in now so the model does not need re-editing.

`app/models/user.rb`, add after `has_many :finance_expenses`:

```ruby
  has_many :finance_group_memberships, class_name: "Finance::GroupMembership", dependent: :destroy
  has_many :finance_groups, through: :finance_group_memberships, source: :group

  # This iteration assumes a single shared space per user.
  def shared_group
    finance_groups.order(:id).first
  end
```

- [ ] **Step 6: Run tests**

Run: `bin/rails test test/models/finance/group_test.rb`
Expected: 6 runs, 0 failures.

- [ ] **Step 7: Commit**

```bash
bundle exec rubocop app/models/finance/group.rb app/models/finance/group_membership.rb app/models/user.rb test/models/finance/group_test.rb
git add db/migrate/20260906000002_create_finance_groups.rb db/schema.rb app/models/finance/group.rb app/models/finance/group_membership.rb app/models/user.rb test/fixtures/finance_groups.yml test/fixtures/finance_group_memberships.yml test/models/finance/group_test.rb
git commit -m "feat: add finance groups and memberships"
```

---

### Task 3: Expense sharing columns, shares model, visibility

**Files:**
- Create: `db/migrate/20260906000003_add_sharing_to_finance_expenses.rb`
- Create: `app/models/finance/expense_share.rb`
- Create: `test/fixtures/finance_categories.yml`, `test/fixtures/finance_expenses.yml`, `test/fixtures/finance_expense_shares.yml`
- Create: `test/models/finance/expense_test.rb`
- Modify: `app/models/finance/expense.rb`

**Interfaces:**
- Produces: `Finance::ExpenseShare(expense, user, amount, amount_ars)`; `Finance::Expense#group`, `#payer`, `#shares`, `#shared? -> Boolean`, `#share_for(user) -> ExpenseShare | nil`, `#amount_ars_for(user) -> BigDecimal`, `#assign_shares!(rows)` where `rows = [{ user:, amount:, amount_ars: }]`, scope `Finance::Expense.visible_to(user)`, scope `Finance::Expense.in_group(group)`.

- [ ] **Step 1: Fixtures**

`test/fixtures/finance_categories.yml`:

```yaml
comida:
  name: Comida
  icon: fa-utensils
  color: "#ef4444"

servicios:
  name: Servicios
  icon: fa-bolt
  color: "#f59e0b"

otros:
  name: Otros
  icon: fa-ellipsis
  color: "#6b7280"
```

`test/fixtures/finance_expenses.yml` (a legacy row with no payer and no group mirrors production data created before this feature):

```yaml
legacy_nafta:
  user: manu
  category: comida
  amount: 3000
  amount_ars: 3000
  currency: ARS
  description: Nafta
  expense_type: variable
  expense_date: <%= Date.current %>

super_compartido:
  user: manu
  payer: manu
  group: pareja
  category: comida
  amount: 8000
  amount_ars: 8000
  currency: ARS
  description: Super
  expense_type: variable
  expense_date: <%= Date.current %>

novia_cafe:
  user: novia
  payer: novia
  category: comida
  amount: 500
  amount_ars: 500
  currency: ARS
  description: Cafe
  expense_type: variable
  expense_date: <%= Date.current %>

luz_compartida_novia_pago:
  user: novia
  payer: novia
  group: pareja
  category: servicios
  amount: 2000
  amount_ars: 2000
  currency: ARS
  description: Luz
  expense_type: fijo
  expense_date: <%= Date.current %>
```

`test/fixtures/finance_expense_shares.yml`:

```yaml
super_manu:
  expense: super_compartido
  user: manu
  amount: 4000
  amount_ars: 4000

super_novia:
  expense: super_compartido
  user: novia
  amount: 4000
  amount_ars: 4000

luz_manu:
  expense: luz_compartida_novia_pago
  user: manu
  amount: 1000
  amount_ars: 1000

luz_novia:
  expense: luz_compartida_novia_pago
  user: novia
  amount: 1000
  amount_ars: 1000
```

Fixture note: the `category:` association label works because `belongs_to :category, foreign_key: :finance_category_id` is declared on the model; Rails resolves fixture labels through the association name.

- [ ] **Step 2: Failing tests**

`test/models/finance/expense_test.rb`:

```ruby
require "test_helper"

module Finance
  class ExpenseTest < ActiveSupport::TestCase
    test "legacy expense without group or payer is personal and counts 100%" do
      legacy = finance_expenses(:legacy_nafta)
      assert_not legacy.shared?
      assert_nil legacy.payer
      assert_equal BigDecimal("3000"), legacy.amount_ars_for(users(:manu))
    end

    test "shared expense returns the user's share" do
      expense = finance_expenses(:super_compartido)
      assert expense.shared?
      assert_equal BigDecimal("4000"), expense.amount_ars_for(users(:novia))
    end

    test "visible_to includes personal, paid and shared-in expenses only" do
      visible = Finance::Expense.visible_to(users(:manu))
      assert_includes visible, finance_expenses(:legacy_nafta)
      assert_includes visible, finance_expenses(:super_compartido)
      assert_includes visible, finance_expenses(:luz_compartida_novia_pago)
      assert_not_includes visible, finance_expenses(:novia_cafe)
    end

    test "visible_to for stranger is empty" do
      assert_empty Finance::Expense.visible_to(users(:stranger))
    end

    test "assign_shares! replaces shares atomically" do
      expense = finance_expenses(:super_compartido)
      expense.assign_shares!([
        { user: users(:manu), amount: BigDecimal("6000"), amount_ars: BigDecimal("6000") },
        { user: users(:novia), amount: BigDecimal("2000"), amount_ars: BigDecimal("2000") }
      ])
      assert_equal 2, expense.shares.count
      assert_equal BigDecimal("6000"), expense.share_for(users(:manu)).amount
    end

    test "shared expense requires payer to be a member" do
      expense = finance_expenses(:super_compartido)
      expense.payer = users(:stranger)
      assert_not expense.valid?
    end
  end
end
```

- [ ] **Step 3: Run to verify failure**

Run: `bin/rails test test/models/finance/expense_test.rb`
Expected: failures about unknown attribute `payer`/`group`.

- [ ] **Step 4: Migration**

`db/migrate/20260906000003_add_sharing_to_finance_expenses.rb`:

```ruby
class AddSharingToFinanceExpenses < ActiveRecord::Migration[7.1]
  def up
    add_reference :finance_expenses, :group, null: true, foreign_key: { to_table: :finance_groups }
    add_reference :finance_expenses, :payer, null: true, foreign_key: { to_table: :users }

    execute "UPDATE finance_expenses SET payer_id = user_id WHERE payer_id IS NULL"

    create_table :finance_expense_shares do |t|
      t.references :expense, null: false, foreign_key: { to_table: :finance_expenses }
      t.references :user, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.decimal :amount_ars, precision: 12, scale: 2, null: false
      t.timestamps
    end
    add_index :finance_expense_shares, %i[expense_id user_id], unique: true
  end

  def down
    drop_table :finance_expense_shares
    remove_reference :finance_expenses, :payer
    remove_reference :finance_expenses, :group
  end
end
```

Run: `bin/rails db:migrate && bin/rails db:test:prepare`

Verify the backfill on dev data:

Run: `bin/rails runner 'puts Finance::Expense.where(payer_id: nil).count'`
Expected: `0`.

- [ ] **Step 5: ExpenseShare model**

`app/models/finance/expense_share.rb`:

```ruby
module Finance
  class ExpenseShare < ApplicationRecord
    self.table_name = "finance_expense_shares"

    belongs_to :expense, class_name: "Finance::Expense"
    belongs_to :user

    validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :amount_ars, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :user_id, uniqueness: { scope: :expense_id }
  end
end
```

- [ ] **Step 6: Expense model**

Replace `app/models/finance/expense.rb` with:

```ruby
module Finance
  class Expense < ApplicationRecord
    self.table_name = "finance_expenses"

    belongs_to :user
    belongs_to :category, class_name: "Finance::Category", foreign_key: :finance_category_id
    belongs_to :message, optional: true
    belongs_to :group, class_name: "Finance::Group", optional: true
    belongs_to :payer, class_name: "User", optional: true

    has_many :shares, class_name: "Finance::ExpenseShare", foreign_key: :expense_id, dependent: :destroy
    has_many_attached :receipts

    validates :amount, presence: true, numericality: { greater_than: 0 }
    validates :expense_date, presence: true
    validates :description, presence: true
    validates :exchange_rate, numericality: { greater_than: 0 }, allow_nil: true
    validates :expense_type, inclusion: { in: %w[fijo variable] }
    validate :payer_belongs_to_group, if: :shared?

    before_validation :compute_amount_ars

    scope :for_period, ->(start_date, end_date) { where(expense_date: start_date..end_date) }
    scope :for_category, ->(category_id) { where(finance_category_id: category_id) }
    scope :for_expense_type, ->(type) { where(expense_type: type) }
    scope :recent, -> { order(expense_date: :desc, created_at: :desc) }
    scope :personal, -> { where(group_id: nil) }
    scope :in_group, ->(group) { where(group_id: group.id) }

    # Personal expenses the user registered, plus shared expenses they paid or have a share in.
    scope :visible_to, lambda { |user|
      where(user_id: user.id, group_id: nil)
        .or(where(payer_id: user.id).where.not(group_id: nil))
        .or(where(id: Finance::ExpenseShare.select(:expense_id).where(user_id: user.id)))
    }

    def shared?
      group_id.present?
    end

    def share_for(user)
      shares.find { |share| share.user_id == user.id }
    end

    # What this expense costs the given user: their share if shared, the full amount if personal.
    def amount_ars_for(user)
      return amount_ars || BigDecimal("0") unless shared?

      share_for(user)&.amount_ars || BigDecimal("0")
    end

    # rows: [{ user:, amount:, amount_ars: }]
    def assign_shares!(rows)
      transaction do
        shares.destroy_all
        rows.each { |row| shares.create!(user: row[:user], amount: row[:amount], amount_ars: row[:amount_ars]) }
      end
      shares.reset
    end

    private

    def compute_amount_ars
      if currency == "USD" && exchange_rate.present?
        self.amount_ars = amount * exchange_rate
      elsif currency.blank? || currency == "ARS"
        self.amount_ars = amount
      end
    end

    def payer_belongs_to_group
      errors.add(:payer, "debe ser miembro del espacio compartido") if payer.nil? || !group.member?(payer)
    end
  end
end
```

- [ ] **Step 7: Run tests**

Run: `bin/rails test test/models/finance/expense_test.rb test/models/finance/group_test.rb`
Expected: all pass.

- [ ] **Step 8: Commit**

```bash
bundle exec rubocop app/models/finance/expense.rb app/models/finance/expense_share.rb test/models/finance/expense_test.rb
git add db/migrate/20260906000003_add_sharing_to_finance_expenses.rb db/schema.rb app/models/finance/expense.rb app/models/finance/expense_share.rb test/fixtures/finance_categories.yml test/fixtures/finance_expenses.yml test/fixtures/finance_expense_shares.yml test/models/finance/expense_test.rb
git commit -m "feat: add group, payer and shares to finance expenses"
```

---

### Task 4: SplitCalculator and share/unshare on Expense

**Files:**
- Create: `app/services/finance/split_calculator.rb`
- Create: `test/services/finance/split_calculator_test.rb`
- Modify: `app/models/finance/expense.rb`
- Modify: `test/models/finance/expense_test.rb`

**Interfaces:**
- Produces: `Finance::SplitCalculator.equal(expense, members) -> rows`, `.by_percent(expense, { user => percent }) -> rows`, `.by_amount(expense, { user => amount }) -> rows` (raises `ArgumentError` if amounts don't sum to `expense.amount` or percents don't sum to 100). `rows = [{ user:, amount:, amount_ars: }]`, last row absorbs rounding so sums close exactly.
- Produces: `Finance::Expense#share_with!(group, payer:, rows: nil)`, `#unshare!`, `#rebalance_shares!` (recomputes shares keeping current proportions after amount change).

- [ ] **Step 1: Failing tests**

`test/services/finance/split_calculator_test.rb`:

```ruby
require "test_helper"

module Finance
  class SplitCalculatorTest < ActiveSupport::TestCase
    setup do
      @manu = users(:manu)
      @novia = users(:novia)
    end

    def build_expense(amount:, currency: "ARS", exchange_rate: nil)
      Finance::Expense.new(user: @manu, category: finance_categories(:comida), description: "x",
                           expense_date: Date.current, amount: amount, currency: currency,
                           exchange_rate: exchange_rate).tap(&:valid?)
    end

    test "equal split of even amount" do
      rows = Finance::SplitCalculator.equal(build_expense(amount: 8000), [@manu, @novia])
      assert_equal [BigDecimal("4000"), BigDecimal("4000")], rows.map { |r| r[:amount] }
      assert_equal [BigDecimal("4000"), BigDecimal("4000")], rows.map { |r| r[:amount_ars] }
    end

    test "equal split of odd cents closes exactly on last member" do
      rows = Finance::SplitCalculator.equal(build_expense(amount: BigDecimal("100.01")), [@manu, @novia])
      assert_equal BigDecimal("100.01"), rows.sum { |r| r[:amount] }
      assert_equal BigDecimal("50.00"), rows.first[:amount]
      assert_equal BigDecimal("50.01"), rows.last[:amount]
    end

    test "by_percent 70/30" do
      rows = Finance::SplitCalculator.by_percent(build_expense(amount: 10_000), { @manu => 70, @novia => 30 })
      assert_equal BigDecimal("7000"), rows.find { |r| r[:user] == @manu }[:amount]
      assert_equal BigDecimal("3000"), rows.find { |r| r[:user] == @novia }[:amount]
    end

    test "by_percent rejects percents not summing to 100" do
      assert_raises(ArgumentError) do
        Finance::SplitCalculator.by_percent(build_expense(amount: 100), { @manu => 60, @novia => 30 })
      end
    end

    test "by_amount rejects amounts not summing to total" do
      assert_raises(ArgumentError) do
        Finance::SplitCalculator.by_amount(build_expense(amount: 100), { @manu => 10, @novia => 20 })
      end
    end

    test "USD expense converts share amount_ars with the expense rate and closes exactly" do
      expense = build_expense(amount: BigDecimal("33.33"), currency: "USD", exchange_rate: BigDecimal("1400"))
      rows = Finance::SplitCalculator.equal(expense, [@manu, @novia])
      assert_equal expense.amount_ars.round(2), rows.sum { |r| r[:amount_ars] }
      assert_equal BigDecimal("16.66"), rows.first[:amount]
      assert_equal BigDecimal("16.67"), rows.last[:amount]
    end
  end
end
```

Add to `test/models/finance/expense_test.rb` inside the class:

```ruby
    test "share_with! sets group, payer and equal shares" do
      expense = finance_expenses(:legacy_nafta)
      expense.share_with!(finance_groups(:pareja), payer: users(:manu))
      assert expense.reload.shared?
      assert_equal users(:manu), expense.payer
      assert_equal BigDecimal("1500"), expense.amount_ars_for(users(:novia))
    end

    test "unshare! clears group and shares" do
      expense = finance_expenses(:super_compartido)
      expense.unshare!
      assert_not expense.reload.shared?
      assert_equal 0, expense.shares.count
      assert_equal BigDecimal("8000"), expense.amount_ars_for(users(:manu))
    end

    test "updating amount of a shared expense rebalances shares keeping proportions" do
      expense = finance_expenses(:super_compartido)
      expense.update!(amount: 10_000)
      assert_equal BigDecimal("5000"), expense.reload.amount_ars_for(users(:manu))
      assert_equal BigDecimal("5000"), expense.amount_ars_for(users(:novia))
    end
```

- [ ] **Step 2: Run to verify failure**

Run: `bin/rails test test/services/finance/split_calculator_test.rb test/models/finance/expense_test.rb`
Expected: `uninitialized constant Finance::SplitCalculator`, undefined `share_with!`.

- [ ] **Step 3: SplitCalculator**

`app/services/finance/split_calculator.rb`:

```ruby
module Finance
  # Computes share rows for an expense. Rows are [{ user:, amount:, amount_ars: }].
  # The last row absorbs rounding so that sums equal the expense totals exactly.
  class SplitCalculator
    def self.equal(expense, members)
      percent = BigDecimal("100") / members.size
      percents = members.each_with_object({}) { |member, acc| acc[member] = percent }
      new(expense).by_percent(percents)
    end

    def self.by_percent(expense, percents)
      new(expense).by_percent(percents)
    end

    def self.by_amount(expense, amounts)
      new(expense).by_amount(amounts)
    end

    def initialize(expense)
      @expense = expense
    end

    def by_percent(percents)
      total_percent = percents.values.sum { |value| BigDecimal(value.to_s) }
      raise ArgumentError, "Los porcentajes deben sumar 100 (suman #{total_percent.to_f})" unless total_percent.round(6) == 100

      amounts = percents.transform_values { |value| (@expense.amount * BigDecimal(value.to_s) / 100).round(2) }
      build_rows(amounts, close_amount: true)
    end

    def by_amount(amounts)
      amounts = amounts.transform_values { |value| BigDecimal(value.to_s).round(2) }
      total = amounts.values.sum
      raise ArgumentError, "Las partes deben sumar #{@expense.amount.to_f} (suman #{total.to_f})" unless total == @expense.amount

      build_rows(amounts, close_amount: false)
    end

    private

    def build_rows(amounts, close_amount:)
      users = amounts.keys
      rows = users.map { |user| { user: user, amount: amounts[user], amount_ars: to_ars(amounts[user]) } }
      close_rounding(rows, close_amount: close_amount)
      rows
    end

    def to_ars(share_amount)
      return share_amount if @expense.currency.blank? || @expense.currency == "ARS"

      (share_amount * @expense.exchange_rate).round(2)
    end

    def close_rounding(rows, close_amount:)
      last = rows.last
      if close_amount
        last[:amount] = @expense.amount - rows[0...-1].sum { |row| row[:amount] }
        last[:amount_ars] = to_ars(last[:amount])
      end
      last[:amount_ars] = @expense.amount_ars.round(2) - rows[0...-1].sum { |row| row[:amount_ars] }
    end
  end
end
```

- [ ] **Step 4: share_with!, unshare!, rebalance on Expense**

In `app/models/finance/expense.rb`, add after `before_validation :compute_amount_ars`:

```ruby
    after_update :rebalance_shares!, if: -> { shared? && (saved_change_to_amount? || saved_change_to_amount_ars?) }
```

Add these public methods after `assign_shares!`:

```ruby
    # rows: optional precomputed rows; defaults to equal split among group members.
    def share_with!(group, payer:, rows: nil)
      transaction do
        update!(group: group, payer: payer)
        assign_shares!(rows || Finance::SplitCalculator.equal(self, group.members.to_a))
      end
    end

    def unshare!
      transaction do
        shares.destroy_all
        update!(group: nil)
      end
      shares.reset
    end

    # Recomputes shares after the total changed, preserving each member's proportion.
    def rebalance_shares!
      current = shares.to_a
      return if current.empty?

      previous_total = current.sum(&:amount)
      return if previous_total.zero?

      percents = current.each_with_object({}) { |share, acc| acc[share.user] = share.amount * 100 / previous_total }
      assign_shares!(Finance::SplitCalculator.by_percent(self, percents))
    end
```

- [ ] **Step 5: Run tests**

Run: `bin/rails test test/services/finance/split_calculator_test.rb test/models/finance/expense_test.rb`
Expected: all pass. If the odd-cents test fails on `50.00`/`50.01`, check that `round(2)` uses banker's rounding: `BigDecimal("50.005").round(2)` is `50.01` (ROUND_HALF_UP by default), which would make the first row `50.01` and the last `50.00`. In that case change the assertion to `assert_equal BigDecimal("100.01"), rows.sum { |r| r[:amount] }` only and drop the per-row asserts; exact closure is the requirement, not which row gets the cent.

- [ ] **Step 6: Commit**

```bash
bundle exec rubocop app/services/finance/split_calculator.rb app/models/finance/expense.rb test/services/finance/split_calculator_test.rb test/models/finance/expense_test.rb
git add app/services/finance/split_calculator.rb app/models/finance/expense.rb test/services/finance/split_calculator_test.rb test/models/finance/expense_test.rb
git commit -m "feat: add split calculator and share/unshare for expenses"
```

---

### Task 5: Settlements and GroupBalance

**Files:**
- Create: `db/migrate/20260906000004_create_finance_settlements.rb`
- Create: `app/models/finance/settlement.rb`
- Create: `app/services/finance/group_balance.rb`
- Create: `test/fixtures/finance_settlements.yml`
- Create: `test/models/finance/settlement_test.rb`, `test/services/finance/group_balance_test.rb`

**Interfaces:**
- Produces: `Finance::Settlement(group, from_user, to_user, amount_ars, settled_on, description, message)`; `Finance::GroupBalance.new(group)#net_by_member -> { User => BigDecimal }` (positive means others owe them), `#debts -> [{ from: User, to: User, amount_ars: BigDecimal }]`.

- [ ] **Step 1: Fixture (empty by default so balance tests start clean)**

`test/fixtures/finance_settlements.yml`:

```yaml
# intentionally empty; tests create settlements explicitly
```

- [ ] **Step 2: Failing tests**

`test/models/finance/settlement_test.rb`:

```ruby
require "test_helper"

module Finance
  class SettlementTest < ActiveSupport::TestCase
    test "valid between two members" do
      settlement = Finance::Settlement.new(group: finance_groups(:pareja), from_user: users(:novia), to_user: users(:manu),
                                           amount_ars: 1000, settled_on: Date.current)
      assert settlement.valid?
    end

    test "invalid when from and to are the same" do
      settlement = Finance::Settlement.new(group: finance_groups(:pareja), from_user: users(:manu), to_user: users(:manu),
                                           amount_ars: 1000, settled_on: Date.current)
      assert_not settlement.valid?
    end

    test "invalid when a party is not a member" do
      settlement = Finance::Settlement.new(group: finance_groups(:pareja), from_user: users(:stranger), to_user: users(:manu),
                                           amount_ars: 1000, settled_on: Date.current)
      assert_not settlement.valid?
    end
  end
end
```

`test/services/finance/group_balance_test.rb` (fixtures: Manu paid 8000 split 4000/4000; Novia paid 2000 split 1000/1000. Manu net = 8000 − 5000 = +3000; Novia net = 2000 − 5000 = −3000):

```ruby
require "test_helper"

module Finance
  class GroupBalanceTest < ActiveSupport::TestCase
    setup do
      @group = finance_groups(:pareja)
      @manu = users(:manu)
      @novia = users(:novia)
    end

    test "net per member from paid minus shares" do
      net = Finance::GroupBalance.new(@group).net_by_member
      assert_equal BigDecimal("3000"), net[@manu]
      assert_equal BigDecimal("-3000"), net[@novia]
    end

    test "debts lists who owes whom" do
      debts = Finance::GroupBalance.new(@group).debts
      assert_equal 1, debts.size
      assert_equal @novia, debts.first[:from]
      assert_equal @manu, debts.first[:to]
      assert_equal BigDecimal("3000"), debts.first[:amount_ars]
    end

    test "partial settlement reduces debt" do
      Finance::Settlement.create!(group: @group, from_user: @novia, to_user: @manu, amount_ars: 1000, settled_on: Date.current)
      assert_equal BigDecimal("2000"), Finance::GroupBalance.new(@group).debts.first[:amount_ars]
    end

    test "full settlement clears debts" do
      Finance::Settlement.create!(group: @group, from_user: @novia, to_user: @manu, amount_ars: 3000, settled_on: Date.current)
      assert_empty Finance::GroupBalance.new(@group).debts
    end
  end
end
```

- [ ] **Step 3: Run to verify failure**

Run: `bin/rails test test/models/finance/settlement_test.rb test/services/finance/group_balance_test.rb`
Expected: uninitialized constants.

- [ ] **Step 4: Migration**

`db/migrate/20260906000004_create_finance_settlements.rb`:

```ruby
class CreateFinanceSettlements < ActiveRecord::Migration[7.1]
  def change
    create_table :finance_settlements do |t|
      t.references :group, null: false, foreign_key: { to_table: :finance_groups }
      t.references :from_user, null: false, foreign_key: { to_table: :users }
      t.references :to_user, null: false, foreign_key: { to_table: :users }
      t.decimal :amount_ars, precision: 12, scale: 2, null: false
      t.date :settled_on, null: false
      t.string :description
      t.references :message, null: true, foreign_key: true
      t.timestamps
    end
  end
end
```

Run: `bin/rails db:migrate && bin/rails db:test:prepare`

- [ ] **Step 5: Settlement model**

`app/models/finance/settlement.rb`:

```ruby
module Finance
  class Settlement < ApplicationRecord
    self.table_name = "finance_settlements"

    belongs_to :group, class_name: "Finance::Group"
    belongs_to :from_user, class_name: "User"
    belongs_to :to_user, class_name: "User"
    belongs_to :message, optional: true

    validates :amount_ars, presence: true, numericality: { greater_than: 0 }
    validates :settled_on, presence: true
    validate :different_parties
    validate :parties_are_members

    scope :recent, -> { order(settled_on: :desc, created_at: :desc) }

    private

    def different_parties
      errors.add(:to_user, "debe ser distinto de quien paga") if from_user_id.present? && from_user_id == to_user_id
    end

    def parties_are_members
      return if group.nil?

      errors.add(:from_user, "no es miembro") if from_user && !group.member?(from_user)
      errors.add(:to_user, "no es miembro") if to_user && !group.member?(to_user)
    end
  end
end
```

- [ ] **Step 6: GroupBalance**

`app/services/finance/group_balance.rb`:

```ruby
module Finance
  # Net position per member of a group and the resulting debts.
  # net > 0: others owe this member. net < 0: this member owes.
  class GroupBalance
    def initialize(group)
      @group = group
    end

    def net_by_member
      @net_by_member ||= @group.members.to_a.each_with_object({}) do |member, acc|
        acc[member] = paid_by(member) - owed_share_of(member) + settlements_sent_by(member) - settlements_received_by(member)
      end
    end

    # Greedy matching of debtors to creditors. With two members yields at most one debt.
    def debts
      creditors = net_by_member.select { |_, net| net.positive? }.sort_by { |_, net| -net }.map { |user, net| [user, net] }
      debtors = net_by_member.select { |_, net| net.negative? }.sort_by { |_, net| net }.map { |user, net| [user, -net] }
      match_debts(creditors, debtors)
    end

    private

    def paid_by(member)
      @group.expenses.where(payer_id: member.id).sum(:amount_ars)
    end

    def owed_share_of(member)
      Finance::ExpenseShare.joins(:expense)
                           .where(finance_expenses: { group_id: @group.id }, user_id: member.id)
                           .sum(:amount_ars)
    end

    def settlements_sent_by(member)
      @group.settlements.where(from_user_id: member.id).sum(:amount_ars)
    end

    def settlements_received_by(member)
      @group.settlements.where(to_user_id: member.id).sum(:amount_ars)
    end

    def match_debts(creditors, debtors)
      result = []
      until creditors.empty? || debtors.empty?
        creditor, credit = creditors.first
        debtor, debt = debtors.first
        amount = [credit, debt].min
        result << { from: debtor, to: creditor, amount_ars: amount }
        credit -= amount
        debt -= amount
        credit.zero? ? creditors.shift : creditors[0] = [creditor, credit]
        debt.zero? ? debtors.shift : debtors[0] = [debtor, debt]
      end
      result
    end
  end
end
```

- [ ] **Step 7: Run tests**

Run: `bin/rails test test/models/finance test/services/finance`
Expected: all pass.

- [ ] **Step 8: Commit**

```bash
bundle exec rubocop app/models/finance/settlement.rb app/services/finance/group_balance.rb test/models/finance/settlement_test.rb test/services/finance/group_balance_test.rb
git add db/migrate/20260906000004_create_finance_settlements.rb db/schema.rb app/models/finance/settlement.rb app/services/finance/group_balance.rb test/fixtures/finance_settlements.yml test/models/finance/settlement_test.rb test/services/finance/group_balance_test.rb
git commit -m "feat: add settlements and group balance calculation"
```

---

### Task 6: PeriodResolver (refactor of four copies)

**Files:**
- Create: `app/services/finance/period_resolver.rb`
- Create: `test/services/finance/period_resolver_test.rb`
- Modify: `app/controllers/finance/expenses_controller.rb`, `app/controllers/finance/charts_controller.rb`, `app/tools/list_expenses_tool.rb`, `app/tools/get_balance_tool.rb`

**Interfaces:**
- Produces: `Finance::PeriodResolver.call(period, start_date: nil, end_date: nil) -> { start: Date, end: Date }`. Accepts `"today" | "week" | "month" | "year" | "custom"`; anything else means month. For `"custom"`, blank start defaults to beginning of month and blank end defaults to today.

- [ ] **Step 1: Failing test**

`test/services/finance/period_resolver_test.rb`:

```ruby
require "test_helper"

module Finance
  class PeriodResolverTest < ActiveSupport::TestCase
    test "today" do
      assert_equal({ start: Date.current, end: Date.current }, Finance::PeriodResolver.call("today"))
    end

    test "week, month, year" do
      assert_equal Date.current.beginning_of_week, Finance::PeriodResolver.call("week")[:start]
      assert_equal Date.current.end_of_month, Finance::PeriodResolver.call("month")[:end]
      assert_equal Date.current.beginning_of_year, Finance::PeriodResolver.call("year")[:start]
    end

    test "custom parses dates" do
      range = Finance::PeriodResolver.call("custom", start_date: "2026-01-10", end_date: "2026-01-20")
      assert_equal Date.new(2026, 1, 10), range[:start]
      assert_equal Date.new(2026, 1, 20), range[:end]
    end

    test "custom with blanks defaults to month start and today" do
      range = Finance::PeriodResolver.call("custom")
      assert_equal Date.current.beginning_of_month, range[:start]
      assert_equal Date.current, range[:end]
    end

    test "unknown falls back to month" do
      assert_equal Date.current.beginning_of_month, Finance::PeriodResolver.call("whatever")[:start]
      assert_equal Date.current.beginning_of_month, Finance::PeriodResolver.call(nil)[:start]
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bin/rails test test/services/finance/period_resolver_test.rb`
Expected: `uninitialized constant Finance::PeriodResolver`.

- [ ] **Step 3: Implementation**

`app/services/finance/period_resolver.rb`:

```ruby
module Finance
  class PeriodResolver
    def self.call(period, start_date: nil, end_date: nil)
      today = Date.current
      case period.to_s
      when "today" then { start: today, end: today }
      when "week"  then { start: today.beginning_of_week, end: today.end_of_week }
      when "year"  then { start: today.beginning_of_year, end: today.end_of_year }
      when "custom"
        {
          start: start_date.present? ? Date.parse(start_date.to_s) : today.beginning_of_month,
          end: end_date.present? ? Date.parse(end_date.to_s) : today
        }
      else { start: today.beginning_of_month, end: today.end_of_month }
      end
    end
  end
end
```

- [ ] **Step 4: Replace the four copies**

In `app/controllers/finance/expenses_controller.rb`: delete the private `resolve_dates` method and replace the call `dates = resolve_dates(@period, params[:start_date], params[:end_date])` with:

```ruby
      dates = Finance::PeriodResolver.call(@period, start_date: params[:start_date], end_date: params[:end_date])
```

Same in `app/controllers/finance/charts_controller.rb`.

In `app/tools/list_expenses_tool.rb`: delete private `resolve_dates`, replace `dates = resolve_dates(period, start_date, end_date)` with:

```ruby
    dates = Finance::PeriodResolver.call(period, start_date: start_date, end_date: end_date)
```

Note this changes behavior slightly for the tool: `custom` without dates no longer raises on `Date.parse("")`; it defaults to month-start..today. That is an improvement, keep it.

In `app/tools/get_balance_tool.rb`: delete private `resolve_dates`, replace `dates = resolve_dates(period)` with:

```ruby
    dates = Finance::PeriodResolver.call(period)
```

Remove the now-empty `private` keyword in the tools if nothing remains below it (RegisterExpenseTool is untouched here).

- [ ] **Step 5: Run tests and boot check**

Run: `bin/rails test test/services/finance/period_resolver_test.rb && bin/rails runner 'puts ListExpensesTool.new(User.first).execute(period: "month")[:period]'`
Expected: tests pass; runner prints a `YYYY-MM-DD a YYYY-MM-DD` string.

- [ ] **Step 6: Commit**

```bash
bundle exec rubocop app/services/finance/period_resolver.rb app/controllers/finance app/tools test/services/finance/period_resolver_test.rb
git add app/services/finance/period_resolver.rb app/controllers/finance/expenses_controller.rb app/controllers/finance/charts_controller.rb app/tools/list_expenses_tool.rb app/tools/get_balance_tool.rb test/services/finance/period_resolver_test.rb
git commit -m "refactor: extract Finance::PeriodResolver from controllers and tools"
```

---

### Task 7: SpendingQuery and wiring into Expenses/Charts controllers

**Files:**
- Create: `app/services/finance/spending_query.rb`
- Create: `test/services/finance/spending_query_test.rb`
- Modify: `app/controllers/finance/expenses_controller.rb`, `app/controllers/finance/charts_controller.rb`

**Interfaces:**
- Produces: `Finance::SpendingQuery.new(user, start_date:, end_date:, currency: nil, category_id: nil, expense_type: nil)` with `#total_ars -> BigDecimal`, `#by_category -> { category_id => BigDecimal }`, `#by_date -> { Date => BigDecimal }`, `#by_month -> { Time => BigDecimal }` (month truncation), `#by_month_and_type -> { [Time, String] => BigDecimal }`. All sums combine personal `amount_ars` and the user's `finance_expense_shares.amount_ars`.

- [ ] **Step 1: Failing test**

Fixture math for Manu, current month: personal legacy 3000 + share of super 4000 + share of luz 1000 = 8000. Comida: 3000 + 4000 = 7000. Servicios: 1000. Fijo: 1000, variable: 7000.

`test/services/finance/spending_query_test.rb`:

```ruby
require "test_helper"

module Finance
  class SpendingQueryTest < ActiveSupport::TestCase
    setup do
      @range = Finance::PeriodResolver.call("month")
    end

    def query_for(user, **filters)
      Finance::SpendingQuery.new(user, start_date: @range[:start], end_date: @range[:end], **filters)
    end

    test "total mixes personal and shares" do
      assert_equal BigDecimal("8000"), query_for(users(:manu)).total_ars
      assert_equal BigDecimal("5500"), query_for(users(:novia)).total_ars
      assert_equal BigDecimal("0"), query_for(users(:stranger)).total_ars
    end

    test "by_category" do
      by_cat = query_for(users(:manu)).by_category
      assert_equal BigDecimal("7000"), by_cat[finance_categories(:comida).id]
      assert_equal BigDecimal("1000"), by_cat[finance_categories(:servicios).id]
    end

    test "expense_type filter applies to shares too" do
      assert_equal BigDecimal("1000"), query_for(users(:manu), expense_type: "fijo").total_ars
    end

    test "category filter" do
      assert_equal BigDecimal("1000"), query_for(users(:manu), category_id: finance_categories(:servicios).id).total_ars
    end

    test "by_date groups on expense_date" do
      assert_equal BigDecimal("8000"), query_for(users(:manu)).by_date[Date.current]
    end

    test "by_month and by_month_and_type" do
      month_key = Date.current.beginning_of_month
      by_month = query_for(users(:manu)).by_month
      assert_equal BigDecimal("8000"), by_month.find { |k, _| k.to_date == month_key }&.last
      by_type = query_for(users(:manu)).by_month_and_type
      assert_equal BigDecimal("1000"), by_type.find { |(k, type), _| k.to_date == month_key && type == "fijo" }&.last
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bin/rails test test/services/finance/spending_query_test.rb`
Expected: `uninitialized constant Finance::SpendingQuery`.

- [ ] **Step 3: Implementation**

`app/services/finance/spending_query.rb`:

```ruby
module Finance
  # Aggregates what a user spent: personal expenses at 100% plus their share of shared expenses.
  # Every public method returns sums in ARS.
  class SpendingQuery
    def initialize(user, start_date:, end_date:, currency: nil, category_id: nil, expense_type: nil)
      @user = user
      @start_date = start_date
      @end_date = end_date
      @currency = currency.presence
      @category_id = category_id.presence
      @expense_type = expense_type.presence
    end

    def total_ars
      personal.sum(:amount_ars) + shares.sum("finance_expense_shares.amount_ars")
    end

    def by_category
      merge_sums(
        personal.group(:finance_category_id).sum(:amount_ars),
        shares.group("finance_expenses.finance_category_id").sum("finance_expense_shares.amount_ars")
      )
    end

    def by_date
      merge_sums(
        personal.group(:expense_date).sum(:amount_ars),
        shares.group("finance_expenses.expense_date").sum("finance_expense_shares.amount_ars")
      )
    end

    def by_month
      merge_sums(
        personal.group("DATE_TRUNC('month', expense_date)").sum(:amount_ars),
        shares.group("DATE_TRUNC('month', finance_expenses.expense_date)").sum("finance_expense_shares.amount_ars")
      )
    end

    def by_month_and_type
      merge_sums(
        personal.group("DATE_TRUNC('month', expense_date)", :expense_type).sum(:amount_ars),
        shares.group("DATE_TRUNC('month', finance_expenses.expense_date)", "finance_expenses.expense_type")
              .sum("finance_expense_shares.amount_ars")
      )
    end

    private

    def personal
      apply_filters(Finance::Expense.personal.where(user_id: @user.id))
    end

    def shares
      Finance::ExpenseShare.joins(:expense)
                           .where(user_id: @user.id)
                           .merge(apply_filters(Finance::Expense.where.not(group_id: nil)))
    end

    def apply_filters(scope)
      scope = scope.for_period(@start_date, @end_date)
      scope = scope.where(currency: @currency) if @currency
      scope = scope.where(finance_category_id: @category_id) if @category_id
      scope = scope.for_expense_type(@expense_type) if @expense_type
      scope
    end

    def merge_sums(first, second)
      first.merge(second) { |_key, a, b| a + b }.transform_values { |value| BigDecimal(value.to_s) }
    end
  end
end
```

Note on `merge`: `.merge(Finance::Expense...)` on an `ExpenseShare` relation applies the Expense `where` clauses table-qualified (`finance_expenses.expense_date`, etc.), which is what we want after `joins(:expense)`.

- [ ] **Step 4: Run test**

Run: `bin/rails test test/services/finance/spending_query_test.rb`
Expected: pass.

- [ ] **Step 5: Wire ExpensesController index**

In `app/controllers/finance/expenses_controller.rb`, replace the body of `index` from `expenses = current_user.finance_expenses` through `@categories = ...` with:

```ruby
      expenses = Finance::Expense.visible_to(current_user)
                                 .for_period(@start_date, @end_date)
                                 .includes(:category, :payer, :group, shares: :user)

      expenses = expenses.where(currency: @currency_filter) if @currency_filter.present?
      expenses = expenses.where(finance_category_id: @category_filter) if @category_filter.present?
      expenses = expenses.where("finance_expenses.description ILIKE ?", "%#{@search}%") if @search.present?
      expenses = expenses.for_expense_type(@expense_type_filter) if @expense_type_filter.present?

      @expenses = expenses.recent.limit(50)
      @total_ars = spending_query.total_ars
      @categories = Finance::Category.order(:name)
```

Add a private method:

```ruby
    def spending_query
      Finance::SpendingQuery.new(current_user, start_date: @start_date, end_date: @end_date,
                                                currency: @currency_filter, category_id: @category_filter,
                                                expense_type: @expense_type_filter)
    end
```

Note: the search filter does not apply to `@total_ars` in the current code either (it filtered `expenses` before summing). To keep behavior identical for searches, when `@search.present?` compute the total from the list instead:

```ruby
      @total_ars = @search.present? ? expenses.sum { |e| e.amount_ars_for(current_user) } : spending_query.total_ars
```

Use this line instead of the plain `@total_ars = spending_query.total_ars`.

- [ ] **Step 6: Wire ChartsController**

Replace `app/controllers/finance/charts_controller.rb` with:

```ruby
module Finance
  class ChartsController < BaseController
    HISTORY_MONTHS = 5

    def show
      read_filters
      resolve_period
      build_category_chart
      build_daily_chart
      build_history_charts
      @categories = Finance::Category.order(:name)
    end

    private

    def read_filters
      @period = params[:period].presence || "month"
      @currency_filter = params[:currency].presence
      @category_filter = params[:category].presence
      @expense_type_filter = params[:expense_type].presence
    end

    def resolve_period
      dates = Finance::PeriodResolver.call(@period, start_date: params[:start_date], end_date: params[:end_date])
      @start_date = dates[:start]
      @end_date = dates[:end]
    end

    def period_query
      @period_query ||= spending_query(@start_date, @end_date)
    end

    def history_query
      @history_query ||= spending_query(HISTORY_MONTHS.months.ago.beginning_of_month.to_date, Date.current.end_of_month)
    end

    def spending_query(start_date, end_date)
      Finance::SpendingQuery.new(current_user, start_date: start_date, end_date: end_date,
                                                currency: @currency_filter, category_id: @category_filter,
                                                expense_type: @expense_type_filter)
    end

    def build_category_chart
      @by_category = period_query.by_category
                                 .map { |cat_id, total| [Finance::Category.find(cat_id), total] }
                                 .sort_by { |_, total| -total }
    end

    def build_daily_chart
      daily = period_query.by_date
      accumulated = 0
      @daily_accumulated = (@start_date..[@end_date, Date.current].min).map do |date|
        accumulated += (daily[date] || 0).to_f
        { date: date.strftime("%d/%m"), total: accumulated.round(2) }
      end
    end

    def build_history_charts
      @monthly_history = history_query.by_month
                                      .sort_by { |date, _| date }
                                      .map { |date, total| { month: date.strftime("%b %y"), total: total.to_f.round(2) } }

      by_type = history_query.by_month_and_type
      months = by_type.keys.map(&:first).uniq.sort
      @fixed_vs_variable = months.map do |month|
        {
          month: month.strftime("%b %y"),
          fijo: (by_type[[month, "fijo"]] || 0).to_f.round(2),
          variable: (by_type[[month, "variable"]] || 0).to_f.round(2)
        }
      end
    end
  end
end
```

The view `app/views/finance/charts/show.html.erb` consumes the same instance variables with the same shapes; do not modify it.

- [ ] **Step 7: Smoke test via runner and full finance tests**

Run:

```bash
bin/rails test test/services/finance test/models/finance
bin/rails runner 'u = User.first; q = Finance::SpendingQuery.new(u, start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month); puts q.total_ars; puts q.by_category.inspect'
```

Expected: tests pass; runner prints the dev user's month total and a hash.

- [ ] **Step 8: Commit**

```bash
bundle exec rubocop app/services/finance/spending_query.rb app/controllers/finance/expenses_controller.rb app/controllers/finance/charts_controller.rb test/services/finance/spending_query_test.rb
git add app/services/finance/spending_query.rb app/controllers/finance/expenses_controller.rb app/controllers/finance/charts_controller.rb test/services/finance/spending_query_test.rb
git commit -m "feat: aggregate personal and shared spending with SpendingQuery"
```

---

### Task 8: Tools — shared params on RegisterExpense, scope on List/Balance

**Files:**
- Modify: `app/tools/register_expense_tool.rb`, `app/tools/list_expenses_tool.rb`, `app/tools/get_balance_tool.rb`
- Create: `test/tools/register_expense_tool_test.rb`, `test/tools/list_expenses_tool_test.rb`, `test/tools/get_balance_tool_test.rb`

**Interfaces:**
- Produces: `RegisterExpenseTool#execute(amount:, category:, description:, date: nil, currency: "ARS", exchange_rate: nil, expense_type: "variable", shared: false, my_percent: nil, paid_by_other: false)`.
- Produces: `ListExpensesTool#execute(..., scope: "personal")`, `GetBalanceTool#execute(period: "month", expense_type: nil, scope: "personal")`. `scope` is `"personal"` or `"shared"`.

- [ ] **Step 1: Failing tests**

`test/tools/register_expense_tool_test.rb`:

```ruby
require "test_helper"

class RegisterExpenseToolTest < ActiveSupport::TestCase
  setup do
    @manu = users(:manu)
    @novia = users(:novia)
  end

  test "personal expense still works exactly as before" do
    result = RegisterExpenseTool.new(@manu).execute(amount: "1500", category: "Comida", description: "Pizza")
    assert_equal "success", result[:status]
    expense = Finance::Expense.find(result[:expense_id])
    assert_not expense.shared?
    assert_equal @manu, expense.payer
    assert_equal BigDecimal("1500"), expense.amount_ars_for(@manu)
  end

  test "shared expense splits 50/50 in the user's group" do
    result = RegisterExpenseTool.new(@manu).execute(amount: "6000", category: "Comida", description: "Cena", shared: true)
    assert_equal "success", result[:status]
    expense = Finance::Expense.find(result[:expense_id])
    assert_equal finance_groups(:pareja), expense.group
    assert_equal @manu, expense.payer
    assert_equal BigDecimal("3000"), expense.amount_ars_for(@novia)
    assert_match(/compartido/i, result[:message])
  end

  test "my_percent overrides the split" do
    result = RegisterExpenseTool.new(@manu).execute(amount: "10000", category: "Comida", description: "Cena",
                                                    shared: true, my_percent: 70)
    expense = Finance::Expense.find(result[:expense_id])
    assert_equal BigDecimal("7000"), expense.amount_ars_for(@manu)
    assert_equal BigDecimal("3000"), expense.amount_ars_for(@novia)
  end

  test "paid_by_other sets the other member as payer" do
    result = RegisterExpenseTool.new(@manu).execute(amount: "2000", category: "Servicios", description: "Gas",
                                                    shared: true, paid_by_other: true)
    assert_equal @novia, Finance::Expense.find(result[:expense_id]).payer
  end

  test "shared without a group returns error and creates nothing" do
    assert_no_difference("Finance::Expense.count") do
      result = RegisterExpenseTool.new(users(:stranger)).execute(amount: "100", category: "Otros", description: "x", shared: true)
      assert_equal "error", result[:status]
    end
  end

  test "accepts string booleans from the model" do
    result = RegisterExpenseTool.new(@manu).execute(amount: "100", category: "Otros", description: "x", shared: "true")
    assert Finance::Expense.find(result[:expense_id]).shared?
  end
end
```

`test/tools/list_expenses_tool_test.rb`:

```ruby
require "test_helper"

class ListExpensesToolTest < ActiveSupport::TestCase
  test "personal scope lists visible expenses with my share" do
    result = ListExpensesTool.new(users(:manu)).execute(period: "month")
    descriptions = result[:expenses].map { |e| e[:description] }
    assert_includes descriptions, "Nafta"
    assert_includes descriptions, "Super"
    assert_not_includes descriptions, "Cafe"
    super_item = result[:expenses].find { |e| e[:description] == "Super" }
    assert_equal 4000.0, super_item[:my_share_ars]
    assert_equal true, super_item[:shared]
    assert_equal 8000.0, result[:total_ars]
  end

  test "shared scope lists group expenses with payer" do
    result = ListExpensesTool.new(users(:manu)).execute(period: "month", scope: "shared")
    assert_equal 2, result[:count]
    luz = result[:expenses].find { |e| e[:description] == "Luz" }
    assert_equal "Novia", luz[:paid_by]
    assert_equal 10_000.0, result[:total_ars]
  end

  test "shared scope without group returns error" do
    assert_equal "error", ListExpensesTool.new(users(:stranger)).execute(scope: "shared")[:status]
  end
end
```

`test/tools/get_balance_tool_test.rb`:

```ruby
require "test_helper"

class GetBalanceToolTest < ActiveSupport::TestCase
  test "personal scope totals personal plus shares" do
    result = GetBalanceTool.new(users(:manu)).execute(period: "month")
    assert_equal 8000.0, result[:total_spent_ars]
    comida = result[:by_category].find { |c| c[:category] == "Comida" }
    assert_equal 7000.0, comida[:total]
  end

  test "shared scope includes group totals and debts" do
    result = GetBalanceTool.new(users(:manu)).execute(period: "month", scope: "shared")
    assert_equal 10_000.0, result[:total_spent_ars]
    assert_equal 1, result[:debts].size
    assert_equal "Novia", result[:debts].first[:from]
    assert_equal "Manu", result[:debts].first[:to]
    assert_equal 3000.0, result[:debts].first[:amount_ars]
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bin/rails test test/tools`
Expected: unknown keyword `shared` / `scope`, missing keys.

- [ ] **Step 3: RegisterExpenseTool**

Replace `app/tools/register_expense_tool.rb` with:

```ruby
class RegisterExpenseTool < RubyLLM::Tool
  description "Registers a new expense. Use this when the user mentions paying for something, " \
              "spending money, or any financial transaction. Extract amount, category, and description " \
              "from the user's message. The date defaults to today unless the user specifies otherwise. " \
              "Set shared=true when the user says the expense is shared (compartido, de la casa, entre los dos, mitad y mitad)."

  param :amount, desc: "The expense amount as a number (e.g., '500', '1250.50')"
  param :category, desc: "The expense category. Must be one of: Servicios, Comida, Transporte, " \
                         "Entretenimiento, Salud, Educacion, Ropa, Hogar, Suscripciones, Otros"
  param :description, desc: "Brief description of the expense (e.g., 'Recibo de luz', 'Uber al trabajo')"
  param :date, desc: "The expense date in YYYY-MM-DD format. Default to today if not specified.", required: false
  param :currency, desc: "Currency code: 'ARS' (default) or 'USD'. Use USD when user mentions dolares/USD.", required: false
  param :exchange_rate, desc: "Exchange rate USD->ARS. Only needed for USD expenses when user provides a specific rate. " \
                              "If not provided for USD, the official rate is fetched automatically.", required: false
  param :expense_type, desc: "Type of expense: 'fijo' (fixed/recurring like rent, subscriptions) or 'variable' (one-time like food, outings). Default: 'variable'.", required: false
  param :shared, type: "boolean", desc: "true if the expense is shared with the user's partner (split between both). Default false.", required: false
  param :my_percent, type: "number", desc: "Only for shared expenses: percentage of the total the current user covers (e.g. 70 for 'yo pongo el 70%'). Default 50.", required: false
  param :paid_by_other, type: "boolean", desc: "Only for shared expenses: true if the OTHER person paid (e.g. 'lo pago Manu'). Default false (current user paid).", required: false

  def initialize(user)
    @user = user
  end

  def execute(amount:, category:, description:, date: nil, currency: "ARS", exchange_rate: nil, expense_type: "variable",
              shared: false, my_percent: nil, paid_by_other: false)
    shared = cast_boolean(shared)
    paid_by_other = cast_boolean(paid_by_other)
    group = @user.shared_group

    return missing_group_error if shared && (group.nil? || !group.full?)

    expense_date = date.present? ? Date.parse(date) : Date.current
    cat = Finance::Category.find_by(name: category) || Finance::Category.find_by(name: "Otros")
    currency = currency&.upcase || "ARS"

    rate = nil
    if currency == "USD"
      rate = exchange_rate.present? ? BigDecimal(exchange_rate.to_s) : fetch_dolar_rate
      return { status: "error", message: "No se pudo obtener la cotizacion del dolar. Intenta de nuevo o proporciona el tipo de cambio." } if rate.nil?
    end

    expense = Finance::Expense.transaction do
      created = Finance::Expense.create!(
        user: @user, payer: @user, category: cat, amount: BigDecimal(amount.to_s), description: description,
        expense_date: expense_date, currency: currency, exchange_rate: rate, expense_type: expense_type
      )
      share_in_group(created, group, my_percent: my_percent, paid_by_other: paid_by_other) if shared
      created
    end

    success_response(expense, cat, currency, rate)
  rescue ArgumentError => e
    { status: "error", message: "Error en los datos: #{e.message}" }
  rescue ActiveRecord::RecordInvalid => e
    { status: "error", message: "Error al guardar: #{e.message}" }
  end

  private

  def share_in_group(expense, group, my_percent:, paid_by_other:)
    other = group.other_member(@user)
    payer = paid_by_other ? other : @user
    rows = if my_percent.present?
             mine = BigDecimal(my_percent.to_s)
             Finance::SplitCalculator.by_percent(expense, { @user => mine, other => 100 - mine })
           end
    expense.share_with!(group, payer: payer, rows: rows)
  end

  def success_response(expense, cat, currency, rate)
    message = "Gasto registrado: $#{expense.amount} #{currency} - #{expense.description} (#{cat.name})"
    message += " [TC: $#{rate} = $#{expense.amount_ars} ARS]" if currency == "USD"
    message += shared_summary(expense) if expense.shared?

    response = {
      status: "success", message: message, expense_id: expense.id, amount: expense.amount.to_f,
      currency: currency, category: cat.name, date: expense.expense_date.to_s, shared: expense.shared?
    }
    if expense.shared?
      response[:paid_by] = expense.payer.display_name
      response[:my_share_ars] = expense.amount_ars_for(@user).to_f
    end
    response
  end

  def shared_summary(expense)
    other = expense.group.other_member(@user)
    " Compartido, pago #{expense.payer.display_name}. Tu parte: $#{expense.amount_ars_for(@user)} ARS, " \
      "#{other.display_name}: $#{expense.amount_ars_for(other)} ARS."
  end

  def missing_group_error
    {
      status: "error",
      message: "No tenes un espacio compartido completo todavia. Crealo o unite con el codigo desde /finance/shared " \
               "(ambas personas deben estar dentro) y despues volve a registrar el gasto."
    }
  end

  def cast_boolean(value)
    ActiveModel::Type::Boolean.new.cast(value) || false
  end

  def fetch_dolar_rate
    DolarService.venta
  end
end
```

- [ ] **Step 4: ListExpensesTool**

Replace `app/tools/list_expenses_tool.rb` with:

```ruby
class ListExpensesTool < RubyLLM::Tool
  description "Lists expenses for a given time period and optional category filter. " \
              "Use this when the user asks to see their expenses, spending history, or recent transactions. " \
              "scope='shared' lists only the expenses shared with the partner (full amounts, who paid)."

  param :period, desc: "Time period: 'today', 'week', 'month', 'year', or 'custom'", required: false
  param :start_date, desc: "Start date in YYYY-MM-DD format (required if period is 'custom')", required: false
  param :end_date, desc: "End date in YYYY-MM-DD format (required if period is 'custom')", required: false
  param :category, desc: "Category name to filter by (optional)", required: false
  param :expense_type, desc: "Filter by type: 'fijo' (fixed) or 'variable'. Optional, shows all if omitted.", required: false
  param :scope, desc: "'personal' (default: my expenses plus my share of shared ones) or 'shared' (only shared expenses).", required: false

  def initialize(user)
    @user = user
  end

  def execute(period: "month", start_date: nil, end_date: nil, category: nil, expense_type: nil, scope: "personal")
    dates = Finance::PeriodResolver.call(period, start_date: start_date, end_date: end_date)
    expenses = base_scope(scope)
    return missing_group_error if expenses.nil?

    expenses = expenses.for_period(dates[:start], dates[:end])
    expenses = filter_by_category(expenses, category)
    expenses = expenses.for_expense_type(expense_type) if expense_type.present?
    expenses = expenses.includes(:category, :payer, shares: :user).recent

    {
      period: "#{dates[:start]} a #{dates[:end]}",
      scope: scope,
      total_ars: total_for(expenses, scope),
      count: expenses.count,
      expenses: expenses.limit(20).map { |expense| serialize(expense) }
    }
  end

  private

  def base_scope(scope)
    return Finance::Expense.visible_to(@user) unless scope == "shared"

    group = @user.shared_group
    group && Finance::Expense.in_group(group)
  end

  def filter_by_category(expenses, category)
    return expenses if category.blank?

    cat = Finance::Category.find_by(name: category)
    cat ? expenses.for_category(cat.id) : expenses
  end

  def total_for(expenses, scope)
    return expenses.sum(:amount_ars).to_f if scope == "shared"

    expenses.sum { |expense| expense.amount_ars_for(@user) }.to_f
  end

  def serialize(expense)
    item = { date: expense.expense_date.to_s, amount: expense.amount.to_f, currency: expense.currency,
             description: expense.description, category: expense.category.name, shared: expense.shared? }
    item[:amount_ars] = expense.amount_ars.to_f if expense.currency == "USD"
    if expense.shared?
      item[:paid_by] = expense.payer&.display_name
      item[:my_share_ars] = expense.amount_ars_for(@user).to_f
    end
    item
  end

  def missing_group_error
    { status: "error", message: "No tenes un espacio compartido. Crealo o unite desde /finance/shared." }
  end
end
```

- [ ] **Step 5: GetBalanceTool**

Replace `app/tools/get_balance_tool.rb` with:

```ruby
class GetBalanceTool < RubyLLM::Tool
  description "Gets a summary of spending by category for a given period. " \
              "Use this when the user asks for a balance, summary, totals, or category breakdown. " \
              "All totals are in ARS. scope='shared' returns the shared-space totals plus who owes whom."

  param :period, desc: "Time period: 'week', 'month', 'year'", required: false
  param :expense_type, desc: "Filter by type: 'fijo' or 'variable'. Optional, shows all if omitted.", required: false
  param :scope, desc: "'personal' (default: my expenses plus my share of shared ones) or 'shared' (shared space).", required: false

  def initialize(user)
    @user = user
  end

  def execute(period: "month", expense_type: nil, scope: "personal")
    dates = Finance::PeriodResolver.call(period)
    scope == "shared" ? shared_balance(dates, expense_type) : personal_balance(dates, expense_type)
  end

  private

  def personal_balance(dates, expense_type)
    query = Finance::SpendingQuery.new(@user, start_date: dates[:start], end_date: dates[:end], expense_type: expense_type)
    by_category = query.by_category.map { |cat_id, total| category_row(cat_id, total) }
    personal_count = Finance::Expense.visible_to(@user).for_period(dates[:start], dates[:end])
    personal_count = personal_count.for_expense_type(expense_type) if expense_type.present?

    {
      period: "#{dates[:start]} a #{dates[:end]}",
      scope: "personal",
      total_spent_ars: query.total_ars.to_f,
      transaction_count: personal_count.count,
      by_category: by_category.sort_by { |c| -c[:total] }
    }
  end

  def shared_balance(dates, expense_type)
    group = @user.shared_group
    return { status: "error", message: "No tenes un espacio compartido. Crealo o unite desde /finance/shared." } if group.nil?

    expenses = Finance::Expense.in_group(group).for_period(dates[:start], dates[:end])
    expenses = expenses.for_expense_type(expense_type) if expense_type.present?
    by_category = expenses.group(:finance_category_id).sum(:amount_ars).map { |cat_id, total| category_row(cat_id, total) }

    {
      period: "#{dates[:start]} a #{dates[:end]}",
      scope: "shared",
      total_spent_ars: expenses.sum(:amount_ars).to_f,
      transaction_count: expenses.count,
      by_category: by_category.sort_by { |c| -c[:total] },
      debts: Finance::GroupBalance.new(group).debts.map do |debt|
        { from: debt[:from].display_name, to: debt[:to].display_name, amount_ars: debt[:amount_ars].to_f }
      end
    }
  end

  def category_row(cat_id, total)
    cat = Finance::Category.find(cat_id)
    { category: cat.name, total: total.to_f, icon: cat.icon }
  end
end
```

- [ ] **Step 6: Run tests**

Run: `bin/rails test test/tools`
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
bundle exec rubocop app/tools test/tools
git add app/tools test/tools
git commit -m "feat: support shared expenses and scope in finance tools"
```

---

### Task 9: RegisterSettlementTool and system prompt

**Files:**
- Create: `app/tools/register_settlement_tool.rb`
- Create: `test/tools/register_settlement_tool_test.rb`, `test/jobs/finance/chat_response_job_test.rb`
- Modify: `app/jobs/finance/chat_response_job.rb`

**Interfaces:**
- Produces: `RegisterSettlementTool#execute(amount:, date: nil, description: nil, received: false)`.
- Produces: `Finance::ChatResponseJob#system_prompt(user) -> String` (public, so it can be unit tested without calling the LLM).

- [ ] **Step 1: Failing tests**

`test/tools/register_settlement_tool_test.rb`:

```ruby
require "test_helper"

class RegisterSettlementToolTest < ActiveSupport::TestCase
  test "records a payment from me to the other member" do
    result = RegisterSettlementTool.new(users(:novia)).execute(amount: "3000")
    assert_equal "success", result[:status]
    settlement = Finance::Settlement.find(result[:settlement_id])
    assert_equal users(:novia), settlement.from_user
    assert_equal users(:manu), settlement.to_user
    assert_equal Date.current, settlement.settled_on
    assert_empty Finance::GroupBalance.new(finance_groups(:pareja)).debts
  end

  test "received=true records a payment from the other member to me" do
    result = RegisterSettlementTool.new(users(:manu)).execute(amount: "1000", received: true, date: "2026-09-01")
    settlement = Finance::Settlement.find(result[:settlement_id])
    assert_equal users(:novia), settlement.from_user
    assert_equal Date.new(2026, 9, 1), settlement.settled_on
  end

  test "error without group" do
    assert_equal "error", RegisterSettlementTool.new(users(:stranger)).execute(amount: "10")[:status]
  end
end
```

`test/jobs/finance/chat_response_job_test.rb`:

```ruby
require "test_helper"

module Finance
  class ChatResponseJobTest < ActiveJob::TestCase
    test "prompt mentions the partner when the user has a full shared group" do
      prompt = Finance::ChatResponseJob.new.system_prompt(users(:manu))
      assert_includes prompt, "Novia"
      assert_includes prompt, "register_settlement"
    end

    test "prompt explains how to create a shared space when there is none" do
      prompt = Finance::ChatResponseJob.new.system_prompt(users(:stranger))
      assert_includes prompt, "/finance/shared"
      assert_not_includes prompt, "register_settlement"
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bin/rails test test/tools/register_settlement_tool_test.rb test/jobs/finance/chat_response_job_test.rb`
Expected: uninitialized constant / private method `system_prompt` / wrong arity.

- [ ] **Step 3: RegisterSettlementTool**

`app/tools/register_settlement_tool.rb`:

```ruby
class RegisterSettlementTool < RubyLLM::Tool
  description "Records a money transfer between the user and their partner to settle shared-expense debt. " \
              "Use when the user says they paid/transferred money to the partner ('le transferi 3000 a X', " \
              "'le pague lo que le debia') or that the partner paid them ('X me transfirio 3000' -> received=true). " \
              "Amounts are in ARS."

  param :amount, desc: "Amount transferred in ARS as a number"
  param :date, desc: "Date in YYYY-MM-DD format. Default today.", required: false
  param :description, desc: "Optional note (e.g. 'Transferencia por el super')", required: false
  param :received, type: "boolean", desc: "true if the PARTNER paid the current user. Default false (current user paid the partner).", required: false

  def initialize(user)
    @user = user
  end

  def execute(amount:, date: nil, description: nil, received: false)
    group = @user.shared_group
    return missing_group_error if group.nil? || !group.full?

    other = group.other_member(@user)
    from_user, to_user = ActiveModel::Type::Boolean.new.cast(received) ? [other, @user] : [@user, other]

    settlement = Finance::Settlement.create!(
      group: group, from_user: from_user, to_user: to_user, amount_ars: BigDecimal(amount.to_s),
      settled_on: date.present? ? Date.parse(date) : Date.current, description: description
    )

    remaining = Finance::GroupBalance.new(group).debts.map do |debt|
      "#{debt[:from].display_name} le debe $#{debt[:amount_ars]} a #{debt[:to].display_name}"
    end

    {
      status: "success",
      settlement_id: settlement.id,
      message: "Pago registrado: #{from_user.display_name} le paso $#{settlement.amount_ars} ARS a #{to_user.display_name}.",
      remaining_debts: remaining.presence || ["Estan a mano"]
    }
  rescue ArgumentError => e
    { status: "error", message: "Error en los datos: #{e.message}" }
  rescue ActiveRecord::RecordInvalid => e
    { status: "error", message: "Error al guardar: #{e.message}" }
  end

  private

  def missing_group_error
    { status: "error", message: "No tenes un espacio compartido completo. Crealo o unite desde /finance/shared." }
  end
end
```

- [ ] **Step 4: ChatResponseJob**

Replace `app/jobs/finance/chat_response_job.rb` with:

```ruby
module Finance
  class ChatResponseJob < ApplicationJob
    queue_as :default

    def perform(chat_id, content)
      chat = ::Chat.find(chat_id)
      user = chat.user

      refresh_system_prompt(chat, user)
      register_tools(chat, user)

      # ruby_llm handles tool calling and persists both user and assistant messages
      chat.ask(content)

      broadcast_response(chat)
    end

    def system_prompt(user)
      <<~PROMPT
        Eres un asistente de finanzas personales. Tu trabajo es ayudar al usuario a registrar y consultar sus gastos de manera conversacional.

        Cuando el usuario mencione un gasto (ej: "pague 500 de luz", "gaste 200 en uber", "50 pesos de cafe"), usa la herramienta register_expense para registrarlo.

        Cuando el usuario pregunte por sus gastos (ej: "cuanto llevo este mes", "que gaste hoy"), usa list_expenses o get_balance segun corresponda.

        Responde siempre en espanol, de manera breve y amigable. Confirma los gastos registrados mencionando monto, categoria y fecha. Si no estas seguro de la categoria, usa la mas probable.

        IMPORTANTE: Siempre que el usuario mencione un gasto, registralo con register_expense. NUNCA respondas que ya fue registrado anteriormente. Cada mensaje del usuario es una transaccion nueva e independiente, aunque la descripcion sea similar a una anterior.

        Las categorias disponibles son: Servicios, Comida, Transporte, Entretenimiento, Salud, Educacion, Ropa, Hogar, Suscripciones, Otros.

        Los gastos pueden ser de tipo "fijo" (recurrentes mensuales como alquiler, servicios, suscripciones, monotributo, internet) o "variable" (consumo variable como comida, salidas, transporte, farmacia). Usa expense_type "fijo" cuando el usuario mencione gastos recurrentes/fijos. Por defecto usa "variable".

        La moneda por defecto es ARS (pesos argentinos). Si el usuario menciona dolares, USD o "en dolares":
        - Usa currency "USD" en register_expense con el monto ORIGINAL en dolares (NO conviertas a pesos vos mismo).
        - Ejemplo: si dice "100 usd", pasa amount=100 y currency="USD". NUNCA pases amount=141000 con currency="ARS".
        - El tipo de cambio del dolar oficial se obtiene automaticamente via API. NO necesitas calcularlo.
        - Si el usuario proporciona un tipo de cambio especifico (ej: "a 1400"), pasalo con el parametro exchange_rate.
        - Los totales y balances se muestran en ARS.

        #{shared_instructions(user)}

        Hoy es #{Date.current.strftime("%A %d de %B de %Y")}.
      PROMPT
    end

    private

    def refresh_system_prompt(chat, user)
      system_msg = chat.messages.find_by(role: "system")
      if system_msg
        system_msg.update!(content: system_prompt(user))
      else
        chat.with_instructions(system_prompt(user))
      end
    end

    def register_tools(chat, user)
      chat.with_tool(RegisterExpenseTool.new(user))
      chat.with_tool(ListExpensesTool.new(user))
      chat.with_tool(GetBalanceTool.new(user))
      chat.with_tool(RegisterSettlementTool.new(user)) if user.shared_group&.full?
    end

    def broadcast_response(chat)
      assistant_message = chat.messages.where(role: "assistant").last

      Turbo::StreamsChannel.broadcast_remove_to("chat_#{chat.id}", target: "finance_message_loading")

      return unless assistant_message

      Turbo::StreamsChannel.broadcast_append_to(
        "chat_#{chat.id}",
        target: "finance_messages",
        partial: "finance/messages/message",
        locals: { message: assistant_message }
      )
    end

    def shared_instructions(user)
      group = user.shared_group
      return no_shared_space_instructions if group.nil? || !group.full?

      other = group.other_member(user)
      <<~SHARED
        GASTOS COMPARTIDOS: el usuario se llama #{user.display_name} y comparte gastos con #{other.display_name}.
        - Si el usuario dice que un gasto es "compartido", "de la casa", "entre los dos", "mitad y mitad" o similar, usa register_expense con shared=true. Se divide 50/50 salvo que indique otra proporcion ("yo pongo el 70%" -> my_percent=70).
        - Si dice que lo pago #{other.display_name} ("lo pago #{other.display_name}", "#{other.display_name} pago la luz"), usa paid_by_other=true.
        - Si dice que le transfirio o pago plata a #{other.display_name} ("le pase 3000 a #{other.display_name}"), usa register_settlement. Si #{other.display_name} le transfirio al usuario, usa received=true.
        - Para "como estamos", "cuanto le debo", "gastos compartidos del mes", usa get_balance o list_expenses con scope="shared".
        - Sin mencion de compartir, el gasto es personal (shared=false).
      SHARED
    end

    def no_shared_space_instructions
      <<~SHARED
        GASTOS COMPARTIDOS: el usuario todavia no tiene un espacio compartido activo. Si menciona compartir un gasto con alguien, registralo como personal y explicale que puede crear el espacio compartido o unirse con un codigo desde /finance/shared en la app.
      SHARED
    end
  end
end
```

- [ ] **Step 5: Run tests**

Run: `bin/rails test test/tools test/jobs/finance`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
bundle exec rubocop app/tools/register_settlement_tool.rb app/jobs/finance/chat_response_job.rb test/tools/register_settlement_tool_test.rb test/jobs/finance/chat_response_job_test.rb
git add app/tools/register_settlement_tool.rb app/jobs/finance/chat_response_job.rb test/tools/register_settlement_tool_test.rb test/jobs/finance/chat_response_job_test.rb
git commit -m "feat: add settlement tool and shared-expense instructions to the finance agent"
```

---

### Task 10: `/finance/shared` screen (create, join, balance)

**Files:**
- Create: `app/controllers/finance/shared_controller.rb`
- Create: `app/views/finance/shared/show.html.erb`
- Create: `test/controllers/finance/shared_controller_test.rb`
- Modify: `config/routes.rb`, `app/views/finance/shared/_navbar.html.erb`, `app/assets/stylesheets/components/_finance_chat.scss`

**Interfaces:**
- Produces routes: `GET /finance/shared` (`finance_shared_path`), `POST /finance/shared` (create), `POST /finance/shared/join` (`join_finance_shared_path`).
- Consumes: `User#shared_group`, `Finance::Group#full?/#other_member/#invite_code/#add_member!`, `Finance::GroupBalance#debts`, `Finance::Expense.in_group`.

- [ ] **Step 1: Failing controller tests**

`test/controllers/finance/shared_controller_test.rb`:

```ruby
require "test_helper"

module Finance
  class SharedControllerTest < ActionDispatch::IntegrationTest
    test "requires login" do
      get finance_shared_path
      assert_redirected_to new_user_session_path
    end

    test "show without group offers create and join" do
      sign_in users(:stranger)
      get finance_shared_path
      assert_response :success
      assert_select "form[action=?]", finance_shared_path
      assert_select "form[action=?]", join_finance_shared_path
    end

    test "show with group renders partner, code and debts" do
      sign_in users(:manu)
      get finance_shared_path
      assert_response :success
      assert_select "body", /Novia/
      assert_select "body", /ABCD1234/
      assert_select "body", /3\.000/
    end

    test "create builds a group with the user as owner and member" do
      sign_in users(:stranger)
      assert_difference("Finance::Group.count", 1) { post finance_shared_path }
      assert_redirected_to finance_shared_path
      assert users(:stranger).reload.shared_group.member?(users(:stranger))
    end

    test "create is refused when already in a group" do
      sign_in users(:manu)
      assert_no_difference("Finance::Group.count") { post finance_shared_path }
      assert_redirected_to finance_shared_path
    end

    test "join with valid code adds membership" do
      group = Finance::Group.create!(owner: users(:stranger))
      newcomer = User.create!(email: "new@example.com", password: "password123", name: "Nuevo")
      sign_in newcomer
      post join_finance_shared_path, params: { invite_code: group.invite_code.downcase }
      assert_redirected_to finance_shared_path
      assert group.reload.member?(newcomer)
    end

    test "join with invalid code shows alert" do
      sign_in users(:stranger)
      post join_finance_shared_path, params: { invite_code: "NOPE" }
      assert_redirected_to finance_shared_path
      assert_match(/no existe/i, flash[:alert])
    end

    test "join a full group is refused" do
      sign_in users(:stranger)
      post join_finance_shared_path, params: { invite_code: "ABCD1234" }
      assert_not finance_groups(:pareja).member?(users(:stranger))
      assert_match(/completo/i, flash[:alert])
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bin/rails test test/controllers/finance/shared_controller_test.rb`
Expected: `undefined method finance_shared_path`.

- [ ] **Step 3: Routes**

In `config/routes.rb`, inside `namespace :finance do`, add after `resource :charts, only: [:show]`:

```ruby
    resource :shared, only: [:show, :create], controller: "shared" do
      post :join
    end
    resources :settlements, only: [:create]
```

Run: `bin/rails routes -g finance` and confirm `finance_shared GET /finance/shared`, `POST /finance/shared`, `join_finance_shared POST /finance/shared/join`, `finance_settlements POST /finance/settlements`.

- [ ] **Step 4: Controller**

`app/controllers/finance/shared_controller.rb`:

```ruby
module Finance
  class SharedController < BaseController
    def show
      @group = current_user.shared_group
      return if @group.nil?

      @partner = @group.other_member(current_user)
      @debts = Finance::GroupBalance.new(@group).debts
      @shared_expenses = Finance::Expense.in_group(@group).includes(:category, :payer, shares: :user).recent.limit(30)
      @settlements = @group.settlements.includes(:from_user, :to_user).recent.limit(10)
      @suggested_settlement = @debts.find { |debt| debt[:from] == current_user }
    end

    def create
      if current_user.shared_group
        redirect_to finance_shared_path, alert: "Ya tenes un espacio compartido"
      else
        Finance::Group.create!(owner: current_user)
        redirect_to finance_shared_path, notice: "Espacio creado. Compartile el codigo a tu pareja."
      end
    end

    def join
      group = Finance::Group.find_by(invite_code: params[:invite_code].to_s.strip.upcase)
      return redirect_to(finance_shared_path, alert: "Ese codigo no existe") if group.nil?
      return redirect_to(finance_shared_path, alert: "Ya tenes un espacio compartido") if current_user.shared_group
      return redirect_to(finance_shared_path, alert: "Ese espacio ya esta completo") if group.full?

      group.add_member!(current_user)
      redirect_to finance_shared_path, notice: "Te uniste al espacio de #{group.owner.display_name}"
    end
  end
end
```

- [ ] **Step 5: View**

`app/views/finance/shared/show.html.erb`:

```erb
<% content_for(:finance_title) do %>
  <i class="fas fa-user-friends me-1"></i> Compartido
<% end %>
<% content_for(:finance_nav_actions) do %>
  <%= link_to finance_expenses_path, class: "finance-nav-btn", title: "Gastos" do %>
    <i class="fas fa-receipt"></i>
  <% end %>
  <%= link_to finance_root_path, class: "finance-nav-btn", title: "Volver al chat" do %>
    <i class="fas fa-comment-dots"></i>
  <% end %>
<% end %>

<div class="finance-expenses-page">
  <% if @group.nil? %>
    <div class="finance-shared-card">
      <h5 class="mb-2">Compartir gastos</h5>
      <p class="text-muted small">Crea un espacio y compartile el codigo a tu pareja, o unite con el codigo que te pasaron.</p>
      <%= button_to "Crear espacio compartido", finance_shared_path, method: :post, class: "btn btn-primary w-100 mb-3" %>
      <%= form_with url: join_finance_shared_path, method: :post, class: "d-flex gap-2" do %>
        <input type="text" name="invite_code" class="form-control text-uppercase" placeholder="Codigo" maxlength="8" required>
        <button type="submit" class="btn btn-outline-light">Unirme</button>
      <% end %>
    </div>
  <% else %>
    <div class="finance-shared-card">
      <% if @partner %>
        <div class="d-flex align-items-center gap-2 mb-2">
          <i class="fas fa-user-friends"></i>
          <span>Compartido con <strong><%= @partner.display_name %></strong></span>
        </div>
      <% else %>
        <p class="mb-1">Todavia nadie se unio. Compartile este codigo:</p>
        <div class="finance-invite-code" id="invite_code"><%= @group.invite_code %></div>
        <button type="button" class="btn btn-sm btn-outline-light mt-2"
                onclick="navigator.clipboard.writeText('<%= @group.invite_code %>'); this.textContent = 'Copiado';">
          Copiar codigo
        </button>
      <% end %>
    </div>

    <% if @partner %>
      <div class="finance-expenses-total">
        <div class="total-label">Balance</div>
        <% if @debts.empty? %>
          <div class="total-amount">Estan a mano</div>
        <% else %>
          <% @debts.each do |debt| %>
            <div class="total-amount">
              <%= debt[:from].display_name %> le debe $<%= number_with_delimiter(debt[:amount_ars].round, delimiter: ".") %> a <%= debt[:to].display_name %>
            </div>
          <% end %>
        <% end %>
      </div>

      <% if @suggested_settlement %>
        <div class="finance-shared-card">
          <%= form_with url: finance_settlements_path, method: :post, class: "d-flex gap-2 align-items-center" do %>
            <span class="small">Saldar</span>
            <input type="number" step="0.01" min="0.01" name="settlement[amount_ars]" class="form-control form-control-sm"
                   value="<%= @suggested_settlement[:amount_ars] %>">
            <button type="submit" class="btn btn-sm btn-success">Le pague a <%= @partner.display_name %></button>
          <% end %>
        </div>
      <% end %>
    <% end %>

    <div class="finance-expenses-scroll">
      <div class="finance-expense-list">
        <% @shared_expenses.each do |expense| %>
          <div class="finance-expense-row">
            <div class="expense-row-icon"><i class="fas <%= expense.category.icon %>"></i></div>
            <div class="expense-row-info">
              <div class="expense-row-desc"><%= expense.description %></div>
              <div class="expense-row-meta">
                Pago <%= expense.payer&.display_name %> ·
                <% expense.shares.each do |share| %>
                  <%= share.user.display_name %> $<%= number_with_delimiter(share.amount_ars.round, delimiter: ".") %>
                <% end %>
              </div>
            </div>
            <div class="expense-row-right">
              <div class="expense-row-date"><%= expense.expense_date.strftime("%d/%m") %></div>
              <div class="expense-row-amount"><span class="expense-amount">$<%= number_with_delimiter(expense.amount_ars&.round, delimiter: ".") %></span></div>
            </div>
          </div>
        <% end %>
        <% @settlements.each do |settlement| %>
          <div class="finance-expense-row finance-settlement-row">
            <div class="expense-row-icon"><i class="fas fa-money-bill-transfer"></i></div>
            <div class="expense-row-info">
              <div class="expense-row-desc"><%= settlement.from_user.display_name %> le pago a <%= settlement.to_user.display_name %></div>
              <div class="expense-row-meta"><%= settlement.description.presence || "Pago de deuda" %></div>
            </div>
            <div class="expense-row-right">
              <div class="expense-row-date"><%= settlement.settled_on.strftime("%d/%m") %></div>
              <div class="expense-row-amount"><span class="expense-amount">$<%= number_with_delimiter(settlement.amount_ars.round, delimiter: ".") %></span></div>
            </div>
          </div>
        <% end %>
        <% if @shared_expenses.empty? && @settlements.empty? %>
          <div class="text-center py-5 expense-empty"><i class="fas fa-inbox d-block mb-2"></i>Todavia no hay gastos compartidos</div>
        <% end %>
      </div>
    </div>
  <% end %>
</div>
```

- [ ] **Step 6: Styles and navbar**

Append to `app/assets/stylesheets/components/_finance_chat.scss`:

```scss
.finance-shared-card {
  margin: 12px;
  padding: 14px 16px;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.06);
  color: #e2e8f0;
}

.finance-invite-code {
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 28px;
  letter-spacing: 4px;
  font-weight: 700;
}

.finance-settlement-row .expense-row-icon {
  color: #22c55e;
}

.expense-shared-badge {
  display: inline-block;
  margin-left: 6px;
  padding: 1px 6px;
  border-radius: 6px;
  font-size: 10px;
  font-weight: 600;
  background: rgba(99, 102, 241, 0.25);
  color: #c7d2fe;
}

.expense-share-form {
  display: flex;
  align-items: center;
  gap: 4px;
  input { width: 90px; }
}
```

In `app/views/finance/shared/_navbar.html.erb`, add before the sign-out link inside the right-hand `div.d-flex`:

```erb
      <%= link_to finance_shared_path, class: "text-light", title: "Compartido" do %>
        <i class="fas fa-user-friends"></i>
      <% end %>
```

- [ ] **Step 7: Run tests**

Run: `bin/rails test test/controllers/finance/shared_controller_test.rb`
Expected: all pass. If the `3\.000` assertion fails, print the body and check the delimiter formatting; the balance is 3000 ARS rendered as `3.000`.

- [ ] **Step 8: Commit**

```bash
bundle exec rubocop app/controllers/finance/shared_controller.rb test/controllers/finance/shared_controller_test.rb
git add config/routes.rb app/controllers/finance/shared_controller.rb app/views/finance/shared/show.html.erb app/views/finance/shared/_navbar.html.erb app/assets/stylesheets/components/_finance_chat.scss test/controllers/finance/shared_controller_test.rb
git commit -m "feat: add shared space screen with create, join and balance"
```

---

### Task 11: Settlements controller (Saldar button)

**Files:**
- Create: `app/controllers/finance/settlements_controller.rb`
- Create: `test/controllers/finance/settlements_controller_test.rb`

**Interfaces:**
- Consumes: route `POST /finance/settlements` from Task 10, params `settlement[amount_ars]`, optional `settlement[description]`.

- [ ] **Step 1: Failing test**

`test/controllers/finance/settlements_controller_test.rb`:

```ruby
require "test_helper"

module Finance
  class SettlementsControllerTest < ActionDispatch::IntegrationTest
    test "creates a settlement from current user to partner" do
      sign_in users(:novia)
      assert_difference("Finance::Settlement.count", 1) do
        post finance_settlements_path, params: { settlement: { amount_ars: "3000" } }
      end
      settlement = Finance::Settlement.last
      assert_equal users(:novia), settlement.from_user
      assert_equal users(:manu), settlement.to_user
      assert_redirected_to finance_shared_path
    end

    test "without a full group redirects with alert" do
      sign_in users(:stranger)
      assert_no_difference("Finance::Settlement.count") do
        post finance_settlements_path, params: { settlement: { amount_ars: "10" } }
      end
      assert_redirected_to finance_shared_path
      assert flash[:alert].present?
    end

    test "invalid amount shows alert" do
      sign_in users(:novia)
      post finance_settlements_path, params: { settlement: { amount_ars: "0" } }
      assert flash[:alert].present?
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bin/rails test test/controllers/finance/settlements_controller_test.rb`
Expected: `uninitialized constant Finance::SettlementsController`.

- [ ] **Step 3: Controller**

`app/controllers/finance/settlements_controller.rb`:

```ruby
module Finance
  class SettlementsController < BaseController
    def create
      group = current_user.shared_group
      return redirect_to(finance_shared_path, alert: "No tenes un espacio compartido completo") if group.nil? || !group.full?

      settlement = group.settlements.new(
        from_user: current_user,
        to_user: group.other_member(current_user),
        amount_ars: settlement_params[:amount_ars],
        description: settlement_params[:description],
        settled_on: Date.current
      )

      if settlement.save
        redirect_to finance_shared_path, notice: "Pago registrado"
      else
        redirect_to finance_shared_path, alert: "No se pudo registrar: #{settlement.errors.full_messages.join(', ')}"
      end
    end

    private

    def settlement_params
      params.require(:settlement).permit(:amount_ars, :description)
    end
  end
end
```

- [ ] **Step 4: Run tests**

Run: `bin/rails test test/controllers/finance`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
bundle exec rubocop app/controllers/finance/settlements_controller.rb test/controllers/finance/settlements_controller_test.rb
git add app/controllers/finance/settlements_controller.rb test/controllers/finance/settlements_controller_test.rb
git commit -m "feat: settle shared debts from the shared space screen"
```

---

### Task 12: Expenses list — shared badge, "tu parte", toggle shared, edit my share, authorization

**Files:**
- Modify: `app/controllers/finance/expenses_controller.rb`
- Modify: `app/views/finance/expenses/index.html.erb`
- Create: `test/controllers/finance/expenses_controller_test.rb`

**Interfaces:**
- Consumes: `Finance::Expense.visible_to`, `#share_with!`, `#unshare!`, `#assign_shares!`, `Finance::SplitCalculator.by_amount`.
- Produces: `PATCH /finance/expenses/:id` accepts `expense[shared]` (`"1"`/`"0"`) and `expense[my_share_amount]` in addition to existing fields.

- [ ] **Step 1: Failing tests**

`test/controllers/finance/expenses_controller_test.rb`:

```ruby
require "test_helper"

module Finance
  class ExpensesControllerTest < ActionDispatch::IntegrationTest
    test "index shows my share for shared expenses and total of personal plus shares" do
      sign_in users(:manu)
      get finance_expenses_path
      assert_response :success
      assert_select ".expense-shared-badge", minimum: 1
      assert_select "body", /8\.000/
    end

    test "non member cannot update a shared expense" do
      sign_in users(:stranger)
      patch finance_expense_path(finance_expenses(:super_compartido)), params: { expense: { expense_type: "fijo" } }
      assert_response :not_found
    end

    test "partner can update a shared expense they did not register" do
      sign_in users(:novia)
      patch finance_expense_path(finance_expenses(:super_compartido)), params: { expense: { expense_type: "fijo" } }
      assert_equal "fijo", finance_expenses(:super_compartido).reload.expense_type
    end

    test "toggle shared on a personal expense splits it 50/50" do
      sign_in users(:manu)
      patch finance_expense_path(finance_expenses(:legacy_nafta)), params: { expense: { shared: "1" } }
      expense = finance_expenses(:legacy_nafta).reload
      assert expense.shared?
      assert_equal users(:manu), expense.payer
      assert_equal BigDecimal("1500"), expense.amount_ars_for(users(:novia))
    end

    test "toggle shared off makes it personal again" do
      sign_in users(:manu)
      patch finance_expense_path(finance_expenses(:super_compartido)), params: { expense: { shared: "0" } }
      assert_not finance_expenses(:super_compartido).reload.shared?
    end

    test "editing my share adjusts the partner's share" do
      sign_in users(:manu)
      patch finance_expense_path(finance_expenses(:super_compartido)), params: { expense: { my_share_amount: "6000" } }
      expense = finance_expenses(:super_compartido).reload
      assert_equal BigDecimal("6000"), expense.amount_ars_for(users(:manu))
      assert_equal BigDecimal("2000"), expense.amount_ars_for(users(:novia))
    end

    test "my share above total is rejected with alert" do
      sign_in users(:manu)
      patch finance_expense_path(finance_expenses(:super_compartido)), params: { expense: { my_share_amount: "9000" } }
      assert flash[:alert].present?
      assert_equal BigDecimal("4000"), finance_expenses(:super_compartido).reload.amount_ars_for(users(:manu))
    end

    test "destroy by non member is not found" do
      sign_in users(:stranger)
      delete finance_expense_path(finance_expenses(:legacy_nafta))
      assert_response :not_found
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bin/rails test test/controllers/finance/expenses_controller_test.rb`
Expected: failures on badge selector, `:not_found` (currently `current_user.finance_expenses.find` raises 404 too for non-owners, so some pass), and share toggling.

- [ ] **Step 3: Controller**

Replace `update`, `destroy` and `expense_params` in `app/controllers/finance/expenses_controller.rb` with:

```ruby
    def update
      @expense = Finance::Expense.visible_to(current_user).find(params[:id])
      apply_update
      redirect_to finance_expenses_path(**filter_params), notice: "Gasto actualizado"
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      redirect_to finance_expenses_path(**filter_params), alert: "Error al actualizar: #{e.message}"
    end

    def destroy
      @expense = Finance::Expense.visible_to(current_user).find(params[:id])
      @expense.destroy
      redirect_to finance_expenses_path(**filter_params), notice: "Gasto eliminado"
    end

    private

    def apply_update
      Finance::Expense.transaction do
        @expense.update!(expense_params) if expense_params.present?
        apply_sharing_change
        apply_my_share_change
      end
    end

    def apply_sharing_change
      shared_param = params.dig(:expense, :shared)
      return if shared_param.nil?

      if ActiveModel::Type::Boolean.new.cast(shared_param)
        group = current_user.shared_group
        raise ArgumentError, "No tenes un espacio compartido completo" if group.nil? || !group.full?

        @expense.share_with!(group, payer: @expense.payer || current_user) unless @expense.shared?
      elsif @expense.shared?
        @expense.unshare!
      end
    end

    def apply_my_share_change
      my_share = params.dig(:expense, :my_share_amount)
      return if my_share.blank? || !@expense.shared?

      mine = BigDecimal(my_share.to_s)
      other = @expense.group.other_member(current_user)
      raise ArgumentError, "Tu parte no puede superar el total" if mine > @expense.amount || mine.negative?

      rows = Finance::SplitCalculator.by_amount(@expense, { current_user => mine, other => @expense.amount - mine })
      @expense.assign_shares!(rows)
    end

    def expense_params
      params.fetch(:expense, {}).permit(:description, :amount, :expense_type, :expense_date, :finance_category_id,
                                        :currency, :exchange_rate)
    end

    def filter_params
      { period: params[:period], currency: params[:currency], category: params[:category],
        search: params[:search], expense_type: params[:filter_expense_type] }
    end
```

Note: the previous code used `params.require(:expense)`. `fetch(:expense, {})` lets a request carrying only `expense[shared]` or `expense[my_share_amount]` pass through without raising, and `permit` drops those two keys from the attribute update.

- [ ] **Step 4: View**

In `app/views/finance/expenses/index.html.erb`:

Replace the `expense-row-info` block with:

```erb
            <div class="expense-row-info">
              <div class="expense-row-desc">
                <%= expense.description %>
                <% if expense.shared? %><span class="expense-shared-badge">Compartido</span><% end %>
              </div>
              <div class="expense-row-meta">
                <%= expense.category.name %> · <%= expense.expense_type == "fijo" ? "Fijo" : "Variable" %>
                <% if expense.shared? %>
                  · pago <%= expense.payer&.display_name %> · tu parte $<%= number_with_delimiter(expense.amount_ars_for(current_user).round, delimiter: ".") %>
                <% end %>
              </div>
              <% if expense.shared? && expense.currency == "ARS" %>
                <%= form_with url: finance_expense_path(expense, period: @period, currency: @currency_filter,
                              category: @category_filter, search: @search, filter_expense_type: @expense_type_filter),
                              method: :patch, class: "expense-share-form mt-1" do %>
                  <input type="number" step="0.01" min="0" max="<%= expense.amount %>" name="expense[my_share_amount]"
                         value="<%= expense.share_for(current_user)&.amount %>" class="form-control form-control-sm">
                  <button type="submit" class="expense-action-btn" title="Guardar mi parte"><i class="fas fa-check"></i></button>
                <% end %>
              <% end %>
            </div>
```

Inside `expense-row-actions`, before the delete form, add a toggle-shared form (only when the user has a complete shared space):

```erb
              <% if current_user.shared_group&.full? %>
                <%= form_with url: finance_expense_path(expense, period: @period, currency: @currency_filter,
                              category: @category_filter, search: @search, filter_expense_type: @expense_type_filter),
                              method: :patch do %>
                  <input type="hidden" name="expense[shared]" value="<%= expense.shared? ? '0' : '1' %>">
                  <button type="submit" class="expense-action-btn" title="<%= expense.shared? ? 'Hacer personal' : 'Compartir' %>">
                    <i class="fas <%= expense.shared? ? 'fa-user' : 'fa-user-friends' %>"></i>
                  </button>
                <% end %>
              <% end %>
```

Change the amount display so that for shared expenses the big number is the user's part and the total is a sub-line. Replace the `expense-row-amount` div with:

```erb
              <div class="expense-row-amount">
                <% if expense.shared? %>
                  <span class="expense-amount">$<%= number_with_delimiter(expense.amount_ars_for(current_user).round, delimiter: ".") %></span>
                  <span class="expense-amount-ars-sub">de $<%= number_with_delimiter(expense.amount_ars&.round, delimiter: ".") %></span>
                <% elsif expense.currency == "USD" %>
                  <span class="expense-amount expense-amount-usd">US$<%= number_with_delimiter(expense.amount, delimiter: ".") %></span>
                  <% if expense.amount_ars.present? %>
                    <span class="expense-amount-ars-sub">~$<%= number_with_delimiter(expense.amount_ars&.round, delimiter: ".") %></span>
                  <% end %>
                <% else %>
                  <span class="expense-amount">$<%= number_with_delimiter(expense.amount, delimiter: ".") %></span>
                <% end %>
              </div>
```

- [ ] **Step 5: Run tests**

Run: `bin/rails test test/controllers/finance`
Expected: all pass.

- [ ] **Step 6: Manual smoke in browser**

Run `bin/rails s`, log in, open `/finance/expenses`, `/finance/charts`, `/finance/shared`. Confirm the three pages render with no 500 and the legacy expense still shows its full amount.

- [ ] **Step 7: Commit**

```bash
bundle exec rubocop app/controllers/finance/expenses_controller.rb test/controllers/finance/expenses_controller_test.rb
git add app/controllers/finance/expenses_controller.rb app/views/finance/expenses/index.html.erb test/controllers/finance/expenses_controller_test.rb
git commit -m "feat: show and edit shared expenses in the expenses list"
```

---

### Task 13: Docs, full suite, lint

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update CLAUDE.md**

In the `### Finance Assistant (PWA)` section, add after the `Tools` bullet:

```markdown
- **Shared expenses**: `Finance::Group` (one per couple, `MAX_MEMBERS = 2`, invite code), `Finance::ExpenseShare` (per-member share, `amount`/`amount_ars`), `Finance::Settlement` (transfer between members). `Finance::Expense#group_id` nil = personal. "My spending" = personal at 100% + my shares (`Finance::SpendingQuery`, `Finance::Expense.visible_to(user)`). Balances via `Finance::GroupBalance`. Splits via `Finance::SplitCalculator`.
- **Tools** also include `RegisterSettlementTool`; `RegisterExpenseTool` accepts `shared`, `my_percent`, `paid_by_other`; list/balance tools accept `scope: personal|shared`.
- **Screens**: `/finance/shared` (create/join with code, balance, settle), `/finance/expenses` shows shared badge and lets you toggle sharing / edit your share.
```

In the `### Data Model` section add:

```markdown
- **Finance::Group / GroupMembership / ExpenseShare / Settlement** - shared expenses between two users (tables prefixed `finance_`)
```

In `### Routes` add:

```
/finance/shared        -> finance/shared#show (create: POST, join: POST /finance/shared/join)
/finance/settlements   -> finance/settlements#create
```

In the `## Common Commands` tests line, mention: `bin/rails test test/models/finance test/services/finance test/tools test/controllers/finance` runs the finance suite.

- [ ] **Step 2: Full suite and lint**

Run:

```bash
bin/rails test
bundle exec rubocop
```

Expected: finance tests all green. Report any failures outside `finance`/`tools` as pre-existing (compare with the Task 0 baseline). Fix any RuboCop offenses in files touched by this plan.

- [ ] **Step 3: Verify dev data integrity**

Run:

```bash
bin/rails runner 'puts({ expenses: Finance::Expense.count, personal: Finance::Expense.personal.count, without_payer: Finance::Expense.where(payer_id: nil).count })'
```

Expected: `personal == expenses`, `without_payer == 0`.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document shared expenses in CLAUDE.md"
```

---

## Production rollout notes (for the human)

1. `pg_dump` the production database before deploying.
2. Deploy; migrations are additive and the `payer_id` backfill runs inside the migration.
3. Log in, set your name in the Devise account edit page, then create the shared space at `/finance/shared` and pass the code to your partner. She registers at `/users/sign_up` (name, email, password) and joins with the code.
4. Verify `/finance/expenses` and `/finance/charts` totals match what you saw before deploying: every existing expense is personal, so totals are unchanged.

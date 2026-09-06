require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "display_name returns name when present" do
    assert_equal "Manu", users(:manu).display_name
  end

  test "display_name falls back to email local part" do
    assert_equal "stranger", users(:stranger).display_name
  end

  test "a user in a shared space cannot be destroyed and shared expenses survive" do
    manu = users(:manu)
    assert_not manu.destroy
    assert manu.errors.any?
    assert User.exists?(manu.id)
    assert Finance::Expense.exists?(finance_expenses(:super_compartido).id)
    assert_equal 2, finance_expenses(:super_compartido).shares.count
  end

  test "a user with only personal expenses can be destroyed with them" do
    stranger = users(:stranger)
    Finance::Expense.create!(user: stranger, payer: stranger, category: finance_categories(:otros), amount: 10,
                             description: "x", expense_date: Date.current)
    assert stranger.destroy
    assert_not User.exists?(stranger.id)
    assert_equal 0, Finance::Expense.where(user_id: stranger.id).count
  end
end

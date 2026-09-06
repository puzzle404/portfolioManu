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
    after_update :rebalance_shares!, if: -> { shared? && (saved_change_to_amount? || saved_change_to_amount_ars?) }

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
        .or(where(id: Finance::ExpenseShare.select(:expense_id).where(user_id: user.id)).where.not(group_id: nil))
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

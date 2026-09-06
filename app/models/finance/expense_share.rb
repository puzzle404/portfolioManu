module Finance
  class ExpenseShare < ApplicationRecord
    self.table_name = "finance_expense_shares"

    belongs_to :expense, class_name: "Finance::Expense"
    belongs_to :user

    validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :amount_ars, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :user_id, uniqueness: { scope: :expense_id }
    validate :expense_is_shared

    private

    def expense_is_shared
      errors.add(:expense, "no es compartido") unless expense&.shared?
    end
  end
end

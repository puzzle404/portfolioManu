module Finance
  class Expense < ApplicationRecord
    self.table_name = "finance_expenses"

    belongs_to :user
    belongs_to :category, class_name: "Finance::Category", foreign_key: :finance_category_id
    belongs_to :message, optional: true

    has_many_attached :receipts

    validates :amount, presence: true, numericality: { greater_than: 0 }
    validates :expense_date, presence: true
    validates :description, presence: true
    validates :exchange_rate, numericality: { greater_than: 0 }, allow_nil: true
    validates :expense_type, inclusion: { in: %w[fijo variable] }

    before_validation :compute_amount_ars

    scope :for_period, ->(start_date, end_date) { where(expense_date: start_date..end_date) }
    scope :for_category, ->(category_id) { where(finance_category_id: category_id) }
    scope :for_expense_type, ->(type) { where(expense_type: type) }
    scope :recent, -> { order(expense_date: :desc, created_at: :desc) }

    private

    def compute_amount_ars
      if currency == "USD" && exchange_rate.present?
        self.amount_ars = amount * exchange_rate
      elsif currency.blank? || currency == "ARS"
        self.amount_ars = amount
      end
    end
  end
end

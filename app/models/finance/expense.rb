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

    scope :for_period, ->(start_date, end_date) { where(expense_date: start_date..end_date) }
    scope :for_category, ->(category_id) { where(finance_category_id: category_id) }
    scope :recent, -> { order(expense_date: :desc, created_at: :desc) }
  end
end

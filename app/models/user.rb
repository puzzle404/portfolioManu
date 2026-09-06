class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :chats, dependent: :destroy

  # These restrictions must run before the destructive associations below: they stop the
  # destroy of a user who still has shared-expense involvement (see app/models/user.rb history).
  has_many :owned_finance_groups, class_name: "Finance::Group", foreign_key: :owner_id,
                                  dependent: :restrict_with_error
  has_many :finance_expense_shares, class_name: "Finance::ExpenseShare", dependent: :restrict_with_error
  has_many :paid_finance_expenses, -> { where.not(group_id: nil) },
           class_name: "Finance::Expense", foreign_key: :payer_id, dependent: :restrict_with_error
  has_many :finance_settlements_sent, class_name: "Finance::Settlement", foreign_key: :from_user_id,
                                      dependent: :restrict_with_error
  has_many :finance_settlements_received, class_name: "Finance::Settlement", foreign_key: :to_user_id,
                                          dependent: :restrict_with_error

  has_many :finance_expenses, class_name: "Finance::Expense", dependent: :destroy
  has_many :finance_group_memberships, class_name: "Finance::GroupMembership", dependent: :restrict_with_error
  has_many :finance_groups, through: :finance_group_memberships, source: :group

  # This iteration assumes a single shared space per user.
  def shared_group
    finance_groups.order(:id).first
  end

  def display_name
    name.presence || email.to_s.split("@").first
  end
end

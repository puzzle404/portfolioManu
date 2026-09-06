class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :chats, dependent: :destroy
  has_many :finance_expenses, class_name: "Finance::Expense", dependent: :destroy
  has_many :finance_group_memberships, class_name: "Finance::GroupMembership", dependent: :destroy
  has_many :finance_groups, through: :finance_group_memberships, source: :group

  # This iteration assumes a single shared space per user.
  def shared_group
    finance_groups.order(:id).first
  end

  def display_name
    name.presence || email.to_s.split("@").first
  end
end

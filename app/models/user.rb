class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :chats, dependent: :destroy
  has_many :finance_expenses, class_name: "Finance::Expense", dependent: :destroy

  def display_name
    name.presence || email.to_s.split("@").first
  end
end

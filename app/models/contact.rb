class Contact < ApplicationRecord
  validates :name, :message, :email, presence: true
end

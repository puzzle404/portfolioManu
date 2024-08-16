class Question < ApplicationRecord
  validates :user_question, presence: true
end

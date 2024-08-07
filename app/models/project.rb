class Project < ApplicationRecord
  has_many :project_skills
  has_many :skills, through: :project_skills
  has_many_attached :photos
  validates :short_description, length: { maximum: 50 }
end

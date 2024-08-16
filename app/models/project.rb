class Project < ApplicationRecord
  include Chunkable
  has_many :project_skills
  has_many :skills, through: :project_skills
  has_many_attached :photos
  has_many :chunks, as: :chunkable, dependent: :destroy
  validates :short_description, length: { maximum: 50 }

  def chunkable_s
    description
  end

  def chunkable_separators
    ['\n# ', '\n## ', '\n## ']
  end
end

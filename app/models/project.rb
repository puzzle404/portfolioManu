class Project < ApplicationRecord
  include Chunkable
  has_many :project_skills
  has_many :skills, through: :project_skills
  has_many_attached :photos
  has_many :chunks, as: :chunkable, dependent: :destroy
  validates :short_description, length: { maximum: 50 }

  def chunkable_s
    project_content = [
      "Project Name: #{name}",
      "Start Date: #{start_date.to_s}",
      "End Date: #{end_date.to_s}",
      "Description: #{description}"
    ].compact.join("\n")

    # Concatenar información de skills asociados con una etiqueta identificativa
    skills_content = "Skills: #{skills.pluck(:name).join(', ')}"

    # Retornar contenido combinado
    [project_content, skills_content].join("\n\n")
  end

  def chunkable_separators
    ['\n# ', '\n## ', '\n## ']
  end
end

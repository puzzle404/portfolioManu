class CreateExperienceSkills < ActiveRecord::Migration[7.1]
  def change
    create_table :experience_skills do |t|
      t.references :skill, null: false, foreign_key: true
      t.references :experience, null: false, foreign_key: true

      t.timestamps
    end
  end
end

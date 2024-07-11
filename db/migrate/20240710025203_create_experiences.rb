class CreateExperiences < ActiveRecord::Migration[7.1]
  def change
    create_table :experiences do |t|
      t.string :name
      t.text :description
      t.text :short_description
      t.date :start_date
      t.date :end_date
      t.string :company
      t.string :role

      t.timestamps
    end
  end
end

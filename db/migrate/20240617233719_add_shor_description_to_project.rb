class AddShorDescriptionToProject < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :short_description, :text
  end
end

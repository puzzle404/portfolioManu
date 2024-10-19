class CreateContacts < ActiveRecord::Migration[7.1]
  def change
    create_table :contacts do |t|
      t.string :message
      t.string :name
      t.string :email

      t.timestamps
    end
  end
end

class CreateFinanceCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :finance_categories do |t|
      t.string :name, null: false
      t.string :icon
      t.string :color

      t.timestamps
    end
    add_index :finance_categories, :name, unique: true
  end
end

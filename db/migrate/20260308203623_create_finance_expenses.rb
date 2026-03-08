class CreateFinanceExpenses < ActiveRecord::Migration[7.1]
  def change
    create_table :finance_expenses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :finance_category, null: false, foreign_key: true
      t.references :message, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :description
      t.string :currency, default: "ARS"
      t.date :expense_date, null: false

      t.timestamps
    end
    add_index :finance_expenses, :expense_date
    add_index :finance_expenses, [:user_id, :expense_date]
  end
end

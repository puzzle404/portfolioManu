class AddExpenseTypeToFinanceExpenses < ActiveRecord::Migration[7.1]
  def change
    add_column :finance_expenses, :expense_type, :string, default: "variable", null: false
    add_index :finance_expenses, :expense_type
  end
end

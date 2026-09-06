class AddSharingToFinanceExpenses < ActiveRecord::Migration[7.1]
  def up
    add_reference :finance_expenses, :group, null: true, foreign_key: { to_table: :finance_groups }
    add_reference :finance_expenses, :payer, null: true, foreign_key: { to_table: :users }

    execute "UPDATE finance_expenses SET payer_id = user_id WHERE payer_id IS NULL"

    create_table :finance_expense_shares do |t|
      t.references :expense, null: false, foreign_key: { to_table: :finance_expenses }
      t.references :user, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.decimal :amount_ars, precision: 12, scale: 2, null: false
      t.timestamps
    end
    add_index :finance_expense_shares, %i[expense_id user_id], unique: true
  end

  def down
    drop_table :finance_expense_shares
    remove_reference :finance_expenses, :payer
    remove_reference :finance_expenses, :group
  end
end

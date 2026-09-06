class CreateFinanceSettlements < ActiveRecord::Migration[7.1]
  def change
    create_table :finance_settlements do |t|
      t.references :group, null: false, foreign_key: { to_table: :finance_groups }
      t.references :from_user, null: false, foreign_key: { to_table: :users }
      t.references :to_user, null: false, foreign_key: { to_table: :users }
      t.decimal :amount_ars, precision: 12, scale: 2, null: false
      t.date :settled_on, null: false
      t.string :description
      t.references :message, null: true, foreign_key: true
      t.timestamps
    end
  end
end

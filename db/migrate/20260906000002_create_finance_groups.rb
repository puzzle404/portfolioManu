class CreateFinanceGroups < ActiveRecord::Migration[7.1]
  def change
    create_table :finance_groups do |t|
      t.string :name, null: false, default: "Compartido"
      t.string :invite_code, null: false
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :finance_groups, :invite_code, unique: true

    create_table :finance_group_memberships do |t|
      t.references :group, null: false, foreign_key: { to_table: :finance_groups }
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :finance_group_memberships, %i[group_id user_id], unique: true
  end
end

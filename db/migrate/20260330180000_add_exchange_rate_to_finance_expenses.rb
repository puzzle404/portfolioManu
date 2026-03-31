class AddExchangeRateToFinanceExpenses < ActiveRecord::Migration[7.1]
  def change
    add_column :finance_expenses, :exchange_rate, :decimal, precision: 10, scale: 4
    add_column :finance_expenses, :amount_ars, :decimal, precision: 12, scale: 2

    reversible do |dir|
      dir.up do
        execute "UPDATE finance_expenses SET amount_ars = amount WHERE currency = 'ARS' OR currency IS NULL"
      end
    end
  end
end

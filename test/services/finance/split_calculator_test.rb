require "test_helper"

module Finance
  class SplitCalculatorTest < ActiveSupport::TestCase
    setup do
      @manu = users(:manu)
      @novia = users(:novia)
    end

    def build_expense(amount:, currency: "ARS", exchange_rate: nil)
      Finance::Expense.new(user: @manu, category: finance_categories(:comida), description: "x",
                           expense_date: Date.current, amount: amount, currency: currency,
                           exchange_rate: exchange_rate).tap(&:valid?)
    end

    test "equal split of even amount" do
      rows = Finance::SplitCalculator.equal(build_expense(amount: 8000), [@manu, @novia])
      assert_equal [BigDecimal("4000"), BigDecimal("4000")], rows.map { |r| r[:amount] }
      assert_equal [BigDecimal("4000"), BigDecimal("4000")], rows.map { |r| r[:amount_ars] }
    end

    test "equal split of odd cents closes exactly on last member" do
      rows = Finance::SplitCalculator.equal(build_expense(amount: BigDecimal("100.01")), [@manu, @novia])
      assert_equal BigDecimal("100.01"), rows.sum { |r| r[:amount] }
      # BigDecimal#round uses ROUND_HALF_UP: 50.005 rounds up to the first row, so the
      # last row absorbs the remainder instead. Exact closure of the sum is the requirement.
      assert_equal BigDecimal("50.01"), rows.first[:amount]
      assert_equal BigDecimal("50.00"), rows.last[:amount]
    end

    test "by_percent 70/30" do
      rows = Finance::SplitCalculator.by_percent(build_expense(amount: 10_000), { @manu => 70, @novia => 30 })
      assert_equal BigDecimal("7000"), rows.find { |r| r[:user] == @manu }[:amount]
      assert_equal BigDecimal("3000"), rows.find { |r| r[:user] == @novia }[:amount]
    end

    test "by_percent rejects percents not summing to 100" do
      assert_raises(ArgumentError) do
        Finance::SplitCalculator.by_percent(build_expense(amount: 100), { @manu => 60, @novia => 30 })
      end
    end

    test "by_amount rejects amounts not summing to total" do
      assert_raises(ArgumentError) do
        Finance::SplitCalculator.by_amount(build_expense(amount: 100), { @manu => 10, @novia => 20 })
      end
    end

    test "USD expense converts share amount_ars with the expense rate and closes exactly" do
      expense = build_expense(amount: BigDecimal("33.33"), currency: "USD", exchange_rate: BigDecimal("1400"))
      rows = Finance::SplitCalculator.equal(expense, [@manu, @novia])
      assert_equal expense.amount_ars.round(2), rows.sum { |r| r[:amount_ars] }
      # See the rounding note above: 16.665 rounds up to the first row here too.
      assert_equal BigDecimal("16.67"), rows.first[:amount]
      assert_equal BigDecimal("16.66"), rows.last[:amount]
    end
  end
end

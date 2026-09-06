require "test_helper"

class GetBalanceToolTest < ActiveSupport::TestCase
  test "personal scope totals personal plus shares" do
    result = GetBalanceTool.new(users(:manu)).execute(period: "month")
    assert_equal 8000.0, result[:total_spent_ars]
    comida = result[:by_category].find { |c| c[:category] == "Comida" }
    assert_equal 7000.0, comida[:total]
  end

  test "shared scope includes group totals and debts" do
    result = GetBalanceTool.new(users(:manu)).execute(period: "month", scope: "shared")
    assert_equal 10_000.0, result[:total_spent_ars]
    assert_equal 1, result[:debts].size
    assert_equal "Novia", result[:debts].first[:from]
    assert_equal "Manu", result[:debts].first[:to]
    assert_equal 3000.0, result[:debts].first[:amount_ars]
  end
end

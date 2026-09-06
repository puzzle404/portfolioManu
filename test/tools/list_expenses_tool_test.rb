require "test_helper"

class ListExpensesToolTest < ActiveSupport::TestCase
  test "personal scope lists what the user paid, with full amounts" do
    result = ListExpensesTool.new(users(:manu)).execute(period: "month")
    descriptions = result[:expenses].map { |e| e[:description] }
    assert_includes descriptions, "Nafta"
    assert_includes descriptions, "Super"
    assert_not_includes descriptions, "Cafe"
    assert_not_includes descriptions, "Luz" # paid by novia
    super_item = result[:expenses].find { |e| e[:description] == "Super" }
    assert_equal 8000.0, super_item[:amount]
    assert_equal true, super_item[:shared]
    assert_equal "Novia", super_item[:shared_with]
    assert_equal 50, super_item[:my_percent]
    assert_equal 11_000.0, result[:total_ars]
    assert_equal 11_000.0, result[:paid_ars]
    assert_equal 0.0, result[:settlements_net_ars]
  end

  test "personal total is adjusted by settlements" do
    Finance::Settlement.create!(group: finance_groups(:pareja), from_user: users(:novia), to_user: users(:manu),
                                amount_ars: 1000, settled_on: Date.current)
    result = ListExpensesTool.new(users(:manu)).execute(period: "month")
    assert_equal(-1000.0, result[:settlements_net_ars])
    assert_equal 10_000.0, result[:total_ars]
  end

  test "shared scope lists group expenses with payer" do
    result = ListExpensesTool.new(users(:manu)).execute(period: "month", scope: "shared")
    assert_equal 2, result[:count]
    luz = result[:expenses].find { |e| e[:description] == "Luz" }
    assert_equal "Novia", luz[:paid_by]
    assert_equal 10_000.0, result[:total_ars]
  end

  test "shared scope without group returns error" do
    assert_equal "error", ListExpensesTool.new(users(:stranger)).execute(scope: "shared")[:status]
  end
end

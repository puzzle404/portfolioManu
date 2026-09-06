require "test_helper"

class ListExpensesToolTest < ActiveSupport::TestCase
  test "personal scope lists visible expenses with my share" do
    result = ListExpensesTool.new(users(:manu)).execute(period: "month")
    descriptions = result[:expenses].map { |e| e[:description] }
    assert_includes descriptions, "Nafta"
    assert_includes descriptions, "Super"
    assert_not_includes descriptions, "Cafe"
    super_item = result[:expenses].find { |e| e[:description] == "Super" }
    assert_equal 4000.0, super_item[:my_share_ars]
    assert_equal true, super_item[:shared]
    assert_equal 8000.0, result[:total_ars]
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

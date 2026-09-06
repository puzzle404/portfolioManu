require "test_helper"

class RegisterSettlementToolTest < ActiveSupport::TestCase
  test "records a payment from me to the other member" do
    result = RegisterSettlementTool.new(users(:novia)).execute(amount: "3000")
    assert_equal "success", result[:status]
    settlement = Finance::Settlement.find(result[:settlement_id])
    assert_equal users(:novia), settlement.from_user
    assert_equal users(:manu), settlement.to_user
    assert_equal Date.current, settlement.settled_on
    assert_empty Finance::GroupBalance.new(finance_groups(:pareja)).debts
  end

  test "received=true records a payment from the other member to me" do
    result = RegisterSettlementTool.new(users(:manu)).execute(amount: "1000", received: true, date: "2026-09-01")
    settlement = Finance::Settlement.find(result[:settlement_id])
    assert_equal users(:novia), settlement.from_user
    assert_equal Date.new(2026, 9, 1), settlement.settled_on
  end

  test "error without group" do
    assert_equal "error", RegisterSettlementTool.new(users(:stranger)).execute(amount: "10")[:status]
  end
end

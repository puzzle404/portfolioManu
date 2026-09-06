require "test_helper"

module Finance
  class SettlementTest < ActiveSupport::TestCase
    test "valid between two members" do
      settlement = Finance::Settlement.new(
        group: finance_groups(:pareja), from_user: users(:novia), to_user: users(:manu),
        amount_ars: 1000, settled_on: Date.current
      )
      assert settlement.valid?
    end

    test "invalid when from and to are the same" do
      settlement = Finance::Settlement.new(
        group: finance_groups(:pareja), from_user: users(:manu), to_user: users(:manu),
        amount_ars: 1000, settled_on: Date.current
      )
      assert_not settlement.valid?
    end

    test "invalid when a party is not a member" do
      settlement = Finance::Settlement.new(
        group: finance_groups(:pareja), from_user: users(:stranger), to_user: users(:manu),
        amount_ars: 1000, settled_on: Date.current
      )
      assert_not settlement.valid?
    end
  end
end

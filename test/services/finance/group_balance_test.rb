require "test_helper"

module Finance
  class GroupBalanceTest < ActiveSupport::TestCase
    setup do
      @group = finance_groups(:pareja)
      @manu = users(:manu)
      @novia = users(:novia)
    end

    test "net per member from paid minus shares" do
      net = Finance::GroupBalance.new(@group).net_by_member
      assert_equal BigDecimal("3000"), net[@manu]
      assert_equal BigDecimal("-3000"), net[@novia]
    end

    test "debts lists who owes whom" do
      debts = Finance::GroupBalance.new(@group).debts
      assert_equal 1, debts.size
      assert_equal @novia, debts.first[:from]
      assert_equal @manu, debts.first[:to]
      assert_equal BigDecimal("3000"), debts.first[:amount_ars]
    end

    test "partial settlement reduces debt" do
      Finance::Settlement.create!(
        group: @group, from_user: @novia, to_user: @manu, amount_ars: 1000, settled_on: Date.current
      )
      assert_equal BigDecimal("2000"), Finance::GroupBalance.new(@group).debts.first[:amount_ars]
    end

    test "full settlement clears debts" do
      Finance::Settlement.create!(
        group: @group, from_user: @novia, to_user: @manu, amount_ars: 3000, settled_on: Date.current
      )
      assert_empty Finance::GroupBalance.new(@group).debts
    end
  end
end

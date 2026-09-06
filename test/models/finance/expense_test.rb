require "test_helper"

module Finance
  class ExpenseTest < ActiveSupport::TestCase
    test "legacy expense without group or payer is personal and counts 100%" do
      legacy = finance_expenses(:legacy_nafta)
      assert_not legacy.shared?
      assert_nil legacy.payer
      assert_equal BigDecimal("3000"), legacy.amount_ars_for(users(:manu))
    end

    test "shared expense returns the user's share" do
      expense = finance_expenses(:super_compartido)
      assert expense.shared?
      assert_equal BigDecimal("4000"), expense.amount_ars_for(users(:novia))
    end

    test "visible_to includes personal, paid and shared-in expenses only" do
      visible = Finance::Expense.visible_to(users(:manu))
      assert_includes visible, finance_expenses(:legacy_nafta)
      assert_includes visible, finance_expenses(:super_compartido)
      assert_includes visible, finance_expenses(:luz_compartida_novia_pago)
      assert_not_includes visible, finance_expenses(:novia_cafe)
    end

    test "visible_to for stranger is empty" do
      assert_empty Finance::Expense.visible_to(users(:stranger))
    end

    test "assign_shares! replaces shares atomically" do
      expense = finance_expenses(:super_compartido)
      expense.assign_shares!([
        { user: users(:manu), amount: BigDecimal("6000"), amount_ars: BigDecimal("6000") },
        { user: users(:novia), amount: BigDecimal("2000"), amount_ars: BigDecimal("2000") }
      ])
      assert_equal 2, expense.shares.count
      assert_equal BigDecimal("6000"), expense.share_for(users(:manu)).amount
    end

    test "shared expense requires payer to be a member" do
      expense = finance_expenses(:super_compartido)
      expense.payer = users(:stranger)
      assert_not expense.valid?
    end
  end
end

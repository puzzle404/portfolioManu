require "test_helper"

class RegisterExpenseToolTest < ActiveSupport::TestCase
  setup do
    @manu = users(:manu)
    @novia = users(:novia)
  end

  test "personal expense still works exactly as before" do
    result = RegisterExpenseTool.new(@manu).execute(amount: "1500", category: "Comida", description: "Pizza")
    assert_equal "success", result[:status]
    expense = Finance::Expense.find(result[:expense_id])
    assert_not expense.shared?
    assert_equal @manu, expense.payer
    assert_equal BigDecimal("1500"), expense.amount_ars_for(@manu)
  end

  test "shared expense splits 50/50 in the user's group" do
    result = RegisterExpenseTool.new(@manu).execute(amount: "6000", category: "Comida", description: "Cena", shared: true)
    assert_equal "success", result[:status]
    expense = Finance::Expense.find(result[:expense_id])
    assert_equal finance_groups(:pareja), expense.group
    assert_equal @manu, expense.payer
    assert_equal BigDecimal("3000"), expense.amount_ars_for(@novia)
    assert_match(/compartido/i, result[:message])
  end

  test "my_percent overrides the split" do
    result = RegisterExpenseTool.new(@manu).execute(amount: "10000", category: "Comida", description: "Cena",
                                                    shared: true, my_percent: 70)
    expense = Finance::Expense.find(result[:expense_id])
    assert_equal BigDecimal("7000"), expense.amount_ars_for(@manu)
    assert_equal BigDecimal("3000"), expense.amount_ars_for(@novia)
  end

  test "paid_by_other sets the other member as payer" do
    result = RegisterExpenseTool.new(@manu).execute(amount: "2000", category: "Servicios", description: "Gas",
                                                    shared: true, paid_by_other: true)
    assert_equal @novia, Finance::Expense.find(result[:expense_id]).payer
  end

  test "shared without a group returns error and creates nothing" do
    assert_no_difference("Finance::Expense.count") do
      result = RegisterExpenseTool.new(users(:stranger)).execute(amount: "100", category: "Otros", description: "x", shared: true)
      assert_equal "error", result[:status]
    end
  end

  test "accepts string booleans from the model" do
    result = RegisterExpenseTool.new(@manu).execute(amount: "100", category: "Otros", description: "x", shared: "true")
    assert Finance::Expense.find(result[:expense_id]).shared?
  end
end

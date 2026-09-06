require "test_helper"

module Finance
  class ExpensesControllerTest < ActionDispatch::IntegrationTest
    test "index shows my share for shared expenses and total of personal plus shares" do
      sign_in users(:manu)
      get finance_expenses_path
      assert_response :success
      assert_select ".expense-split .split-bar-fill[style*=?]", "width: 50%", minimum: 1
      assert_select ".expense-split-legend", /vos \$4\.000/
      assert_select "body", /8\.000/
      assert_select "input[name='expense[my_share_amount]'][value=?][max=?]", "4000.00", "8000.00"
    end

    test "non member cannot update a shared expense" do
      sign_in users(:stranger)
      patch finance_expense_path(finance_expenses(:super_compartido)), params: { expense: { expense_type: "fijo" } }
      assert_response :not_found
    end

    test "partner can update a shared expense they did not register" do
      sign_in users(:novia)
      patch finance_expense_path(finance_expenses(:super_compartido)), params: { expense: { expense_type: "fijo" } }
      assert_equal "fijo", finance_expenses(:super_compartido).reload.expense_type
    end

    test "toggle shared on a personal expense splits it 50/50" do
      sign_in users(:manu)
      patch finance_expense_path(finance_expenses(:legacy_nafta)), params: { expense: { shared: "1" } }
      expense = finance_expenses(:legacy_nafta).reload
      assert expense.shared?
      assert_equal users(:manu), expense.payer
      assert_equal BigDecimal("1500"), expense.amount_ars_for(users(:novia))
    end

    test "toggle shared off makes it personal again" do
      sign_in users(:manu)
      patch finance_expense_path(finance_expenses(:super_compartido)), params: { expense: { shared: "0" } }
      assert_not finance_expenses(:super_compartido).reload.shared?
    end

    test "editing my share adjusts the partner's share" do
      sign_in users(:manu)
      patch finance_expense_path(finance_expenses(:super_compartido)), params: { expense: { my_share_amount: "6000" } }
      expense = finance_expenses(:super_compartido).reload
      assert_equal BigDecimal("6000"), expense.amount_ars_for(users(:manu))
      assert_equal BigDecimal("2000"), expense.amount_ars_for(users(:novia))
    end

    test "my share above total is rejected with alert" do
      sign_in users(:manu)
      patch finance_expense_path(finance_expenses(:super_compartido)), params: { expense: { my_share_amount: "9000" } }
      assert flash[:alert].present?
      assert_equal BigDecimal("4000"), finance_expenses(:super_compartido).reload.amount_ars_for(users(:manu))
    end

    test "destroy by non member is not found" do
      sign_in users(:stranger)
      delete finance_expense_path(finance_expenses(:legacy_nafta))
      assert_response :not_found
    end

    test "sharing a usd expense without exchange rate keeps it personal with an alert" do
      sign_in users(:manu)
      expense = Finance::Expense.create!(user: users(:manu), payer: users(:manu),
                                         category: finance_categories(:comida), amount: 100, currency: "USD",
                                         exchange_rate: nil, description: "Compra", expense_date: Date.current)
      patch finance_expense_path(expense), params: { expense: { shared: "1" } }
      assert flash[:alert].present?
      assert_not expense.reload.shared?
    end
    test "partner cannot unshare an expense they did not register" do
      sign_in users(:novia)
      patch finance_expense_path(finance_expenses(:super_compartido)), params: { expense: { shared: "0" } }
      assert_match(/solo quien cargo el gasto/i, flash[:alert])
      assert finance_expenses(:super_compartido).reload.shared?
    end

    test "sharing toggle is only rendered for the user who registered the expense" do
      sign_in users(:novia)
      get finance_expenses_path
      assert_select "form input[name='expense[shared]'][value='0']", count: 1 # luz, registered by novia
      sign_in users(:manu)
      get finance_expenses_path
      assert_select "form input[name='expense[shared]']", count: 2 # legacy_nafta (share) + super (unshare)
    end
  end
end

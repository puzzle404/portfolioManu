module Finance
  # Aggregates what a user spent: personal expenses at 100% plus their share of shared expenses.
  # Every public method returns sums in ARS.
  class SpendingQuery
    def initialize(user, start_date:, end_date:, currency: nil, category_id: nil, expense_type: nil)
      @user = user
      @start_date = start_date
      @end_date = end_date
      @currency = currency.presence
      @category_id = category_id.presence
      @expense_type = expense_type.presence
    end

    def total_ars
      personal.sum(:amount_ars) + shares.sum("finance_expense_shares.amount_ars")
    end

    def by_category
      merge_sums(
        personal.group(:finance_category_id).sum(:amount_ars),
        shares.group("finance_expenses.finance_category_id").sum("finance_expense_shares.amount_ars")
      )
    end

    def by_date
      merge_sums(
        personal.group(:expense_date).sum(:amount_ars),
        shares.group("finance_expenses.expense_date").sum("finance_expense_shares.amount_ars")
      )
    end

    def by_month
      merge_sums(
        personal.group("DATE_TRUNC('month', expense_date)").sum(:amount_ars),
        shares.group("DATE_TRUNC('month', finance_expenses.expense_date)").sum("finance_expense_shares.amount_ars")
      )
    end

    def by_month_and_type
      merge_sums(
        personal.group("DATE_TRUNC('month', expense_date)", :expense_type).sum(:amount_ars),
        shares.group("DATE_TRUNC('month', finance_expenses.expense_date)", "finance_expenses.expense_type")
              .sum("finance_expense_shares.amount_ars")
      )
    end

    private

    def personal
      apply_filters(Finance::Expense.personal.where(user_id: @user.id))
    end

    def shares
      Finance::ExpenseShare.joins(:expense)
                           .where(user_id: @user.id)
                           .merge(apply_filters(Finance::Expense.where.not(group_id: nil)))
    end

    def apply_filters(scope)
      scope = scope.for_period(@start_date, @end_date)
      scope = scope.where(currency: @currency) if @currency
      scope = scope.where(finance_category_id: @category_id) if @category_id
      scope = scope.for_expense_type(@expense_type) if @expense_type
      scope
    end

    def merge_sums(first, second)
      first.merge(second) { |_key, a, b| a + b }.transform_values { |value| BigDecimal(value.to_s) }
    end
  end
end

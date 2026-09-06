module Finance
  # Aggregates what a user actually paid: expenses where they are the payer (personal or shared, full
  # amount), adjusted by settlements with their partner (money sent raises the total, money received
  # lowers it). Settlements only apply when no category/type/currency filter is active. Sums in ARS.
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
      expenses_total_ars + settlements_net_ars
    end

    def expenses_total_ars
      to_decimal(paid.sum(:amount_ars))
    end

    def settlements_net_ars
      return BigDecimal("0") if filtered?

      to_decimal(sent.sum(:amount_ars)) - to_decimal(received.sum(:amount_ars))
    end

    def by_category
      paid.group(:finance_category_id).sum(:amount_ars).transform_values { |value| to_decimal(value) }
    end

    def by_date
      merge_sums(paid.group(:expense_date).sum(:amount_ars), settlements_by(:settled_on))
    end

    def by_month
      merge_sums(paid.group("DATE_TRUNC('month', expense_date)").sum(:amount_ars),
                 settlements_by("DATE_TRUNC('month', settled_on)"))
    end

    def by_month_and_type
      paid.group("DATE_TRUNC('month', expense_date)", :expense_type).sum(:amount_ars)
          .transform_values { |value| to_decimal(value) }
    end

    private

    def paid
      apply_filters(Finance::Expense.paid_by(@user))
    end

    def filtered?
      @currency.present? || @category_id.present? || @expense_type.present?
    end

    def sent
      Finance::Settlement.where(from_user_id: @user.id).for_period(@start_date, @end_date)
    end

    def received
      Finance::Settlement.where(to_user_id: @user.id).for_period(@start_date, @end_date)
    end

    def settlements_by(group_expression)
      return {} if filtered?

      merge_sums(sent.group(group_expression).sum(:amount_ars),
                 received.group(group_expression).sum(:amount_ars).transform_values(&:-@))
    end

    def apply_filters(scope)
      scope = scope.for_period(@start_date, @end_date)
      scope = scope.where(currency: @currency) if @currency
      scope = scope.where(finance_category_id: @category_id) if @category_id
      scope = scope.for_expense_type(@expense_type) if @expense_type
      scope
    end

    def merge_sums(first, second)
      first.merge(second) { |_key, a, b| a + b }.transform_values { |value| to_decimal(value) }
    end

    def to_decimal(value)
      BigDecimal(value.to_s)
    end
  end
end

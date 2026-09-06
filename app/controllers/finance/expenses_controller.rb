module Finance
  class ExpensesController < BaseController
    def index
      read_filters
      resolve_period
      @expenses = filtered_expenses.recent.limit(50)
      @settlements = period_settlements
      @rows = Finance::ExpenseFeed.merge(@expenses, @settlements)
      @paid_ars = compute_paid_ars
      @settlements_net_ars = filters_active? ? BigDecimal("0") : spending_query.settlements_net_ars
      @total_ars = @paid_ars + @settlements_net_ars
      @categories = Finance::Category.order(:name)
    end

    def update
      @expense = Finance::Expense.visible_to(current_user).find(params[:id])
      apply_update
      redirect_to after_change_path, notice: "Gasto actualizado"
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      redirect_to after_change_path, alert: "Error al actualizar: #{e.message}"
    end

    def destroy
      @expense = Finance::Expense.visible_to(current_user).find(params[:id])
      @expense.destroy
      redirect_to after_change_path, notice: "Gasto eliminado"
    end

    private

    def read_filters
      @period = params[:period].presence || "month"
      @currency_filter = params[:currency].presence
      @category_filter = params[:category].presence
      @search = params[:search].presence
      @expense_type_filter = params[:expense_type].presence
    end

    def resolve_period
      dates = Finance::PeriodResolver.call(@period, start_date: params[:start_date], end_date: params[:end_date])
      @start_date = dates[:start]
      @end_date = dates[:end]
    end

    def filtered_expenses
      @filtered_expenses ||= build_filtered_expenses
    end

    def build_filtered_expenses
      expenses = Finance::Expense.paid_by(current_user)
                                 .for_period(@start_date, @end_date)
                                 .includes(:category, :payer, :group, shares: :user)

      expenses = expenses.where(currency: @currency_filter) if @currency_filter.present?
      expenses = expenses.where(finance_category_id: @category_filter) if @category_filter.present?
      expenses = expenses.where("finance_expenses.description ILIKE ?", "%#{@search}%") if @search.present?
      expenses = expenses.for_expense_type(@expense_type_filter) if @expense_type_filter.present?
      expenses
    end

    def filters_active?
      @search.present? || @currency_filter.present? || @category_filter.present? || @expense_type_filter.present?
    end

    def period_settlements
      return Finance::Settlement.none if filters_active?

      Finance::ExpenseFeed.settlements_for(current_user, @start_date, @end_date)
    end

    def compute_paid_ars
      return filtered_expenses.sum { |expense| expense.amount_ars || 0 } if @search.present?

      spending_query.expenses_total_ars
    end

    def after_change_path
      return finance_shared_path if params[:return_to] == "shared"

      finance_expenses_path(**filter_params)
    end

    def spending_query
      Finance::SpendingQuery.new(current_user, start_date: @start_date, end_date: @end_date,
                                               currency: @currency_filter, category_id: @category_filter,
                                               expense_type: @expense_type_filter)
    end

    def apply_update
      Finance::ExpenseUpdater.new(@expense, current_user).call(
        attributes: expense_params,
        shared: params.dig(:expense, :shared),
        my_share_amount: params.dig(:expense, :my_share_amount)
      )
    end

    def expense_params
      params.fetch(:expense, {}).permit(:description, :amount, :expense_type, :expense_date, :finance_category_id,
                                        :currency, :exchange_rate)
    end

    def filter_params
      { period: params[:period], currency: params[:currency], category: params[:category],
        search: params[:search], expense_type: params[:filter_expense_type] }
    end
  end
end

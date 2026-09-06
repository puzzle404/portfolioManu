module Finance
  class ExpensesController < BaseController
    def index
      read_filters
      resolve_period
      @expenses = filtered_expenses.recent.limit(50)
      @total_ars = compute_total_ars
      @categories = Finance::Category.order(:name)
    end

    def update
      @expense = current_user.finance_expenses.find(params[:id])
      if @expense.update(expense_params)
        redirect_to finance_expenses_path(period: params[:period], currency: params[:currency],
                                          category: params[:category], search: params[:search],
                                          expense_type: params[:filter_expense_type]),
                    notice: "Gasto actualizado"
      else
        redirect_to finance_expenses_path, alert: "Error al actualizar: #{@expense.errors.full_messages.join(', ')}"
      end
    end

    def destroy
      @expense = current_user.finance_expenses.find(params[:id])
      @expense.destroy
      redirect_to finance_expenses_path(period: params[:period], currency: params[:currency],
                                        category: params[:category], search: params[:search],
                                        expense_type: params[:filter_expense_type]),
                  notice: "Gasto eliminado"
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
      expenses = Finance::Expense.visible_to(current_user)
                                 .for_period(@start_date, @end_date)
                                 .includes(:category, :payer, :group, shares: :user)

      expenses = expenses.where(currency: @currency_filter) if @currency_filter.present?
      expenses = expenses.where(finance_category_id: @category_filter) if @category_filter.present?
      expenses = expenses.where("finance_expenses.description ILIKE ?", "%#{@search}%") if @search.present?
      expenses = expenses.for_expense_type(@expense_type_filter) if @expense_type_filter.present?
      expenses
    end

    def compute_total_ars
      return filtered_expenses.sum { |e| e.amount_ars_for(current_user) } if @search.present?

      spending_query.total_ars
    end

    def spending_query
      Finance::SpendingQuery.new(current_user, start_date: @start_date, end_date: @end_date,
                                               currency: @currency_filter, category_id: @category_filter,
                                               expense_type: @expense_type_filter)
    end

    def expense_params
      params.require(:expense).permit(:description, :amount, :expense_type, :expense_date, :finance_category_id, :currency, :exchange_rate)
    end
  end
end

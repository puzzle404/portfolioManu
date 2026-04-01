module Finance
  class ExpensesController < BaseController
    def index
      @period = params[:period].presence || "month"
      @currency_filter = params[:currency].presence
      @category_filter = params[:category].presence
      @search = params[:search].presence
      @expense_type_filter = params[:expense_type].presence

      dates = resolve_dates(@period, params[:start_date], params[:end_date])
      @start_date = dates[:start]
      @end_date = dates[:end]

      expenses = current_user.finance_expenses
                             .for_period(@start_date, @end_date)
                             .includes(:category)

      expenses = expenses.where(currency: @currency_filter) if @currency_filter.present?
      expenses = expenses.where(finance_category_id: @category_filter) if @category_filter.present?
      expenses = expenses.where("description ILIKE ?", "%#{@search}%") if @search.present?
      expenses = expenses.for_expense_type(@expense_type_filter) if @expense_type_filter.present?

      @expenses = expenses.recent.limit(50)
      @total_ars = expenses.sum(:amount_ars)
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

    def expense_params
      params.require(:expense).permit(:description, :amount, :expense_type, :expense_date, :finance_category_id, :currency, :exchange_rate)
    end

    def resolve_dates(period, start_date, end_date)
      case period
      when "today" then { start: Date.current, end: Date.current }
      when "week"  then { start: Date.current.beginning_of_week, end: Date.current.end_of_week }
      when "month" then { start: Date.current.beginning_of_month, end: Date.current.end_of_month }
      when "year"  then { start: Date.current.beginning_of_year, end: Date.current.end_of_year }
      when "custom"
        s = start_date.present? ? Date.parse(start_date) : Date.current.beginning_of_month
        e = end_date.present? ? Date.parse(end_date) : Date.current
        { start: s, end: e }
      else { start: Date.current.beginning_of_month, end: Date.current.end_of_month }
      end
    end
  end
end

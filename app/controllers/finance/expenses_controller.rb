module Finance
  class ExpensesController < BaseController
    def index
      @period = params[:period] || "month"
      @currency_filter = params[:currency]
      @category_filter = params[:category]
      @search = params[:search]

      dates = resolve_dates(@period, params[:start_date], params[:end_date])
      @start_date = dates[:start]
      @end_date = dates[:end]

      expenses = current_user.finance_expenses
                             .for_period(@start_date, @end_date)
                             .includes(:category)

      expenses = expenses.where(currency: @currency_filter) if @currency_filter.present?
      expenses = expenses.where(finance_category_id: @category_filter) if @category_filter.present?
      expenses = expenses.where("description ILIKE ?", "%#{@search}%") if @search.present?

      @expenses = expenses.recent.limit(50)
      @total_ars = expenses.sum(:amount_ars)
      @categories = Finance::Category.order(:name)
    end

    private

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

module Finance
  class ChartsController < BaseController
    def show
      @period = params[:period].presence || "month"
      dates = resolve_dates(@period, params[:start_date], params[:end_date])
      @start_date = dates[:start]
      @end_date = dates[:end]

      expenses = current_user.finance_expenses
                             .for_period(@start_date, @end_date)
                             .includes(:category)

      @by_category = expenses.group(:finance_category_id)
                             .sum(:amount_ars)
                             .map { |cat_id, total| [Finance::Category.find(cat_id), total] }
                             .sort_by { |_, total| -total }

      @daily_accumulated = build_daily_accumulated(expenses)

      @monthly_history = build_monthly_history

      @fixed_vs_variable = build_fixed_vs_variable
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

    def build_daily_accumulated(expenses)
      daily = expenses.group(:expense_date).sum(:amount_ars)
      accumulated = 0
      (@start_date..[@end_date, Date.current].min).map do |date|
        accumulated += (daily[date] || 0).to_f
        { date: date.strftime("%d/%m"), total: accumulated.round(2) }
      end
    end

    def build_monthly_history
      start = 5.months.ago.beginning_of_month.to_date
      current_user.finance_expenses
                  .where(expense_date: start..Date.current.end_of_month)
                  .group("DATE_TRUNC('month', expense_date)")
                  .sum(:amount_ars)
                  .sort_by { |date, _| date }
                  .map { |date, total| { month: date.strftime("%b %y"), total: total.to_f.round(2) } }
    end

    def build_fixed_vs_variable
      start = 5.months.ago.beginning_of_month.to_date
      data = current_user.finance_expenses
                         .where(expense_date: start..Date.current.end_of_month)
                         .group("DATE_TRUNC('month', expense_date)", :expense_type)
                         .sum(:amount_ars)

      months = data.keys.map(&:first).uniq.sort
      months.map do |month|
        {
          month: month.strftime("%b %y"),
          fijo: (data[[month, "fijo"]] || 0).to_f.round(2),
          variable: (data[[month, "variable"]] || 0).to_f.round(2)
        }
      end
    end
  end
end

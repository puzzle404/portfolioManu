module Finance
  class ChartsController < BaseController
    def show
      @period = params[:period].presence || "month"
      @currency_filter = params[:currency].presence
      @category_filter = params[:category].presence
      @expense_type_filter = params[:expense_type].presence

      dates = resolve_dates(@period, params[:start_date], params[:end_date])
      @start_date = dates[:start]
      @end_date = dates[:end]

      expenses = current_user.finance_expenses
                             .for_period(@start_date, @end_date)
                             .includes(:category)

      expenses = expenses.where(currency: @currency_filter) if @currency_filter.present?
      expenses = expenses.where(finance_category_id: @category_filter) if @category_filter.present?
      expenses = expenses.for_expense_type(@expense_type_filter) if @expense_type_filter.present?

      @by_category = expenses.group(:finance_category_id)
                             .sum(:amount_ars)
                             .map { |cat_id, total| [Finance::Category.find(cat_id), total] }
                             .sort_by { |_, total| -total }

      @daily_accumulated = build_daily_accumulated(expenses)

      @monthly_history = build_monthly_history
      @fixed_vs_variable = build_fixed_vs_variable

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

    def filtered_scope
      scope = current_user.finance_expenses
      scope = scope.where(currency: @currency_filter) if @currency_filter.present?
      scope = scope.where(finance_category_id: @category_filter) if @category_filter.present?
      scope = scope.for_expense_type(@expense_type_filter) if @expense_type_filter.present?
      scope
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
      filtered_scope
        .where(expense_date: start..Date.current.end_of_month)
        .group("DATE_TRUNC('month', expense_date)")
        .sum(:amount_ars)
        .sort_by { |date, _| date }
        .map { |date, total| { month: date.strftime("%b %y"), total: total.to_f.round(2) } }
    end

    def build_fixed_vs_variable
      start = 5.months.ago.beginning_of_month.to_date
      data = filtered_scope
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

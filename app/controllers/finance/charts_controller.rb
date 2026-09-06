module Finance
  class ChartsController < BaseController
    HISTORY_MONTHS = 5

    def show
      read_filters
      resolve_period
      build_category_chart
      build_daily_chart
      build_history_charts
      @categories = Finance::Category.order(:name)
    end

    private

    def read_filters
      @period = params[:period].presence || "month"
      @currency_filter = params[:currency].presence
      @category_filter = params[:category].presence
      @expense_type_filter = params[:expense_type].presence
    end

    def resolve_period
      dates = Finance::PeriodResolver.call(@period, start_date: params[:start_date], end_date: params[:end_date])
      @start_date = dates[:start]
      @end_date = dates[:end]
    end

    def period_query
      @period_query ||= spending_query(@start_date, @end_date)
    end

    def history_query
      @history_query ||= spending_query(HISTORY_MONTHS.months.ago.beginning_of_month.to_date, Date.current.end_of_month)
    end

    def spending_query(start_date, end_date)
      Finance::SpendingQuery.new(current_user, start_date: start_date, end_date: end_date,
                                               currency: @currency_filter, category_id: @category_filter,
                                               expense_type: @expense_type_filter)
    end

    def build_category_chart
      @by_category = period_query.by_category
                                 .map { |cat_id, total| [Finance::Category.find(cat_id), total] }
                                 .sort_by { |_, total| -total }
    end

    def build_daily_chart
      daily = period_query.by_date
      accumulated = 0
      @daily_accumulated = (@start_date..[@end_date, Date.current].min).map do |date|
        accumulated += (daily[date] || 0).to_f
        { date: date.strftime("%d/%m"), total: accumulated.round(2) }
      end
    end

    def build_history_charts
      @monthly_history = build_monthly_history
      @fixed_vs_variable = build_fixed_vs_variable
    end

    def build_monthly_history
      history_query.by_month
                   .sort_by { |date, _| date }
                   .map { |date, total| { month: date.strftime("%b %y"), total: total.to_f.round(2) } }
    end

    def build_fixed_vs_variable
      by_type = history_query.by_month_and_type
      months = by_type.keys.map(&:first).uniq.sort
      months.map do |month|
        {
          month: month.strftime("%b %y"),
          fijo: (by_type[[month, "fijo"]] || 0).to_f.round(2),
          variable: (by_type[[month, "variable"]] || 0).to_f.round(2)
        }
      end
    end
  end
end

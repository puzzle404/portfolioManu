class GetBalanceTool < RubyLLM::Tool
  description "Gets a summary of spending by category for a given period. " \
              "Use this when the user asks for a balance, summary, totals, or category breakdown."

  param :period, desc: "Time period: 'week', 'month', 'year'", required: false

  def initialize(user)
    @user = user
  end

  def execute(period: "month")
    dates = resolve_dates(period)
    expenses = @user.finance_expenses.for_period(dates[:start], dates[:end]).includes(:category)

    by_category = expenses.group(:finance_category_id).sum(:amount).map do |cat_id, total|
      cat = Finance::Category.find(cat_id)
      { category: cat.name, total: total.to_f, icon: cat.icon }
    end

    {
      period: "#{dates[:start]} a #{dates[:end]}",
      total_spent: expenses.sum(:amount).to_f,
      transaction_count: expenses.count,
      by_category: by_category.sort_by { |c| -c[:total] }
    }
  end

  private

  def resolve_dates(period)
    case period
    when "week"  then { start: Date.current.beginning_of_week, end: Date.current.end_of_week }
    when "month" then { start: Date.current.beginning_of_month, end: Date.current.end_of_month }
    when "year"  then { start: Date.current.beginning_of_year, end: Date.current.end_of_year }
    else { start: Date.current.beginning_of_month, end: Date.current.end_of_month }
    end
  end
end

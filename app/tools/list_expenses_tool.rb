class ListExpensesTool < RubyLLM::Tool
  description "Lists expenses for a given time period and optional category filter. " \
              "Use this when the user asks to see their expenses, spending history, or recent transactions."

  param :period, desc: "Time period: 'today', 'week', 'month', 'year', or 'custom'", required: false
  param :start_date, desc: "Start date in YYYY-MM-DD format (required if period is 'custom')", required: false
  param :end_date, desc: "End date in YYYY-MM-DD format (required if period is 'custom')", required: false
  param :category, desc: "Category name to filter by (optional)", required: false

  def initialize(user)
    @user = user
  end

  def execute(period: "month", start_date: nil, end_date: nil, category: nil)
    dates = resolve_dates(period, start_date, end_date)
    expenses = @user.finance_expenses.for_period(dates[:start], dates[:end])

    if category.present?
      cat = Finance::Category.find_by(name: category)
      expenses = expenses.for_category(cat.id) if cat
    end

    expenses = expenses.includes(:category).recent
    total = expenses.sum(:amount)

    items = expenses.limit(20).map do |e|
      { date: e.expense_date.to_s, amount: e.amount.to_f, description: e.description, category: e.category.name }
    end

    {
      period: "#{dates[:start]} a #{dates[:end]}",
      total: total.to_f,
      count: expenses.count,
      expenses: items
    }
  end

  private

  def resolve_dates(period, start_date, end_date)
    case period
    when "today" then { start: Date.current, end: Date.current }
    when "week"  then { start: Date.current.beginning_of_week, end: Date.current.end_of_week }
    when "month" then { start: Date.current.beginning_of_month, end: Date.current.end_of_month }
    when "year"  then { start: Date.current.beginning_of_year, end: Date.current.end_of_year }
    when "custom"
      { start: Date.parse(start_date.to_s), end: Date.parse(end_date.to_s) }
    else
      { start: Date.current.beginning_of_month, end: Date.current.end_of_month }
    end
  end
end

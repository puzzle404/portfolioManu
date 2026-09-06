class ListExpensesTool < RubyLLM::Tool
  description "Lists expenses for a given time period and optional category filter. " \
              "Use this when the user asks to see their expenses, spending history, or recent transactions. " \
              "scope='shared' lists only the expenses shared with the partner (full amounts, who paid)."

  param :period, desc: "Time period: 'today', 'week', 'month', 'year', or 'custom'", required: false
  param :start_date, desc: "Start date in YYYY-MM-DD format (required if period is 'custom')", required: false
  param :end_date, desc: "End date in YYYY-MM-DD format (required if period is 'custom')", required: false
  param :category, desc: "Category name to filter by (optional)", required: false
  param :expense_type, desc: "Filter by type: 'fijo' (fixed) or 'variable'. Optional, shows all if omitted.",
                       required: false
  param :scope, desc: "'personal' (default: my expenses plus my share of shared ones) or 'shared' " \
                      "(only shared expenses).", required: false

  def initialize(user)
    @user = user
  end

  def execute(period: "month", start_date: nil, end_date: nil, category: nil, expense_type: nil, scope: "personal")
    dates = Finance::PeriodResolver.call(period, start_date: start_date, end_date: end_date)
    expenses = base_scope(scope)
    return missing_group_error if expenses.nil?

    expenses = expenses.for_period(dates[:start], dates[:end])
    expenses = filter_by_category(expenses, category)
    expenses = expenses.for_expense_type(expense_type) if expense_type.present?
    expenses = expenses.includes(:category, :payer, shares: :user).recent

    {
      period: "#{dates[:start]} a #{dates[:end]}",
      scope: scope,
      total_ars: total_for(expenses, scope),
      count: expenses.count,
      expenses: expenses.limit(20).map { |expense| serialize(expense) }
    }
  end

  private

  def base_scope(scope)
    return Finance::Expense.visible_to(@user) unless scope == "shared"

    group = @user.shared_group
    group && Finance::Expense.in_group(group)
  end

  def filter_by_category(expenses, category)
    return expenses if category.blank?

    cat = Finance::Category.find_by(name: category)
    cat ? expenses.for_category(cat.id) : expenses
  end

  def total_for(expenses, scope)
    # Ruby-level sum: expenses is eager-loaded with shares (has_many), and a SQL-level
    # sum(:amount_ars) here would double-count rows because of the join duplication.
    return expenses.sum { |expense| expense.amount_ars || 0 }.to_f if scope == "shared"

    expenses.sum { |expense| expense.amount_ars_for(@user) }.to_f
  end

  def serialize(expense)
    item = { date: expense.expense_date.to_s, amount: expense.amount.to_f, currency: expense.currency,
             description: expense.description, category: expense.category.name, shared: expense.shared? }
    item[:amount_ars] = expense.amount_ars.to_f if expense.currency == "USD"
    if expense.shared?
      item[:paid_by] = expense.payer&.display_name
      item[:my_share_ars] = expense.amount_ars_for(@user).to_f
    end
    item
  end

  def missing_group_error
    { status: "error", message: "No tenes un espacio compartido. Crealo o unite desde /finance/shared." }
  end
end

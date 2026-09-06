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
  param :scope, desc: "'personal' (default: expenses the user paid, full amounts, adjusted by settlements) or " \
                      "'shared' (only shared expenses, who paid).", required: false

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
    expenses = expenses.includes(:category, :payer, :group, shares: :user).recent

    response = {
      period: "#{dates[:start]} a #{dates[:end]}",
      scope: scope,
      count: expenses.count,
      expenses: expenses.limit(20).map { |expense| serialize(expense) }
    }
    response.merge(totals_for(expenses, scope, dates, category, expense_type))
  end

  private

  def base_scope(scope)
    return Finance::Expense.paid_by(@user) unless scope == "shared"

    group = @user.shared_group
    group && Finance::Expense.in_group(group)
  end

  def filter_by_category(expenses, category)
    return expenses if category.blank?

    cat = Finance::Category.find_by(name: category)
    cat ? expenses.for_category(cat.id) : expenses
  end

  # Ruby-level sums: expenses is eager-loaded with shares (has_many), and a SQL-level
  # sum(:amount_ars) here would double-count rows because of the join duplication.
  def totals_for(expenses, scope, dates, category, expense_type)
    paid = expenses.sum { |expense| expense.amount_ars || 0 }
    return { total_ars: paid.to_f } if scope == "shared"

    net = settlements_net(dates, category, expense_type)
    { paid_ars: paid.to_f, settlements_net_ars: net.to_f, total_ars: (paid + net).to_f }
  end

  def settlements_net(dates, category, expense_type)
    cat = category.present? ? Finance::Category.find_by(name: category) : nil
    Finance::SpendingQuery.new(@user, start_date: dates[:start], end_date: dates[:end],
                                      category_id: cat&.id, expense_type: expense_type).settlements_net_ars
  end

  def serialize(expense)
    item = { date: expense.expense_date.to_s, amount: expense.amount.to_f, currency: expense.currency,
             description: expense.description, category: expense.category.name, shared: expense.shared? }
    item[:amount_ars] = expense.amount_ars.to_f if expense.currency == "USD"
    if expense.shared?
      item[:paid_by] = expense.payer&.display_name
      item[:shared_with] = expense.group.other_member(@user)&.display_name
      item[:my_share_ars] = expense.amount_ars_for(@user).to_f
      item[:my_percent] = my_percent(expense)
    end
    item
  end

  def my_percent(expense)
    total = expense.amount_ars.to_f
    total.positive? ? (expense.amount_ars_for(@user).to_f / total * 100).round : 50
  end

  def missing_group_error
    { status: "error", message: "No tenes un espacio compartido. Crealo o unite desde /finance/shared." }
  end
end

class GetBalanceTool < RubyLLM::Tool
  description "Gets a summary of spending by category for a given period. " \
              "Use this when the user asks for a balance, summary, totals, or category breakdown. " \
              "All totals are in ARS. Personal scope = what the user paid, adjusted by settlements with the partner " \
              "(paid_ars, settlements_net_ars, total_spent_ars). scope='shared' returns the shared-space totals " \
              "plus who owes whom."

  param :period, desc: "Time period: 'week', 'month', 'year'", required: false
  param :expense_type, desc: "Filter by type: 'fijo' or 'variable'. Optional, shows all if omitted.", required: false
  param :scope, desc: "'personal' (default: what the user paid, adjusted by settlements) or 'shared' (shared space).",
                required: false

  def initialize(user)
    @user = user
  end

  def execute(period: "month", expense_type: nil, scope: "personal")
    dates = Finance::PeriodResolver.call(period)
    scope == "shared" ? shared_balance(dates, expense_type) : personal_balance(dates, expense_type)
  end

  private

  def personal_balance(dates, expense_type)
    query = Finance::SpendingQuery.new(@user, start_date: dates[:start], end_date: dates[:end],
                                              expense_type: expense_type)
    {
      period: "#{dates[:start]} a #{dates[:end]}",
      scope: "personal",
      transaction_count: paid_count(dates, expense_type),
      by_category: category_breakdown(query.by_category)
    }.merge(personal_totals(query))
  end

  def personal_totals(query)
    { total_spent_ars: query.total_ars.to_f, paid_ars: query.expenses_total_ars.to_f,
      settlements_net_ars: query.settlements_net_ars.to_f }
  end

  def shared_balance(dates, expense_type)
    group = @user.shared_group or return missing_group_error
    expenses = shared_expenses(group, dates, expense_type)
    {
      period: "#{dates[:start]} a #{dates[:end]}",
      scope: "shared",
      total_spent_ars: expenses.sum(:amount_ars).to_f,
      transaction_count: expenses.count,
      by_category: category_breakdown(expenses.group(:finance_category_id).sum(:amount_ars)),
      debts: format_debts(group)
    }
  end

  def shared_expenses(group, dates, expense_type)
    expenses = Finance::Expense.in_group(group).for_period(dates[:start], dates[:end])
    expense_type.present? ? expenses.for_expense_type(expense_type) : expenses
  end

  def paid_count(dates, expense_type)
    scope = Finance::Expense.paid_by(@user).for_period(dates[:start], dates[:end])
    scope = scope.for_expense_type(expense_type) if expense_type.present?
    scope.count
  end

  def category_breakdown(rows)
    rows.map { |cat_id, total| category_row(cat_id, total) }.sort_by { |c| -c[:total] }
  end

  def format_debts(group)
    Finance::GroupBalance.new(group).debts.map do |debt|
      { from: debt[:from].display_name, to: debt[:to].display_name, amount_ars: debt[:amount_ars].to_f }
    end
  end

  def category_row(cat_id, total)
    cat = Finance::Category.find(cat_id)
    { category: cat.name, total: total.to_f, icon: cat.icon }
  end

  def missing_group_error
    { status: "error", message: "No tenes un espacio compartido. Crealo o unite desde /finance/shared." }
  end
end

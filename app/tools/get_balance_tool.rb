class GetBalanceTool < RubyLLM::Tool
  description "Gets a summary of spending by category for a given period. " \
              "Use this when the user asks for a balance, summary, totals, or category breakdown. " \
              "All totals are in ARS. scope='shared' returns the shared-space totals plus who owes whom."

  param :period, desc: "Time period: 'week', 'month', 'year'", required: false
  param :expense_type, desc: "Filter by type: 'fijo' or 'variable'. Optional, shows all if omitted.", required: false
  param :scope, desc: "'personal' (default: my expenses plus my share of shared ones) or 'shared' (shared space).",
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
    by_category = query.by_category.map { |cat_id, total| category_row(cat_id, total) }
    personal_count = Finance::Expense.visible_to(@user).for_period(dates[:start], dates[:end])
    personal_count = personal_count.for_expense_type(expense_type) if expense_type.present?

    {
      period: "#{dates[:start]} a #{dates[:end]}",
      scope: "personal",
      total_spent_ars: query.total_ars.to_f,
      transaction_count: personal_count.count,
      by_category: by_category.sort_by { |c| -c[:total] }
    }
  end

  def shared_balance(dates, expense_type)
    group = @user.shared_group
    if group.nil?
      return { status: "error", message: "No tenes un espacio compartido. Crealo o unite desde /finance/shared." }
    end

    expenses = Finance::Expense.in_group(group).for_period(dates[:start], dates[:end])
    expenses = expenses.for_expense_type(expense_type) if expense_type.present?
    by_category = expenses.group(:finance_category_id).sum(:amount_ars)
                          .map { |cat_id, total| category_row(cat_id, total) }

    {
      period: "#{dates[:start]} a #{dates[:end]}",
      scope: "shared",
      total_spent_ars: expenses.sum(:amount_ars).to_f,
      transaction_count: expenses.count,
      by_category: by_category.sort_by { |c| -c[:total] },
      debts: Finance::GroupBalance.new(group).debts.map do |debt|
        { from: debt[:from].display_name, to: debt[:to].display_name, amount_ars: debt[:amount_ars].to_f }
      end
    }
  end

  def category_row(cat_id, total)
    cat = Finance::Category.find(cat_id)
    { category: cat.name, total: total.to_f, icon: cat.icon }
  end
end

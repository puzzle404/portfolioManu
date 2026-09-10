class RegisterExpenseTool < RubyLLM::Tool
  class DolarRateUnavailable < StandardError; end

  description "Registers a new expense. Use this when the user mentions paying for something, " \
              "spending money, or any financial transaction. Extract amount, category, and description " \
              "from the user's message. The date defaults to today unless the user specifies otherwise. " \
              "Set shared=true when the user says the expense is shared (compartido, de la casa, entre los dos, " \
              "mitad y mitad)."

  param :amount, desc: "The expense amount as a number (e.g., '500', '1250.50')"
  param :category, desc: "The expense category. Must be one of: Servicios, Comida, Transporte, " \
                         "Entretenimiento, Salud, Educacion, Ropa, Hogar, Suscripciones, Otros"
  param :description, desc: "Brief description of the expense (e.g., 'Recibo de luz', 'Uber al trabajo')"
  param :date, desc: "The expense date in YYYY-MM-DD format. Default to today if not specified.", required: false
  param :currency, desc: "Currency code: 'ARS' (default) or 'USD'. Use USD when user mentions dolares/USD.",
                   required: false
  param :exchange_rate, desc: "Exchange rate USD->ARS. Only needed for USD expenses when user provides a specific " \
                              "rate. If not provided for USD, the official rate is fetched automatically.",
                        required: false
  param :expense_type, desc: "Type of expense: 'fijo' (fixed/recurring like rent, subscriptions) or 'variable' " \
                             "(one-time like food, outings). Default: 'variable'.", required: false
  param :shared, type: "boolean",
                 desc: "true if the expense is shared with the user's partner (split between both). Default false.",
                 required: false
  param :my_percent, type: "number",
                     desc: "Only for shared expenses: percentage of the total the current user covers " \
                           "(e.g. 70 for 'yo pongo el 70%'). Default 50.", required: false
  param :paid_by_other, type: "boolean",
                        desc: "Only for shared expenses. true ONLY when the user explicitly says the PARTNER paid. " \
                              "false when the user paid, when they name themselves, or when nobody is named " \
                              "(default: the person registering the expense paid it).", required: false

  def initialize(user)
    @user = user
  end

  def execute(amount:, category:, description:, date: nil, currency: "ARS", exchange_rate: nil,
              expense_type: "variable", shared: false, my_percent: nil, paid_by_other: false)
    with_error_handling do
      shared = cast_boolean(shared)
      group = @user.shared_group
      return missing_group_error if shared && !group_ready?(group)

      cat, currency, rate = resolve_transaction(category, currency, exchange_rate)
      attrs = { amount: amount, description: description, date: date, expense_type: expense_type,
                category: cat, currency: currency, exchange_rate: rate }
      sharing = { shared: shared, group: group, my_percent: my_percent, paid_by_other: cast_boolean(paid_by_other) }

      expense = save_expense(attrs, sharing)
      success_response(expense, cat, currency, rate)
    end
  end

  private

  def with_error_handling
    yield
  rescue ArgumentError => e
    { status: "error", message: "Error en los datos: #{e.message}" }
  rescue ActiveRecord::RecordInvalid => e
    { status: "error", message: "Error al guardar: #{e.message}" }
  rescue DolarRateUnavailable
    { status: "error",
      message: "No se pudo obtener la cotizacion del dolar. Intenta de nuevo o proporciona el tipo de cambio." }
  end

  def group_ready?(group)
    group.present? && group.full?
  end

  def resolve_transaction(category, currency, exchange_rate)
    currency = currency&.upcase || "ARS"
    [find_category(category), currency, resolve_rate(currency, exchange_rate)]
  end

  def resolve_rate(currency, exchange_rate)
    return nil unless currency == "USD"

    rate = exchange_rate.present? ? BigDecimal(exchange_rate.to_s) : fetch_dolar_rate
    raise DolarRateUnavailable if rate.nil?

    rate
  end

  def find_category(category)
    Finance::Category.find_by(name: category) || Finance::Category.find_by(name: "Otros")
  end

  def save_expense(attrs, sharing)
    Finance::Expense.transaction do
      created = create_expense(attrs)
      if sharing[:shared]
        share_in_group(created, sharing[:group], my_percent: sharing[:my_percent],
                                                 paid_by_other: sharing[:paid_by_other])
      end
      created
    end
  end

  def create_expense(attrs)
    Finance::Expense.create!(
      user: @user, payer: @user, category: attrs[:category], amount: BigDecimal(attrs[:amount].to_s),
      description: attrs[:description], expense_date: resolve_date(attrs[:date]), currency: attrs[:currency],
      exchange_rate: attrs[:exchange_rate], expense_type: attrs[:expense_type]
    )
  end

  def resolve_date(date)
    date.present? ? Date.parse(date) : Date.current
  end

  def share_in_group(expense, group, my_percent:, paid_by_other:)
    other = group.other_member(@user)
    payer = paid_by_other ? other : @user
    rows = if my_percent.present?
             mine = BigDecimal(my_percent.to_s)
             Finance::SplitCalculator.by_percent(expense, { @user => mine, other => 100 - mine })
           end
    expense.share_with!(group, payer: payer, rows: rows)
  end

  def success_response(expense, cat, currency, rate)
    response = {
      status: "success", message: success_message(expense, cat, currency, rate), expense_id: expense.id,
      amount: expense.amount.to_f, currency: currency, category: cat.name, date: expense.expense_date.to_s,
      shared: expense.shared?
    }
    add_shared_details(response, expense) if expense.shared?
    response
  end

  def success_message(expense, cat, currency, rate)
    message = "Gasto registrado: $#{expense.amount} #{currency} - #{expense.description} (#{cat.name})"
    message += " [TC: $#{rate} = $#{expense.amount_ars} ARS]" if currency == "USD"
    message += shared_summary(expense) if expense.shared?
    message
  end

  def add_shared_details(response, expense)
    response[:paid_by] = expense.payer.display_name
    response[:my_share_ars] = expense.amount_ars_for(@user).to_f
  end

  def shared_summary(expense)
    other = expense.group.other_member(@user)
    " Compartido, pago #{expense.payer.display_name}. Tu parte: $#{expense.amount_ars_for(@user)} ARS, " \
      "#{other.display_name}: $#{expense.amount_ars_for(other)} ARS."
  end

  def missing_group_error
    {
      status: "error",
      message: "No tenes un espacio compartido completo todavia. Crealo o unite con el codigo desde /finance/shared " \
               "(ambas personas deben estar dentro) y despues volve a registrar el gasto."
    }
  end

  def cast_boolean(value)
    ActiveModel::Type::Boolean.new.cast(value) || false
  end

  def fetch_dolar_rate
    DolarService.venta
  end
end

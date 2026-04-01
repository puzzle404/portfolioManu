class RegisterExpenseTool < RubyLLM::Tool
  description "Registers a new expense. Use this when the user mentions paying for something, " \
              "spending money, or any financial transaction. Extract amount, category, and description " \
              "from the user's message. The date defaults to today unless the user specifies otherwise."

  param :amount, desc: "The expense amount as a number (e.g., '500', '1250.50')"
  param :category, desc: "The expense category. Must be one of: Servicios, Comida, Transporte, " \
                         "Entretenimiento, Salud, Educacion, Ropa, Hogar, Suscripciones, Otros"
  param :description, desc: "Brief description of the expense (e.g., 'Recibo de luz', 'Uber al trabajo')"
  param :date, desc: "The expense date in YYYY-MM-DD format. Default to today if not specified.", required: false
  param :currency, desc: "Currency code: 'ARS' (default) or 'USD'. Use USD when user mentions dolares/USD.", required: false
  param :exchange_rate, desc: "Exchange rate USD->ARS. Only needed for USD expenses when user provides a specific rate. " \
                              "If not provided for USD, the official rate is fetched automatically.", required: false
  param :expense_type, desc: "Type of expense: 'fijo' (fixed/recurring like rent, subscriptions) or 'variable' (one-time like food, outings). Default: 'variable'.", required: false

  def initialize(user)
    @user = user
  end

  def execute(amount:, category:, description:, date: nil, currency: "ARS", exchange_rate: nil, expense_type: "variable")
    expense_date = date.present? ? Date.parse(date) : Date.current
    cat = Finance::Category.find_by(name: category) || Finance::Category.find_by(name: "Otros")
    currency = currency&.upcase || "ARS"

    rate = nil
    if currency == "USD"
      rate = exchange_rate.present? ? BigDecimal(exchange_rate.to_s) : fetch_dolar_rate
      return { status: "error", message: "No se pudo obtener la cotizacion del dolar. Intenta de nuevo o proporciona el tipo de cambio." } if rate.nil?
    end

    expense = Finance::Expense.create!(
      user: @user,
      category: cat,
      amount: BigDecimal(amount.to_s),
      description: description,
      expense_date: expense_date,
      currency: currency,
      exchange_rate: rate,
      expense_type: expense_type
    )

    message = "Gasto registrado: $#{expense.amount} #{currency} - #{expense.description} (#{cat.name})"
    message += " [TC: $#{rate} = $#{expense.amount_ars} ARS]" if currency == "USD"

    {
      status: "success",
      message: message,
      expense_id: expense.id,
      amount: expense.amount.to_f,
      currency: currency,
      category: cat.name,
      date: expense.expense_date.to_s
    }
  rescue ArgumentError => e
    { status: "error", message: "Error en la fecha: #{e.message}" }
  rescue ActiveRecord::RecordInvalid => e
    { status: "error", message: "Error al guardar: #{e.message}" }
  end

  private

  def fetch_dolar_rate
    DolarService.venta
  end
end

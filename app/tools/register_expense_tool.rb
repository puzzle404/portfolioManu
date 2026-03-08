class RegisterExpenseTool < RubyLLM::Tool
  description "Registers a new expense. Use this when the user mentions paying for something, " \
              "spending money, or any financial transaction. Extract amount, category, and description " \
              "from the user's message. The date defaults to today unless the user specifies otherwise."

  param :amount, desc: "The expense amount as a number (e.g., '500', '1250.50')"
  param :category, desc: "The expense category. Must be one of: Servicios, Comida, Transporte, " \
                         "Entretenimiento, Salud, Educacion, Ropa, Hogar, Suscripciones, Otros"
  param :description, desc: "Brief description of the expense (e.g., 'Recibo de luz', 'Uber al trabajo')"
  param :date, desc: "The expense date in YYYY-MM-DD format. Default to today if not specified.", required: false
  param :currency, desc: "Currency code (default ARS)", required: false

  def initialize(user)
    @user = user
  end

  def execute(amount:, category:, description:, date: nil, currency: "ARS")
    expense_date = date.present? ? Date.parse(date) : Date.current
    cat = Finance::Category.find_by(name: category) || Finance::Category.find_by(name: "Otros")

    expense = Finance::Expense.create!(
      user: @user,
      category: cat,
      amount: BigDecimal(amount.to_s),
      description: description,
      expense_date: expense_date,
      currency: currency
    )

    {
      status: "success",
      message: "Gasto registrado: $#{expense.amount} - #{expense.description} (#{cat.name})",
      expense_id: expense.id,
      amount: expense.amount.to_f,
      category: cat.name,
      date: expense.expense_date.to_s
    }
  rescue ArgumentError => e
    { status: "error", message: "Error en la fecha: #{e.message}" }
  rescue ActiveRecord::RecordInvalid => e
    { status: "error", message: "Error al guardar: #{e.message}" }
  end
end

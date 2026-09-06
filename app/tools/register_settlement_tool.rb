class RegisterSettlementTool < RubyLLM::Tool
  description "Records a money transfer between the user and their partner to settle shared-expense debt. " \
              "Use when the user says they paid/transferred money to the partner ('le transferi 3000 a X', " \
              "'le pague lo que le debia') or that the partner paid them ('X me transfirio 3000' -> received=true). " \
              "Amounts are in ARS."

  param :amount, desc: "Amount transferred in ARS as a number"
  param :date, desc: "Date in YYYY-MM-DD format. Default today.", required: false
  param :description, desc: "Optional note (e.g. 'Transferencia por el super')", required: false
  param :received, type: "boolean",
                   desc: "true if the PARTNER paid the current user. Default false (current user paid the " \
                         "partner).", required: false

  def initialize(user)
    @user = user
  end

  def execute(amount:, date: nil, description: nil, received: false)
    group = @user.shared_group
    return missing_group_error if group.nil? || !group.full?

    other = group.other_member(@user)
    from_user, to_user = ActiveModel::Type::Boolean.new.cast(received) ? [other, @user] : [@user, other]

    settlement = Finance::Settlement.create!(
      group: group, from_user: from_user, to_user: to_user, amount_ars: BigDecimal(amount.to_s),
      settled_on: date.present? ? Date.parse(date) : Date.current, description: description
    )

    remaining = Finance::GroupBalance.new(group).debts.map do |debt|
      "#{debt[:from].display_name} le debe $#{debt[:amount_ars]} a #{debt[:to].display_name}"
    end

    {
      status: "success",
      settlement_id: settlement.id,
      message: "Pago registrado: #{from_user.display_name} le paso $#{settlement.amount_ars} ARS a " \
               "#{to_user.display_name}.",
      remaining_debts: remaining.presence || ["Estan a mano"]
    }
  rescue ArgumentError => e
    { status: "error", message: "Error en los datos: #{e.message}" }
  rescue ActiveRecord::RecordInvalid => e
    { status: "error", message: "Error al guardar: #{e.message}" }
  end

  private

  def missing_group_error
    { status: "error", message: "No tenes un espacio compartido completo. Crealo o unite desde /finance/shared." }
  end
end

module Finance
  class SettlementsController < BaseController
    def create
      group = current_user.shared_group
      return redirect_without_full_group unless group&.full?

      settlement = build_settlement(group)

      if settlement.save
        redirect_to finance_shared_path, notice: "Pago registrado"
      else
        redirect_with_settlement_errors(settlement)
      end
    end

    private

    def build_settlement(group)
      group.settlements.new(
        from_user: current_user,
        to_user: group.other_member(current_user),
        amount_ars: settlement_params[:amount_ars],
        description: settlement_params[:description],
        settled_on: Date.current
      )
    end

    def redirect_without_full_group
      redirect_to finance_shared_path, alert: "No tenes un espacio compartido completo"
    end

    def redirect_with_settlement_errors(settlement)
      redirect_to finance_shared_path, alert: "No se pudo registrar: #{settlement.errors.full_messages.join(', ')}"
    end

    def settlement_params
      params.require(:settlement).permit(:amount_ars, :description)
    end
  end
end

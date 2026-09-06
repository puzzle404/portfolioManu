module Finance
  class SharedController < BaseController
    def show
      @group = current_user.shared_group
      return if @group.nil?

      @partner = @group.other_member(current_user)
      @debts = Finance::GroupBalance.new(@group).debts
      @shared_expenses = Finance::Expense.in_group(@group).includes(:category, :payer, shares: :user).recent.limit(30)
      @settlements = @group.settlements.includes(:from_user, :to_user).recent.limit(10)
      @suggested_settlement = @debts.find { |debt| debt[:from] == current_user }
    end

    def create
      if current_user.shared_group
        redirect_to finance_shared_path, alert: "Ya tenes un espacio compartido"
      else
        create_group_for_current_user
      end
    end

    def join
      group = Finance::Group.find_by(invite_code: params[:invite_code].to_s.strip.upcase)
      return redirect_to(finance_shared_path, alert: "Ese codigo no existe") if group.nil?
      return redirect_to(finance_shared_path, alert: "Ya tenes un espacio compartido") if current_user.shared_group
      return redirect_to(finance_shared_path, alert: "Ese espacio ya esta completo") if group.full?

      join_group(group)
    end

    def destroy
      group = current_user.shared_group
      return redirect_to(finance_shared_path, alert: "No tenes un espacio compartido") if group.nil?
      if group.full?
        return redirect_to(finance_shared_path, alert: "No podes salir mientras haya otra persona en el espacio")
      end

      group.destroy!
      redirect_to finance_shared_path, notice: "Saliste del espacio compartido"
    end

    private

    def create_group_for_current_user
      Finance::Group.create!(owner: current_user)
      redirect_to finance_shared_path, notice: "Espacio creado. Compartile el codigo a tu pareja."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      redirect_to finance_shared_path, alert: "No se pudo completar, intenta de nuevo"
    end

    def join_group(group)
      group.add_member!(current_user)
      redirect_to finance_shared_path, notice: "Te uniste al espacio de #{group.owner.display_name}"
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      redirect_to finance_shared_path, alert: "No se pudo completar, intenta de nuevo"
    end
  end
end

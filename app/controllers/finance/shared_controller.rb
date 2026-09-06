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
        Finance::Group.create!(owner: current_user)
        redirect_to finance_shared_path, notice: "Espacio creado. Compartile el codigo a tu pareja."
      end
    end

    def join
      group = Finance::Group.find_by(invite_code: params[:invite_code].to_s.strip.upcase)
      return redirect_to(finance_shared_path, alert: "Ese codigo no existe") if group.nil?
      return redirect_to(finance_shared_path, alert: "Ya tenes un espacio compartido") if current_user.shared_group
      return redirect_to(finance_shared_path, alert: "Ese espacio ya esta completo") if group.full?

      group.add_member!(current_user)
      redirect_to finance_shared_path, notice: "Te uniste al espacio de #{group.owner.display_name}"
    end
  end
end

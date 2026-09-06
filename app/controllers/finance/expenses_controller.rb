module Finance
  class ExpensesController < BaseController
    def index
      read_filters
      resolve_period
      @expenses = filtered_expenses.recent.limit(50)
      @total_ars = compute_total_ars
      @categories = Finance::Category.order(:name)
    end

    def update
      @expense = Finance::Expense.visible_to(current_user).find(params[:id])
      apply_update
      redirect_to finance_expenses_path(**filter_params), notice: "Gasto actualizado"
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      redirect_to finance_expenses_path(**filter_params), alert: "Error al actualizar: #{e.message}"
    end

    def destroy
      @expense = Finance::Expense.visible_to(current_user).find(params[:id])
      @expense.destroy
      redirect_to finance_expenses_path(**filter_params), notice: "Gasto eliminado"
    end

    private

    def read_filters
      @period = params[:period].presence || "month"
      @currency_filter = params[:currency].presence
      @category_filter = params[:category].presence
      @search = params[:search].presence
      @expense_type_filter = params[:expense_type].presence
    end

    def resolve_period
      dates = Finance::PeriodResolver.call(@period, start_date: params[:start_date], end_date: params[:end_date])
      @start_date = dates[:start]
      @end_date = dates[:end]
    end

    def filtered_expenses
      @filtered_expenses ||= build_filtered_expenses
    end

    def build_filtered_expenses
      expenses = Finance::Expense.visible_to(current_user)
                                 .for_period(@start_date, @end_date)
                                 .includes(:category, :payer, :group, shares: :user)

      expenses = expenses.where(currency: @currency_filter) if @currency_filter.present?
      expenses = expenses.where(finance_category_id: @category_filter) if @category_filter.present?
      expenses = expenses.where("finance_expenses.description ILIKE ?", "%#{@search}%") if @search.present?
      expenses = expenses.for_expense_type(@expense_type_filter) if @expense_type_filter.present?
      expenses
    end

    def compute_total_ars
      return filtered_expenses.sum { |e| e.amount_ars_for(current_user) } if @search.present?

      spending_query.total_ars
    end

    def spending_query
      Finance::SpendingQuery.new(current_user, start_date: @start_date, end_date: @end_date,
                                               currency: @currency_filter, category_id: @category_filter,
                                               expense_type: @expense_type_filter)
    end

    def apply_update
      Finance::Expense.transaction do
        @expense.update!(expense_params) if expense_params.present?
        apply_sharing_change
        apply_my_share_change
      end
    end

    def apply_sharing_change
      shared_param = params.dig(:expense, :shared)
      return if shared_param.nil?

      unless @expense.user_id == current_user.id
        raise ArgumentError, "Solo quien cargo el gasto puede cambiar si es compartido"
      end

      ActiveModel::Type::Boolean.new.cast(shared_param) ? enable_sharing : disable_sharing
    end

    def enable_sharing
      group = current_user.shared_group
      raise ArgumentError, "No tenes un espacio compartido completo" if group.nil? || !group.full?
      raise ArgumentError, "No se puede compartir un gasto sin monto en pesos" if @expense.amount_ars.nil?

      @expense.share_with!(group, payer: @expense.payer || current_user) unless @expense.shared?
    end

    def disable_sharing
      @expense.unshare! if @expense.shared?
    end

    def apply_my_share_change
      my_share = params.dig(:expense, :my_share_amount)
      return if my_share.blank? || !@expense.shared?

      mine = BigDecimal(my_share.to_s)
      other = @expense.group.other_member(current_user)
      raise ArgumentError, "Tu parte no puede superar el total" if mine > @expense.amount || mine.negative?

      rows = Finance::SplitCalculator.by_amount(@expense, { current_user => mine, other => @expense.amount - mine })
      @expense.assign_shares!(rows)
    end

    def expense_params
      params.fetch(:expense, {}).permit(:description, :amount, :expense_type, :expense_date, :finance_category_id,
                                        :currency, :exchange_rate)
    end

    def filter_params
      { period: params[:period], currency: params[:currency], category: params[:category],
        search: params[:search], expense_type: params[:filter_expense_type] }
    end
  end
end

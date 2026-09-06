module Finance
  # Applies an edit coming from the expenses list: plain attributes, toggling sharing (registrar only),
  # and re-splitting "my share". Everything runs in one transaction; errors surface as ArgumentError or
  # ActiveRecord::RecordInvalid for the controller to turn into an alert.
  class ExpenseUpdater
    def initialize(expense, user)
      @expense = expense
      @user = user
    end

    def call(attributes:, shared:, my_share_amount:)
      Finance::Expense.transaction do
        @expense.update!(attributes) if attributes.present?
        apply_sharing_change(shared) unless shared.nil?
        apply_my_share_change(my_share_amount) if my_share_amount.present?
      end
    end

    private

    def apply_sharing_change(shared_param)
      unless @expense.user_id == @user.id
        raise ArgumentError, "Solo quien cargo el gasto puede cambiar si es compartido"
      end

      ActiveModel::Type::Boolean.new.cast(shared_param) ? enable_sharing : disable_sharing
    end

    def enable_sharing
      group = @user.shared_group
      raise ArgumentError, "No tenes un espacio compartido completo" if group.nil? || !group.full?
      raise ArgumentError, "No se puede compartir un gasto sin monto en pesos" if @expense.amount_ars.nil?

      @expense.share_with!(group, payer: @expense.payer || @user) unless @expense.shared?
    end

    def disable_sharing
      @expense.unshare! if @expense.shared?
    end

    def apply_my_share_change(my_share)
      return unless @expense.shared?

      mine = BigDecimal(my_share.to_s)
      other = @expense.group.other_member(@user)
      raise ArgumentError, "Tu parte no puede superar el total" if mine > @expense.amount || mine.negative?

      rows = Finance::SplitCalculator.by_amount(@expense, { @user => mine, other => @expense.amount - mine })
      @expense.assign_shares!(rows)
    end
  end
end

module Finance
  # Computes share rows for an expense. Rows are [{ user:, amount:, amount_ars: }].
  # The last row absorbs rounding so that sums equal the expense totals exactly.
  class SplitCalculator
    def self.equal(expense, members)
      percent = BigDecimal("100") / members.size
      percents = members.each_with_object({}) { |member, acc| acc[member] = percent }
      new(expense).by_percent(percents)
    end

    def self.by_percent(expense, percents)
      new(expense).by_percent(percents)
    end

    def self.by_amount(expense, amounts)
      new(expense).by_amount(amounts)
    end

    def initialize(expense)
      @expense = expense
    end

    def by_percent(percents)
      total_percent = percents.values.sum { |value| BigDecimal(value.to_s) }
      unless total_percent.round(6) == 100
        raise ArgumentError, "Los porcentajes deben sumar 100 (suman #{total_percent.to_f})"
      end

      amounts = percents.transform_values { |value| (@expense.amount * BigDecimal(value.to_s) / 100).round(2) }
      build_rows(amounts, close_amount: true)
    end

    def by_amount(amounts)
      amounts = amounts.transform_values { |value| BigDecimal(value.to_s).round(2) }
      total = amounts.values.sum
      unless total == @expense.amount
        raise ArgumentError, "Las partes deben sumar #{@expense.amount.to_f} (suman #{total.to_f})"
      end

      build_rows(amounts, close_amount: false)
    end

    private

    def build_rows(amounts, close_amount:)
      users = amounts.keys
      rows = users.map { |user| { user: user, amount: amounts[user], amount_ars: to_ars(amounts[user]) } }
      close_rounding(rows, close_amount: close_amount)
      rows
    end

    def to_ars(share_amount)
      return share_amount if @expense.currency.blank? || @expense.currency == "ARS"

      (share_amount * @expense.exchange_rate).round(2)
    end

    def close_rounding(rows, close_amount:)
      last = rows.last
      if close_amount
        last[:amount] = @expense.amount - rows[0...-1].sum { |row| row[:amount] }
        last[:amount_ars] = to_ars(last[:amount])
      end
      last[:amount_ars] = @expense.amount_ars.round(2) - rows[0...-1].sum { |row| row[:amount_ars] }
    end
  end
end

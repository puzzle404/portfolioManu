module Finance
  # Rows for the "Mis gastos" list: expenses the user paid plus, when no filter is active,
  # the settlements they took part in, newest first.
  class ExpenseFeed
    def self.settlements_for(user, start_date, end_date)
      Finance::Settlement.involving(user).for_period(start_date, end_date)
                         .includes(:from_user, :to_user).recent.limit(50)
    end

    def self.merge(expenses, settlements)
      (expenses.to_a + settlements.to_a).sort_by { |row| [-row_date(row).jd, -row.created_at.to_i] }
    end

    def self.row_date(row)
      row.is_a?(Finance::Settlement) ? row.settled_on : row.expense_date
    end
    private_class_method :row_date
  end
end

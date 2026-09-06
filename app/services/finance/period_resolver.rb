module Finance
  class PeriodResolver
    def self.call(period, start_date: nil, end_date: nil)
      today = Date.current
      case period.to_s
      when "today" then { start: today, end: today }
      when "week"  then { start: today.beginning_of_week, end: today.end_of_week }
      when "year"  then { start: today.beginning_of_year, end: today.end_of_year }
      when "custom" then custom_range(start_date, end_date, today)
      else { start: today.beginning_of_month, end: today.end_of_month }
      end
    end

    def self.custom_range(start_date, end_date, today)
      {
        start: start_date.present? ? Date.parse(start_date.to_s) : today.beginning_of_month,
        end: end_date.present? ? Date.parse(end_date.to_s) : today
      }
    end
    private_class_method :custom_range
  end
end

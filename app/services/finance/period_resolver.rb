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
        start: parse_date(start_date, today.beginning_of_month),
        end: parse_date(end_date, today)
      }
    end
    private_class_method :custom_range

    def self.parse_date(value, fallback)
      return fallback if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError
      fallback
    end
    private_class_method :parse_date
  end
end

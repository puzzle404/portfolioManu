require "test_helper"

module Finance
  class PeriodResolverTest < ActiveSupport::TestCase
    test "today" do
      assert_equal({ start: Date.current, end: Date.current }, Finance::PeriodResolver.call("today"))
    end

    test "week, month, year" do
      assert_equal Date.current.beginning_of_week, Finance::PeriodResolver.call("week")[:start]
      assert_equal Date.current.end_of_month, Finance::PeriodResolver.call("month")[:end]
      assert_equal Date.current.beginning_of_year, Finance::PeriodResolver.call("year")[:start]
    end

    test "custom parses dates" do
      range = Finance::PeriodResolver.call("custom", start_date: "2026-01-10", end_date: "2026-01-20")
      assert_equal Date.new(2026, 1, 10), range[:start]
      assert_equal Date.new(2026, 1, 20), range[:end]
    end

    test "custom with blanks defaults to month start and today" do
      range = Finance::PeriodResolver.call("custom")
      assert_equal Date.current.beginning_of_month, range[:start]
      assert_equal Date.current, range[:end]
    end

    test "unknown falls back to month" do
      assert_equal Date.current.beginning_of_month, Finance::PeriodResolver.call("whatever")[:start]
      assert_equal Date.current.beginning_of_month, Finance::PeriodResolver.call(nil)[:start]
    end

    test "custom with invalid start_date falls back to month start" do
      range = Finance::PeriodResolver.call("custom", start_date: "not-a-date")
      assert_equal Date.current.beginning_of_month, range[:start]
    end

    test "custom with invalid end_date falls back to today" do
      range = Finance::PeriodResolver.call("custom", end_date: "garbage")
      assert_equal Date.current, range[:end]
    end
  end
end

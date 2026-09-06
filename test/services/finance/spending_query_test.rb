require "test_helper"

module Finance
  class SpendingQueryTest < ActiveSupport::TestCase
    setup do
      @range = Finance::PeriodResolver.call("month")
    end

    def query_for(user, **filters)
      Finance::SpendingQuery.new(user, start_date: @range[:start], end_date: @range[:end], **filters)
    end

    test "total mixes personal and shares" do
      assert_equal BigDecimal("8000"), query_for(users(:manu)).total_ars
      assert_equal BigDecimal("5500"), query_for(users(:novia)).total_ars
      assert_equal BigDecimal("0"), query_for(users(:stranger)).total_ars
    end

    test "by_category" do
      by_cat = query_for(users(:manu)).by_category
      assert_equal BigDecimal("7000"), by_cat[finance_categories(:comida).id]
      assert_equal BigDecimal("1000"), by_cat[finance_categories(:servicios).id]
    end

    test "expense_type filter applies to shares too" do
      assert_equal BigDecimal("1000"), query_for(users(:manu), expense_type: "fijo").total_ars
    end

    test "category filter" do
      assert_equal BigDecimal("1000"), query_for(users(:manu), category_id: finance_categories(:servicios).id).total_ars
    end

    test "by_date groups on expense_date" do
      assert_equal BigDecimal("8000"), query_for(users(:manu)).by_date[Date.current]
    end

    test "by_month and by_month_and_type" do
      month_key = Date.current.beginning_of_month
      by_month = query_for(users(:manu)).by_month
      assert_equal BigDecimal("8000"), by_month.find { |k, _| k.to_date == month_key }&.last
      by_type = query_for(users(:manu)).by_month_and_type
      assert_equal BigDecimal("1000"), by_type.find { |(k, type), _| k.to_date == month_key && type == "fijo" }&.last
    end
  end
end

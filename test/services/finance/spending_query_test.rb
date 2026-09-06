require "test_helper"

module Finance
  class SpendingQueryTest < ActiveSupport::TestCase
    # Fixtures, current month: manu paid legacy_nafta 3000 (Comida) and super_compartido 8000 (Comida, shared);
    # novia paid novia_cafe 500 (Comida) and luz_compartida_novia_pago 2000 (Servicios, fijo, shared).
    setup do
      @range = Finance::PeriodResolver.call("month")
    end

    def query_for(user, **filters)
      Finance::SpendingQuery.new(user, start_date: @range[:start], end_date: @range[:end], **filters)
    end

    test "total is what the user actually paid, regardless of the split" do
      assert_equal BigDecimal("11000"), query_for(users(:manu)).total_ars
      assert_equal BigDecimal("2500"), query_for(users(:novia)).total_ars
      assert_equal BigDecimal("0"), query_for(users(:stranger)).total_ars
    end

    test "settlements adjust the total: receiving money lowers it, sending raises it" do
      Finance::Settlement.create!(group: finance_groups(:pareja), from_user: users(:novia), to_user: users(:manu),
                                  amount_ars: 1000, settled_on: Date.current)
      manu = query_for(users(:manu))
      assert_equal BigDecimal("11000"), manu.expenses_total_ars
      assert_equal BigDecimal("-1000"), manu.settlements_net_ars
      assert_equal BigDecimal("10000"), manu.total_ars
      assert_equal BigDecimal("3500"), query_for(users(:novia)).total_ars
    end

    test "settlements are ignored when a category, type or currency filter is active" do
      Finance::Settlement.create!(group: finance_groups(:pareja), from_user: users(:novia), to_user: users(:manu),
                                  amount_ars: 1000, settled_on: Date.current)
      assert_equal BigDecimal("11000"), query_for(users(:manu), category_id: finance_categories(:comida).id).total_ars
      assert_equal BigDecimal("0"), query_for(users(:manu), expense_type: "fijo").total_ars
    end

    test "by_category only counts expenses the user paid" do
      by_cat = query_for(users(:manu)).by_category
      assert_equal BigDecimal("11000"), by_cat[finance_categories(:comida).id]
      assert_nil by_cat[finance_categories(:servicios).id]
      assert_equal BigDecimal("2000"), query_for(users(:novia)).by_category[finance_categories(:servicios).id]
    end

    test "expense_type filter" do
      assert_equal BigDecimal("2000"), query_for(users(:novia), expense_type: "fijo").total_ars
    end

    test "by_date includes settlements on their date" do
      Finance::Settlement.create!(group: finance_groups(:pareja), from_user: users(:novia), to_user: users(:manu),
                                  amount_ars: 1000, settled_on: Date.current)
      assert_equal BigDecimal("10000"), query_for(users(:manu)).by_date[Date.current]
    end

    test "by_month and by_month_and_type" do
      month_key = Date.current.beginning_of_month
      by_month = query_for(users(:manu)).by_month
      assert_equal BigDecimal("11000"), by_month.find { |k, _| k.to_date == month_key }&.last
      by_type = query_for(users(:novia)).by_month_and_type
      assert_equal BigDecimal("2000"), by_type.find { |(k, type), _| k.to_date == month_key && type == "fijo" }&.last
    end

    test "expense and settlement buckets merge into single keys of consistent types" do
      Finance::Settlement.create!(group: finance_groups(:pareja), from_user: users(:novia), to_user: users(:manu),
                                  amount_ars: 1000, settled_on: Date.current)
      query = query_for(users(:manu))
      assert_equal 1, query.by_date.size
      assert query.by_date.keys.all?(Date)
      assert_equal 1, query.by_month.size
      assert(query.by_month.keys.all? { |k| k.respond_to?(:to_date) })
      assert_equal 1, query.by_month_and_type.size
    end
  end
end

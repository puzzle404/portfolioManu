require "test_helper"

module Finance
  class ChartsControllerTest < ActionDispatch::IntegrationTest
    test "requires login" do
      get finance_charts_path
      assert_redirected_to new_user_session_path
    end

    test "renders for a user with personal and shared expenses across periods" do
      sign_in users(:manu)
      %w[today week month year].each do |period|
        get finance_charts_path(period: period)
        assert_response :success
      end
      get finance_charts_path(period: "custom", start_date: Date.current.beginning_of_month.to_s,
                              end_date: Date.current.to_s)
      assert_response :success
    end

    test "renders for a user without expenses" do
      sign_in users(:stranger)
      get finance_charts_path
      assert_response :success
    end
  end
end

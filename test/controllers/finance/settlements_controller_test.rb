require "test_helper"

module Finance
  class SettlementsControllerTest < ActionDispatch::IntegrationTest
    test "creates a settlement from current user to partner" do
      sign_in users(:novia)
      assert_difference("Finance::Settlement.count", 1) do
        post finance_settlements_path, params: { settlement: { amount_ars: "3000" } }
      end
      settlement = Finance::Settlement.last
      assert_equal users(:novia), settlement.from_user
      assert_equal users(:manu), settlement.to_user
      assert_redirected_to finance_shared_path
    end

    test "without a full group redirects with alert" do
      sign_in users(:stranger)
      assert_no_difference("Finance::Settlement.count") do
        post finance_settlements_path, params: { settlement: { amount_ars: "10" } }
      end
      assert_redirected_to finance_shared_path
      assert flash[:alert].present?
    end

    test "invalid amount shows alert" do
      sign_in users(:novia)
      post finance_settlements_path, params: { settlement: { amount_ars: "0" } }
      assert flash[:alert].present?
    end
  end
end

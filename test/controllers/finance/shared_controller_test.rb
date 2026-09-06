require "test_helper"

module Finance
  class SharedControllerTest < ActionDispatch::IntegrationTest
    test "requires login" do
      get finance_shared_path
      assert_redirected_to new_user_session_path
    end

    test "show without group offers create and join" do
      sign_in users(:stranger)
      get finance_shared_path
      assert_response :success
      assert_select "form[action=?]", finance_shared_path
      assert_select "form[action=?]", join_finance_shared_path
    end

    test "show with group renders partner, code and debts" do
      sign_in users(:manu)
      get finance_shared_path
      assert_response :success
      assert_select "body", /Novia/
      assert_select "body", /ABCD1234/
      assert_select "body", /3\.000/
    end

    test "create builds a group with the user as owner and member" do
      sign_in users(:stranger)
      assert_difference("Finance::Group.count", 1) { post finance_shared_path }
      assert_redirected_to finance_shared_path
      assert users(:stranger).reload.shared_group.member?(users(:stranger))
    end

    test "create is refused when already in a group" do
      sign_in users(:manu)
      assert_no_difference("Finance::Group.count") { post finance_shared_path }
      assert_redirected_to finance_shared_path
    end

    test "join with valid code adds membership" do
      group = Finance::Group.create!(owner: users(:stranger))
      newcomer = User.create!(email: "new@example.com", password: "password123", name: "Nuevo")
      sign_in newcomer
      post join_finance_shared_path, params: { invite_code: group.invite_code.downcase }
      assert_redirected_to finance_shared_path
      assert group.reload.member?(newcomer)
    end

    test "join with invalid code shows alert" do
      sign_in users(:stranger)
      post join_finance_shared_path, params: { invite_code: "NOPE" }
      assert_redirected_to finance_shared_path
      assert_match(/no existe/i, flash[:alert])
    end

    test "join a full group is refused" do
      sign_in users(:stranger)
      post join_finance_shared_path, params: { invite_code: "ABCD1234" }
      assert_not finance_groups(:pareja).member?(users(:stranger))
      assert_match(/completo/i, flash[:alert])
    end
  end
end

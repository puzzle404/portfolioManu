require "test_helper"
require "minitest/mock"

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

    test "show prefills the settle form for the debtor" do
      sign_in users(:novia)
      get finance_shared_path
      assert_select "input[name='settlement[amount_ars]'][value=?]", "3000.00"
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

    test "create redirects with alert when a race causes group creation to fail" do
      sign_in users(:stranger)
      Finance::Group.stub(:create!, ->(*) { raise ActiveRecord::RecordNotUnique, "boom" }) do
        post finance_shared_path
      end
      assert_redirected_to finance_shared_path
      assert_match(/no se pudo completar/i, flash[:alert])
    end

    test "join redirects with alert when a race causes membership creation to fail" do
      owner = User.create!(email: "owner@example.com", password: "password123", name: "Owner")
      group = Finance::Group.create!(owner: owner)
      sign_in users(:stranger)
      group.stub(:add_member!, ->(*) { raise ActiveRecord::RecordInvalid, group }) do
        Finance::Group.stub(:find_by, group) do
          post join_finance_shared_path, params: { invite_code: group.invite_code }
        end
      end
      assert_redirected_to finance_shared_path
      assert_match(/no se pudo completar/i, flash[:alert])
    end
    test "show without partner explains the flow and offers to leave" do
      owner = User.create!(email: "solo@example.com", password: "password123", name: "Solo")
      Finance::Group.create!(owner: owner)
      sign_in owner
      get finance_shared_path
      assert_response :success
      assert_select "body", /Tu pareja tiene que registrarse/
      assert_select "form[action=?][method=post]", finance_shared_path do
        assert_select "input[name=_method][value=delete]"
      end
    end

    test "destroy removes the space when the user is its only member" do
      owner = User.create!(email: "solo@example.com", password: "password123", name: "Solo")
      group = Finance::Group.create!(owner: owner)
      sign_in owner
      assert_difference("Finance::Group.count", -1) { delete finance_shared_path }
      assert_redirected_to finance_shared_path
      assert_not Finance::Group.exists?(group.id)
      assert_nil owner.reload.shared_group
    end

    test "destroy is refused when the partner already joined" do
      sign_in users(:manu)
      assert_no_difference("Finance::Group.count") { delete finance_shared_path }
      assert_redirected_to finance_shared_path
      assert_match(/otra persona/i, flash[:alert])
    end

    test "destroy without a space redirects with alert" do
      sign_in users(:stranger)
      delete finance_shared_path
      assert_redirected_to finance_shared_path
      assert flash[:alert].present?
    end
  end
end

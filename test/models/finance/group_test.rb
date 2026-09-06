require "test_helper"
require "minitest/mock"

module Finance
  class GroupTest < ActiveSupport::TestCase
    test "generates an 8 char uppercase invite code on create" do
      group = Finance::Group.create!(owner: users(:stranger))
      assert_match(/\A[A-Z0-9]{8}\z/, group.invite_code)
    end

    test "creating a group adds the owner as member" do
      group = Finance::Group.create!(owner: users(:stranger))
      assert group.member?(users(:stranger))
    end

    test "other_member returns the other user" do
      assert_equal users(:novia), finance_groups(:pareja).other_member(users(:manu))
      assert_equal users(:manu), finance_groups(:pareja).other_member(users(:novia))
    end

    test "full? when MAX_MEMBERS reached" do
      assert finance_groups(:pareja).full?
      assert_not Finance::Group.create!(owner: users(:stranger)).full?
    end

    test "add_member! refuses when full" do
      assert_raises(ActiveRecord::RecordInvalid) { finance_groups(:pareja).add_member!(users(:stranger)) }
    end

    test "user.shared_group returns the group" do
      assert_equal finance_groups(:pareja), users(:manu).shared_group
      assert_nil users(:stranger).shared_group
    end

    test "add_member! locks the group row while creating the membership" do
      group = Finance::Group.create!(owner: users(:stranger))
      newcomer = User.create!(email: "lock@example.com", password: "password123", name: "Lock")
      locked = false
      lock_stub = lambda do |&block|
        locked = true
        block.call
      end
      group.stub(:with_lock, lock_stub) { group.add_member!(newcomer) }
      assert locked
      assert group.member?(newcomer)
    end
  end
end

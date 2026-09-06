require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "display_name returns name when present" do
    assert_equal "Manu", users(:manu).display_name
  end

  test "display_name falls back to email local part" do
    assert_equal "stranger", users(:stranger).display_name
  end
end

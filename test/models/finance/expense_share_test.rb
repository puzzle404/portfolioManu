require "test_helper"

module Finance
  class ExpenseShareTest < ActiveSupport::TestCase
    test "a share built on a personal expense is invalid" do
      share = Finance::ExpenseShare.new(expense: finance_expenses(:legacy_nafta), user: users(:novia),
                                        amount: 100, amount_ars: 100)
      assert_not share.valid?
      assert_includes share.errors[:expense], "no es compartido"
    end
  end
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    set_fixture_class finance_categories: "Finance::Category",
                      finance_expenses: "Finance::Expense",
                      finance_groups: "Finance::Group",
                      finance_group_memberships: "Finance::GroupMembership",
                      finance_expense_shares: "Finance::ExpenseShare",
                      finance_settlements: "Finance::Settlement"

    fixtures :all
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
  end
end

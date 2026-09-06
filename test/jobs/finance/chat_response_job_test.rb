require "test_helper"

module Finance
  class ChatResponseJobTest < ActiveJob::TestCase
    test "prompt mentions the partner when the user has a full shared group" do
      prompt = Finance::ChatResponseJob.new.system_prompt(users(:manu))
      assert_includes prompt, "Novia"
      assert_includes prompt, "register_settlement"
    end

    test "prompt explains how to create a shared space when there is none" do
      prompt = Finance::ChatResponseJob.new.system_prompt(users(:stranger))
      assert_includes prompt, "/finance/shared"
      assert_not_includes prompt, "register_settlement"
    end
  end
end

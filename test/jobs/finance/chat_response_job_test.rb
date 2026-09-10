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
    test "prompt attributes the payment to the user by default and treats their own name as themselves" do
      prompt = Finance::ChatResponseJob.new.system_prompt(users(:manu))
      assert_includes prompt, "Si no dice quien pago, pago el usuario"
      assert_includes prompt, "paid_by_other=false"
      assert_match(/"pagado por Manu".*paid_by_other=false/m, prompt)
      assert_match(/paid_by_other=true SOLO/, prompt)
    end
  end
end

class Chat < ApplicationRecord
  acts_as_chat messages_foreign_key: :chat_id
  belongs_to :user

  # Limit context sent to the API to prevent old messages from poisoning model behavior.
  # All messages remain in DB for display, but only recent ones are sent to the LLM.
  MAX_CONTEXT_MESSAGES = 20

  def to_llm
    model_record = model_association
    @chat ||= (context || RubyLLM).chat(
      model: model_record.model_id,
      provider: model_record.provider.to_sym,
      assume_model_exists: assume_model_exists || false
    )
    @chat.reset_messages!

    system_msgs = messages_association.where(role: "system").order(:id).to_a
    recent_msgs = messages_association.where.not(role: "system").order(:id).last(MAX_CONTEXT_MESSAGES)

    order_messages_for_llm(system_msgs + recent_msgs).each do |msg|
      @chat.add_message(msg.to_llm)
    end
    reapply_runtime_instructions(@chat)

    setup_persistence_callbacks
  end
end

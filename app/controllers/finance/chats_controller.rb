module Finance
  class ChatsController < BaseController
    def show
      @chat = current_user_chat
      @messages = @chat.messages.includes(:tool_calls).order(:created_at)
    end

    private

    def current_user_chat
      current_user.chats.first_or_create!(model_id: "gpt-4o-mini")
    end
  end
end

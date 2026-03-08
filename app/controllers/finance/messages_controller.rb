module Finance
  class MessagesController < BaseController
    def create
      @chat = current_user.chats.first!
      @content = params.dig(:message, :content)

      return head(:bad_request) if @content.blank?

      # Enqueue AI response job (ruby_llm's chat.ask will persist both user + assistant messages)
      Finance::ChatResponseJob.perform_later(@chat.id, @content)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to finance_root_path }
      end
    end
  end
end

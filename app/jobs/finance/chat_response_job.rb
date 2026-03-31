module Finance
  class ChatResponseJob < ApplicationJob
    queue_as :default

    def perform(chat_id, content)
      chat = ::Chat.find(chat_id)
      user = chat.user

      # Set system instructions if this is the first interaction
      if chat.messages.where(role: "system").none?
        chat.with_instructions(system_prompt)
      end

      # Register tools with user context
      chat.with_tool(RegisterExpenseTool.new(user))
      chat.with_tool(ListExpensesTool.new(user))
      chat.with_tool(GetBalanceTool.new(user))

      # Ask the AI - ruby_llm handles tool calling and message persistence automatically
      chat.ask(content)

      # After response is complete, broadcast the full updated chat
      # Remove loading indicator and append AI response
      assistant_message = chat.messages.where(role: "assistant").last

      Turbo::StreamsChannel.broadcast_remove_to(
        "chat_#{chat.id}",
        target: "finance_message_loading"
      )

      if assistant_message
        Turbo::StreamsChannel.broadcast_append_to(
          "chat_#{chat.id}",
          target: "finance_messages",
          partial: "finance/messages/message",
          locals: { message: assistant_message }
        )
      end
    end

    private

    def system_prompt
      <<~PROMPT
        Eres un asistente de finanzas personales. Tu trabajo es ayudar al usuario a registrar y consultar sus gastos de manera conversacional.

        Cuando el usuario mencione un gasto (ej: "pague 500 de luz", "gaste 200 en uber", "50 pesos de cafe"), usa la herramienta register_expense para registrarlo.

        Cuando el usuario pregunte por sus gastos (ej: "cuanto llevo este mes", "que gaste hoy"), usa list_expenses o get_balance segun corresponda.

        Responde siempre en espanol, de manera breve y amigable. Confirma los gastos registrados mencionando monto, categoria y fecha. Si no estas seguro de la categoria, usa la mas probable.

        Las categorias disponibles son: Servicios, Comida, Transporte, Entretenimiento, Salud, Educacion, Ropa, Hogar, Suscripciones, Otros.

        La moneda por defecto es ARS (pesos argentinos). Si el usuario menciona dolares, USD o "en dolares", usa currency "USD" en register_expense. El tipo de cambio del dolar oficial se obtiene automaticamente. Si el usuario proporciona un tipo de cambio especifico, usalo con el parametro exchange_rate. Los totales y balances se muestran en ARS.

        Hoy es #{Date.current.strftime("%A %d de %B de %Y")}.
      PROMPT
    end
  end
end

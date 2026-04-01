module Finance
  class ChatResponseJob < ApplicationJob
    queue_as :default

    def perform(chat_id, content)
      chat = ::Chat.find(chat_id)
      user = chat.user

      # Replace system instructions on every request to pick up prompt changes and update date
      system_msg = chat.messages.find_by(role: "system")
      if system_msg
        system_msg.update!(content: system_prompt)
      else
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

        IMPORTANTE: Siempre que el usuario mencione un gasto, registralo con register_expense. NUNCA respondas que ya fue registrado anteriormente. Cada mensaje del usuario es una transaccion nueva e independiente, aunque la descripcion sea similar a una anterior.

        Las categorias disponibles son: Servicios, Comida, Transporte, Entretenimiento, Salud, Educacion, Ropa, Hogar, Suscripciones, Otros.

        Los gastos pueden ser de tipo "fijo" (recurrentes mensuales como alquiler, servicios, suscripciones, monotributo, internet) o "variable" (consumo variable como comida, salidas, transporte, farmacia). Usa expense_type "fijo" cuando el usuario mencione gastos recurrentes/fijos. Por defecto usa "variable".

        La moneda por defecto es ARS (pesos argentinos). Si el usuario menciona dolares, USD o "en dolares":
        - Usa currency "USD" en register_expense con el monto ORIGINAL en dolares (NO conviertas a pesos vos mismo).
        - Ejemplo: si dice "100 usd", pasa amount=100 y currency="USD". NUNCA pases amount=141000 con currency="ARS".
        - El tipo de cambio del dolar oficial se obtiene automaticamente via API. NO necesitas calcularlo.
        - Si el usuario proporciona un tipo de cambio especifico (ej: "a 1400"), pasalo con el parametro exchange_rate.
        - Los totales y balances se muestran en ARS.

        Hoy es #{Date.current.strftime("%A %d de %B de %Y")}.
      PROMPT
    end
  end
end

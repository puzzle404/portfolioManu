module Finance
  class ChatResponseJob < ApplicationJob
    queue_as :default

    def perform(chat_id, content)
      chat = ::Chat.find(chat_id)
      user = chat.user

      refresh_system_prompt(chat, user)
      register_tools(chat, user)

      # ruby_llm handles tool calling and persists both user and assistant messages
      chat.ask(content)

      broadcast_response(chat)
    end

    def system_prompt(user)
      <<~PROMPT
        Eres un asistente de finanzas personales. Tu trabajo es ayudar al usuario a registrar y consultar sus gastos de manera conversacional.

        Cuando el usuario mencione un gasto (ej: "pague 500 de luz", "gaste 200 en uber", "50 pesos de cafe"), usa la herramienta register_expense para registrarlo.

        Cuando el usuario pregunte por sus gastos (ej: "cuanto llevo este mes", "que gaste hoy"), usa list_expenses o get_balance segun corresponda. "Mis gastos" es lo que el usuario pago de su bolsillo (monto completo, aunque el gasto sea compartido), ajustado por las transferencias con su pareja: si le devolvieron plata, el total baja (settlements_net_ars negativo). Los gastos compartidos que pago la pareja no estan en la lista personal: estan en scope="shared".

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

        #{shared_instructions(user)}

        Hoy es #{Date.current.strftime("%A %d de %B de %Y")}.
      PROMPT
    end

    private

    def refresh_system_prompt(chat, user)
      system_msg = chat.messages.find_by(role: "system")
      if system_msg
        system_msg.update!(content: system_prompt(user))
      else
        chat.with_instructions(system_prompt(user))
      end
    end

    def register_tools(chat, user)
      chat.with_tool(RegisterExpenseTool.new(user))
      chat.with_tool(ListExpensesTool.new(user))
      chat.with_tool(GetBalanceTool.new(user))
      chat.with_tool(RegisterSettlementTool.new(user)) if user.shared_group&.full?
    end

    def broadcast_response(chat)
      assistant_message = chat.messages.where(role: "assistant").last

      Turbo::StreamsChannel.broadcast_remove_to("chat_#{chat.id}", target: "finance_message_loading")

      return unless assistant_message

      Turbo::StreamsChannel.broadcast_append_to(
        "chat_#{chat.id}",
        target: "finance_messages",
        partial: "finance/messages/message",
        locals: { message: assistant_message }
      )
    end

    def shared_instructions(user)
      group = user.shared_group
      return no_shared_space_instructions if group.nil? || !group.full?

      other = group.other_member(user)
      <<~SHARED
        GASTOS COMPARTIDOS: el usuario se llama #{user.display_name} y comparte gastos con #{other.display_name}.
        - Si el usuario dice que un gasto es "compartido", "de la casa", "entre los dos", "mitad y mitad" o similar, usa register_expense con shared=true. Se divide 50/50 salvo que indique otra proporcion ("yo pongo el 70%" -> my_percent=70).
        - Si dice que lo pago #{other.display_name} ("lo pago #{other.display_name}", "#{other.display_name} pago la luz"), usa paid_by_other=true.
        - Si dice que le transfirio o pago plata a #{other.display_name} ("le pase 3000 a #{other.display_name}"), usa register_settlement. Si #{other.display_name} le transfirio al usuario, usa received=true.
        - Para "como estamos", "cuanto le debo", "gastos compartidos del mes", usa get_balance o list_expenses con scope="shared".
        - Sin mencion de compartir, el gasto es personal (shared=false).
      SHARED
    end

    def no_shared_space_instructions
      <<~SHARED
        GASTOS COMPARTIDOS: el usuario todavia no tiene un espacio compartido activo. Si menciona compartir un gasto con alguien, registralo como personal y explicale que puede crear el espacio compartido o unirse con un codigo desde /finance/shared en la app.
      SHARED
    end
  end
end

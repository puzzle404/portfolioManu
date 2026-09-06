# Gastos compartidos entre dos usuarios — Diseño

**Fecha:** 2026-09-06
**Estado:** aprobado en brainstorming, pendiente de plan de implementación

## Objetivo

Que una segunda persona (la pareja de Manuel) pueda usar la app de finanzas
en `/finance` con su propio usuario, cargar sus gastos personales, y que
ambos puedan marcar gastos como **compartidos**: se dividen entre los dos,
se lleva cuenta de quién le debe a quién y se pueden saldar deudas.

El caso de uso es una pareja. La UI y el agente asumen **un único espacio
compartido por usuario**. El modelo de datos usa una tabla de grupos
mínima para no cerrar la puerta a más de dos personas en el futuro, pero
no se construye ninguna gestión de múltiples grupos.

## Requisito no negociable: no romper datos existentes

Hay siete meses de gastos cargados en `finance_expenses`. Toda migración es
aditiva:

- No se borra, renombra ni cambia el tipo de ninguna columna existente.
- Las columnas nuevas en tablas existentes son nullable o tienen default.
- Un gasto con `group_id` nulo es **personal** y se comporta exactamente
  como hoy: cuenta al 100% para su `user_id` en listados y gráficos.
- Antes de migrar en producción se hace `pg_dump`.
- Un test carga un gasto "viejo" (sin group ni shares) y verifica que
  aparece en `visible_to(user)` y suma al 100%.

## Situación actual

- `Finance::Expense` tiene `user_id`, categoría, `amount`, `currency`,
  `exchange_rate`, `amount_ars`, `expense_type` (fijo/variable),
  `expense_date`, `message_id` opcional.
- `Finance::ExpensesController`, `Finance::ChartsController`,
  `ListExpensesTool`, `GetBalanceTool` filtran por
  `current_user.finance_expenses`.
- `RegisterExpenseTool.new(user)` crea gastos para el usuario del chat.
- `Finance::ChatResponseJob` reescribe el system prompt en cada request y
  registra los tres tools.
- Devise con `:registerable` activo; `users` solo tiene `email`.
- `resolve_dates` está duplicado en cuatro archivos.

## Modelo de datos

### Tablas nuevas (namespace `Finance`, prefijo `finance_`)

**`finance_groups`**
| columna | tipo | notas |
|---|---|---|
| name | string, not null | default "Compartido"; no se expone en la UI de esta iteración |
| invite_code | string, not null, unique | 8 chars alfanuméricos mayúsculas, `SecureRandom.alphanumeric(8).upcase` |
| owner_id | bigint FK users, not null | quien creó el espacio |

**`finance_group_memberships`**
| columna | tipo | notas |
|---|---|---|
| group_id | FK finance_groups, not null | |
| user_id | FK users, not null | |
| índice único | (group_id, user_id) | el owner también tiene membership |

**`finance_expense_shares`**
| columna | tipo | notas |
|---|---|---|
| expense_id | FK finance_expenses, not null | |
| user_id | FK users, not null | |
| amount | decimal(10,2), not null | en la moneda del gasto |
| amount_ars | decimal(12,2), not null | `amount * exchange_rate` o `amount` si ARS |
| índice único | (expense_id, user_id) | |

**`finance_settlements`**
| columna | tipo | notas |
|---|---|---|
| group_id | FK finance_groups, not null | |
| from_user_id | FK users, not null | quien paga |
| to_user_id | FK users, not null | quien recibe |
| amount_ars | decimal(12,2), not null | |
| settled_on | date, not null | |
| description | string, nullable | |
| message_id | FK messages, nullable | trazabilidad con el chat, igual que expenses |

### Cambios aditivos a tablas existentes

**`finance_expenses`**
- `group_id` bigint FK finance_groups, **nullable**, indexado. Nulo = personal.
- `payer_id` bigint FK users, **nullable**. Backfill en la misma migración:
  `UPDATE finance_expenses SET payer_id = user_id WHERE payer_id IS NULL`.
  `user_id` mantiene el significado "quién lo registró".

**`users`**
- `name` string, nullable. Se pide en registro y edición de Devise.
  `User#display_name` devuelve `name` o la parte local del email como
  fallback.

### Modelos Ruby

- `Finance::Group`: `has_many :memberships`, `has_many :members, through:`,
  `has_many :expenses`, `has_many :settlements`, `belongs_to :owner`.
  `before_create :generate_invite_code`. `#other_member(user)` devuelve el
  otro miembro (para la UX de dos personas).
- `Finance::GroupMembership`.
- `Finance::ExpenseShare`: `belongs_to :expense`, `belongs_to :user`.
- `Finance::Settlement`: validación `from_user != to_user`, ambos miembros
  del grupo.
- `Finance::Expense` gana: `belongs_to :group, optional: true`,
  `belongs_to :payer, class_name: "User", optional: true`,
  `has_many :shares, dependent: :destroy`, `#shared?` (`group_id.present?`),
  `#amount_ars_for(user)` (share del user si compartido, `amount_ars` si
  personal), `#share_for(user)`.
- `User` gana: `has_many :group_memberships`, `has_many :groups, through:`,
  `#shared_group` (el primero; la UI asume uno), `#display_name`.

## Semántica de "mis gastos"

**Revisado el 2026-09-06 tras las pruebas con datos reales.** La primera
versión sumaba "personales al 100% más mi share de los compartidos" y
resultó confusa: el usuario veía montos que no había pagado. La regla
vigente es:

- **"Mis gastos" es lo que salió del bolsillo del usuario**: los gastos en
  los que es `payer`, personales o compartidos, al monto completo
  (`Finance::Expense.paid_by(user)`). Un gasto compartido que pagó la
  pareja no aparece en la lista personal, aunque lo haya cargado el
  usuario; vive en la pantalla Compartido.
- **Los saldos ajustan el total**: una transferencia enviada suma, una
  recibida resta. Se listan como filas en "Mis gastos" ("Le pagaste a X",
  "X te pago"). Con un filtro de categoría, tipo, moneda o búsqueda activo
  los saldos no se aplican.
- La fila de un gasto compartido en "Mis gastos" muestra el monto completo
  y una nota "compartido con X (N%)". El detalle del reparto (barra,
  quién pagó, partes, ajustar mi parte) está solo en `/finance/shared`.
- `Finance::SpendingQuery` implementa esta regla para listados, gráficos
  y tools. `Finance::Expense.visible_to(user)` queda solo para
  autorización (editar/borrar).

## Split

- `Finance::SplitCalculator.call(expense, members:, percents: nil)`:
  partes iguales entre `members` por defecto; con `percents` (hash
  user => porcentaje que suma 100) se aplican esos. El redondeo a
  centavos se ajusta en el último participante para que la suma cierre
  exacta al `amount` del gasto. Genera `amount` y `amount_ars` por share.
- Al crear un gasto compartido se generan shares para todos los
  miembros del grupo (dos personas).
- Editar el gasto (monto o moneda) regenera los shares conservando los
  porcentajes actuales. Editar los shares desde la UI valida que sumen
  el total.

## Balance del espacio compartido

`Finance::GroupBalance.new(group)`:
- Por miembro: `neto = pagado − shares + settlements enviados −
  settlements recibidos` (todo en ARS). Positivo: le deben. Negativo: debe.
- `#debts` devuelve pares `{from:, to:, amount_ars:}`. Con dos miembros
  hay a lo sumo uno. Se implementa con greedy sobre netos ordenados para
  que sirva con más miembros sin cambios.

## Agente

Todos los tools siguen recibiendo `user` en `initialize`.

**`RegisterExpenseTool`** gana parámetros opcionales:
- `shared` (boolean): si true, el gasto va al `user.shared_group` con
  split 50/50. Si el usuario no tiene espacio compartido, devuelve error
  explicando cómo crearlo.
- `my_percent` (número 0–100): override del split, el resto va al otro
  miembro. Ej. "yo pongo el 70%".
- `paid_by_other` (boolean): el pagador es el otro miembro. Ej. "lo pagó
  Manu".
Sin `shared`, el comportamiento es idéntico al actual.

**`ListExpensesTool`** y **`GetBalanceTool`** ganan `scope`:
`"personal"` (default: personales + mis shares) o `"shared"` (todos los
gastos del espacio compartido, montos completos). `GetBalanceTool` con
`scope: "shared"` incluye además `debts` del `GroupBalance`.

**`RegisterSettlementTool`** (nuevo): "le transferí 3000 a Manu" →
`Settlement` de user a `other_member` en `shared_group`. Parámetros:
`amount`, `date` opcional, `description` opcional, `received` (boolean,
para "Manu me transfirió 3000").

**System prompt** (`ChatResponseJob#system_prompt`): se agrega un bloque
condicional cuando el usuario tiene espacio compartido: nombre del otro
miembro, y las reglas: "compartido", "de la casa", "entre los dos",
"mitad y mitad" → `shared: true`; "lo pagó X" → `paid_by_other`; "le
pasé/transferí plata a X" → `register_settlement`. Si no tiene espacio
compartido y menciona compartir, explicar cómo crearlo en `/finance/shared`.

## Controllers y vistas

Namespace `finance`, layout `finance` existente, mobile-first.

**`Finance::SharedController`** (singular resource `/finance/shared`):
- `show`: si no hay grupo, muestra dos acciones: "Crear espacio" (genera
  el grupo y muestra el código) y "Unirme con código" (formulario). Si
  hay grupo: otro miembro (o "esperando que alguien se una" con el código
  y botón copiar), balance con quién debe a quién, botón "Saldar"
  prellenado, lista de gastos compartidos recientes con pagador y split.
- `create`: crea grupo con owner y membership.
- `join`: `POST /finance/shared/join` con `invite_code`; valida que exista,
  que el usuario no esté ya en un grupo, y que el grupo tenga menos de
  dos miembros (límite de esta iteración; constante `MAX_MEMBERS = 2`
  en `Finance::Group`, fácil de subir).

**`Finance::SettlementsController#create`**: desde el botón Saldar.
Redirige a `/finance/shared`.

**`Finance::ExpensesController`**:
- `index` usa `visible_to(current_user)` y `SpendingQuery` para el total.
  Cada gasto compartido muestra etiqueta "Compartido", quién pagó y "tu
  parte: $X".
- `update`/`destroy`: `find` sobre `visible_to`; solo miembros del grupo
  tocan compartidos. El modal de edición permite marcar/desmarcar
  compartido y ajustar los montos de cada share.
- `expense_params` permite `shared`, `payer_id`, `shares_attributes`.

**`Finance::ChartsController`**: reemplaza sus agregaciones por
`SpendingQuery`. Sin filtros nuevos.

**Navbar**: ícono `fa-user-friends` hacia `/finance/shared` junto al de
gráficos.

**Devise**: campo `name` en `registrations/new` y `registrations/edit`;
`configure_permitted_parameters` en `ApplicationController`.

## Refactor incluido

`resolve_dates` duplicado en `ExpensesController`, `ChartsController`,
`ListExpensesTool` y `GetBalanceTool` pasa a `Finance::PeriodResolver.call(
period, start_date: nil, end_date: nil)`. Se hace porque los cuatro
archivos se tocan de todas formas.

## Testing (Minitest)

- **Modelos**: `SplitCalculator` (50/50, 70/30, redondeo con montos
  impares, USD con exchange_rate), `visible_to`, `amount_ars_for`,
  `GroupBalance` (sin settlements, con settlement parcial y total),
  gasto legacy sin group cuenta al 100%.
- **Servicio**: `SpendingQuery` mezcla personales y shares correctamente
  en `total_ars` y `by_category`.
- **Tools**: registrar personal sigue igual (regresión); `shared: true`
  genera dos shares; `my_percent: 70`; `paid_by_other`; sin grupo devuelve
  error; `RegisterSettlementTool` con y sin `received`.
- **Controllers**: `join` con código válido, inválido y grupo lleno;
  no-miembro no puede `update` un gasto compartido; `create` de
  settlement.
- Fixtures: dos usuarios, un grupo, gastos personales y compartidos.

## Fuera de alcance

- Más de dos miembros por espacio (el modelo lo permite, la UI y el
  agente no).
- Salir de un espacio o expulsar miembros.
- Múltiples espacios compartidos por usuario.
- Filtro personal/compartido en gráficos.
- Notificaciones al otro miembro.
- Tipo de cambio distinto por participante (se usa el del gasto).

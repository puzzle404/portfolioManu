# Seed de gastos de ejemplo para probar el flujo de finanzas con USD y ARS
# Correr con: rails runner db/seeds/finance_expenses.rb

user = User.first
abort "No hay usuarios creados. Crea uno primero." unless user

Finance::Category.seed!
Finance::Expense.where(user: user).destroy_all

cat = ->(name) { Finance::Category.find_by!(name: name) }

# Gastos en ARS
[
  { category: "Servicios", amount: 15_000, description: "Recibo de luz", days_ago: 2 },
  { category: "Servicios", amount: 8_500, description: "Gas natural", days_ago: 5 },
  { category: "Servicios", amount: 12_000, description: "Internet Fibertel", days_ago: 10 },
  { category: "Comida", amount: 4_500, description: "Supermercado Dia", days_ago: 1 },
  { category: "Comida", amount: 8_200, description: "Carrefour semanal", days_ago: 4 },
  { category: "Comida", amount: 3_800, description: "Verduleria", days_ago: 7 },
  { category: "Comida", amount: 6_500, description: "Pedidos Ya - pizza", days_ago: 3 },
  { category: "Transporte", amount: 1_200, description: "SUBE recarga", days_ago: 6 },
  { category: "Transporte", amount: 5_500, description: "Uber al centro", days_ago: 2 },
  { category: "Entretenimiento", amount: 3_500, description: "Netflix", days_ago: 12 },
  { category: "Entretenimiento", amount: 7_000, description: "Cine con amigos", days_ago: 8 },
  { category: "Salud", amount: 4_000, description: "Farmacia - remedios", days_ago: 9 },
  { category: "Ropa", amount: 25_000, description: "Zapatillas Nike", days_ago: 11 },
  { category: "Hogar", amount: 18_000, description: "Lampara nueva", days_ago: 14 },
  { category: "Suscripciones", amount: 2_800, description: "Spotify Premium", days_ago: 1 },
  { category: "Suscripciones", amount: 9_500, description: "ChatGPT Plus", days_ago: 15 },
  { category: "Educacion", amount: 35_000, description: "Curso Udemy Rails", days_ago: 13 },
  { category: "Otros", amount: 2_000, description: "Propina delivery", days_ago: 3 },
].each do |data|
  Finance::Expense.create!(
    user: user,
    category: cat.call(data[:category]),
    amount: data[:amount],
    description: data[:description],
    expense_date: Date.current - data[:days_ago],
    currency: "ARS"
  )
end

# Gastos en USD
dolar_rate = DolarService.venta || 1420.0

[
  { category: "Suscripciones", amount: 20, description: "GitHub Pro", days_ago: 5 },
  { category: "Suscripciones", amount: 10, description: "Cursor IDE", days_ago: 10 },
  { category: "Educacion", amount: 49.99, description: "Udemy - Docker course", days_ago: 8 },
  { category: "Entretenimiento", amount: 6.99, description: "Disney+ mensual", days_ago: 12 },
].each do |data|
  Finance::Expense.create!(
    user: user,
    category: cat.call(data[:category]),
    amount: data[:amount],
    description: data[:description],
    expense_date: Date.current - data[:days_ago],
    currency: "USD",
    exchange_rate: dolar_rate
  )
end

ars_count = Finance::Expense.where(user: user, currency: "ARS").count
usd_count = Finance::Expense.where(user: user, currency: "USD").count
puts "Listo: #{ars_count} gastos ARS + #{usd_count} gastos USD (TC: $#{dolar_rate})"

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Cleaning existing data..."
Project.destroy_all
Experience.destroy_all
Skill.destroy_all

puts "Creating skills..."
Skill::SKILLS.each do |skill|
  Skill.create!(name: skill)
end

puts "Creating projects..."

Project.create!(
  name: "E-Commerce Platform",
  short_description: "Full-stack e-commerce platform with integrated payments",
  description: "Built a complete e-commerce platform with Ruby on Rails, implementing shopping cart, Stripe payment gateway, inventory management, and admin dashboard. Features Devise authentication, Elasticsearch for search, and AWS deployment.",
  start_date: Date.new(2023, 6, 1),
  end_date: Date.new(2023, 12, 15)
)

Project.create!(
  name: "Real-Time Task Manager",
  short_description: "Collaborative task management app with live updates",
  description: "Productivity app built with Rails and Hotwire for real-time updates. Implements Turbo Streams for instant synchronization between users, Stimulus for frontend interactivity, and PostgreSQL with full-text search for task searching.",
  start_date: Date.new(2023, 1, 10),
  end_date: Date.new(2023, 5, 20)
)

Project.create!(
  name: "Fintech REST API",
  short_description: "Robust API for payment processing",
  description: "Designed and developed a RESTful API for a fintech startup using Rails API mode. Implemented JWT authentication, rate limiting, Swagger documentation, and comprehensive RSpec tests. The API handles thousands of daily transactions with 99.9% uptime.",
  start_date: Date.new(2022, 8, 1),
  end_date: Date.new(2023, 2, 28)
)

Project.create!(
  name: "Analytics Dashboard",
  short_description: "Interactive dashboard for data visualization",
  description: "Built an analytics dashboard using Rails with Chart.js and D3.js for interactive visualizations. Includes exportable reports, dynamic filters with Stimulus, and query optimization with Redis caching to handle large data volumes.",
  start_date: Date.new(2022, 3, 1),
  end_date: Date.new(2022, 7, 30)
)

puts "Creating work experiences..."

Experience.create!(
  name: "Full-Stack Developer",
  company: "GoCuotas",
  role: "Senior Full-Stack Developer",
  short_description: "Building payment platform with Rails and modern technologies",
  description: "Responsible for developing and maintaining the main payment platform. Implemented rewards system, integration with multiple payment providers, and performance optimization. Working with agile team using Scrum methodology.",
  start_date: Date.new(2022, 3, 1),
  end_date: nil
)

Experience.create!(
  name: "Backend Developer",
  company: "Fintech Startup",
  role: "Ruby on Rails Developer",
  short_description: "Developing APIs and microservices for financial applications",
  description: "Developed RESTful APIs and microservices for financial transaction processing. Implemented authentication systems, bank integrations, and monitoring dashboards. Participated in monolith to microservices architecture migration.",
  start_date: Date.new(2020, 6, 1),
  end_date: Date.new(2022, 2, 28)
)

Experience.create!(
  name: "Web Developer",
  company: "Digital Agency",
  role: "Jr. Full-Stack Developer",
  short_description: "Building websites and web applications for diverse clients",
  description: "Developed over 15 websites and web applications for clients across various industries. Worked with Ruby on Rails, JavaScript, HTML/CSS. Participated in client meetings and project estimation. Learned agile methodologies and teamwork.",
  start_date: Date.new(2019, 1, 15),
  end_date: Date.new(2020, 5, 31)
)

puts "Creating finance categories..."
Finance::Category.seed!

puts "✅ Seeds completed!"
puts "   - #{Project.count} projects created"
puts "   - #{Experience.count} experiences created"
puts "   - #{Skill.count} skills created"
puts "   - #{Finance::Category.count} finance categories created"

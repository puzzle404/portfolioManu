# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

#borramos las categorias

Skill.destroy_all
Skill::SKILLS.each do |skill|
  Skill.create!(name: skill)
end

Project.create!(name: "Trousers", description: "A pair of bluejeans best suited for tall people.")
Project.create!(name: "Shirt", description: "A white shirt with a pocket.")
Project.create!(name: "Shoes", description: "A pair of black shoes.")
Project.create!(name: "Hat", description: "A baseball cap.")
Project.create!(name: "Chair", description: "A wooden chair.")
Project.create!(name: "Table", description: "A metal table.")
Project.create!(name: "Sofa", description: "A leather sofa.")
Project.create!(name: "Bed", description: "A queen-sized bed.")

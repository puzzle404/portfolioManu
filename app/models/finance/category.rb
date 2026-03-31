module Finance
  class Category < ApplicationRecord
    self.table_name = "finance_categories"

    has_many :expenses, class_name: "Finance::Expense", foreign_key: :finance_category_id

    validates :name, presence: true, uniqueness: true

    DEFAULTS = [
      { name: "Servicios", icon: "fa-bolt", color: "#f59e0b" },
      { name: "Comida", icon: "fa-utensils", color: "#ef4444" },
      { name: "Transporte", icon: "fa-car", color: "#3b82f6" },
      { name: "Entretenimiento", icon: "fa-film", color: "#8b5cf6" },
      { name: "Salud", icon: "fa-heart-pulse", color: "#ec4899" },
      { name: "Educacion", icon: "fa-graduation-cap", color: "#06b6d4" },
      { name: "Ropa", icon: "fa-shirt", color: "#f97316" },
      { name: "Hogar", icon: "fa-house", color: "#10b981" },
      { name: "Suscripciones", icon: "fa-repeat", color: "#6366f1" },
      { name: "Otros", icon: "fa-ellipsis", color: "#6b7280" }
    ].freeze

    def self.seed!
      DEFAULTS.each do |attrs|
        find_or_create_by!(name: attrs[:name]) do |cat|
          cat.icon = attrs[:icon]
          cat.color = attrs[:color]
        end
      end
    end
  end
end

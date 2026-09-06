module Finance
  class Settlement < ApplicationRecord
    self.table_name = "finance_settlements"

    belongs_to :group, class_name: "Finance::Group"
    belongs_to :from_user, class_name: "User"
    belongs_to :to_user, class_name: "User"
    belongs_to :message, optional: true

    validates :amount_ars, presence: true, numericality: { greater_than: 0 }
    validates :settled_on, presence: true
    validate :different_parties
    validate :parties_are_members

    scope :recent, -> { order(settled_on: :desc, created_at: :desc) }
    scope :for_period, ->(start_date, end_date) { where(settled_on: start_date..end_date) }
    scope :involving, ->(user) { where("from_user_id = :id OR to_user_id = :id", id: user.id) }

    def counterpart_for(user)
      from_user_id == user.id ? to_user : from_user
    end

    def sent_by?(user)
      from_user_id == user.id
    end

    private

    def different_parties
      errors.add(:to_user, "debe ser distinto de quien paga") if from_user_id.present? && from_user_id == to_user_id
    end

    def parties_are_members
      return if group.nil?

      errors.add(:from_user, "no es miembro") if from_user && !group.member?(from_user)
      errors.add(:to_user, "no es miembro") if to_user && !group.member?(to_user)
    end
  end
end

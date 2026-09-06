module Finance
  class GroupMembership < ApplicationRecord
    self.table_name = "finance_group_memberships"

    belongs_to :group, class_name: "Finance::Group"
    belongs_to :user

    validates :user_id, uniqueness: { scope: :group_id }
    validate :group_not_full, on: :create

    private

    def group_not_full
      return unless group && group.memberships.count >= Finance::Group::MAX_MEMBERS

      errors.add(:base, "El espacio compartido ya esta completo")
    end
  end
end

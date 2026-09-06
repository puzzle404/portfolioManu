module Finance
  class Group < ApplicationRecord
    self.table_name = "finance_groups"

    MAX_MEMBERS = 2

    belongs_to :owner, class_name: "User"
    has_many :memberships, class_name: "Finance::GroupMembership", foreign_key: :group_id, dependent: :destroy
    has_many :members, through: :memberships, source: :user
    has_many :expenses, class_name: "Finance::Expense", foreign_key: :group_id, dependent: :nullify
    has_many :settlements, class_name: "Finance::Settlement", foreign_key: :group_id, dependent: :destroy

    validates :name, presence: true
    validates :invite_code, presence: true, uniqueness: true

    before_validation :generate_invite_code, on: :create
    after_create :add_owner_membership

    def full?
      memberships.count >= MAX_MEMBERS
    end

    def member?(user)
      memberships.exists?(user_id: user.id)
    end

    def other_member(user)
      members.where.not(id: user.id).first
    end

    def add_member!(user)
      memberships.create!(user: user)
    end

    private

    def generate_invite_code
      self.invite_code ||= loop do
        code = SecureRandom.alphanumeric(8).upcase
        break code unless Finance::Group.exists?(invite_code: code)
      end
    end

    def add_owner_membership
      memberships.create!(user: owner)
    end
  end
end

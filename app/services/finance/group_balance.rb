module Finance
  # Net position per member of a group and the resulting debts.
  # net > 0: others owe this member. net < 0: this member owes.
  class GroupBalance
    def initialize(group)
      @group = group
    end

    def net_by_member
      @net_by_member ||= @group.members.to_a.each_with_object({}) do |member, acc|
        acc[member] = paid_by(member) - owed_share_of(member) +
                      settlements_sent_by(member) - settlements_received_by(member)
      end
    end

    # Greedy matching of debtors to creditors. With two members yields at most one debt.
    def debts
      creditors = net_by_member.select { |_, net| net.positive? }
                               .sort_by { |_, net| -net }
                               .map { |user, net| [user, net] }
      debtors = net_by_member.select { |_, net| net.negative? }
                             .sort_by { |_, net| net }
                             .map { |user, net| [user, -net] }
      match_debts(creditors, debtors)
    end

    private

    def paid_by(member)
      @group.expenses.where(payer_id: member.id).sum(:amount_ars)
    end

    def owed_share_of(member)
      Finance::ExpenseShare.joins(:expense)
                           .where(finance_expenses: { group_id: @group.id }, user_id: member.id)
                           .sum(:amount_ars)
    end

    def settlements_sent_by(member)
      @group.settlements.where(from_user_id: member.id).sum(:amount_ars)
    end

    def settlements_received_by(member)
      @group.settlements.where(to_user_id: member.id).sum(:amount_ars)
    end

    def match_debts(creditors, debtors)
      result = []
      result << settle_one_pair(creditors, debtors) until creditors.empty? || debtors.empty?
      result
    end

    def settle_one_pair(creditors, debtors)
      creditor, credit = creditors.first
      debtor, debt = debtors.first
      amount = [credit, debt].min
      remaining_credit = credit - amount
      remaining_debt = debt - amount
      remaining_credit.zero? ? creditors.shift : creditors[0] = [creditor, remaining_credit]
      remaining_debt.zero? ? debtors.shift : debtors[0] = [debtor, remaining_debt]
      { from: debtor, to: creditor, amount_ars: amount }
    end
  end
end

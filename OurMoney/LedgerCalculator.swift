import Foundation

struct LedgerCalculator {
    func calculate(currentUserId: String, transactions: [Transaction], settlements: [Settlement]) -> LedgerBalance {
        var myTotalPaid: Int64 = 0
        var partnerTotalPaid: Int64 = 0
        var myTotalResponsibility: Int64 = 0
        var partnerTotalResponsibility: Int64 = 0

        for tx in transactions where !tx.isDeleted && !tx.personal && tx.type != .income && tx.type != .transfer {
            if tx.paidBy == currentUserId { myTotalPaid += tx.amountPaise } else { partnerTotalPaid += tx.amountPaise }
            for split in tx.splits {
                if split.userId == currentUserId { myTotalResponsibility += split.amountPaise }
                else { partnerTotalResponsibility += split.amountPaise }
            }
        }

        // Exact mathematical behavior copied from the Android LedgerCalculator: 50/50 of paid difference.
        var net = (myTotalPaid - partnerTotalPaid) / 2
        var settlementsByMe: Int64 = 0
        var settlementsByPartner: Int64 = 0
        for settlement in settlements {
            if settlement.paidBy == currentUserId {
                net += settlement.amountPaise
                settlementsByMe += settlement.amountPaise
            } else if settlement.receivedBy == currentUserId {
                net -= settlement.amountPaise
                settlementsByPartner += settlement.amountPaise
            }
        }
        return LedgerBalance(
            amountOwedToMePaise: max(net, 0),
            amountIOwePaise: max(-net, 0),
            netBalancePaise: net,
            totalSharedPaidByMePaise: myTotalPaid,
            totalSharedPaidByPartnerPaise: partnerTotalPaid,
            myResponsibilityPaise: myTotalResponsibility,
            partnerResponsibilityPaise: partnerTotalResponsibility,
            totalSettlementsPaidByMePaise: settlementsByMe,
            totalSettlementsPaidByPartnerPaise: settlementsByPartner
        )
    }
}

import XCTest
@testable import OurMoney

/// Regression tests for the shared-ledger balance algorithm.
/// The Android OurMoney implementation computes the net balance as
/// `net = (myTotalPaid - partnerTotalPaid) / 2` over non-deleted shared
/// expenses (excluding income/transfers), then adjusts for settlements:
/// a settlement paid by me increases my net; one received by me decreases it.
/// These tests lock that exact behavior in, including asymmetric cases.
final class LedgerCalculatorTests: XCTestCase {

    private let me = "user-me"
    private let partner = "user-partner"

    private func tx(amountPaise: Int64, paidBy: String, personal: Bool = false,
                    type: TransactionType = .expense, isDeleted: Bool = false,
                    splitMethod: SplitMethod = .equal,
                    splits: [SplitAmount]? = nil) -> Transaction {
        var t = Transaction()
        t.amountPaise = amountPaise
        t.paidBy = paidBy
        t.createdBy = paidBy
        t.personal = personal
        t.type = type
        t.isDeleted = isDeleted
        t.splitMethod = splitMethod
        if let splits {
            t.splits = splits
        } else {
            let half = amountPaise / 2
            t.splits = [SplitAmount(userId: me, amountPaise: half),
                        SplitAmount(userId: partner, amountPaise: amountPaise - half)]
        }
        return t
    }

    private func settlement(amountPaise: Int64, paidBy: String, receivedBy: String) -> Settlement {
        var s = Settlement()
        s.amountPaise = amountPaise
        s.paidBy = paidBy
        s.receivedBy = receivedBy
        return s
    }

    func testEmptyLedgerIsZero() {
        let b = LedgerCalculator().calculate(currentUserId: me, transactions: [], settlements: [])
        XCTAssertEqual(b.netBalancePaise, 0)
        XCTAssertEqual(b.amountOwedToMePaise, 0)
        XCTAssertEqual(b.amountIOwePaise, 0)
    }

    func testSingleEvenExpense_IPaid() {
        // I paid 100.00; each owes 50.00 → partner owes me 50.00.
        let b = LedgerCalculator().calculate(currentUserId: me,
                                             transactions: [tx(amountPaise: 10_000, paidBy: me)],
                                             settlements: [])
        XCTAssertEqual(b.netBalancePaise, 5_000)
        XCTAssertEqual(b.amountOwedToMePaise, 5_000)
        XCTAssertEqual(b.amountIOwePaise, 0)
        XCTAssertEqual(b.totalSharedPaidByMePaise, 10_000)
        XCTAssertEqual(b.totalSharedPaidByPartnerPaise, 0)
    }

    func testSingleEvenExpense_PartnerPaid() {
        let b = LedgerCalculator().calculate(currentUserId: me,
                                             transactions: [tx(amountPaise: 10_000, paidBy: partner)],
                                             settlements: [])
        XCTAssertEqual(b.netBalancePaise, -5_000)
        XCTAssertEqual(b.amountIOwePaise, 5_000)
        XCTAssertEqual(b.amountOwedToMePaise, 0)
    }

    func testAsymmetricExpenses_NetIsHalfOfPaidDifference() {
        // Me: 300.00 across two expenses, partner: 100.00 once.
        // (30000 - 10000) / 2 = 10000 → partner owes me 100.00.
        let txs = [tx(amountPaise: 18_000, paidBy: me),
                   tx(amountPaise: 12_000, paidBy: me),
                   tx(amountPaise: 10_000, paidBy: partner)]
        let b = LedgerCalculator().calculate(currentUserId: me, transactions: txs, settlements: [])
        XCTAssertEqual(b.netBalancePaise, 10_000)
        XCTAssertEqual(b.amountOwedToMePaise, 10_000)
        XCTAssertEqual(b.totalSharedPaidByMePaise, 30_000)
        XCTAssertEqual(b.totalSharedPaidByPartnerPaise, 10_000)
    }

    func testOddAmountRoundsTowardZero() {
        // 3.01 split: Int64 division truncates, matching Android integer math.
        // (301 - 0) / 2 = 150 (truncated), partner responsibility 151.
        let b = LedgerCalculator().calculate(currentUserId: me,
                                             transactions: [tx(amountPaise: 301, paidBy: me)],
                                             settlements: [])
        XCTAssertEqual(b.netBalancePaise, 150)
        XCTAssertEqual(b.myResponsibilityPaise, 150)
        XCTAssertEqual(b.partnerResponsibilityPaise, 151)
    }

    func testSettlementPaidByMeReducesOwedToMe() {
        // Partner owes me 100.00; I receive a 40.00 settlement → net 60.00.
        let txs = [tx(amountPaise: 20_000, paidBy: me)]
        let sets = [settlement(amountPaise: 4_000, paidBy: partner, receivedBy: me)]
        let b = LedgerCalculator().calculate(currentUserId: me, transactions: txs, settlements: sets)
        XCTAssertEqual(b.netBalancePaise, 6_000)
        XCTAssertEqual(b.totalSettlementsPaidByPartnerPaise, 4_000)
        XCTAssertEqual(b.totalSettlementsPaidByMePaise, 0)
    }

    func testSettlementPaidByMeIncreasesNet() {
        // I owe 100.00; I pay a 40.00 settlement → net -60.00.
        let txs = [tx(amountPaise: 20_000, paidBy: partner)]
        let sets = [settlement(amountPaise: 4_000, paidBy: me, receivedBy: partner)]
        let b = LedgerCalculator().calculate(currentUserId: me, transactions: txs, settlements: sets)
        XCTAssertEqual(b.netBalancePaise, -6_000)
        XCTAssertEqual(b.totalSettlementsPaidByMePaise, 4_000)
    }

    func testFullySettledLedgerReturnsToZero() {
        // I paid 250.00, partner paid 50.00 → net 100.00, then I receive 100.00.
        let txs = [tx(amountPaise: 25_000, paidBy: me), tx(amountPaise: 5_000, paidBy: partner)]
        let sets = [settlement(amountPaise: 10_000, paidBy: partner, receivedBy: me)]
        let b = LedgerCalculator().calculate(currentUserId: me, transactions: txs, settlements: sets)
        XCTAssertEqual(b.netBalancePaise, 0)
        XCTAssertEqual(b.amountOwedToMePaise, 0)
        XCTAssertEqual(b.amountIOwePaise, 0)
    }

    func testPersonalAndDeletedAndNonExpenseTransactionsAreIgnored() {
        var deleted = tx(amountPaise: 50_000, paidBy: me); deleted.isDeleted = true
        let personalMine = tx(amountPaise: 20_000, paidBy: me, personal: true)
        let personalPartner = tx(amountPaise: 15_000, paidBy: partner, personal: true)
        let income = tx(amountPaise: 9_999, paidBy: me, type: .income)
        let transfer = tx(amountPaise: 7_777, paidBy: partner, type: .transfer)
        let b = LedgerCalculator().calculate(currentUserId: me,
                                             transactions: [deleted, personalMine, personalPartner, income, transfer],
                                             settlements: [])
        XCTAssertEqual(b.netBalancePaise, 0)
        XCTAssertEqual(b.totalSharedPaidByMePaise, 0)
        XCTAssertEqual(b.totalSharedPaidByPartnerPaise, 0)
    }

    func testPersonalTransactionsRespectCreatedByPrivacy() {
        // Personal expense from the partner must not enter my ledger view.
        let personalPartner = tx(amountPaise: 88_000, paidBy: partner, personal: true)
        let shared = tx(amountPaise: 10_000, paidBy: me)
        let b = LedgerCalculator().calculate(currentUserId: me,
                                             transactions: [personalPartner, shared],
                                             settlements: [])
        XCTAssertEqual(b.netBalancePaise, 5_000)
        XCTAssertEqual(b.totalSharedPaidByMePaise, 10_000)
    }

    func testExactSplitMethodUsesRecordedSplits() {
        // 100.00 expense, exact splits: I owe 30.00, partner 70.00; I paid.
        let t = tx(amountPaise: 10_000, paidBy: me, splitMethod: .exact,
                   splits: [SplitAmount(userId: me, amountPaise: 3_000),
                            SplitAmount(userId: partner, amountPaise: 7_000)])
        let b = LedgerCalculator().calculate(currentUserId: me, transactions: [t], settlements: [])
        XCTAssertEqual(b.myResponsibilityPaise, 3_000)
        XCTAssertEqual(b.partnerResponsibilityPaise, 7_000)
        XCTAssertEqual(b.netBalancePaise, 5_000) // Net remains half of paid difference.
    }

    func testAsymmetricMixedScenario() {
        // Realistic asymmetric month:
        // Shared: me 480.50, partner 219.50 → net 130.50
        // Settlements: partner settled 80.50 → net 50.00
        let txs = [
            tx(amountPaise: 25_050, paidBy: me),
            tx(amountPaise: 13_000, paidBy: me),
            tx(amountPaise: 10_000, paidBy: partner),
            tx(amountPaise: 12_000, paidBy: partner),
        ]
        let sets = [settlement(amountPaise: 8_050, paidBy: partner, receivedBy: me)]
        let b = LedgerCalculator().calculate(currentUserId: me, transactions: txs, settlements: sets)
        XCTAssertEqual(b.totalSharedPaidByMePaise, 48_050)
        XCTAssertEqual(b.totalSharedPaidByPartnerPaise, 22_000)
        XCTAssertEqual(b.netBalancePaise, 5_000)
        XCTAssertEqual(b.amountOwedToMePaise, 5_000)
    }

    func testUnrelatedSettlementDoesNotAffectMe() {
        // Defensive: a settlement between two other users must not move my net.
        let txs = [tx(amountPaise: 10_000, paidBy: me)]
        let sets = [settlement(amountPaise: 4_000, paidBy: "someone-else", receivedBy: "another")]
        let b = LedgerCalculator().calculate(currentUserId: me, transactions: txs, settlements: sets)
        XCTAssertEqual(b.netBalancePaise, 5_000)
        XCTAssertEqual(b.totalSettlementsPaidByMePaise, 0)
        XCTAssertEqual(b.totalSettlementsPaidByPartnerPaise, 0)
    }
}

import Foundation

// Mirrors app/src/main/java/com/example/model/Models.kt from the uploaded Android source.

enum TransactionType: String, Codable { case expense = "EXPENSE", income = "INCOME", transfer = "TRANSFER" }
enum SplitMethod: String, Codable { case equal = "EQUAL", exact = "EXACT", percentage = "PERCENTAGE", shares = "SHARES" }
enum AIScope: String, Codable { case personal = "PERSONAL", shared = "SHARED" }
enum AIMessageRole: String, Codable { case user = "USER", model = "MODEL", system = "SYSTEM" }

enum BudgetScope: String, CaseIterable { case all = "ALL", shared = "SHARED", personal = "PERSONAL" }
enum BudgetHealth { case onTrack, watch, atRisk, overBudget }

struct SplitAmount: Codable, Hashable {
    var userId: String = ""
    var amountPaise: Int64 = 0
}

struct Transaction: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var amountPaise: Int64 = 0
    var category: String = ""
    var dateMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    var paidBy: String = ""
    var createdBy: String = ""
    var personal: Bool = false
    var splitMethod: SplitMethod = .equal
    var splits: [SplitAmount] = []
    var notes: String = ""
    var type: TransactionType = .expense
    var paymentMethod: String = "UPI"
    var isDeleted: Bool = false
    var isPending: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, amountPaise, category, dateMillis, paidBy, createdBy, personal, splitMethod, splits, notes, type, paymentMethod, isDeleted
    }
}

struct User: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String = ""
    var email: String = ""
    var householdId: String? = nil
    var connectedAt: Int64? = nil
    var createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
}

struct Household: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var code: String = ""
    var members: [String] = []
    var createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
}

struct Settlement: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var amountPaise: Int64 = 0
    var paidBy: String = ""
    var receivedBy: String = ""
    var dateMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    var paymentMethod: String = ""
    var notes: String = ""
    var createdBy: String = ""
    var createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    var isPending: Bool = false
    
    enum CodingKeys: String, CodingKey { case id, amountPaise, paidBy, receivedBy, dateMillis, paymentMethod, notes, createdBy, createdAt }
}

struct Goal: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String = ""
    var targetAmountPaise: Int64 = 0
    var currentAmountPaise: Int64 = 0
    var personal: Bool = false
    var createdBy: String = ""
    var createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    var isPending: Bool = false
    
    enum CodingKeys: String, CodingKey { case id, name, targetAmountPaise, currentAmountPaise, personal, createdBy, createdAt }
}

struct Budget: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var category: String = ""
    var limitAmountPaise: Int64 = 0
    var personal: Bool = false
    var createdBy: String = ""
    var monthYear: String = ""
    var createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    var isPending: Bool = false
    
    enum CodingKeys: String, CodingKey { case id, category, limitAmountPaise, personal, createdBy, monthYear, createdAt }
}

struct CustomCategory: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String = ""
    var createdBy: String = ""
    var createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
}

struct AIChat: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var title: String = "New Conversation"
    var createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    var updatedAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    var ownerId: String = ""
    var householdId: String = ""
    var scope: AIScope = .personal
}

struct AIMessage: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var chatId: String = ""
    var role: AIMessageRole = .user
    var content: String = ""
    var timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
}

struct LedgerBalance: Hashable {
    var amountOwedToMePaise: Int64 = 0
    var amountIOwePaise: Int64 = 0
    var netBalancePaise: Int64 = 0
    var totalSharedPaidByMePaise: Int64 = 0
    var totalSharedPaidByPartnerPaise: Int64 = 0
    var myResponsibilityPaise: Int64 = 0
    var partnerResponsibilityPaise: Int64 = 0
    var totalSettlementsPaidByMePaise: Int64 = 0
    var totalSettlementsPaidByPartnerPaise: Int64 = 0
}

struct WeeklyDayStat: Identifiable { var id: Int64 { dateMillis }; let dayName: String; let spentPaise: Int64; let dateMillis: Int64 }
struct CategoryStat: Identifiable { var id: String { budget.id }; let budget: Budget; let spentPaise: Int64; let totalTransactions: Int; let largestTransaction: Int64; let averageTransaction: Int64; let transactions: [Transaction] }
struct ComprehensiveBudgetState {
    let monthYearStr: String
    let monthName: String
    let totalBudgetPaise: Int64
    let totalSpentPaise: Int64
    let spentTodayPaise: Int64
    let safeDailyLimitPaise: Int64
    let spentThisWeekPaise: Int64
    let weeklyBudgetPaise: Int64
    let expectedMonthEndPaise: Int64
    let expectedRemainingPaise: Int64
    let daysInMonth: Int
    let daysElapsed: Int
    let daysRemaining: Int
    let healthStatus: BudgetHealth
    let categories: [CategoryStat]
    let weeklyChartData: [WeeklyDayStat]
    let spentLastWeekPaise: Int64
    let spentLastMonthPaise: Int64
    let upiSpentPaise: Int64
    let cashSpentPaise: Int64
    let currentUserSpentPaise: Int64
    let partnerSpentPaise: Int64
    let currentUserResponsiblePaise: Int64
    let partnerResponsiblePaise: Int64
    let partnerName: String
    let insights: [String]
    let selectedScope: BudgetScope
}

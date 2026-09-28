import Foundation

final class AIFinancialContextEngine {
    func generate(scope: AIScope, currentUser: User, transactions: [Transaction], budgets: [Budget], goals: [Goal], settlements: [Settlement]) -> String {
        var text = "CURRENT FINANCIAL STATE (Generated on \(DateFormatter.ourMoney("dd MMM yyyy").string(from: Date())))\n"
        text += "User Name: \(currentUser.name)\nScope: \(scope.rawValue)\n\n"
        let active = transactions.filter { !$0.isDeleted }
        let relevant = active.filter { !$0.personal || ($0.personal && $0.createdBy == currentUser.id) }
        let expenses = relevant.filter { $0.type == .expense }
        let total = expenses.reduce(Int64(0)) { $0 + $1.amountPaise }
        text += "TOTAL SPENDING: ₹\(Double(total)/100.0)\n\nSPENDING BY CATEGORY:\n"
        let groups = Dictionary(grouping: expenses, by: { $0.category }).mapValues { $0.reduce(Int64(0)) { $0 + $1.amountPaise } }
        for (cat, amount) in groups.sorted(by: {$0.key < $1.key}) { text += "- \(cat): ₹\(Double(amount)/100.0)\n" }
        text += "\n"
        let relevantBudgets = budgets.filter { !$0.personal || ($0.personal && $0.createdBy == currentUser.id) }
        if !relevantBudgets.isEmpty {
            text += "BUDGETS:\n"
            for b in relevantBudgets {
                let spent = groups[b.category] ?? 0
                let remaining = b.limitAmountPaise - spent
                let pct = b.limitAmountPaise > 0 ? (Double(spent)/Double(b.limitAmountPaise))*100 : 0
                text += String(format: "- %@: Limit ₹%.2f, Spent ₹%.2f, Remaining ₹%.2f (%.1f%% used)\n", b.category, Double(b.limitAmountPaise)/100, Double(spent)/100, Double(remaining)/100, pct)
            }
            text += "\n"
        }
        let relevantGoals = goals.filter { !$0.personal || ($0.personal && $0.createdBy == currentUser.id) }
        if !relevantGoals.isEmpty {
            text += "GOALS:\n"
            for g in relevantGoals {
                let remaining = g.targetAmountPaise - g.currentAmountPaise
                let pct = g.targetAmountPaise > 0 ? (Double(g.currentAmountPaise)/Double(g.targetAmountPaise))*100 : 0
                text += String(format: "- %@: Target ₹%.2f, Saved ₹%.2f, Remaining ₹%.2f (%.1f%% complete)\n", g.name, Double(g.targetAmountPaise)/100, Double(g.currentAmountPaise)/100, Double(remaining)/100, pct)
            }
            text += "\n"
        }
        let balance = LedgerCalculator().calculate(currentUserId: currentUser.id, transactions: relevant, settlements: settlements)
        text += "SETTLEMENT STATE (Shared):\n"
        text += "- You paid total: ₹\(Double(balance.totalSharedPaidByMePaise)/100.0)\n- Friend paid total: ₹\(Double(balance.totalSharedPaidByPartnerPaise)/100.0)\n"
        text += "- Settlements paid by you: ₹\(Double(balance.totalSettlementsPaidByMePaise)/100.0)\n- Settlements paid by friend: ₹\(Double(balance.totalSettlementsPaidByPartnerPaise)/100.0)\n"
        if balance.netBalancePaise > 0 { text += "- Current Net Balance: You are ahead by ₹\(Double(balance.netBalancePaise)/100.0)\n" }
        else if balance.netBalancePaise < 0 { text += "- Current Net Balance: You owe ₹\(Double(balance.amountIOwePaise)/100.0)\n" }
        else { text += "- Current Net Balance: Balanced (₹0)\n" }
        text += "\nRECENT TRANSACTIONS (Last 10):\n"
        for tx in relevant.sorted(by: {$0.dateMillis > $1.dateMillis}).prefix(10) {
            let kind = tx.type == .expense ? "Spent" : "Earned"
            text += "- \(DateFormatter.ourMoney("dd MMM yyyy").string(from: dateFromMillis(tx.dateMillis))): \(kind) ₹\(Double(tx.amountPaise)/100.0) on \(tx.category) via \(tx.paymentMethod) (Paid by: \(tx.paidBy))\n"
        }
        return text
    }
}

final class GeminiClient {
    private let model: String
    private let apiKey: String
    init(model: String = "gemini-3.5-flash", apiKey: String? = nil) {
        self.model = model
        self.apiKey = apiKey ?? (Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String ?? "")
    }

    func generate(systemInstruction: String, history: [(role: String, text: String)]) async throws -> String {
        guard !apiKey.isEmpty, !apiKey.contains("$(") else { throw NSError(domain: "OurMoneyAI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Gemini API key is missing."]) }
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        struct Part: Codable { let text: String }
        struct Content: Codable { let role: String; let parts: [Part] }
        struct Req: Codable { let systemInstruction: SystemInstruction; let contents: [Content] }
        struct SystemInstruction: Codable { let parts: [Part] }
        struct Resp: Codable { struct Candidate: Codable { let content: Content? }; let candidates: [Candidate]? }
        let contents = history.map { Content(role: $0.role == "MODEL" ? "model" : "user", parts: [Part(text: $0.text)]) }
        let req = Req(systemInstruction: SystemInstruction(parts: [Part(text: systemInstruction)]), contents: contents)
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try JSONEncoder().encode(req)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw NSError(domain: "OurMoneyAI", code: 2, userInfo: [NSLocalizedDescriptionKey: "AI request failed."]) }
        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        return decoded.candidates?.first?.content?.parts.first?.text ?? "No response generated."
    }
}

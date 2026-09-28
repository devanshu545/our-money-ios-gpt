import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class FinanceStore: ObservableObject {
    let currentUser: User
    let household: Household
    @Published var partnerUser: User?
    @Published private(set) var transactions: [Transaction] = []
    @Published private(set) var settlements: [Settlement] = []
    @Published private(set) var goals: [Goal] = []
    @Published private(set) var budgets: [Budget] = []
    @Published private(set) var categories: [CustomCategory] = []
    @Published private(set) var error: String?

    private let service = FirestoreService()
    private var cancellables = Set<AnyCancellable>()
    private let calculator = LedgerCalculator()

    init(user: User, household: Household, partner: User?) {
        self.currentUser = user; self.household = household; self.partnerUser = partner
        startListeners()
    }

    var balance: LedgerBalance { calculator.calculate(currentUserId: currentUser.id, transactions: transactions, settlements: settlements) }
    var partnerName: String { partnerUser?.name ?? "Friend" }

    func startListeners() {
        cancellables.insert(service.observeTransactions(householdId: household.id, currentUserId: currentUser.id, handler: { [weak self] v in self?.transactions = v }, onError: { [weak self] e in self?.error = e.localizedDescription }))
        cancellables.insert(service.observeSettlements(householdId: household.id, handler: { [weak self] v in self?.settlements = v }, onError: { [weak self] e in self?.error = e.localizedDescription }))
        cancellables.insert(service.observeGoals(householdId: household.id, currentUserId: currentUser.id, handler: { [weak self] v in self?.goals = v }, onError: { [weak self] e in self?.error = e.localizedDescription }))
        cancellables.insert(service.observeBudgets(householdId: household.id, currentUserId: currentUser.id, handler: { [weak self] v in self?.budgets = v }, onError: { [weak self] e in self?.error = e.localizedDescription }))
        cancellables.insert(service.observeCategories(householdId: household.id, handler: { [weak self] v in self?.categories = v }, onError: { [weak self] e in self?.error = e.localizedDescription }))
    }

    func saveTransaction(_ tx: Transaction) async throws { var tx = tx; tx.createdBy = tx.createdBy.isEmpty ? currentUser.id : tx.createdBy; try await service.write(tx, householdId: household.id) }
    func deleteTransaction(_ id: String) async throws { try await service.deleteTransaction(householdId: household.id, id: id) }
    func saveSettlement(_ s: Settlement) async throws { try await service.write(s, householdId: household.id) }
    func deleteSettlement(_ id: String) async throws { try await service.deleteSettlement(householdId: household.id, id: id) }
    func saveGoal(_ g: Goal) async throws { try await service.write(g, householdId: household.id) }
    func deleteGoal(_ id: String) async throws { try await service.deleteGoal(householdId: household.id, id: id) }
    func saveBudget(_ b: Budget) async throws { try await service.write(b, householdId: household.id) }
    func deleteBudget(_ id: String) async throws { try await service.deleteBudget(householdId: household.id, id: id) }
    func saveCategory(_ c: CustomCategory) async throws { try await service.write(c, householdId: household.id) }
    func deleteCategory(_ id: String) async throws { try await service.deleteCategory(householdId: household.id, id: id) }
    func resetTransactions() async throws { try await service.resetTransactions(householdId: household.id, currentUserId: currentUser.id) }

    func getTransaction(_ id: String) async -> Transaction? { try? await service.getTransaction(householdId: household.id, id: id) }
    func getSettlement(_ id: String) async -> Settlement? { try? await service.getSettlement(householdId: household.id, id: id) }
}

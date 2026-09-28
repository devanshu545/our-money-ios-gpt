import SwiftUI
import Combine
import Charts
import FirebaseAuth

struct GlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(16)
            .background(.ultraThinMaterial.opacity(0.78))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(AppTheme.outline.opacity(0.12), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct AnimatedBackground: View {
    @State private var phase = false
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            Circle().fill(AppTheme.primary.opacity(0.07)).frame(width: 280).blur(radius: 40).offset(x: phase ? 130 : -100, y: phase ? -260 : -180)
            Circle().fill(AppTheme.secondary.opacity(0.05)).frame(width: 260).blur(radius: 50).offset(x: phase ? -130 : 100, y: phase ? 260 : 180)
        }
        .onAppear { withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) { phase = true } }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack { AnimatedBackground(); VStack(spacing: 14) { Image(systemName: "wallet.pass.fill").font(.system(size: 54, weight: .semibold)).foregroundStyle(AppTheme.primary); Text("OurMoney").font(.system(size: 34, weight: .bold)); Text("Shared money, without the mess.").foregroundStyle(AppTheme.onSurfaceVariant) } }
    }
}

struct ErrorView: View {
    let message: String
    var body: some View {
        ZStack { AnimatedBackground(); VStack(spacing: 16) { Image(systemName: "exclamationmark.triangle").font(.system(size: 40)).foregroundStyle(AppTheme.error); Text("OurMoney setup error").font(.title2.bold()); Text(message).multilineTextAlignment(.center).foregroundStyle(AppTheme.onSurfaceVariant).padding(.horizontal, 28) } }
    }
}

struct GoogleSignInView: View {
    @ObservedObject var auth: AuthManager
    @State private var busy = false
    var body: some View {
        ZStack { AnimatedBackground(); VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wallet.pass.fill").font(.system(size: 62)).foregroundStyle(AppTheme.primary)
            Text("OurMoney").font(.system(size: 36, weight: .bold))
            Text("Shared expenses for roommates and couples.").multilineTextAlignment(.center).foregroundStyle(AppTheme.onSurfaceVariant)
            Button {
                busy = true
                Task { await auth.signInWithGoogle(); busy = false }
            } label: {
                HStack { Image(systemName: "g.circle.fill"); Text(busy ? "Signing in…" : "Sign in with Google").bold() }
                    .frame(maxWidth: .infinity).padding(.vertical, 16).background(Color.white).foregroundStyle(Color.black).clipShape(RoundedRectangle(cornerRadius: 16))
            }.disabled(busy)
            if case .error(let message) = auth.state { Text(message).font(.footnote).foregroundStyle(AppTheme.error).multilineTextAlignment(.center).padding(.horizontal) }
            Spacer()
        }.padding() }
    }
}

struct NameInputView: View {
    @ObservedObject var auth: AuthManager
    let uid: String
    @State private var name = ""
    @State private var saving = false
    var body: some View {
        ZStack { AnimatedBackground(); VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("Your name").font(.largeTitle.bold())
            Text("This is what your partner will see.").foregroundStyle(AppTheme.onSurfaceVariant)
            TextField("Your Name", text: $name).textInputAutocapitalization(.words).padding(14).background(AppTheme.surfaceVariant).clipShape(RoundedRectangle(cornerRadius: 14))
            Button { saving = true; Task { await auth.saveName(name, uid: uid); saving = false } } label: { Text(saving ? "Saving…" : "Continue").bold().frame(maxWidth: .infinity).padding(.vertical, 15) }
                .buttonStyle(.borderedProminent).tint(AppTheme.primary)
            Spacer()
        }.padding(24) }
    }
}

struct PairingView: View {
    @ObservedObject var auth: AuthManager
    let user: User
    let household: Household?
    let error: String?
    @State private var code = ""
    @State private var busy = false
    var body: some View {
        ZStack { AnimatedBackground(); ScrollView { VStack(spacing: 18) {
            Text("Connect with your partner").font(.largeTitle.bold())
            if let household {
                GlassCard { VStack(spacing: 10) {
                    Text("Share this code with your partner").foregroundStyle(AppTheme.onSurfaceVariant)
                    Text(household.code).font(.system(size: 36, weight: .bold, design: .monospaced)).tracking(4)
                    Text("Members: \(household.members.count) / 2").foregroundStyle(AppTheme.onSurfaceVariant)
                    Button("Copy Code") { UIPasteboard.general.string = household.code }.buttonStyle(.bordered)
                } }
            } else {
                GlassCard { VStack(spacing: 12) {
                    TextField("Connection Code", text: $code).keyboardType(.numberPad).multilineTextAlignment(.center).font(.title3.monospaced()).padding(12).background(AppTheme.surfaceVariant).clipShape(RoundedRectangle(cornerRadius: 14))
                    Button { busy = true; Task { await auth.joinHousehold(user: user, code: code); busy = false } } label: { Text(busy ? "Joining…" : "Join Connection").bold().frame(maxWidth: .infinity).padding(.vertical, 14) }.buttonStyle(.borderedProminent).tint(AppTheme.primary)
                } }
            }
            Divider().overlay(AppTheme.outline.opacity(0.3))
            Button { busy = true; Task { await auth.createHousehold(user: user); busy = false } } label: { Text(busy ? "Creating…" : "Create New Connection").bold().frame(maxWidth: .infinity).padding(.vertical, 14) }.buttonStyle(.bordered).tint(AppTheme.primary)
            if let error { Text(error).foregroundStyle(AppTheme.error).multilineTextAlignment(.center) }
            Button("Cancel Connection") { Task { await auth.cancelPairing(user: user) } }.foregroundStyle(AppTheme.error)
            Button("Sign Out") { auth.signOut() }.foregroundStyle(AppTheme.onSurfaceVariant)
        }.padding(24) } }
    }
}

struct MainRootView: View {
    @StateObject private var store: FinanceStore
    @State private var selectedTab: MainTab = .home
    @State private var addExpense = false
    @State private var editTransaction: Transaction?
    @State private var settleUp = false
    @State private var editSettlement: Settlement?
    @State private var settings = false

    enum MainTab: String, CaseIterable {
        case home, history, stats, budgets, goals, ai
        var title: String { switch self { case .home: "Home"; case .history: "History"; case .stats: "Stats"; case .budgets: "Budgets"; case .goals: "Goals"; case .ai: "AI" } }
        var icon: String { switch self { case .home: "house.fill"; case .history: "list.bullet.rectangle"; case .stats: "chart.bar.xaxis"; case .budgets: "checkmark.circle.fill"; case .goals: "star.fill"; case .ai: "sparkles" } }
    }

    init(user: User, household: Household, partner: User?) { _store = StateObject(wrappedValue: FinanceStore(user: user, household: household, partner: partner)) }

    var body: some View {
        ZStack { AnimatedBackground(); VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home: DashboardView(store: store, onAdd: { addExpense = true }, onEdit: { editTransaction = $0 }, onSettle: { settleUp = true }, onSettings: { settings = true })
                case .history: HistoryView(store: store, onEditExpense: { editTransaction = $0 }, onEditSettlement: { editSettlement = $0 })
                case .stats: AnalyticsView(store: store)
                case .budgets: BudgetsView(store: store)
                case .goals: GoalsView(store: store)
                case .ai: AIView(store: store)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 0) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    Button { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab } } label: { VStack(spacing: 4) { Image(systemName: tab.icon).font(.system(size: 16, weight: .semibold)); Text(tab.title).font(.caption2) }.frame(maxWidth: .infinity).padding(.vertical, 8) }
                        .foregroundStyle(selectedTab == tab ? AppTheme.primary : AppTheme.onSurfaceVariant)
                }
            }.padding(.bottom, 2).background(AppTheme.surface.opacity(0.95))
        } }
        .sheet(isPresented: $addExpense) { AddExpenseView(store: store) }
        .sheet(item: $editTransaction) { tx in AddExpenseView(store: store, edit: tx) }
        .sheet(isPresented: $settleUp) { SettleUpView(store: store, onEdit: { s in editSettlement = s; settleUp = false }) }
        .sheet(item: $editSettlement) { s in SettleUpView(store: store, edit: s) }
        .sheet(isPresented: $settings) { SettingsView(store: store) }
    }
}

struct DashboardView: View {
    @ObservedObject var store: FinanceStore
    let onAdd: () -> Void
    let onEdit: (Transaction) -> Void
    let onSettle: () -> Void
    let onSettings: () -> Void
    @State private var search = ""
    @State private var deleteTarget: Transaction?

    var filtered: [Transaction] {
        Array(store.transactions.filter { search.isEmpty || $0.category.localizedCaseInsensitiveContains(search) || $0.notes.localizedCaseInsensitiveContains(search) }.prefix(8))
    }

    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            HStack { VStack(alignment: .leading) { Text("OurMoney").font(.largeTitle.bold()); Text("Connected with \(store.partnerName)").font(.caption).foregroundStyle(AppTheme.onSurfaceVariant) }; Spacer(); Button(action: onSettle) { Label("Settle", systemImage: "arrow.left.arrow.right") }; Button(action: onSettings) { Image(systemName: "gearshape.fill") } }
            BalanceCard(balance: store.balance, partnerName: store.partnerName)
            HStack { Text("Recent Transactions").font(.title3.bold()); Spacer(); Button(action: onAdd) { Image(systemName: "plus.circle.fill").font(.title2) } }
            TextField("Search transactions…", text: $search).padding(12).background(AppTheme.surfaceVariant).clipShape(RoundedRectangle(cornerRadius: 14))
            ForEach(filtered) { tx in
                TransactionRow(tx: tx, currentUser: store.currentUser, partner: store.partnerUser, onEdit: { onEdit(tx) }, onDelete: { deleteTarget = tx })
            }
        }.padding(18) }
        .alert("Delete Transaction?", isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })) {
            Button("Delete", role: .destructive) { if let id = deleteTarget?.id { Task { try? await store.deleteTransaction(id) } }; deleteTarget = nil }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: { Text("This may affect your balance, budgets and analytics.") }
    }
}

struct BalanceCard: View {
    let balance: LedgerBalance
    let partnerName: String
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(balance.netBalancePaise > 0 ? "You are owed" : balance.netBalancePaise < 0 ? "You owe" : "All Settled Up").font(.caption.bold()).textCase(.uppercase).foregroundStyle(.white.opacity(0.72))
            Text(shortRupees(abs(balance.netBalancePaise))).font(.system(size: 38, weight: .bold, design: .rounded)).foregroundStyle(.white)
            if balance.netBalancePaise != 0 { Text(balance.netBalancePaise > 0 ? "\(partnerName) owes you" : "You owe \(partnerName)").foregroundStyle(.white.opacity(0.82)) }
            HStack { stat("You Paid", balance.totalSharedPaidByMePaise); stat("\(partnerName) Paid", balance.totalSharedPaidByPartnerPaise); stat("Total Shared", balance.totalSharedPaidByMePaise + balance.totalSharedPaidByPartnerPaise) }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(balance.netBalancePaise > 0 ? AppTheme.primaryContainer : balance.netBalancePaise < 0 ? Color.red.opacity(0.5) : AppTheme.secondaryContainer).clipShape(RoundedRectangle(cornerRadius: 26))
    }
    @ViewBuilder private func stat(_ title: String, _ value: Int64) -> some View { VStack(alignment: .leading, spacing: 3) { Text(title).font(.caption2).foregroundStyle(.white.opacity(0.65)); Text(shortRupees(value)).font(.subheadline.bold()).foregroundStyle(.white) }.frame(maxWidth: .infinity, alignment: .leading) }
}

struct TransactionRow: View {
    let tx: Transaction; let currentUser: User; let partner: User?; let onEdit: () -> Void; let onDelete: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            ZStack { RoundedRectangle(cornerRadius: 12).fill(AppTheme.surfaceVariant); Image(systemName: categoryIcon(tx.category)).foregroundStyle(AppTheme.primary) }.frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 4) { Text(tx.category).font(.headline); Text(tx.personal ? "Personal" : "Paid by \(tx.paidBy == currentUser.id ? "You" : firstName(partner?.name ?? "Friend"))").font(.caption).foregroundStyle(AppTheme.onSurfaceVariant); Text(DateFormatter.ourMoney("dd MMM, hh:mm a").string(from: dateFromMillis(tx.dateMillis))).font(.caption2).foregroundStyle(AppTheme.outline) }
            Spacer(); Text(shortRupees(tx.amountPaise)).font(.headline)
            Menu { Button("Edit", action: onEdit); Button("Delete", role: .destructive, action: onDelete) } label: { Image(systemName: "ellipsis.circle") }
        }.padding(.vertical, 6)
    }
}

struct HistoryView: View {
    @ObservedObject var store: FinanceStore
    let onEditExpense: (Transaction) -> Void
    let onEditSettlement: (Settlement) -> Void
    @State private var search = ""
    @State private var filters = Set<String>()
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var report = false
    @State private var exportURL: ExportFile?
    @State private var startPicker = false
    @State private var endPicker = false
    @State private var deleteTarget: Transaction?
    @State private var deleteSettlementTarget: Settlement?

    private let availableFilters = ["Today", "This Week", "This Month", "Last Month", "Shared", "Personal", "Cash", "UPI"]

    var filtered: [Transaction] {
        store.transactions.filter { tx in
            var ok = true
            let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !q.isEmpty {
                let amount = String(Double(tx.amountPaise) / 100.0)
                let date = DateFormatter.ourMoney("dd MMM yyyy").string(from: dateFromMillis(tx.dateMillis)).lowercased()
                let scope = tx.personal ? "personal" : "shared"
                ok = tx.category.lowercased().contains(q) || tx.notes.lowercased().contains(q) || tx.paymentMethod.lowercased().contains(q) || amount.contains(q) || date.contains(q) || scope.contains(q)
            }
            if let startDate { ok = ok && dateFromMillis(tx.dateMillis) >= startDate }
            if let endDate { ok = ok && dateFromMillis(tx.dateMillis) <= endDate }
            var cal = Calendar.current
            if filters.contains("Today") { ok = ok && cal.isDateInToday(dateFromMillis(tx.dateMillis)) }
            if filters.contains("This Week") { cal.firstWeekday = 2; let start = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date(); let end = cal.date(byAdding: .day, value: 7, to: start) ?? Date(); let d = dateFromMillis(tx.dateMillis); ok = ok && d >= start && d < end }
            if filters.contains("This Month") { ok = ok && cal.component(.month, from: dateFromMillis(tx.dateMillis)) == cal.component(.month, from: Date()) && cal.component(.year, from: dateFromMillis(tx.dateMillis)) == cal.component(.year, from: Date()) }
            if filters.contains("Last Month"), let last = cal.date(byAdding: .month, value: -1, to: Date()) { ok = ok && cal.component(.month, from: dateFromMillis(tx.dateMillis)) == cal.component(.month, from: last) && cal.component(.year, from: dateFromMillis(tx.dateMillis)) == cal.component(.year, from: last) }
            if filters.contains("Shared") { ok = ok && !tx.personal }
            if filters.contains("Personal") { ok = ok && tx.personal }
            if filters.contains("Cash") { ok = ok && tx.paymentMethod.localizedCaseInsensitiveContains("cash") }
            if filters.contains("UPI") { ok = ok && tx.paymentMethod.localizedCaseInsensitiveContains("upi") }
            return ok
        }
    }

    var filteredSettlements: [Settlement] {
        store.settlements.filter { s in
            var ok = true
            let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !q.isEmpty {
                let amount = String(Double(s.amountPaise) / 100.0)
                let date = DateFormatter.ourMoney("dd MMM yyyy").string(from: dateFromMillis(s.dateMillis)).lowercased()
                let who = "\(s.paidBy == store.currentUser.id ? "you" : store.partnerName) \(s.receivedBy == store.currentUser.id ? "you" : store.partnerName)".lowercased()
                ok = "settlement".contains(q) || s.notes.lowercased().contains(q) || s.paymentMethod.lowercased().contains(q) || amount.contains(q) || date.contains(q) || who.contains(q)
            }
            if let startDate { ok = ok && dateFromMillis(s.dateMillis) >= startDate }
            if let endDate { ok = ok && dateFromMillis(s.dateMillis) <= endDate }
            var cal = Calendar.current
            if filters.contains("Today") { ok = ok && cal.isDateInToday(dateFromMillis(s.dateMillis)) }
            if filters.contains("This Week") { cal.firstWeekday = 2; let start = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date(); let end = cal.date(byAdding: .day, value: 7, to: start) ?? Date(); let d = dateFromMillis(s.dateMillis); ok = ok && d >= start && d < end }
            if filters.contains("This Month") { let d = dateFromMillis(s.dateMillis); ok = ok && cal.component(.month, from: d) == cal.component(.month, from: Date()) && cal.component(.year, from: d) == cal.component(.year, from: Date()) }
            if filters.contains("Last Month"), let last = cal.date(byAdding: .month, value: -1, to: Date()) { let d = dateFromMillis(s.dateMillis); ok = ok && cal.component(.month, from: d) == cal.component(.month, from: last) && cal.component(.year, from: d) == cal.component(.year, from: last) }
            if filters.contains("Personal") { ok = false }
            if filters.contains("Cash") { ok = ok && s.paymentMethod.localizedCaseInsensitiveContains("cash") }
            if filters.contains("UPI") { ok = ok && s.paymentMethod.localizedCaseInsensitiveContains("upi") }
            return ok
        }.sorted { $0.dateMillis > $1.dateMillis }
    }

    var body: some View {
        VStack {
            HStack { Text("Transaction History").font(.largeTitle.bold()); Spacer(); Button { report = true } label: { Image(systemName: "doc.text.fill") } }.padding(.horizontal, 18).padding(.top, 18)
            TextField("Search transactions…", text: $search).padding(12).background(AppTheme.surfaceVariant).clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal, 18)
            HStack { Button(startDate == nil ? "Start" : DateFormatter.ourMoney("dd MMM").string(from: startDate!)) { startPicker = true }; Button(endDate == nil ? "End" : DateFormatter.ourMoney("dd MMM").string(from: endDate!)) { endPicker = true }; Spacer(); if !filters.isEmpty { Button("Clear All") { filters.removeAll() }.font(.caption) } }.padding(.horizontal, 18)
            ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(availableFilters, id: \.self) { f in Button { filters.contains(f) ? filters.remove(f) : filters.insert(f) } label: { Text(f).font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 8).background(filters.contains(f) ? AppTheme.primary.opacity(0.22) : AppTheme.surfaceVariant).clipShape(Capsule()) } } }.padding(.horizontal, 18) }
            List {
                ForEach(filtered) { tx in TransactionRow(tx: tx, currentUser: store.currentUser, partner: store.partnerUser, onEdit: { onEditExpense(tx) }, onDelete: { deleteTarget = tx }).listRowBackground(Color.clear) }
                ForEach(filteredSettlements) { s in SettlementHistoryRow(settlement: s, currentUser: store.currentUser, partnerName: store.partnerName, onEdit: { onEditSettlement(s) }, onDelete: { deleteSettlementTarget = s }).listRowBackground(Color.clear) }
            }.scrollContentBackground(.hidden).background(Color.clear)
        }
        .sheet(isPresented: $report) { ExportReportView(store: store) { url in exportURL = url.map(ExportFile.init); report = false } }
        .sheet(item: $exportURL) { file in ShareSheet(items: [file.url]) }
        .sheet(isPresented: $startPicker) { DateRangePicker(title: "Select Start Date", initial: startDate ?? Date()) { startDate = $0; startPicker = false } }
        .sheet(isPresented: $endPicker) { DateRangePicker(title: "Select End Date", initial: endDate ?? Date()) { let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: $0) ?? $0; endDate = end; endPicker = false } }
        .alert("Delete Transaction?", isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })) { Button("Delete", role: .destructive) { if let id = deleteTarget?.id { Task { try? await store.deleteTransaction(id) } }; deleteTarget = nil }; Button("Cancel", role: .cancel) {} } message: { Text("This may affect your balance, budgets and analytics.") }
        .alert("Delete Settlement?", isPresented: Binding(get: { deleteSettlementTarget != nil }, set: { if !$0 { deleteSettlementTarget = nil } })) { Button("Delete", role: .destructive) { if let id = deleteSettlementTarget?.id { Task { try? await store.deleteSettlement(id) } }; deleteSettlementTarget = nil }; Button("Cancel", role: .cancel) {} } message: { Text("This will change your current balance.") }
    }
}

struct SettlementHistoryRow: View {
    let settlement: Settlement; let currentUser: User; let partnerName: String; let onEdit: () -> Void; let onDelete: () -> Void
    var body: some View { HStack(spacing: 12) { ZStack { RoundedRectangle(cornerRadius: 12).fill(AppTheme.surfaceVariant); Image(systemName: "arrow.left.arrow.right.circle.fill").foregroundStyle(AppTheme.primary) }.frame(width: 46, height: 46); VStack(alignment: .leading, spacing: 4) { Text("Settlement").font(.headline); Text("\(settlement.paidBy == currentUser.id ? "You" : partnerName) → \(settlement.receivedBy == currentUser.id ? "You" : partnerName)").font(.caption).foregroundStyle(AppTheme.onSurfaceVariant); if !settlement.notes.isEmpty { Text(settlement.notes).font(.caption2).foregroundStyle(AppTheme.outline) }; Text(DateFormatter.ourMoney("dd MMM, hh:mm a").string(from: dateFromMillis(settlement.dateMillis))).font(.caption2).foregroundStyle(AppTheme.outline) }; Spacer(); Text(shortRupees(settlement.amountPaise)).font(.headline); Menu { Button("Edit", action: onEdit); Button("Delete", role: .destructive, action: onDelete) } label: { Image(systemName: "ellipsis.circle") } }.padding(.vertical, 6) }
}

struct DateRangePicker: View { @Environment(\.dismiss) private var dismiss; let title: String; let onDone: (Date) -> Void; @State private var date: Date
    init(title: String, initial: Date, onDone: @escaping (Date) -> Void) { self.title = title; self.onDone = onDone; _date = State(initialValue: initial) }
    var body: some View { NavigationStack { VStack { DatePicker(title, selection: $date, displayedComponents: .date).datePickerStyle(.graphical).padding(); Spacer() }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("OK") { onDone(date); dismiss() } } } } }
}

struct ExportFile: Identifiable { let id = UUID(); let url: URL }

struct ExportReportView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: FinanceStore
    let onExport: (URL?) -> Void
    @State private var scope = 0
    @State private var start: Date
    @State private var end: Date
    init(store: FinanceStore, onExport: @escaping (URL?) -> Void) {
        self.store = store; self.onExport = onExport
        let now = Date(); let cal = Calendar.current
        _start = State(initialValue: cal.date(from: DateComponents(year: cal.component(.year, from: now), month: cal.component(.month, from: now), day: 1)) ?? now)
        _end = State(initialValue: now)
    }
    var body: some View {
        NavigationStack {
            Form {
                Picker("Select Scope", selection: $scope) { Text("All").tag(0); Text("Shared").tag(1); Text("Personal").tag(2) }.pickerStyle(.segmented)
                DatePicker("Start", selection: $start, displayedComponents: .date)
                DatePicker("End", selection: $end, displayedComponents: .date)
                Button("Export Custom Report") {
                    let cal = Calendar.current
                    let effectiveEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
                    let txs = store.transactions
                        .filter { let d = dateFromMillis($0.dateMillis); return d >= start && d <= effectiveEnd }
                        .filter { scope == 0 || (scope == 1 && !$0.personal) || (scope == 2 && $0.personal) }
                        .sorted { $0.dateMillis < $1.dateMillis }
                    let sets = store.settlements.filter { let d = dateFromMillis($0.dateMillis); return d >= start && d <= effectiveEnd }.sorted { $0.dateMillis < $1.dateMillis }
                    var rows = [["Date", "Category", "Amount", "Scope"]]
                    let total = txs.sum(\.amountPaise); let shared = txs.filter { !$0.personal }.sum(\.amountPaise); let personal = txs.filter { $0.personal }.sum(\.amountPaise)
                    rows.append(["SUMMARY", "Total Spending", shortRupees(total), scope == 0 ? "All" : scope == 1 ? "Shared" : "Personal"])
                    rows.append(["", "Shared Spending", shortRupees(shared), "Shared"])
                    rows.append(["", "Personal Spending", shortRupees(personal), "Personal"])
                    for tx in txs { rows.append([DateFormatter.ourMoney("dd MMM yyyy").string(from: dateFromMillis(tx.dateMillis)), tx.category, shortRupees(tx.amountPaise), tx.personal ? "Personal" : "Shared"]) }
                    for s in sets { rows.append([DateFormatter.ourMoney("dd MMM yyyy").string(from: dateFromMillis(s.dateMillis)), "Settlement", shortRupees(s.amountPaise), "Shared"]) }
                    let subtitle = "Generated for \(store.currentUser.name) • \(DateFormatter.ourMoney("dd MMM yyyy").string(from: start)) - \(DateFormatter.ourMoney("dd MMM yyyy").string(from: effectiveEnd))"
                    onExport(makePDF(title: "OurMoney Report", rows: rows, subtitle: subtitle))
                }
            }
            .navigationTitle("Export Report")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: FinanceStore
    let edit: Transaction?
    @State private var amount = ""; @State private var category = ""; @State private var notes = ""; @State private var personal = false; @State private var paidByMe = true; @State private var method = "UPI"; @State private var date = Date(); @State private var saving = false; @State private var error = ""; @State private var customDialog = false; @State private var customName = ""
    init(store: FinanceStore, edit: Transaction? = nil) { self.store = store; self.edit = edit; _amount = State(initialValue: edit.map { String(Double($0.amountPaise)/100.0) } ?? ""); _category = State(initialValue: edit?.category ?? ""); _notes = State(initialValue: edit?.notes ?? ""); _personal = State(initialValue: edit?.personal ?? false); _paidByMe = State(initialValue: edit.map { $0.paidBy == store.currentUser.id } ?? true); _method = State(initialValue: edit?.paymentMethod ?? "UPI"); _date = State(initialValue: edit.map { dateFromMillis($0.dateMillis) } ?? Date()) }
    private var allCategories: [String] { (standardCategories + store.categories.map(\.name)).uniqued().sorted() }
    var body: some View { NavigationStack { Form {
        Section("Amount") { TextField("Amount (₹)", text: $amount).keyboardType(.decimalPad).font(.title.bold()); Picker("Category", selection: $category) { Text("Choose…").tag(""); ForEach(allCategories, id: \.self) { Text($0).tag($0) } }; TextField("Notes (optional)", text: $notes) }
        Section("Details") { Picker("Payment Method", selection: $method) { Text("UPI").tag("UPI"); Text("Cash").tag("Cash") }.pickerStyle(.segmented); DatePicker("Date & Time", selection: $date); Toggle("Personal (only you can see this)", isOn: $personal); if !personal { Picker("Paid By", selection: $paidByMe) { Text("You").tag(true); Text(store.partnerName).tag(false) }.pickerStyle(.segmented) } }
        if !error.isEmpty { Section { Text(error).foregroundStyle(AppTheme.error) } }
        Section("Custom Categories") { Button("Add Custom Category…") { customDialog = true }; ForEach(store.categories) { c in HStack { Text(c.name); Spacer(); Button(role: .destructive) { Task { try? await store.deleteCategory(c.id) } } label: { Image(systemName: "trash") } } } }
        Section { Button { save() } label: { Text(saving ? "Saving…" : "Save").frame(maxWidth: .infinity) }.disabled(saving) }
    }.navigationTitle(edit == nil ? "Expense" : "Edit Expense").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) } }.alert("Add Custom Category", isPresented: $customDialog) { TextField("Category Name", text: $customName); Button("Add") { let name = customName.trimmingCharacters(in: .whitespacesAndNewlines); if !name.isEmpty { Task { try? await store.saveCategory(CustomCategory(name: name, createdBy: store.currentUser.id)); category = name } }; customName = "" }; Button("Cancel", role: .cancel) {} } } }
    private func save() { guard let value = Double(amount), value > 0, !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { error = "Please enter a valid amount and category"; return }; saving = true; error = ""; Task { do { let paise = Int64((value * 100).rounded()); let other = store.household.members.first { $0 != store.currentUser.id } ?? ""; let split: [SplitAmount] = personal ? [SplitAmount(userId: store.currentUser.id, amountPaise: paise)] : [SplitAmount(userId: store.currentUser.id, amountPaise: paise / 2), SplitAmount(userId: other, amountPaise: paise - paise / 2)]; var tx = edit ?? Transaction(); tx.amountPaise = paise; tx.category = category.trimmingCharacters(in: .whitespacesAndNewlines); tx.paidBy = paidByMe ? store.currentUser.id : other; tx.createdBy = edit?.createdBy ?? store.currentUser.id; tx.personal = personal; tx.splitMethod = .equal; tx.splits = split; tx.notes = notes; tx.paymentMethod = method; tx.dateMillis = millis(date); tx.type = edit?.type ?? .expense; tx.isDeleted = false; try await store.saveTransaction(tx); dismiss() } catch { self.error = error.localizedDescription }; saving = false } }
}

struct SettleUpView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: FinanceStore
    let edit: Settlement?
    let onEdit: (Settlement) -> Void
    @State private var amount = ""; @State private var paidByMe = true; @State private var method = "UPI"; @State private var notes = ""; @State private var date = Date(); @State private var saving = false; @State private var error = ""
    init(store: FinanceStore, edit: Settlement? = nil, onEdit: @escaping (Settlement) -> Void = { _ in }) { self.store = store; self.edit = edit; self.onEdit = onEdit; _amount = State(initialValue: edit.map { String(Double($0.amountPaise)/100.0) } ?? ""); _paidByMe = State(initialValue: edit.map { $0.paidBy == store.currentUser.id } ?? true); _method = State(initialValue: edit?.paymentMethod ?? "UPI"); _notes = State(initialValue: edit?.notes ?? ""); _date = State(initialValue: edit.map { dateFromMillis($0.dateMillis) } ?? Date()) }
    var body: some View { NavigationStack { Form {
        Section("SETTLEMENT BREAKDOWN") { LabeledContent("Total You Paid", value: shortRupees(store.balance.totalSharedPaidByMePaise)); LabeledContent("Total \(store.partnerName) Paid", value: shortRupees(store.balance.totalSharedPaidByPartnerPaise)); LabeledContent("Paid Difference", value: shortRupees(abs(store.balance.totalSharedPaidByMePaise - store.balance.totalSharedPaidByPartnerPaise))); LabeledContent("Settled by You", value: shortRupees(store.balance.totalSettlementsPaidByMePaise)); LabeledContent("Settled by \(store.partnerName)", value: shortRupees(store.balance.totalSettlementsPaidByPartnerPaise)) }
        Section(edit == nil ? "NEW SETTLEMENT" : "EDIT SETTLEMENT") { TextField("Amount Settled (₹)", text: $amount).keyboardType(.decimalPad); Picker("Who paid?", selection: $paidByMe) { Text("You").tag(true); Text(store.partnerName).tag(false) }.pickerStyle(.segmented); Picker("Payment Method", selection: $method) { Text("UPI").tag("UPI"); Text("Cash").tag("Cash") }.pickerStyle(.segmented); DatePicker("Date & Time", selection: $date); TextField("Notes (optional)", text: $notes); if !error.isEmpty { Text(error).foregroundStyle(AppTheme.error) }; Button { save() } label: { Text(saving ? "Saving…" : (edit == nil ? "Save Settlement" : "Save Changes")).frame(maxWidth: .infinity) }.disabled(saving) }
        Section("SETTLEMENT HISTORY") { ForEach(store.settlements) { s in HStack { VStack(alignment: .leading, spacing: 3) { Text("\(s.paidBy == store.currentUser.id ? "You" : store.partnerName) → \(s.receivedBy == store.currentUser.id ? "You" : store.partnerName)").font(.headline); Text(DateFormatter.ourMoney("dd MMM yyyy, hh:mm a").string(from: dateFromMillis(s.dateMillis))).font(.caption).foregroundStyle(AppTheme.onSurfaceVariant) }; Spacer(); Text(shortRupees(s.amountPaise)).bold(); Menu { Button("Edit") { onEdit(s) }; Button("Delete", role: .destructive) { Task { try? await store.deleteSettlement(s.id) } } } label: { Image(systemName: "ellipsis.circle") } } } }
    }.navigationTitle(edit == nil ? "Settlement" : "Edit Settlement").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } } } }
    private func save() { guard let value = Double(amount), value > 0 else { error = "Please enter a valid amount"; return }; let other = store.household.members.first { $0 != store.currentUser.id } ?? ""; guard !other.isEmpty else { error = "No partner to settle with."; return }; saving = true; Task { do { var s = edit ?? Settlement(); s.amountPaise = Int64((value*100).rounded()); s.paidBy = paidByMe ? store.currentUser.id : other; s.receivedBy = paidByMe ? other : store.currentUser.id; s.dateMillis = millis(date); s.paymentMethod = method; s.notes = notes; s.createdBy = edit?.createdBy ?? store.currentUser.id; try await store.saveSettlement(s); dismiss() } catch { error = error.localizedDescription }; saving = false } }
}

struct AnalyticsView: View {
    @ObservedObject var store: FinanceStore
    @State private var showContent = false

    var expenses: [Transaction] { store.transactions.filter { !$0.isDeleted && $0.type == .expense } }
    var totalSpent: Int64 { expenses.sum(\.amountPaise) }
    var youPaid: Int64 { expenses.filter { $0.paidBy == store.currentUser.id }.sum(\.amountPaise) }
    var partnerPaid: Int64 { totalSpent - youPaid }
    var upiSpent: Int64 { expenses.filter { $0.paymentMethod.localizedCaseInsensitiveContains("upi") }.sum(\.amountPaise) }
    var cashSpent: Int64 { expenses.filter { $0.paymentMethod.localizedCaseInsensitiveContains("cash") }.sum(\.amountPaise) }
    var categoryTotals: [(String, Int64)] { Dictionary(grouping: expenses, by: \.category).mapValues { $0.sum(\.amountPaise) }.sorted { $0.value > $1.value } }
    var highest: Transaction? { expenses.max { $0.amountPaise < $1.amountPaise } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Analytics").font(.largeTitle.bold())
                DonutChartView(data: categoryTotals, total: totalSpent, animated: showContent)
                    .frame(height: 240)
                HStack {
                    metric("You Paid", youPaid)
                    metric("Partner Paid", partnerPaid)
                }
                HStack {
                    metric("UPI", upiSpent)
                    metric("Cash", cashSpent)
                }
                if let highest {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Highest Single Transaction").font(.caption).foregroundStyle(AppTheme.onSurfaceVariant)
                            Text("\(highest.category): \(shortRupees(highest.amountPaise))").font(.title3.bold())
                            if !highest.notes.isEmpty { Text(highest.notes).font(.caption).foregroundStyle(AppTheme.onSurfaceVariant) }
                        }
                    }
                }
                Text("Category Breakdown").font(.title3.bold())
                if categoryTotals.isEmpty {
                    Text("No data to display.").foregroundStyle(AppTheme.onSurfaceVariant)
                } else {
                    ForEach(categoryTotals, id: \.0) { category, amount in
                        let pct = totalSpent > 0 ? Double(amount) / Double(totalSpent) : 0
                        VStack(spacing: 6) {
                            HStack { Text(category).fontWeight(.medium); Spacer(); Text(shortRupees(amount)).fontWeight(.medium) }
                            ProgressView(value: showContent ? pct : 0)
                                .tint(AppTheme.primary)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            .padding(18)
        }
        .task { try? await Task.sleep(for: .milliseconds(120)); withAnimation(.easeOut(duration: 0.5)) { showContent = true } }
    }

    @ViewBuilder private func metric(_ title: String, _ value: Int64) -> some View {
        GlassCard { VStack(alignment: .leading, spacing: 6) { Text(title).font(.caption).foregroundStyle(AppTheme.onSurfaceVariant); Text(shortRupees(value)).font(.title3.bold()) } }.frame(maxWidth: .infinity)
    }
}

struct DonutChartView: View {
    let data: [(String, Int64)]
    let total: Int64
    let animated: Bool
    private let ringWidth: CGFloat = 34
    private let palette: [Color] = [.purple, .teal, .pink, .yellow, .green, .orange, .blue]
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if total > 0 {
                    Circle().stroke(AppTheme.surfaceVariant, lineWidth: ringWidth)
                    ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                        let start = angle(at: index)
                        let sweep = sweep(for: item.1)
                        Circle()
                            .trim(from: start, to: min(start + sweep * (animated ? 1 : 0), 0.999999))
                            .stroke(palette[index % palette.count], style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt))
                            .rotationEffect(.degrees(-90))
                    }
                }
                VStack(spacing: 3) {
                    Text(shortRupees(total)).font(.title2.bold())
                    Text("Total Spending").font(.caption).foregroundStyle(AppTheme.onSurfaceVariant)
                }
            }
            .frame(width: min(geo.size.width, 230), height: min(geo.size.width, 230))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    private func angle(at index: Int) -> CGFloat { data.prefix(index).reduce(0) { $0 + CGFloat(total == 0 ? 0 : Double($1.1) / Double(total)) } }
    private func sweep(for amount: Int64) -> CGFloat { total == 0 ? 0 : CGFloat(Double(amount) / Double(total)) }
}

struct GoalsView: View {
    @ObservedObject var store: FinanceStore
    @State private var create = false
    @State private var editing: Goal?
    @State private var contribution: Goal?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Savings Goals").font(.largeTitle.bold())
                    Spacer()
                    Button("New Goal") { create = true }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.primary)
                }
                if store.goals.isEmpty {
                    Text("No savings goals yet.")
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(36)
                }
                ForEach(store.goals) { goal in
                    GoalCard(goal: goal, store: store, onEdit: { editing = goal }, onContribute: { contribution = goal })
                }
            }
            .padding(18)
        }
        .sheet(isPresented: $create) { GoalEditorSheet(store: store) }
        .sheet(item: $editing) { goal in GoalEditorSheet(store: store, edit: goal) }
        .sheet(item: $contribution) { goal in ContributionSheet(goal: goal, store: store) }
    }
}

struct GoalCard: View {
    let goal: Goal
    @ObservedObject var store: FinanceStore
    let onEdit: () -> Void
    let onContribute: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "target").foregroundStyle(AppTheme.primary)
                    Text(goal.name).font(.headline)
                    Spacer()
                    Text(goal.personal ? "Personal" : "Shared")
                        .font(.caption)
                        .foregroundStyle(AppTheme.onSurfaceVariant)
                    Menu {
                        Button("Edit", action: onEdit)
                        Button("Delete", role: .destructive) {
                            Task { try? await store.deleteGoal(goal.id) }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ProgressView(
                    value: Double(min(goal.currentAmountPaise, goal.targetAmountPaise)),
                    total: max(Double(goal.targetAmountPaise), 1)
                )
                HStack {
                    Text("\(shortRupees(goal.currentAmountPaise)) / \(shortRupees(goal.targetAmountPaise))")
                    Spacer()
                    Button("Contribute", action: onContribute)
                }
            }
        }
    }
}

struct GoalEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: FinanceStore
    let edit: Goal?
    @State private var name: String
    @State private var target: String
    @State private var personal: Bool

    init(store: FinanceStore, edit: Goal? = nil) {
        self.store = store
        self.edit = edit
        _name = State(initialValue: edit?.name ?? "")
        _target = State(initialValue: edit.map { String(Double($0.targetAmountPaise) / 100.0) } ?? "")
        _personal = State(initialValue: edit?.personal ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Goal Name", text: $name)
                TextField("Target Amount (₹)", text: $target).keyboardType(.decimalPad)
                Toggle("Personal Goal", isOn: $personal)
                Button("Save") {
                    Task {
                        guard let value = Double(target), value > 0,
                              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        var goal = edit ?? Goal()
                        goal.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        goal.targetAmountPaise = Int64((value * 100).rounded())
                        goal.personal = personal
                        goal.createdBy = edit?.createdBy ?? store.currentUser.id
                        try? await store.saveGoal(goal)
                        dismiss()
                    }
                }
            }
            .navigationTitle(edit == nil ? "New Goal" : "Edit Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

struct ContributionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let goal: Goal
    @ObservedObject var store: FinanceStore
    @State private var amount = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Amount (₹)", text: $amount).keyboardType(.decimalPad)
                Button("Save Contribution") {
                    Task {
                        if let value = Double(amount), value > 0 {
                            var updated = goal
                            updated.currentAmountPaise += Int64((value * 100).rounded())
                            try? await store.saveGoal(updated)
                        }
                        dismiss()
                    }
                }
            }
            .navigationTitle("Contribute to \(goal.name)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

struct BudgetsView: View {
    @ObservedObject var store: FinanceStore
    @State private var month = Date()
    @State private var scope: BudgetScope = .all
    @State private var create = false
    @State private var editing: Budget?
    var state: ComprehensiveBudgetState? { BudgetCalculator.build(store: store, selectedMonth: month, scope: scope) }
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 18) { HStack { Button { month = Calendar.current.date(byAdding: .month, value: -1, to: month) ?? month } label: { Image(systemName: "chevron.left") }; Text(state?.monthName ?? "Budget").font(.title2.bold()); Button { month = Calendar.current.date(byAdding: .month, value: 1, to: month) ?? month } label: { Image(systemName: "chevron.right") }; Spacer(); Button("Add Budget") { create = true }.buttonStyle(.borderedProminent).tint(AppTheme.primary) }; Picker("Scope", selection: $scope) { ForEach(BudgetScope.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }.pickerStyle(.segmented)
            if let s = state { GlassCard { VStack(alignment: .leading, spacing: 10) { HStack { Text(s.healthStatus.title).font(.title2.bold()); Spacer(); Text("\(Int(s.totalBudgetPaise > 0 ? (Double(s.totalSpentPaise)/Double(s.totalBudgetPaise))*100 : 0))% used").font(.caption) }; ProgressView(value: Double(s.totalSpentPaise), total: max(Double(s.totalBudgetPaise), 1)); HStack { Text("Spent \(shortRupees(s.totalSpentPaise))"); Spacer(); Text("Budget \(shortRupees(s.totalBudgetPaise))") }; Text("Safe rate: \(shortRupees(s.safeDailyLimitPaise))/day").font(.caption).foregroundStyle(AppTheme.onSurfaceVariant) } }; HStack { budgetMetric("TODAY", s.spentTodayPaise); budgetMetric("WEEKLY", s.spentThisWeekPaise); budgetMetric("MONTHLY", s.totalSpentPaise) }; Text("WHERE YOUR MONEY WENT").font(.caption.bold()); if s.categories.isEmpty { Text("No budgets set yet.").foregroundStyle(AppTheme.onSurfaceVariant) } else { ForEach(s.categories) { c in GlassCard { HStack { Image(systemName: categoryIcon(c.budget.category)).foregroundStyle(AppTheme.primary); VStack(alignment: .leading) { Text(c.budget.category).bold(); Text("\(c.totalTransactions) transactions").font(.caption).foregroundStyle(AppTheme.onSurfaceVariant) }; Spacer(); VStack(alignment: .trailing) { Text(shortRupees(c.spentPaise)).bold(); Text("of \(shortRupees(c.budget.limitAmountPaise))").font(.caption).foregroundStyle(AppTheme.onSurfaceVariant) }; Menu { Button("Edit") { editing = c.budget }; Button("Delete", role: .destructive) { Task { try? await store.deleteBudget(c.budget.id) } } } label: { Image(systemName: "ellipsis.circle") } } } } }; Text("HOW YOU PAID").font(.caption.bold()); HStack { budgetMetric("UPI", s.upiSpentPaise); budgetMetric("Cash", s.cashSpentPaise) }; Text("SHARED OVERVIEW").font(.caption.bold()); HStack { budgetMetric("You Paid", s.currentUserSpentPaise); budgetMetric("\(s.partnerName) Paid", s.partnerSpentPaise) }; HStack { budgetMetric("Your Responsibility", s.currentUserResponsiblePaise); budgetMetric("Their Responsibility", s.partnerResponsiblePaise) }; if !s.insights.isEmpty { Text("INSIGHTS").font(.caption.bold()); ForEach(s.insights, id: \.self) { Text("• \($0)").font(.subheadline) } }; Text("WEEKLY SPENDING").font(.caption.bold()); Chart(s.weeklyChartData) { day in BarMark(x: .value("Day", day.dayName), y: .value("Spent", Double(day.spentPaise)/100.0)) }.frame(height: 180) }
        }.padding(18) }.sheet(isPresented: $create) { BudgetEditorSheet(store: store, month: month) }.sheet(item: $editing) { budget in BudgetEditorSheet(store: store, month: month, edit: budget) } }
    @ViewBuilder private func budgetMetric(_ title: String, _ value: Int64) -> some View { GlassCard { VStack(alignment: .leading) { Text(title).font(.caption2); Text(shortRupees(value)).font(.headline) } }.frame(maxWidth: .infinity) }
}

extension BudgetHealth { var title: String { switch self { case .onTrack: "On track"; case .watch: "Keep an eye on it"; case .atRisk: "At risk"; case .overBudget: "Over budget" } } }

struct BudgetEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: FinanceStore
    let month: Date
    let edit: Budget?
    @State private var category: String; @State private var limit: String; @State private var personal: Bool
    init(store: FinanceStore, month: Date, edit: Budget? = nil) { self.store = store; self.month = month; self.edit = edit; _category = State(initialValue: edit?.category ?? "Food & Dining"); _limit = State(initialValue: edit.map { String(Double($0.limitAmountPaise)/100.0) } ?? ""); _personal = State(initialValue: edit?.personal ?? false) }
    var body: some View { NavigationStack { Form { Picker("Category", selection: $category) { ForEach((standardCategories + store.categories.map(\.name)).uniqued().sorted(), id: \.self) { Text($0).tag($0) } }; TextField("Monthly Limit (₹)", text: $limit).keyboardType(.decimalPad); Toggle("Personal Budget", isOn: $personal); Button("Save") { Task { guard let value = Double(limit), value > 0 else { return }; var budget = edit ?? Budget(); budget.category = category; budget.limitAmountPaise = Int64((value*100).rounded()); budget.personal = personal; budget.createdBy = edit?.createdBy ?? store.currentUser.id; budget.monthYear = edit?.monthYear ?? DateFormatter.ourMoney("MM-yyyy").string(from: month); try? await store.saveBudget(budget); dismiss() } } }.navigationTitle(edit == nil ? "Create a Budget" : "Edit Budget").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } } } }
}
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: FinanceStore
    @State private var showReset = false; @State private var resetText = ""; @State private var showDisconnect = false
    @State private var firebaseLoaded: Bool?; @State private var firestoreRead: Bool?; @State private var firestoreWrite: Bool?
    var body: some View { NavigationStack { Form {
        Section("Connection") { LabeledContent("You", value: store.currentUser.name); LabeledContent("Connected with", value: store.partnerName); LabeledContent("Connection code", value: store.household.code).contextMenu { Button("Copy") { UIPasteboard.general.string = store.household.code } }; Button("Disconnect / Leave Connection", role: .destructive) { showDisconnect = true } }
        Section("Danger Zone") { Text("Permanently delete all transactions and reset balances, history and analytics.").font(.caption).foregroundStyle(AppTheme.onSurfaceVariant); Button("Reset All Transactions", role: .destructive) { showReset = true } }
        Section("Diagnostics") { DiagnosticItemSwift(name: "Application Running", status: true); DiagnosticItemSwift(name: "Firebase Initialized", status: firebaseLoaded); DiagnosticItemSwift(name: "Current User Session", status: Auth.auth().currentUser != nil); DiagnosticItemSwift(name: "Shared Space Valid", status: !store.household.id.isEmpty); DiagnosticItemSwift(name: "Members", status: store.household.members.count == 2, detail: "\(store.household.members.count) / 2"); DiagnosticItemSwift(name: "Firestore Read", status: firestoreRead); DiagnosticItemSwift(name: "Firestore Write", status: firestoreWrite); DiagnosticItemSwift(name: "Realtime Active", status: true) }
        Section("Account") { LabeledContent("Email", value: store.currentUser.email); Button("Sign Out") { try? Auth.auth().signOut(); dismiss() } }
    }.navigationTitle("Settings").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
     .alert("Confirm Reset", isPresented: $showReset) { TextField("Type RESET", text: $resetText); Button("Reset", role: .destructive) { guard resetText == "RESET" else { return }; Task { try? await store.resetTransactions(); resetText = "" } }; Button("Cancel", role: .cancel) {} } message: { Text("This is a destructive action. Type RESET to continue.") }
     .alert("Disconnect Connection?", isPresented: $showDisconnect) { Button("Disconnect", role: .destructive) { Task { var u = store.currentUser; u.householdId = nil; u.connectedAt = nil; let service = FirestoreService(); try? await service.setUser(u); try? await service.updateHouseholdMembers(id: store.household.id, members: store.household.members.filter { $0 != store.currentUser.id }); dismiss() } }; Button("Cancel", role: .cancel) {} } message: { Text("Your financial data is not silently deleted, but this device will stop syncing with \(store.partnerName).") }
     .task { await runDiagnostics() }
    }
    }
    private func runDiagnostics() async { firebaseLoaded = FirebaseApp.app() != nil; do { let ref = Firestore.firestore().collection("households").document(store.household.id).collection("diagnostics").document("test"); try await ref.setData(["timestamp": FieldValue.serverTimestamp()]); firestoreWrite = true; firestoreRead = try (await ref.getDocument()).exists } catch { if firestoreWrite == nil { firestoreWrite = false }; if firestoreRead == nil { firestoreRead = false } } }
}

struct DiagnosticItemSwift: View { let name: String; let status: Bool?; let detail: String; init(name: String, status: Bool?, detail: String = "") { self.name = name; self.status = status; self.detail = detail }; var body: some View { HStack { Text(name); Spacer(); switch status { case true: Text(detail.isEmpty ? "✓ Yes" : "✓ \(detail)").foregroundStyle(AppTheme.primary).bold(); case false: Text(detail.isEmpty ? "✗ Error" : "✗ \(detail)").foregroundStyle(AppTheme.error).bold(); case nil: Text("Testing…").foregroundStyle(AppTheme.onSurfaceVariant) } } } }

@MainActor
final class AIViewModel: ObservableObject {
    @Published var scope: AIScope = .personal { didSet { reloadChats() } }
    @Published private(set) var chats: [AIChat] = []
    @Published private(set) var currentChat: AIChat?
    @Published private(set) var messages: [AIMessage] = []
    @Published var input = ""
    @Published var loading = false
    @Published var error = ""
    let store: FinanceStore
    private let service = FirestoreService()
    private let ai = GeminiClient()
    private var chatListener: AnyCancellable?
    private var messageListener: AnyCancellable?

    init(store: FinanceStore) { self.store = store; reloadChats() }
    deinit { chatListener?.cancel(); messageListener?.cancel() }
    private func reloadChats() { chatListener?.cancel(); chatListener = service.observeChats(userId: store.currentUser.id, householdId: store.household.id, scope: scope) { [weak self] chats in Task { @MainActor in self?.chats = chats } } }
    func open(_ chat: AIChat) { currentChat = chat; messageListener?.cancel(); messageListener = service.observeMessages(chatId: chat.id) { [weak self] messages in Task { @MainActor in self?.messages = messages } } }
    func close() { currentChat = nil; messages = []; messageListener?.cancel(); messageListener = nil }
    func newChat() async { let chat = AIChat(ownerId: store.currentUser.id, householdId: store.household.id, scope: scope); do { try await service.createChat(chat); open(chat) } catch { error = error.localizedDescription } }
    func delete(_ chat: AIChat) async { do { try await service.deleteChat(chat.id); if currentChat?.id == chat.id { close() } } catch { error = error.localizedDescription } }
    func send() { guard let chat = currentChat, !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }; let text = input.trimmingCharacters(in: .whitespacesAndNewlines); input = ""; loading = true; error = ""; Task { do { let userMessage = AIMessage(chatId: chat.id, role: .user, content: text); try await service.addMessage(userMessage); if messages.isEmpty { try? await service.updateChatTitle(id: chat.id, title: text.count > 30 ? String(text.prefix(27)) + "..." : text) }; let context = AIFinancialContextEngine().generate(scope: scope, currentUser: store.currentUser, transactions: store.transactions, budgets: store.budgets, goals: store.goals, settlements: store.settlements); let system = "You are OurMoney AI, a premium personal financial intelligence assistant. Answer only from the supplied OurMoney data. Do not invent data. Answer the question first. Do not use markdown, hashtags, asterisks, backticks or raw IDs. Keep simple answers short and complex answers useful. Use human-friendly Indian rupee formatting.\n\nFINANCIAL CONTEXT:\n\(context)"; var history: [(String, String)] = []; for m in messages where m.id != userMessage.id { history.append((m.role.rawValue, m.content)) }; history.append(("USER", text)); let reply = try await ai.generate(systemInstruction: system, history: history); try await service.addMessage(AIMessage(chatId: chat.id, role: .model, content: reply)) } catch { error = "Sorry, I couldn't analyze that right now.\nYour financial data is safe. Try again." }; loading = false } }
}

struct AIView: View {
    @StateObject private var model: AIViewModel
    init(store: FinanceStore) { _model = StateObject(wrappedValue: AIViewModel(store: store)) }
    var body: some View { VStack(spacing: 0) { HStack { VStack(alignment: .leading) { Text("OurMoney AI").font(.largeTitle.bold()); Text("Your personal financial intelligence").font(.caption).foregroundStyle(AppTheme.onSurfaceVariant) }; Spacer(); Button { Task { await model.newChat() } } label: { Image(systemName: "plus.bubble.fill") } }.padding(18); Picker("Scope", selection: $model.scope) { Text("Personal").tag(AIScope.personal); Text("Shared").tag(AIScope.shared) }.pickerStyle(.segmented).padding(.horizontal, 18); if let _ = model.currentChat { ScrollView { LazyVStack(alignment: .leading, spacing: 10) { ForEach(model.messages) { message in ChatBubble(message: message) } }.padding(18) }; if !model.error.isEmpty { Text(model.error).font(.caption).foregroundStyle(AppTheme.error).padding(.horizontal, 18) }; HStack { TextField("Ask OurMoney anything…", text: $model.input, axis: .vertical).lineLimit(1...4).padding(10).background(AppTheme.surfaceVariant).clipShape(RoundedRectangle(cornerRadius: 14)); Button { model.send() } label: { Image(systemName: model.loading ? "hourglass" : "arrow.up.circle.fill").font(.title2) }.disabled(model.loading) }.padding(12) } else { ContentUnavailableView("How can I help you today?", systemImage: "sparkles", description: Text("I can analyze your spending and budgets.")); if !model.chats.isEmpty { List(model.chats) { chat in HStack { Button { model.open(chat) } label: { Text(chat.title).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain); Button(role: .destructive) { Task { await model.delete(chat) } } label: { Image(systemName: "trash") } }.listRowBackground(Color.clear) }.scrollContentBackground(.hidden) } } }.background(Color.clear) }
}

struct ChatBubble: View { let message: AIMessage; var body: some View { HStack { if message.role == .user { Spacer() }; Text(message.content).padding(12).background(message.role == .model ? AppTheme.surfaceVariant : AppTheme.primaryContainer).clipShape(RoundedRectangle(cornerRadius: 16)); if message.role == .model { Spacer() } } } }

struct BudgetCalculator {
    static func build(store: FinanceStore, selectedMonth: Date, scope: BudgetScope) -> ComprehensiveBudgetState? {
        let cal = Calendar.current; let now = Date(); let year = cal.component(.year, from: selectedMonth); let month = cal.component(.month, from: selectedMonth); let isCurrent = cal.component(.year, from: now) == year && cal.component(.month, from: now) == month; let isPast = selectedMonth < now && !isCurrent; let start = cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? selectedMonth; let daysInMonth = cal.range(of: .day, in: .month, for: start)?.count ?? 30; let daysElapsed = isPast ? daysInMonth : (isCurrent ? cal.component(.day, from: now) : 0); let daysRemaining = isPast ? 0 : max(1, daysInMonth - daysElapsed); let monthYear = DateFormatter.ourMoney("MM-yyyy").string(from: start); let monthName = DateFormatter.ourMoney("MMMM yyyy").string(from: start)
        let scopedBudget = store.budgets.filter { scope == .all ? (!$0.personal || $0.createdBy == store.currentUser.id) : (scope == .shared ? !$0.personal : ($0.personal && $0.createdBy == store.currentUser.id)) }; let currentBudgets = scopedBudget.filter { $0.monthYear == monthYear }; let totalBudget = currentBudgets.sum(\.limitAmountPaise)
        let expenses = store.transactions.filter { tx in let scopeOK = scope == .all ? (!tx.personal || tx.createdBy == store.currentUser.id) : (scope == .shared ? !tx.personal : (tx.personal && tx.createdBy == store.currentUser.id)); return scopeOK && tx.type == .expense && !tx.isDeleted }; let current = expenses.filter { DateFormatter.ourMoney("MM-yyyy").string(from: dateFromMillis($0.dateMillis)) == monthYear }; let lastMonthDate = cal.date(byAdding: .month, value: -1, to: start) ?? start; let lastMonthYear = DateFormatter.ourMoney("MM-yyyy").string(from: lastMonthDate); let lastMonth = expenses.filter { DateFormatter.ourMoney("MM-yyyy").string(from: dateFromMillis($0.dateMillis)) == lastMonthYear }
        let referenceDay: Date = isCurrent ? now : isPast ? cal.date(bySetting: .day, value: daysInMonth, of: start) ?? start : start; var weekCalendar = cal; weekCalendar.firstWeekday = 2; let weekStart = weekCalendar.dateInterval(of: .weekOfYear, for: referenceDay)?.start ?? start; let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart; let lastWeekStart = cal.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
        let totalSpent = current.sum(\.amountPaise); let spentToday = current.filter { cal.isDate(dateFromMillis($0.dateMillis), inSameDayAs: referenceDay) }.sum(\.amountPaise); let spentThisWeek = current.filter { let d=dateFromMillis($0.dateMillis); return d >= weekStart && d < weekEnd }.sum(\.amountPaise); let spentLastWeek = expenses.filter { let d=dateFromMillis($0.dateMillis); return d >= lastWeekStart && d < weekStart }.sum(\.amountPaise); let spentLastMonth = lastMonth.sum(\.amountPaise)
        let remaining = totalBudget - totalSpent; let safeDaily = remaining > 0 && daysRemaining > 0 ? remaining / Int64(daysRemaining) : 0; let avg = daysElapsed > 0 ? totalSpent / Int64(daysElapsed) : 0; let forecast = totalSpent + avg * Int64(daysRemaining); let budgetPct = totalBudget > 0 ? Float(totalSpent) / Float(totalBudget) : 0; let timePct = daysInMonth > 0 ? Float(daysElapsed) / Float(daysInMonth) : 0; let health: BudgetHealth = totalSpent > totalBudget ? .overBudget : budgetPct > timePct + 0.1 ? .atRisk : budgetPct > timePct ? .watch : .onTrack
        let categories = currentBudgets.map { b -> CategoryStat in let txs = current.filter { $0.category.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(b.category.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame && $0.personal == b.personal }; let spent = txs.sum(\.amountPaise); return CategoryStat(budget: b, spentPaise: spent, totalTransactions: txs.count, largestTransaction: txs.map(\.amountPaise).max() ?? 0, averageTransaction: txs.isEmpty ? 0 : spent / Int64(txs.count), transactions: txs.sorted { $0.dateMillis > $1.dateMillis }) }.sorted { $0.spentPaise > $1.spentPaise }
        let weekly = (0..<7).map { offset -> WeeklyDayStat in let day = cal.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart; let end = cal.date(byAdding: .day, value: 1, to: day) ?? day; return WeeklyDayStat(dayName: DateFormatter.ourMoney("EEE").string(from: day), spentPaise: current.filter { let d=dateFromMillis($0.dateMillis); return d >= day && d < end }.sum(\.amountPaise), dateMillis: millis(day)) }
        var insights: [String] = []; if spentThisWeek < spentLastWeek && spentLastWeek > 0 { insights.append("You spent \(shortRupees(spentLastWeek - spentThisWeek)) less this week than last week.") }; if avg > safeDaily && safeDaily > 0 { insights.append("You're spending \(shortRupees(avg - safeDaily))/day faster than your safe rate.") }; if let top = categories.first, totalSpent > 0 { insights.append("\(top.budget.category) accounts for \(Int(Double(top.spentPaise)/Double(max(totalSpent,1))*100))% of your spending.") }; if forecast < totalBudget && totalBudget > 0 { insights.append("You're currently on pace to finish \(shortRupees(totalBudget - forecast)) under budget.") }
        let mySpent = current.filter { $0.paidBy == store.currentUser.id }.sum(\.amountPaise); let partnerId = store.household.members.first { $0 != store.currentUser.id }; let partnerSpent = current.filter { $0.paidBy == partnerId }.sum(\.amountPaise); var myResp: Int64 = 0; var partnerResp: Int64 = 0; for tx in current { if tx.personal { if tx.createdBy == store.currentUser.id { myResp += tx.amountPaise } else { partnerResp += tx.amountPaise } } else { if tx.splitMethod == .exact { for split in tx.splits { if split.userId == store.currentUser.id { myResp += split.amountPaise } else if split.userId == partnerId { partnerResp += split.amountPaise } } } else { let half = tx.amountPaise / 2; myResp += half; partnerResp += tx.amountPaise - half } } }
        let upi = current.filter { $0.paymentMethod.localizedCaseInsensitiveContains("upi") }.sum(\.amountPaise); let cash = current.filter { $0.paymentMethod.localizedCaseInsensitiveContains("cash") }.sum(\.amountPaise)
        return ComprehensiveBudgetState(monthYearStr: monthYear, monthName: monthName, totalBudgetPaise: totalBudget, totalSpentPaise: totalSpent, spentTodayPaise: spentToday, safeDailyLimitPaise: safeDaily, spentThisWeekPaise: spentThisWeek, weeklyBudgetPaise: totalBudget / Int64(max(daysInMonth, 1)) * 7, expectedMonthEndPaise: forecast, expectedRemainingPaise: totalBudget - forecast, daysInMonth: daysInMonth, daysElapsed: daysElapsed, daysRemaining: daysRemaining, healthStatus: health, categories: categories, weeklyChartData: weekly, spentLastWeekPaise: spentLastWeek, spentLastMonthPaise: spentLastMonth, upiSpentPaise: upi, cashSpentPaise: cash, currentUserSpentPaise: mySpent, partnerSpentPaise: partnerSpent, currentUserResponsiblePaise: myResp, partnerResponsiblePaise: partnerResp, partnerName: store.partnerName, insights: insights, selectedScope: scope)
    }
}

extension Sequence { func sum(_ keyPath: KeyPath<Element, Int64>) -> Int64 { reduce(0) { $0 + $1[keyPath: keyPath] } } }
extension Collection where Element: Hashable { func uniqued() -> [Element] { var set = Set<Element>(); return filter { set.insert($0).inserted } } }

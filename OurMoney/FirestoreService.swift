import Foundation
import Combine
import FirebaseFirestore

final class FirestoreService {
    // Computed on first use: Firestore.firestore() requires FirebaseApp.configure()
    // to have run; a stored property would capture it at instance creation time.
    private var db: Firestore { Firestore.firestore() }

    func userDocument(_ uid: String) -> DocumentReference { db.collection("users").document(uid) }
    func householdDocument(_ id: String) -> DocumentReference { db.collection("households").document(id) }

    func observeUser(uid: String, handler: @escaping (Result<User?, Error>) -> Void) -> AnyCancellable {
        let reg = userDocument(uid).addSnapshotListener { snap, error in
            if let error { handler(.failure(error)); return }
            guard let snap, snap.exists else { handler(.success(nil)); return }
            do { handler(.success(try FirestoreCodec.decode(User.self, from: FirestoreCodec.dataForDocument(snap)))) }
            catch { handler(.failure(error)) }
        }
        return AnyCancellable { reg.remove() }
    }

    func observeHousehold(id: String, handler: @escaping (Result<Household?, Error>) -> Void) -> AnyCancellable {
        let reg = householdDocument(id).addSnapshotListener { snap, error in
            if let error { handler(.failure(error)); return }
            guard let snap, snap.exists else { handler(.success(nil)); return }
            do { handler(.success(try FirestoreCodec.decode(Household.self, from: FirestoreCodec.dataForDocument(snap)))) }
            catch { handler(.failure(error)) }
        }
        return AnyCancellable { reg.remove() }
    }

    func getUser(uid: String) async throws -> User? {
        let snap = try await userDocument(uid).getDocument()
        guard snap.exists else { return nil }
        return try FirestoreCodec.decode(User.self, from: FirestoreCodec.dataForDocument(snap))
    }

    func setUser(_ user: User) async throws { try await userDocument(user.id).setData(FirestoreCodec.encode(user)) }

    func createHousehold(_ household: Household) async throws { try await householdDocument(household.id).setData(FirestoreCodec.encode(household)) }

    func updateHouseholdMembers(id: String, members: [String]) async throws { try await householdDocument(id).updateData(["members": members]) }

    func deleteHousehold(id: String) async throws { try await householdDocument(id).delete() }

    func observeTransactions(householdId: String, currentUserId: String, handler: @escaping ([Transaction]) -> Void, onError: @escaping (Error) -> Void) -> AnyCancellable {
        let base = householdDocument(householdId).collection("transactions")
        let sharedQuery = base.whereField("personal", isEqualTo: false).order(by: "dateMillis", descending: true)
        let personalQuery = base.whereField("personal", isEqualTo: true).whereField("createdBy", isEqualTo: currentUserId).order(by: "dateMillis", descending: true)
        var shared: [Transaction] = []; var personal: [Transaction] = []; let lock = NSLock()
        func emit() { lock.lock(); let out = (shared + personal).sorted { $0.dateMillis > $1.dateMillis }; lock.unlock(); handler(out) }
        let r1 = sharedQuery.addSnapshotListener(includeMetadataChanges: true) { snap, error in if let error { onError(error) } else { shared = (snap?.documents ?? []).compactMap { self.decodeTransaction($0) }; emit() } }
        let r2 = personalQuery.addSnapshotListener(includeMetadataChanges: true) { snap, error in if let error { onError(error) } else { personal = (snap?.documents ?? []).compactMap { self.decodeTransaction($0) }; emit() } }
        return AnyCancellable { r1.remove(); r2.remove() }
    }

    func observeSettlements(householdId: String, handler: @escaping ([Settlement]) -> Void, onError: @escaping (Error) -> Void) -> AnyCancellable {
        let q = householdDocument(householdId).collection("settlements").order(by: "dateMillis", descending: true)
        let reg = q.addSnapshotListener(includeMetadataChanges: true) { snap, error in
            if let error { onError(error); return }
            handler((snap?.documents ?? []).compactMap { self.decodeSettlement($0) })
        }
        return AnyCancellable { reg.remove() }
    }

    func observeGoals(householdId: String, currentUserId: String, handler: @escaping ([Goal]) -> Void, onError: @escaping (Error) -> Void) -> AnyCancellable {
        let shared = householdDocument(householdId).collection("goals").whereField("personal", isEqualTo: false)
        let personal = householdDocument(householdId).collection("goals").whereField("personal", isEqualTo: true).whereField("createdBy", isEqualTo: currentUserId)
        var a: [Goal] = []; var b: [Goal] = []
        let lock = NSLock()
        func emit() { lock.lock(); let out = (a + b).sorted { $0.createdAt > $1.createdAt }; lock.unlock(); handler(out) }
        let r1 = shared.addSnapshotListener(includeMetadataChanges: true) { snap, error in if let error { onError(error) } else { a = (snap?.documents ?? []).compactMap { self.decodeGoal($0) }; emit() } }
        let r2 = personal.addSnapshotListener(includeMetadataChanges: true) { snap, error in if let error { onError(error) } else { b = (snap?.documents ?? []).compactMap { self.decodeGoal($0) }; emit() } }
        return AnyCancellable { r1.remove(); r2.remove() }
    }

    func observeBudgets(householdId: String, currentUserId: String, handler: @escaping ([Budget]) -> Void, onError: @escaping (Error) -> Void) -> AnyCancellable {
        let shared = householdDocument(householdId).collection("budgets").whereField("personal", isEqualTo: false)
        let personal = householdDocument(householdId).collection("budgets").whereField("personal", isEqualTo: true).whereField("createdBy", isEqualTo: currentUserId)
        var a: [Budget] = []; var b: [Budget] = []
        let lock = NSLock()
        func emit() { lock.lock(); let out = (a + b).sorted { $0.createdAt > $1.createdAt }; lock.unlock(); handler(out) }
        let r1 = shared.addSnapshotListener(includeMetadataChanges: true) { snap, error in if let error { onError(error) } else { a = (snap?.documents ?? []).compactMap { self.decodeBudget($0) }; emit() } }
        let r2 = personal.addSnapshotListener(includeMetadataChanges: true) { snap, error in if let error { onError(error) } else { b = (snap?.documents ?? []).compactMap { self.decodeBudget($0) }; emit() } }
        return AnyCancellable { r1.remove(); r2.remove() }
    }

    func observeCategories(householdId: String, handler: @escaping ([CustomCategory]) -> Void, onError: @escaping (Error) -> Void) -> AnyCancellable {
        let q = householdDocument(householdId).collection("categories").order(by: "name")
        let reg = q.addSnapshotListener(includeMetadataChanges: true) { snap, error in
            if let error { onError(error); return }
            handler((snap?.documents ?? []).compactMap { self.decodeCategory($0) })
        }
        return AnyCancellable { reg.remove() }
    }

    func observeChats(userId: String, householdId: String, scope: AIScope, handler: @escaping ([AIChat]) -> Void, onError: @escaping (Error) -> Void) -> AnyCancellable {
        let q: Query = scope == .personal
            ? db.collection("ai_chats").whereField("ownerId", isEqualTo: userId).whereField("scope", isEqualTo: "PERSONAL")
            : db.collection("ai_chats").whereField("householdId", isEqualTo: householdId).whereField("scope", isEqualTo: "SHARED")
        let reg = q.addSnapshotListener { snap, error in
            if let error { onError(error); return }
            handler((snap?.documents ?? []).compactMap { self.decodeChat($0) }.sorted { $0.updatedAt > $1.updatedAt })
        }
        return AnyCancellable { reg.remove() }
    }

    func observeMessages(chatId: String, handler: @escaping ([AIMessage]) -> Void, onError: @escaping (Error) -> Void) -> AnyCancellable {
        let q = db.collection("ai_messages").whereField("chatId", isEqualTo: chatId)
        let reg = q.addSnapshotListener { snap, error in
            if let error { onError(error); return }
            handler((snap?.documents ?? []).compactMap { self.decodeMessage($0) }.sorted { $0.timestamp < $1.timestamp })
        }
        return AnyCancellable { reg.remove() }
    }

    func transaction(householdId: String, id: String) -> DocumentReference { householdDocument(householdId).collection("transactions").document(id) }
    func settlement(householdId: String, id: String) -> DocumentReference { householdDocument(householdId).collection("settlements").document(id) }
    func goal(householdId: String, id: String) -> DocumentReference { householdDocument(householdId).collection("goals").document(id) }
    func budget(householdId: String, id: String) -> DocumentReference { householdDocument(householdId).collection("budgets").document(id) }
    func category(householdId: String, id: String) -> DocumentReference { householdDocument(householdId).collection("categories").document(id) }

    func getTransaction(householdId: String, id: String) async throws -> Transaction? { let s = try await transaction(householdId: householdId,id:id).getDocument(); guard s.exists else { return nil }; return decodeTransaction(s) }
    func getSettlement(householdId: String, id: String) async throws -> Settlement? { let s = try await settlement(householdId: householdId,id:id).getDocument(); guard s.exists else { return nil }; return decodeSettlement(s) }

    func write(_ tx: Transaction, householdId: String) async throws { try await transaction(householdId: householdId,id:tx.id).setData(FirestoreCodec.encode(tx)) }
    func deleteTransaction(householdId: String, id: String) async throws { try await transaction(householdId: householdId,id:id).delete() }
    func write(_ s: Settlement, householdId: String) async throws { try await settlement(householdId: householdId,id:s.id).setData(FirestoreCodec.encode(s)) }
    func deleteSettlement(householdId: String, id: String) async throws { try await settlement(householdId: householdId,id:id).delete() }
    func write(_ g: Goal, householdId: String) async throws { try await goal(householdId: householdId,id:g.id).setData(FirestoreCodec.encode(g)) }
    func deleteGoal(householdId: String, id: String) async throws { try await goal(householdId: householdId,id:id).delete() }
    func write(_ b: Budget, householdId: String) async throws { try await budget(householdId: householdId,id:b.id).setData(FirestoreCodec.encode(b)) }
    func deleteBudget(householdId: String, id: String) async throws { try await budget(householdId: householdId,id:id).delete() }
    func write(_ c: CustomCategory, householdId: String) async throws { try await category(householdId: householdId,id:c.id).setData(FirestoreCodec.encode(c)) }
    func deleteCategory(householdId: String, id: String) async throws { try await category(householdId: householdId,id:id).delete() }

    func createChat(_ chat: AIChat) async throws { try await db.collection("ai_chats").document(chat.id).setData(FirestoreCodec.encode(chat)) }
    func updateChatTitle(id: String, title: String) async throws { try await db.collection("ai_chats").document(id).updateData(["title": title, "updatedAt": nowMillis()]) }
    func deleteChat(_ id: String) async throws {
        try await db.collection("ai_chats").document(id).delete()
        let docs = try await db.collection("ai_messages").whereField("chatId", isEqualTo: id).getDocuments()
        for d in docs.documents { try await d.reference.delete() }
    }
    func addMessage(_ msg: AIMessage) async throws {
        try await db.collection("ai_messages").document(msg.id).setData(FirestoreCodec.encode(msg))
        try await db.collection("ai_chats").document(msg.chatId).updateData(["updatedAt": nowMillis()])
    }

    func resetTransactions(householdId: String, currentUserId: String) async throws {
        let ref = householdDocument(householdId)
        let shared = try await ref.collection("transactions").whereField("personal", isEqualTo: false).getDocuments()
        let personal = try await ref.collection("transactions").whereField("personal", isEqualTo: true).whereField("createdBy", isEqualTo: currentUserId).getDocuments()
        let settlements = try await ref.collection("settlements").getDocuments()
        let refs = shared.documents.map(\.reference) + personal.documents.map(\.reference) + settlements.documents.map(\.reference)
        let chunkSize = 450 // stay below Firestore's 500-operation batch limit.
        var start = 0
        while start < refs.count {
            let end = min(start + chunkSize, refs.count)
            let batch = db.batch()
            for document in refs[start..<end] { batch.deleteDocument(document) }
            try await batch.commit()
            start = end
        }
    }

    private func decodeTransaction(_ d: DocumentSnapshot) -> Transaction? { decode(Transaction.self, d, pending: d.metadata.hasPendingWrites) }
    private func decodeSettlement(_ d: DocumentSnapshot) -> Settlement? { decode(Settlement.self, d, pending: d.metadata.hasPendingWrites) }
    private func decodeGoal(_ d: DocumentSnapshot) -> Goal? { decode(Goal.self, d, pending: d.metadata.hasPendingWrites) }
    private func decodeBudget(_ d: DocumentSnapshot) -> Budget? { decode(Budget.self, d, pending: d.metadata.hasPendingWrites) }
    private func decodeCategory(_ d: DocumentSnapshot) -> CustomCategory? { decode(CustomCategory.self, d, pending: false) }
    private func decodeChat(_ d: DocumentSnapshot) -> AIChat? { decode(AIChat.self, d, pending: false) }
    private func decodeMessage(_ d: DocumentSnapshot) -> AIMessage? { decode(AIMessage.self, d, pending: false) }

    private func decode<T: Decodable>(_ type: T.Type, _ d: DocumentSnapshot, pending: Bool) -> T? {
        do { return try FirestoreCodec.decode(type, from: FirestoreCodec.dataForDocument(d)) } catch { return nil }
    }
}

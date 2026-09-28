import Foundation
import FirebaseFirestore

enum FirestoreCodec {
    static func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any] else { throw NSError(domain: "FirestoreCodec", code: 1, userInfo: [NSLocalizedDescriptionKey: "Encoding failed"]) }
        return dict
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: [String: Any]) throws -> T {
        let json = try JSONSerialization.data(withJSONObject: sanitize(data), options: [])
        return try JSONDecoder().decode(type, from: json)
    }

    private static func sanitize(_ value: Any) -> Any {
        if let timestamp = value as? Timestamp { return Int64(timestamp.dateValue().timeIntervalSince1970 * 1000) }
        if let dict = value as? [String: Any] { return dict.mapValues(sanitize) }
        if let arr = value as? [Any] { return arr.map(sanitize) }
        if value is NSNull { return NSNull() }
        return value
    }

    static func dataForDocument(_ snapshot: DocumentSnapshot) -> [String: Any] {
        var data = snapshot.data() ?? [:]
        data["id"] = (data["id"] as? String) ?? snapshot.documentID
        return data
    }
}

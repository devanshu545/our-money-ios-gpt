import Foundation
import UIKit
import SwiftUI

enum AppTheme {
    static let primary = Color(red: 0.502, green: 0.796, blue: 0.769)
    static let primaryContainer = Color(red: 0.0, green: 0.314, blue: 0.286)
    static let secondary = Color(red: 0.690, green: 0.745, blue: 0.773)
    static let secondaryContainer = Color(red: 0.196, green: 0.251, blue: 0.282)
    static let surface = Color(red: 0.102, green: 0.110, blue: 0.118)
    static let background = Color(red: 0.071, green: 0.071, blue: 0.071)
    static let surfaceVariant = Color(red: 0.184, green: 0.188, blue: 0.200)
    static let onSurface = Color(red: 0.89, green: 0.89, blue: 0.90)
    static let onSurfaceVariant = Color(red: 0.77, green: 0.78, blue: 0.82)
    static let outline = Color(red: 0.56, green: 0.56, blue: 0.60)
    static let error = Color(red: 1.0, green: 0.706, blue: 0.671)
}

func nowMillis() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
func millis(_ date: Date) -> Int64 { Int64(date.timeIntervalSince1970 * 1000) }
func dateFromMillis(_ value: Int64) -> Date { Date(timeIntervalSince1970: Double(value) / 1000.0) }

func formatRupees(_ paise: Int64) -> String {
    let value = Double(paise) / 100.0
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencySymbol = "₹"
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = value.rounded() == value ? 0 : 2
    return formatter.string(from: NSNumber(value: value)) ?? "₹\(String(format: "%.2f", value))"
}

func shortRupees(_ paise: Int64) -> String { formatRupees(paise).replacingOccurrences(of: ".00", with: "") }

let standardCategories = ["Food & Dining", "Groceries", "Transport", "Shopping", "Entertainment", "Bills & Utilities", "Health", "Travel", "Education", "Misc"]

func categoryIcon(_ category: String) -> String {
    let c = category.lowercased()
    if c.contains("food") || c.contains("dining") || c.contains("restaurant") { return "fork.knife" }
    if c.contains("grocer") { return "cart" }
    if c.contains("transport") || c.contains("petrol") || c.contains("fuel") { return "car.fill" }
    if c.contains("shop") { return "bag.fill" }
    if c.contains("entertain") { return "gamecontroller.fill" }
    if c.contains("bill") || c.contains("utilit") { return "doc.text.fill" }
    if c.contains("health") { return "heart.fill" }
    if c.contains("travel") { return "airplane" }
    if c.contains("education") { return "book.fill" }
    return "circle.grid.2x2.fill"
}

extension DateFormatter {
    static func ourMoney(_ format: String) -> DateFormatter { let f = DateFormatter(); f.locale = .current; f.dateFormat = format; return f }
}

func firstName(_ value: String) -> String { value.split(separator: " ").first.map(String.init) ?? value }

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

func makePDF(title: String, rows: [[String]], subtitle: String = "") -> URL? {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("OurMoney-\(UUID().uuidString.prefix(8)).pdf")
    let page = CGRect(x: 0, y: 0, width: 612, height: 792)
    let renderer = UIGraphicsPDFRenderer(bounds: page)
    do {
        try renderer.writePDF(to: url) { ctx in
            var y: CGFloat = 44
            func text(_ s: String, x: CGFloat, y: CGFloat, font: UIFont, maxWidth: CGFloat) { NSString(string: s).draw(in: CGRect(x: x, y: y, width: maxWidth, height: 34), withAttributes: [.font: font]) }
            text(title, x: 40, y: y, font: .boldSystemFont(ofSize: 20), maxWidth: 530); y += 30
            if !subtitle.isEmpty { text(subtitle, x: 40, y: y, font: .systemFont(ofSize: 11), maxWidth: 530); y += 24 }
            let widths: [CGFloat] = [92, 236, 90, 90]
            for (i,row) in rows.enumerated() {
                if y > 720 { ctx.beginPage(); y = 44 }
                var x: CGFloat = 40
                for (j,cell) in row.enumerated() { text(cell, x: x, y: y, font: .systemFont(ofSize: i == 0 ? 10 : 9), maxWidth: widths[min(j,widths.count-1)]); x += widths[min(j,widths.count-1)] + 6 }
                y += i == 0 ? 24 : 20
            }
        }
        return url
    } catch { return nil }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

import Foundation
import SwiftUI
import SwiftData

@Model
final class ExpenseCategory {
    var name: String
    /// Stored as a hex string (e.g. "#4CAF50") so it persists cleanly in SwiftData.
    var colorHex: String

    init(name: String, colorHex: String) {
        self.name = name
        self.colorHex = colorHex
    }

    /// The SwiftUI color for this category.
    @Transient
    var color: Color {
        get { Color(hex: colorHex) }
        set { colorHex = newValue.hexString }
    }

    /// True if this instance is one of the app's built-in default categories.
    var isDefault: Bool {
        Self.defaults.contains { $0.name == name }
    }

    /// The fixed, most-common categories the app ships with (max 8).
    /// These are always present and cannot be deleted; users can add their own.
    static let defaults: [(name: String, colorHex: String)] = [
        ("Housing", "#4C7BE0"),        // blue — rent/mortgage
        ("Food & Groceries", "#4CAF50"), // green — food
        ("Transport", "#FF9800"),      // orange — buses, fuel, taxis
        ("Utilities", "#26A69A"),      // teal — water, power, internet
        ("Health", "#E53935"),         // red — medical, pharmacy
        ("Entertainment", "#AB47BC"),  // purple — streaming, outings
        ("Education", "#8D6E63"),      // brown — courses, books
        ("Savings", "#FBC02D"),        // yellow — setting money aside
    ]

    /// Special categories offered only in the "More expenses" view. They are
    /// not stored in the category store, cannot be edited or deleted, and
    /// always keep their fixed color.
    static let specials: [(name: String, colorHex: String)] = [
        ("Cumulative", "#00BCD4"),     // cyan — value is the sum of sub-expenses
        ("Recurring", "#EC407A"),      // pink — amount is base value × multiplier
    ]

    /// True if this name matches one of the special categories.
    static func isSpecial(_ name: String) -> Bool {
        specials.contains { $0.name == name }
    }
}

// MARK: - Menu icon rendering

extension UIImage {
    /// Renders a small circle as a UIImage. Context menus (UIKit) strip
    /// SwiftUI color styling, so colored menu icons must be real images.
    static func categoryDot(color: Color, filled: Bool) -> UIImage {
        let diameter: CGFloat = 18
        let inset: CGFloat = 1.5
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter), format: format)
            .image { _ in
                let rect = CGRect(x: 0, y: 0, width: diameter, height: diameter)
                    .insetBy(dx: inset, dy: inset)
                let path = UIBezierPath(ovalIn: rect)
                if filled {
                    UIColor(color).setFill()
                    path.fill()
                } else {
                    UIColor(color).setStroke()
                    path.lineWidth = 1.5
                    path.stroke()
                }
            }
    }
}

// MARK: - Hex color helpers

extension Color {
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespaces)
        if hex.hasPrefix("#") { hex.removeFirst() }

        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)

        let red, green, blue: Double
        switch hex.count {
        case 6:
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
        default:
            red = 1; green = 1; blue = 1
        }
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    var hexString: String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X",
                      Int(round(red * 255)),
                      Int(round(green * 255)),
                      Int(round(blue * 255)))
    }
}

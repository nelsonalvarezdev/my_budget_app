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

    /// Ensures the built-in default categories exist; a missing one is
    /// re-created. Called at every launch.
    static func ensureDefaultsExist(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ExpenseCategory>())) ?? []
        let existingNames = Set(existing.map(\.name))
        for (name, colorHex) in defaults where !existingNames.contains(name) {
            context.insert(ExpenseCategory(name: name, colorHex: colorHex))
        }
    }

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

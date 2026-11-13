import Foundation

/// App-wide currency helpers. The app operates in Colombian pesos,
/// displayed with a plain "$" prefix (no currency code).
enum Currency {
    /// Locale used for grouping (1.500.000 style thousands separators).
    private static let pesoLocale = Locale(identifier: "es_CO")

    /// Formats a Decimal amount as pesos, e.g. "$ 1.500.000".
    static func format(_ amount: Decimal) -> String {
        let number = amount.formatted(
            .number
                .locale(pesoLocale)
                .precision(.fractionLength(0...2))
        )
        return "$ \(number)"
    }

    /// Formats an amount for editing: plain digits, no grouping or symbol.
    static func formatForEditing(_ amount: Decimal) -> String {
        amount == 0 ? "" : amount.formatted(.number.grouping(.never))
    }

    /// True if the string is a plain, unformatted amount (digits with an
    /// optional decimal separator) — i.e. what the user types while editing,
    /// as opposed to the formatted display string ("$ 1.500.000").
    static func isPlainAmount(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy { $0.isNumber || $0 == "." || $0 == "," }
    }
}

import Foundation
import SwiftData

@Model
final class FixedExpense {
    var name: String
    /// Always stored as a positive value.
    var amount: Decimal
    /// Whether this expense has been "paid" (checked) for the current month.
    var isChecked: Bool
    /// True when this row is a monthly income instead of an expense.
    /// Defaults to false so existing rows survive the schema change
    /// (lightweight migration adds the column for older stores).
    var isIncome: Bool = false
    /// Optional category used to group and color the list.
    var category: ExpenseCategory?

    init(name: String, amount: Decimal, isChecked: Bool = false, isIncome: Bool = false, category: ExpenseCategory? = nil) {
        self.name = name
        self.amount = amount
        self.isChecked = isChecked
        self.isIncome = isIncome
        self.category = category
    }
}

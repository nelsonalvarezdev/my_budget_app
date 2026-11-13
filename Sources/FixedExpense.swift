import Foundation
import SwiftData

@Model
final class FixedExpense {
    var name: String
    /// Always stored as a positive value.
    var amount: Decimal
    /// Whether this expense has been "paid" (checked) for the current month.
    var isChecked: Bool
    /// Optional category used to group and color the list.
    var category: ExpenseCategory?

    init(name: String, amount: Decimal, isChecked: Bool = false, category: ExpenseCategory? = nil) {
        self.name = name
        self.amount = amount
        self.isChecked = isChecked
        self.category = category
    }
}

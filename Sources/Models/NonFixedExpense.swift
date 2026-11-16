import Foundation
import SwiftData

@Model
final class NonFixedExpense {
    var name: String
    /// Always stored as a positive value. For cumulative expenses this is
    /// recomputed as the sum of their sub-expenses.
    var amount: Decimal
    /// True for expenses created with the special Cumulative category:
    /// their value is the sum of sub-expenses and cannot be edited directly.
    /// Defaults to false so existing rows survive the schema change.
    var isCumulative: Bool = false
    /// Sub-expense values that add up to `amount` (only used when
    /// `isCumulative` is true).
    var subExpenses: [SubExpense] = []
    /// True for expenses created with the special Recurring category: the
    /// amount is the base value (set once at creation) times a multiplier
    /// the user grows with a +/− stepper on the row.
    var isRecurring: Bool = false
    /// The per-period amount set once at creation (only used when
    /// `isRecurring` is true). Editable afterwards via a modal.
    var baseAmount: Decimal = 0
    /// Multiplier applied to `baseAmount`; starts at 1 and is changed with
    /// the row's +/− stepper. `amount` always equals baseAmount × multiplier.
    var multiplier: Int = 1
    /// True when this row is an income instead of an expense: its amount is
    /// added to the balance on the Transactions view instead of subtracted.
    /// Defaults to false so existing rows survive the schema change.
    var isIncome: Bool = false

    init(name: String, amount: Decimal, isCumulative: Bool = false, isRecurring: Bool = false, isIncome: Bool = false) {
        self.name = name
        self.amount = amount
        self.isCumulative = isCumulative
        self.isRecurring = isRecurring
        self.isIncome = isIncome
        if isRecurring {
            self.baseAmount = amount
        }
    }
}

/// A single value inside a cumulative expense. No name or category: just an
/// amount that adds up to the parent expense's total.
@Model
final class SubExpense {
    var value: Decimal

    init(value: Decimal) {
        self.value = value
    }
}

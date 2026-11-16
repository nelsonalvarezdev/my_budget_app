import Foundation
import SwiftData

/// Rules for the extra entries of the Expenses view ("More expenses").
/// Every change to an entry's amount moves the Balance; Cash and Savings are
/// never touched.
extension NonFixedExpense {
    /// Cumulative or Recurring entries (listed first, with a fixed color).
    var isSpecial: Bool { isCumulative || isRecurring }

    // MARK: Cumulative — amount = sum of sub-values

    func recalculateCumulativeTotal() {
        amount = subExpenses.reduce(0) { $0 + $1.value }
    }

    /// Adds a sub-value (zero is ignored) and updates the total.
    func addSubValue(_ value: Decimal) {
        guard value != 0 else { return }
        subExpenses.append(SubExpense(value: value))
        recalculateCumulativeTotal()
    }

    /// Removes sub-values, deleting them from the store, and updates the total.
    func removeSubValues(_ removed: [SubExpense], in context: ModelContext) {
        subExpenses.removeAll { candidate in removed.contains { $0 === candidate } }
        for subExpense in removed {
            context.delete(subExpense)
        }
        recalculateCumulativeTotal()
    }

    // MARK: Recurring — amount = base amount × multiplier (minimum 1)

    func stepMultiplier(by step: Int) {
        let updated = multiplier + step
        guard updated >= 1 else { return }
        multiplier = updated
        amount = baseAmount * Decimal(multiplier)
    }

    func setBaseAmount(_ base: Decimal) {
        baseAmount = base
        amount = baseAmount * Decimal(multiplier)
    }

    // MARK: Deletion

    /// Deletes the entry together with its sub-values, so none is left
    /// orphaned in the store.
    func delete(from context: ModelContext) {
        for subExpense in subExpenses {
            context.delete(subExpense)
        }
        subExpenses = []
        context.delete(self)
    }
}

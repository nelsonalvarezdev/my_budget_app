import Foundation
import SwiftData

/// Rules for the extra entries of the Expenses view ("More expenses").
/// Every change to an entry's amount moves the Balance; Cash and Savings are
/// never touched.
extension NonFixedExpense {
    /// Cumulative or Recurring entries (listed first, with a fixed color).
    var isSpecial: Bool { isCumulative || isRecurring || isBudget }

    // MARK: Cumulative — amount = sum of sub-values

    func recalculateCumulativeTotal() {
        let total = subExpenses.reduce(0) { $0 + $1.value }
        // A budget's sub-values are its spends: the amount is what is left.
        amount = isBudget ? max(budgetAmount - total, 0) : total
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

    // MARK: Budget — amount = budget − spends, never below zero

    /// Sum of the spends recorded against the budget.
    var budgetSpent: Decimal { subExpenses.reduce(0) { $0 + $1.value } }
    /// How far the spends went past the budget (0 when within it).
    var budgetOverspend: Decimal { max(budgetSpent - budgetAmount, 0) }
    /// Spent share of the budget, from 0 to 1.
    var budgetSpentFraction: Double {
        guard budgetAmount > 0 else { return 0 }
        return min(max(NSDecimalNumber(decimal: budgetSpent / budgetAmount).doubleValue, 0), 1)
    }

    /// Changes the amount set aside; the spends are kept.
    func setBudgetAmount(_ value: Decimal) {
        budgetAmount = max(value, 0)
        recalculateCumulativeTotal()
    }

    /// Records a spend against the budget (only positive values).
    func addSpend(_ value: Decimal, label: String = "") {
        guard value > 0 else { return }
        subExpenses.append(SubExpense(value: value, label: label))
        recalculateCumulativeTotal()
    }

    /// True for a cumulative entry used as a budget the old way: positive
    /// values set aside and negative values spent.
    var canConvertToBudget: Bool {
        isCumulative
            && subExpenses.contains { $0.value < 0 }
            && subExpenses.contains { $0.value > 0 }
    }

    /// Turns such an entry into a budget: the positive values become the
    /// budget amount and each negative value becomes a spend. What is left
    /// stays the same unless the spends already exceeded the budget.
    func convertToBudget(in context: ModelContext) {
        guard canConvertToBudget else { return }
        let positives = subExpenses.filter { $0.value > 0 }
        budgetAmount = positives.reduce(0) { $0 + $1.value }
        subExpenses.removeAll { candidate in positives.contains { $0 === candidate } }
        for positive in positives { context.delete(positive) }
        for spend in subExpenses { spend.value = -spend.value }
        isCumulative = false
        isBudget = true
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

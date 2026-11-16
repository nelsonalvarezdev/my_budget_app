import Foundation
import Observation
import SwiftData

/// State and actions of the Expenses view ("More expenses"): extra expenses
/// and incomes that adjust the Balance without touching Cash or Savings.
@MainActor
@Observable
final class ExpensesViewModel {
    var isShowingAddSheet = false

    func sections(_ entries: [NonFixedExpense]) -> ExtraEntrySections {
        ExtraEntrySections(entries: entries)
    }

    /// Deletes an entry together with its sub-values.
    func delete(_ entry: NonFixedExpense, context: ModelContext) {
        entry.delete(from: context)
    }
}

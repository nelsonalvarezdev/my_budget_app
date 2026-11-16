import Foundation
import SwiftData
@testable import BudgetApp

/// In-memory store with the app's full schema.
@MainActor
func makeTestContext() throws -> ModelContext {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Transaction.self, FixedExpense.self, NonFixedExpense.self, SubExpense.self, ExpenseCategory.self,
        configurations: configuration
    )
    return ModelContext(container)
}

/// AccountsStore backed by a private UserDefaults domain, so the app's real
/// settings are never touched.
@MainActor
func makeTestAccounts(cash: String = "", savings: String = "", monthlyIncome: String = "") -> AccountsStore {
    let name = "BudgetAppTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    let store = AccountsStore(defaults: defaults)
    store.cashText = cash
    store.savingsText = savings
    store.monthlyIncomeText = monthlyIncome
    return store
}

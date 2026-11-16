import SwiftUI
import SwiftData

@main
struct BudgetAppApp: App {
    /// Cash, Savings and Monthly income, shared by every view.
    @State private var accounts = AccountsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .environment(accounts)
        .modelContainer(for: [Transaction.self, FixedExpense.self, NonFixedExpense.self, SubExpense.self, ExpenseCategory.self])
    }
}

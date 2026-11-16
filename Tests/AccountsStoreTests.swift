import Foundation
import Testing
@testable import BudgetApp

@MainActor
struct AccountsStoreTests {
    /// A private UserDefaults domain per test, so the app's real settings
    /// are never touched.
    private func makeDefaults() -> UserDefaults {
        let name = "AccountsStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func startsEmptyAndReadsAsZero() {
        let store = makeTestAccounts()
        #expect(store.cash == 0)
        #expect(store.savings == 0)
        #expect(store.monthlyIncome == 0)
    }

    @Test func persistsUnderTheOriginalKeys() {
        let defaults = makeDefaults()
        let store = AccountsStore(defaults: defaults)

        store.cashText = "1000"
        store.savingsText = "2000"
        store.monthlyIncomeText = "3000"

        #expect(defaults.string(forKey: "cashBalance") == "1000")
        #expect(defaults.string(forKey: "savingsBalance") == "2000")
        #expect(defaults.string(forKey: "monthlyIncome") == "3000")

        let reloaded = AccountsStore(defaults: defaults)
        #expect(reloaded.cash == 1_000)
        #expect(reloaded.savings == 2_000)
        #expect(reloaded.monthlyIncome == 3_000)
    }

    @Test func creatingTransactionsMovesTheRightField() {
        let store = makeTestAccounts()
        store.cashText = "1000"
        store.savingsText = "2000"

        store.apply(TransactionRules.accountEffect(amount: 300, kind: .expense, paidWith: .cash))
        #expect(store.cash == 700)
        #expect(store.savings == 2_000)

        store.apply(TransactionRules.accountEffect(amount: 500, kind: .expense, paidWith: .savings))
        #expect(store.cash == 700)
        #expect(store.savings == 1_500)

        store.apply(TransactionRules.accountEffect(amount: 999, kind: .expense, paidWith: .creditCard))
        #expect(store.cash == 700)
        #expect(store.savings == 1_500)

        store.apply(TransactionRules.accountEffect(amount: 50, kind: .income, paidWith: .cash))
        #expect(store.cash == 750)
    }

    @Test func cashCanGoNegative() {
        let store = makeTestAccounts()
        store.cashText = "100"
        store.apply(AccountDelta(cash: -250))
        #expect(store.cash == -150)
    }
}

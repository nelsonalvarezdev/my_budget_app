import Foundation
import Testing
@testable import BudgetApp

@MainActor
struct BalanceRulesTests {
    @Test func availableToSpendIsCashPlusSavings() {
        #expect(BalanceRules.availableToSpend(cash: 300, savings: 700) == 1_000)
    }

    @Test func balanceWithoutExtraEntriesIsCashPlusSavings() {
        #expect(BalanceRules.balance(cash: 300, savings: 700, extraEntries: []) == 1_000)
    }

    @Test func extraExpensesSubtractAndExtraIncomesAdd() {
        let entries = [
            NonFixedExpense(name: "Dinner", amount: 120),
            NonFixedExpense(name: "Taxi", amount: 80),
            NonFixedExpense(name: "Refund", amount: 50, isIncome: true),
        ]
        // 1000 − (120 + 80) + 50
        #expect(BalanceRules.balance(cash: 300, savings: 700, extraEntries: entries) == 850)
    }

    @Test func negativeExtraExpenseActsAsCredit() {
        let entries = [NonFixedExpense(name: "Credit", amount: -200)]
        #expect(BalanceRules.balance(cash: 1_000, savings: 0, extraEntries: entries) == 1_200)
    }

    @Test func balanceCanGoNegative() {
        let entries = [NonFixedExpense(name: "Big", amount: 500)]
        #expect(BalanceRules.balance(cash: 100, savings: 0, extraEntries: entries) == -400)
    }
}

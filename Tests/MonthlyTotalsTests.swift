import Foundation
import Testing
@testable import BudgetApp

@MainActor
struct MonthlyTotalsTests {
    private let items = [
        FixedExpense(name: "Rent", amount: 1_000, isChecked: true),
        FixedExpense(name: "Internet", amount: 200, isChecked: false),
        FixedExpense(name: "Side job", amount: 300, isChecked: true, isIncome: true),
        FixedExpense(name: "Bonus", amount: 100, isChecked: false, isIncome: true),
    ]

    @Test func monthlyExpensesIsCheckedExpensesMinusCheckedIncomes() {
        let totals = MonthlyTotals(items: items, monthlyIncome: 5_000)
        #expect(totals.checkedNet == 700)        // 1000 − 300
        #expect(totals.remaining == 4_300)       // 5000 − 700
    }

    @Test func estimatesCountEveryItemRegardlessOfCheckedState() {
        let totals = MonthlyTotals(items: items, monthlyIncome: 5_000)
        #expect(totals.estimatedNet == 800)          // (1000 + 200) − (300 + 100)
        #expect(totals.estimatedRemaining == 4_200)  // 5000 − 800
    }

    @Test func nothingCheckedLeavesTheWholeIncome() {
        let unchecked = [FixedExpense(name: "Rent", amount: 1_000)]
        let totals = MonthlyTotals(items: unchecked, monthlyIncome: 5_000)
        #expect(totals.checkedNet == 0)
        #expect(totals.remaining == 5_000)
    }

    @Test func barFractionsAreSharesOfTheMonthlyIncome() {
        let items = [
            FixedExpense(name: "Rent", amount: 1_000, isChecked: true),
            FixedExpense(name: "Phone", amount: 1_500),
        ]
        let totals = MonthlyTotals(items: items, monthlyIncome: 5_000)
        #expect(totals.paidFraction == 0.2)
        #expect(totals.estimatedFraction == 0.5)
    }

    @Test func barFractionsStayBetweenZeroAndOne() {
        let overspent = MonthlyTotals(items: [FixedExpense(name: "Rent", amount: 9_000, isChecked: true)], monthlyIncome: 5_000)
        #expect(overspent.paidFraction == 1)

        let netIncome = MonthlyTotals(items: [FixedExpense(name: "Bonus", amount: 100, isChecked: true, isIncome: true)], monthlyIncome: 5_000)
        #expect(netIncome.paidFraction == 0)

        let noIncome = MonthlyTotals(items: [FixedExpense(name: "Rent", amount: 100, isChecked: true)], monthlyIncome: 0)
        #expect(noIncome.paidFraction == 0)
        #expect(noIncome.estimatedFraction == 0)
    }

    @Test func remainingCanGoNegative() {
        let totals = MonthlyTotals(items: [FixedExpense(name: "Rent", amount: 1_000, isChecked: true)], monthlyIncome: 400)
        #expect(totals.remaining == -600)
    }
}

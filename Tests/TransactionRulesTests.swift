import Foundation
import Testing
@testable import BudgetApp

@MainActor
struct TransactionRulesTests {
    // MARK: Account effect (applied once, when a transaction is created)

    @Test func cashExpenseSubtractsFromCash() {
        let delta = TransactionRules.accountEffect(amount: 50_000, kind: .expense, paidWith: .cash)
        #expect(delta == AccountDelta(cash: -50_000, savings: 0))
    }

    @Test func savingsExpenseSubtractsFromSavings() {
        let delta = TransactionRules.accountEffect(amount: 50_000, kind: .expense, paidWith: .savings)
        #expect(delta == AccountDelta(cash: 0, savings: -50_000))
    }

    @Test func creditCardExpenseMovesNothing() {
        let delta = TransactionRules.accountEffect(amount: 50_000, kind: .expense, paidWith: .creditCard)
        #expect(delta == AccountDelta())
    }

    @Test(arguments: PaymentSource.allCases)
    func incomeAlwaysAddsToCash(paidWith: PaymentSource) {
        let delta = TransactionRules.accountEffect(amount: 70_000, kind: .income, paidWith: paidWith)
        #expect(delta == AccountDelta(cash: 70_000, savings: 0))
    }

    // MARK: Month filtering, totals and grouping

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test func filtersTransactionsToTheDisplayedMonth() {
        let inMonth = Transaction(amount: 10, kind: .expense, category: "A", date: date(2026, 11, 3))
        let otherMonth = Transaction(amount: 20, kind: .expense, category: "A", date: date(2026, 10, 31))
        let otherYear = Transaction(amount: 30, kind: .expense, category: "A", date: date(2025, 11, 3))

        let result = TransactionRules.transactions([inMonth, otherMonth, otherYear], inMonthOf: date(2026, 11, 16))

        #expect(result.count == 1)
        #expect(result.first === inMonth)
    }

    @Test func totalsSplitIncomeAndExpenses() {
        let transactions = [
            Transaction(amount: 100, kind: .income, category: "Salary"),
            Transaction(amount: 30, kind: .expense, category: "Food"),
            Transaction(amount: 20, kind: .expense, category: "Food", paidWith: .creditCard),
        ]
        let totals = TransactionRules.totals(transactions)
        #expect(totals.income == 100)
        #expect(totals.expenses == 50)
    }

    @Test func groupsByDayNewestFirst() {
        let morning = Transaction(amount: 1, kind: .expense, category: "A", date: date(2026, 11, 5, hour: 8))
        let evening = Transaction(amount: 2, kind: .expense, category: "A", date: date(2026, 11, 5, hour: 20))
        let later = Transaction(amount: 3, kind: .expense, category: "A", date: date(2026, 11, 9))

        let groups = TransactionRules.dayGroups([morning, later, evening])

        #expect(groups.count == 2)
        #expect(groups[0].transactions.count == 1)
        #expect(groups[0].transactions[0] === later)
        #expect(groups[1].transactions[0] === evening)
        #expect(groups[1].transactions[1] === morning)
    }

    @Test func dayNetIsIncomeMinusExpenses() {
        let day = date(2026, 11, 5)
        let groups = TransactionRules.dayGroups([
            Transaction(amount: 250, kind: .income, category: "A", date: day),
            Transaction(amount: 120, kind: .expense, category: "A", date: day),
        ])
        #expect(groups[0].net == 130)
    }

    @Test func categoryTotalsAreSortedLargestFirstPerKind() {
        let transactions = [
            Transaction(amount: 10, kind: .expense, category: "Food"),
            Transaction(amount: 15, kind: .expense, category: "Food"),
            Transaction(amount: 90, kind: .expense, category: "Housing"),
            Transaction(amount: 500, kind: .income, category: "Salary"),
        ]
        #expect(TransactionRules.totalsByCategory(transactions, kind: .expense) == [
            CategoryTotal(category: "Housing", total: 90),
            CategoryTotal(category: "Food", total: 25),
        ])
        #expect(TransactionRules.totalsByCategory(transactions, kind: .income) == [
            CategoryTotal(category: "Salary", total: 500),
        ])
    }
}

import Foundation

/// Rules for the Balance shown on the Transactions view.
enum BalanceRules {
    /// Cash + Savings: the real money available to spend.
    static func availableToSpend(cash: Decimal, savings: Decimal) -> Decimal {
        cash + savings
    }

    /// Totals of the extra entries (Expenses view), split by type.
    static func extraTotals(_ entries: [NonFixedExpense]) -> (expenses: Decimal, incomes: Decimal) {
        let expenses = entries.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        let incomes = entries.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        return (expenses, incomes)
    }

    /// Balance = (Cash + Savings) − extra expenses + extra incomes.
    /// It is global: it does not depend on the displayed month, and
    /// transactions do not feed it (they move Cash / Savings instead).
    static func balance(cash: Decimal, savings: Decimal, extraEntries: [NonFixedExpense]) -> Decimal {
        let extras = extraTotals(extraEntries)
        return availableToSpend(cash: cash, savings: savings) - extras.expenses + extras.incomes
    }
}

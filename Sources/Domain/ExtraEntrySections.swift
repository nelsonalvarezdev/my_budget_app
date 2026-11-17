import Foundation

/// How a new Expenses-view entry computes its amount.
enum ExtraEntryMode {
    /// Amount is whatever is typed (may be negative).
    case plain
    /// Amount is the sum of sub-values.
    case cumulative
    /// Amount is a base amount × a multiplier.
    case recurring
    /// Amount is what is left of a budget after its spends.
    case budget
}

extension NonFixedExpense {
    /// Creates an Expenses-view entry.
    /// - plain: `value` is the amount.
    /// - cumulative: `value` is an optional initial sub-value (0 = none).
    /// - recurring: `value` is the base amount; the multiplier starts at 1.
    static func make(name: String, isIncome: Bool, mode: ExtraEntryMode, value: Decimal) -> NonFixedExpense {
        switch mode {
        case .plain:
            return NonFixedExpense(name: name, amount: value, isIncome: isIncome)
        case .cumulative:
            let entry = NonFixedExpense(name: name, amount: value, isCumulative: true, isIncome: isIncome)
            if value != 0 {
                entry.subExpenses.append(SubExpense(value: value))
            }
            return entry
        case .recurring:
            return NonFixedExpense(name: name, amount: value, isRecurring: true, isIncome: isIncome)
        case .budget:
            return NonFixedExpense(name: name, amount: max(value, 0), isIncome: isIncome, isBudget: true)
        }
    }
}

/// The Expenses view's entries split into its sections: expenses first, then
/// incomes; within each, special (Cumulative / Recurring) entries come first.
struct ExtraEntrySections {
    let specialExpenses: [NonFixedExpense]
    let plainExpenses: [NonFixedExpense]
    let specialIncomes: [NonFixedExpense]
    let plainIncomes: [NonFixedExpense]
    /// Subtracted from the Balance.
    let expensesTotal: Decimal
    /// Added to the Balance.
    let incomesTotal: Decimal

    /// What the entries do to the Balance: incomes − expenses.
    var netEffect: Decimal { incomesTotal - expensesTotal }

    var hasIncomes: Bool { !specialIncomes.isEmpty || !plainIncomes.isEmpty }

    init(entries: [NonFixedExpense]) {
        let expenses = entries.filter { !$0.isIncome }
        let incomes = entries.filter(\.isIncome)
        specialExpenses = expenses.filter(\.isSpecial)
        plainExpenses = expenses.filter { !$0.isSpecial }
        specialIncomes = incomes.filter(\.isSpecial)
        plainIncomes = incomes.filter { !$0.isSpecial }
        let totals = BalanceRules.extraTotals(entries)
        expensesTotal = totals.expenses
        incomesTotal = totals.incomes
    }
}

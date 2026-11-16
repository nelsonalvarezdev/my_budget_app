import Foundation

/// Figures of the Monthly view, computed from its items (fixed expenses and
/// fixed incomes) and the monthly income. The Monthly plan is self-contained:
/// none of this touches Cash, Savings or the Balance.
struct MonthlyTotals: Equatable {
    /// "Monthly expenses": checked expenses − checked incomes.
    let checkedNet: Decimal
    /// Estimated monthly expenses: every expense − every income, regardless
    /// of checked state.
    let estimatedNet: Decimal
    /// "Remaining": monthly income − checkedNet.
    let remaining: Decimal
    /// Estimated remaining: monthly income − estimatedNet.
    let estimatedRemaining: Decimal

    init(items: [FixedExpense], monthlyIncome: Decimal) {
        func net(_ items: [FixedExpense]) -> Decimal {
            items.reduce(0) { $0 + ($1.isIncome ? -$1.amount : $1.amount) }
        }
        checkedNet = net(items.filter(\.isChecked))
        estimatedNet = net(items)
        remaining = monthlyIncome - checkedNet
        estimatedRemaining = monthlyIncome - estimatedNet
    }
}

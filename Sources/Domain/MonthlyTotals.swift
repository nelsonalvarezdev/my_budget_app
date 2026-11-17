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
    let monthlyIncome: Decimal

    /// Share of the monthly income already paid (checked), from 0 to 1.
    var paidFraction: Double { Self.fraction(checkedNet, of: monthlyIncome) }
    /// Share of the monthly income that will be paid once every item is
    /// checked, from 0 to 1.
    var estimatedFraction: Double { Self.fraction(estimatedNet, of: monthlyIncome) }

    private static func fraction(_ part: Decimal, of whole: Decimal) -> Double {
        guard whole > 0 else { return 0 }
        let ratio = NSDecimalNumber(decimal: part / whole).doubleValue
        return min(max(ratio, 0), 1)
    }

    init(items: [FixedExpense], monthlyIncome: Decimal) {
        func net(_ items: [FixedExpense]) -> Decimal {
            items.reduce(0) { $0 + ($1.isIncome ? -$1.amount : $1.amount) }
        }
        self.monthlyIncome = monthlyIncome
        checkedNet = net(items.filter(\.isChecked))
        estimatedNet = net(items)
        remaining = monthlyIncome - checkedNet
        estimatedRemaining = monthlyIncome - estimatedNet
    }
}

import Foundation
import Observation

/// Expenses of the Monthly view that share a category (or none).
struct MonthlyCategoryGroup: Identifiable {
    /// Category name; empty for the uncategorized group.
    let key: String
    var expenses: [FixedExpense]

    var id: String { key }

    var title: String { key.isEmpty ? "No category" : key }
    var checkedCount: Int { expenses.filter(\.isChecked).count }
}

/// Estimated figure shown when the user holds tap on a summary row.
struct EstimatedDetails: Identifiable {
    let title: String
    let amount: Decimal
    var id: String { title }
}

/// State and actions of the Monthly view: a checklist of fixed expenses and
/// fixed incomes measured against the monthly income. Nothing here touches
/// Cash, Savings or the Balance.
@MainActor
@Observable
final class MonthlyViewModel {
    var isShowingAddSheet = false
    var editingItem: FixedExpense?
    var isShowingCategoryManager = false
    /// Set while the user holds tap on a summary row. One per row so each
    /// popover has its own anchor and binding.
    var expensesDetails: EstimatedDetails?
    var remainingDetails: EstimatedDetails?

    // MARK: - Derived data

    func totals(items: [FixedExpense], accounts: AccountsStore) -> MonthlyTotals {
        MonthlyTotals(items: items, monthlyIncome: accounts.monthlyIncome)
    }

    func incomes(_ items: [FixedExpense]) -> [FixedExpense] {
        items.filter(\.isIncome)
    }

    /// Expenses grouped by category, in order of first appearance;
    /// uncategorized expenses go last.
    func groupedExpenses(_ items: [FixedExpense]) -> [MonthlyCategoryGroup] {
        let expenses = items.filter { !$0.isIncome }
        var groups: [MonthlyCategoryGroup] = []
        for expense in expenses {
            guard let category = expense.category else { continue }
            if let index = groups.firstIndex(where: { $0.key == category.name }) {
                groups[index].expenses.append(expense)
            } else {
                groups.append(MonthlyCategoryGroup(key: category.name, expenses: [expense]))
            }
        }
        let uncategorized = expenses.filter { $0.category == nil }
        if !uncategorized.isEmpty {
            groups.append(MonthlyCategoryGroup(key: "", expenses: uncategorized))
        }
        return groups
    }

    // MARK: - Hold-to-peek estimates

    func showEstimatedExpenses(_ totals: MonthlyTotals) {
        expensesDetails = EstimatedDetails(title: "Estimated monthly expenses", amount: totals.estimatedNet)
    }

    func showEstimatedRemaining(_ totals: MonthlyTotals) {
        remainingDetails = EstimatedDetails(title: "Estimated monthly remains", amount: totals.estimatedRemaining)
    }

    // MARK: - Actions

    /// True when at least one item is checked, whatever the amounts add up to.
    func canUncheckAll(_ items: [FixedExpense]) -> Bool {
        items.contains(where: \.isChecked)
    }

    /// Manual start-of-month reset: nothing is unchecked automatically.
    func uncheckAll(_ items: [FixedExpense]) {
        for item in items where item.isChecked {
            item.isChecked = false
        }
    }

    func delete(_ item: FixedExpense) {
        item.modelContext?.delete(item)
    }
}

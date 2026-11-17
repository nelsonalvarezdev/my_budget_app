import Foundation
import Observation
import SwiftData

/// Form state and rules of the "New Transaction" sheet.
@MainActor
@Observable
final class AddTransactionViewModel {
    /// Sentinel category meaning "no category", offered as the first option
    /// for expenses and used when a picked Monthly item has none.
    static let noCategory = "None"

    var kind: TransactionKind = .expense
    var name = ""
    var amountText = ""
    var category = AddTransactionViewModel.noCategory
    var note = ""
    var date: Date = .now
    var paidWith: PaymentSource = .cash
    /// What the transaction pays for, picked in the "Pays for" field: either
    /// a Monthly item or a budget, never both. See `payFor(monthlyItem:)`
    /// and `payFor(budget:)`.
    private(set) var selectedMonthlyItem: FixedExpense?
    private(set) var selectedBudget: NonFixedExpense?

    /// Title of the current "Pays for" choice.
    var paysForTitle: String {
        selectedMonthlyItem?.name ?? selectedBudget?.name ?? "None"
    }

    /// Monthly expenses in the order the "Pays for" list shows them: those
    /// still to pay first, the ones already checked at the end. Monthly
    /// incomes are left out: a transaction does not pay for an income.
    func paysForOrder(_ items: [FixedExpense]) -> [FixedExpense] {
        let expenses = items.filter { !$0.isIncome }
        return expenses.filter { !$0.isChecked } + expenses.filter(\.isChecked)
    }

    /// Pays a Monthly item: prefills name, amount and category (the user can
    /// still adjust them). An item with no category maps to "None".
    func payFor(monthlyItem item: FixedExpense, storedCategories: [ExpenseCategory]) {
        selectedMonthlyItem = item
        selectedBudget = nil
        name = item.name
        amountText = Currency.formatForEditing(item.amount)
        let categoryName = item.category?.name ?? Self.noCategory
        category = categoryOptions(storedCategories: storedCategories).contains(categoryName) ? categoryName : Self.noCategory
    }

    /// Spends from a budget: prefills the name; the amount is typed.
    func payFor(budget: NonFixedExpense) {
        selectedBudget = budget
        selectedMonthlyItem = nil
        name = budget.name
    }

    func payForNothing() {
        selectedMonthlyItem = nil
        selectedBudget = nil
    }

    /// Category options for the current kind. Expenses use the shared
    /// ExpenseCategory list (same as the Monthly view); incomes keep their
    /// own fixed list.
    func categoryOptions(storedCategories: [ExpenseCategory]) -> [String] {
        if kind == .expense {
            let stored = storedCategories.map(\.name)
            return [Self.noCategory] + (stored.isEmpty ? Transaction.expenseCategories : stored)
        }
        return Transaction.incomeCategories
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var amount: Decimal? {
        Currency.parseAmount(amountText)
    }

    /// A name and an amount greater than zero are required.
    var isInputValid: Bool {
        !trimmedName.isEmpty && (amount ?? 0) > 0
    }

    /// Switching type resets the category so it stays valid.
    func resetCategory(storedCategories: [ExpenseCategory]) {
        category = categoryOptions(storedCategories: storedCategories)[0]
    }

    /// Creates the transaction. Returns false when the input is invalid.
    /// Side effects, applied once:
    /// - Cash / Savings move according to `TransactionRules.accountEffect`.
    /// - A Monthly item picked in the form becomes checked ("paid"), even if
    ///   the amount was edited after picking it.
    /// - An expense taken from a budget is recorded as a spend in it, so the
    ///   budget's reserve shrinks by the same amount.
    @discardableResult
    func save(context: ModelContext, accounts: AccountsStore) -> Bool {
        guard let amount, amount > 0, !trimmedName.isEmpty else { return false }
        context.insert(Transaction(name: trimmedName, amount: amount, kind: kind, category: category, note: note, date: date, paidWith: paidWith))
        accounts.apply(TransactionRules.accountEffect(amount: amount, kind: kind, paidWith: paidWith))
        selectedMonthlyItem?.isChecked = true
        if kind == .expense {
            selectedBudget?.addSpend(amount, label: trimmedName)
        }
        return true
    }
}

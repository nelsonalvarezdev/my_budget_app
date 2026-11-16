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
    /// Monthly item picked in the "Fixed expense" picker to prefill the
    /// form. The picker lists every Monthly item (expenses and incomes).
    var selectedMonthlyItem: FixedExpense?

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

    /// Picking a Monthly item prefills name, amount and category; the user
    /// can still adjust them. An item with no category maps to "None".
    func prefillFromSelectedMonthlyItem(storedCategories: [ExpenseCategory]) {
        guard let item = selectedMonthlyItem else { return }
        name = item.name
        amountText = Currency.formatForEditing(item.amount)
        let categoryName = item.category?.name ?? Self.noCategory
        category = categoryOptions(storedCategories: storedCategories).contains(categoryName) ? categoryName : Self.noCategory
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
    @discardableResult
    func save(context: ModelContext, accounts: AccountsStore) -> Bool {
        guard let amount, amount > 0, !trimmedName.isEmpty else { return false }
        context.insert(Transaction(name: trimmedName, amount: amount, kind: kind, category: category, note: note, date: date, paidWith: paidWith))
        accounts.apply(TransactionRules.accountEffect(amount: amount, kind: kind, paidWith: paidWith))
        selectedMonthlyItem?.isChecked = true
        return true
    }
}

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// All fixed expenses from the Monthly view, offered in the
    /// "Fixed expense" picker to prefill the form.
    @Query private var fixedExpenses: [FixedExpense]

    /// Expense categories from the same store the Monthly view uses, so both
    /// views always show the same list.
    @Query private var expenseCategories: [ExpenseCategory]

    /// Sentinel category meaning "no category", offered as the first option
    /// for expenses and used when a picked fixed expense has none.
    private static let noCategory = "None"

    @State private var kind: TransactionKind = .expense
    @State private var name = ""
    @State private var amountText = ""
    @State private var category = Self.noCategory
    @State private var note = ""
    @State private var date: Date = .now
    @State private var paidWith: PaymentSource = .cash
    @State private var selectedFixedExpense: FixedExpense?

    /// Category options for the current kind. Expenses use the shared
    /// ExpenseCategory store (same list as the Monthly view); incomes keep
    /// their own fixed list.
    private var categoryOptions: [String] {
        if kind == .expense {
            let stored = expenseCategories.map(\.name)
            return [Self.noCategory] + (stored.isEmpty ? Transaction.expenseCategories : stored)
        }
        return Transaction.incomeCategories
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) {
                    ForEach(TransactionKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                if kind == .expense {
                    Picker("Fixed expense", selection: $selectedFixedExpense) {
                        Text("None").tag(nil as FixedExpense?)
                        ForEach(fixedExpenses) { expense in
                            Text(expense.name).tag(Optional(expense))
                        }
                    }
                    .onChange(of: selectedFixedExpense) { _, newValue in
                        guard let fixedExpense = newValue else { return }
                        // Pre-fill name, amount and category from the fixed
                        // expense; the user can still adjust them.
                        name = fixedExpense.name
                        amountText = Currency.formatForEditing(fixedExpense.amount)
                        // A fixed expense with no category maps to the
                        // "None" option, not to the first real category.
                        let categoryName = fixedExpense.category?.name ?? Self.noCategory
                        category = categoryOptions.contains(categoryName) ? categoryName : Self.noCategory
                    }
                }

                Section {
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Name")
                } footer: {
                    if kind == .expense && selectedFixedExpense == nil {
                        Text("Required. Pick a fixed expense above to fill it automatically, or type a name.")
                    }
                }

                HStack {
                    Text("Amount")
                    Spacer()
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.title3.monospacedDigit())
                        .frame(width: 160)
                }

                Picker("Category", selection: $category) {
                    ForEach(categoryOptions, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }

                if kind == .expense {
                    Picker("Paid with", selection: $paidWith) {
                        ForEach(PaymentSource.allCases) { source in
                            Text(source.label).tag(source)
                        }
                    }
                }

                TextField("Note (optional)", text: $note)

                DatePicker("Date", selection: $date, displayedComponents: .date)
            }
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isInputValid)
                }
            }
            .onChange(of: kind) { _, _ in
                // Reset the category when switching type so it stays valid.
                category = categoryOptions[0]
            }
        }
    }

    private var isInputValid: Bool {
        !trimmedName.isEmpty && !amountText.isEmpty && (Decimal(string: amountText) ?? 0) > 0
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private func save() {
        guard let amount = Decimal(string: amountText), amount > 0, !trimmedName.isEmpty else { return }
        modelContext.insert(Transaction(name: trimmedName, amount: amount, kind: kind, category: category, note: note, date: date, paidWith: paidWith))
        applyBalanceEffect(amount: amount, kind: kind, paidWith: paidWith)
        // Paying a fixed expense through a transaction marks it as paid
        // (checked) in the Monthly view, even if the amount was edited after
        // picking it.
        selectedFixedExpense?.isChecked = true
        dismiss()
    }

    /// NDEs immediately move the stored balance fields:
    /// - Cash/Savings expenses subtract from their field.
    /// - Credit-card expenses subtract from nothing (deferred payment).
    /// - Income adds to Cash.
    private func applyBalanceEffect(amount: Decimal, kind: TransactionKind, paidWith: PaymentSource) {
        let defaults = UserDefaults.standard
        switch (kind, paidWith) {
        case (.expense, .cash):
            adjustStoredField("cashBalance", by: -amount)
        case (.expense, .savings):
            adjustStoredField("savingsBalance", by: -amount)
        case (.expense, .creditCard):
            break
        case (.income, _):
            adjustStoredField("cashBalance", by: amount)
        }
    }

    private func adjustStoredField(_ key: String, by delta: Decimal) {
        let defaults = UserDefaults.standard
        let current = Decimal(string: defaults.string(forKey: key) ?? "") ?? 0
        let updated = current + delta
        defaults.set(Currency.formatForEditing(updated), forKey: key)
    }
}

#Preview {
    AddTransactionView()
        .modelContainer(for: Transaction.self, inMemory: true)
}

import SwiftUI
import SwiftData

/// Modal for adding a non-fixed expense or income from the "More expenses"
/// view. A segmented control picks the type (same style as the Transactions
/// add modal). Fields: name, value, category. Choosing the special Cumulative
/// category disables the value field — the entry is created at $0 and its
/// total is later built from sub-values. Leaving the category empty creates a
/// plain entry that is edited in place, exactly as before.
struct AddMoreExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var kind: TransactionKind = .expense
    @State private var name = ""
    @State private var valueText = ""
    @State private var initialSubValueText = ""
    @State private var selectedSpecial: String?

    /// True when the Cumulative special category is selected: the value
    /// field is disabled and the entry starts at $0.
    private var isCumulativeSelected: Bool {
        selectedSpecial == "Cumulative"
    }

    /// True when the Recurring special category is selected: the value field
    /// stays enabled and its value is set once, becoming the base amount
    /// that the row's multiplier grows.
    private var isRecurringSelected: Bool {
        selectedSpecial == "Recurring"
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

                Section {
                    TextField(namePlaceholder, text: $name)
                        .autocorrectionDisabled()
                    if isCumulativeSelected {
                        // Optional starting sub-value; defaults to $0.
                        CurrencyField(storedText: $initialSubValueText)
                    } else {
                        CurrencyField(storedText: $valueText)
                    }
                } header: {
                    Text(isCumulativeSelected ? "Initial sub-value" : (kind == .income ? "Incomming" : "Expense"))
                } footer: {
                    if isCumulativeSelected {
                        Text("Optional. The entry starts with this sub-value; every value you add later adds up to it. Leave it empty to start from $0.")
                    } else if isRecurringSelected {
                        Text("This value is the base amount. It is set once; the total grows with the × multiplier on the row.")
                    }
                }

                Section {
                    // No category (default): plain entry, no color.
                    Button {
                        selectedSpecial = nil
                    } label: {
                        HStack {
                            Text("None")
                            Spacer()
                            if selectedSpecial == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    // Special categories, exclusive to this view. Fixed
                    // colors; the user cannot pick or change colors here.
                    ForEach(ExpenseCategory.specials, id: \.name) { special in
                        Button {
                            selectedSpecial = selectedSpecial == special.name ? nil : special.name
                        } label: {
                            HStack {
                                Image(uiImage: .categoryDot(color: Color(hex: special.colorHex), filled: true))
                                Text(special.name)
                                Spacer()
                                if selectedSpecial == special.name {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Category")
                } footer: {
                    if isCumulativeSelected {
                        Text("Tap the entry afterwards to add sub-values that add up to its total.")
                    }
                }
            }
            .navigationTitle(kind == .income ? "New income" : "New expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    /// "Expense name" or "Income name" depending on the selected tab.
    private var namePlaceholder: String {
        kind == .income ? "Income name" : "Expense name"
    }

    private func save() {
        let isIncome = kind == .income
        if isCumulativeSelected {
            // Cumulative: created with the special color and an optional
            // initial sub-value; the total comes from sub-values added
            // later, on top of the initial one.
            let initial = Decimal(string: initialSubValueText.replacingOccurrences(of: ",", with: ".")) ?? 0
            let entry = NonFixedExpense(name: name, amount: initial, isCumulative: true, isIncome: isIncome)
            if initial != 0 {
                entry.subExpenses.append(SubExpense(value: initial))
            }
            modelContext.insert(entry)
        } else if isRecurringSelected {
            // Recurring: the entered value is the base amount, set once;
            // the total grows via the row's multiplier stepper.
            let base = Decimal(string: valueText.replacingOccurrences(of: ",", with: ".")) ?? 0
            modelContext.insert(NonFixedExpense(name: name, amount: base, isRecurring: true, isIncome: isIncome))
        } else {
            let amount = Decimal(string: valueText.replacingOccurrences(of: ",", with: ".")) ?? 0
            modelContext.insert(NonFixedExpense(name: name, amount: amount, isIncome: isIncome))
        }
        dismiss()
    }
}

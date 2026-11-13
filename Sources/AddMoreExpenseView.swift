import SwiftUI
import SwiftData

/// Modal for adding a non-fixed expense from the "More expenses" view.
/// Fields: name, value, category. Choosing the special Cumulative category
/// disables the value field — the expense is created at $0 and its total is
/// later built from sub-expenses. Leaving the category empty creates a plain
/// expense that is edited in place, exactly as before.
struct AddMoreExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var valueText = ""
    @State private var initialSubValueText = ""
    @State private var selectedSpecial: String?

    /// True when the Cumulative special category is selected: the value
    /// field is disabled and the expense starts at $0.
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
                Section {
                    TextField("Expense name", text: $name)
                        .autocorrectionDisabled()
                    if isCumulativeSelected {
                        // Optional starting sub-value; defaults to $0.
                        CurrencyField(storedText: $initialSubValueText)
                    } else {
                        CurrencyField(storedText: $valueText)
                    }
                } header: {
                    Text(isCumulativeSelected ? "Initial sub-value" : "Expense")
                } footer: {
                    if isCumulativeSelected {
                        Text("Optional. The expense starts with this sub-value; every value you add later adds up to it. Leave it empty to start from $0.")
                    } else if isRecurringSelected {
                        Text("This value is the base amount. It is set once; the total grows with the × multiplier on the expense row.")
                    }
                }

                Section {
                    // No category (default): plain expense, no color.
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
                        Text("Tap the expense afterwards to add sub-values that add up to its total.")
                    }
                }
            }
            .navigationTitle("New expense")
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

    private func save() {
        if isCumulativeSelected {
            // Cumulative: created with the special color and an optional
            // initial sub-value; the total comes from sub-expenses added
            // later, on top of the initial one.
            let initial = Decimal(string: initialSubValueText.replacingOccurrences(of: ",", with: ".")) ?? 0
            let expense = NonFixedExpense(name: name, amount: initial, isCumulative: true)
            if initial != 0 {
                expense.subExpenses.append(SubExpense(value: initial))
            }
            modelContext.insert(expense)
        } else if isRecurringSelected {
            // Recurring: the entered value is the base amount, set once;
            // the total grows via the row's multiplier stepper.
            let base = Decimal(string: valueText.replacingOccurrences(of: ",", with: ".")) ?? 0
            modelContext.insert(NonFixedExpense(name: name, amount: base, isRecurring: true))
        } else {
            let amount = Decimal(string: valueText.replacingOccurrences(of: ",", with: ".")) ?? 0
            modelContext.insert(NonFixedExpense(name: name, amount: amount))
        }
        dismiss()
    }
}

import SwiftUI
import SwiftData

/// Detail view for a cumulative expense: a simple list of sub-expense values
/// (no names, no categories) that add up to the expense's total. The parent
/// expense's amount is kept in sync as the sum of all sub-expenses.
struct SubExpensesView: View {
    @Bindable var expense: NonFixedExpense
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var newValueText = ""
    @FocusState private var isNewValueFocused: Bool

    var body: some View {
        List {
            Section {
                if expense.subExpenses.isEmpty {
                    ContentUnavailableView(
                        "No sub-expenses yet",
                        systemImage: "plus.circle.dashed",
                        description: Text("Add a value below; each one adds up to the total.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(expense.subExpenses) { subExpense in
                        SubExpenseRow(subExpense: subExpense, onCommit: expense.recalculateCumulativeTotal)
                    }
                    .onDelete { offsets in
                        expense.removeSubValues(offsets.map { expense.subExpenses[$0] }, in: modelContext)
                    }
                }
            } header: {
                HStack {
                    Text("Sub-expense")
                    Spacer()
                    Text("Value")
                }
                .font(.subheadline.weight(.semibold))
                .textCase(nil)
            } footer: {
                Text("Total: \(Currency.format(expense.amount)). Every value adds up to the expense's total.")
            }

            Section {
                HStack {
                    TextField("New value", text: $newValueText)
                        .keyboardType(.numbersAndPunctuation)
                        .focused($isNewValueFocused)
                        .onSubmit { addSubExpense() }
                        // Tapping outside the field (keyboard dismiss) also
                        // commits the pending value.
                        .onChange(of: isNewValueFocused) { _, focused in
                            if !focused { addSubExpense() }
                        }

                    Button("Add") { addSubExpense() }
                        .disabled(!canAdd)
                }
            } header: {
                Text("Add sub-expense")
            }
        }
        .navigationTitle(expense.name)
        .navigationBarTitleDisplayMode(.inline)
        .dismissKeyboardOnTap()
        .safeAreaInset(edge: .bottom) {
            Button(role: .destructive) {
                expense.delete(from: modelContext)
                dismiss()
            } label: {
                Label("Delete expense", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding()
        }
    }

    /// A sub-value must be a non-zero number.
    private var newValue: Decimal? {
        guard let value = Currency.parseAmount(newValueText), value != 0 else { return nil }
        return value
    }

    private var canAdd: Bool { newValue != nil }

    private func addSubExpense() {
        guard let newValue else { return }
        expense.addSubValue(newValue)
        newValueText = ""
    }
}

/// Editable row for a single sub-expense value: raw digits while editing,
/// formatted pesos when idle. Calls `onCommit` after each change so the
/// parent expense's total stays in sync.
struct SubExpenseRow: View {
    @Bindable var subExpense: SubExpense
    var onCommit: () -> Void

    @State private var valueText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            TextField("0", text: displayBinding)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .focused($isFocused)
                .onSubmit { commit() }
                .onChange(of: valueText) { _, _ in commit() }
        }
        .onAppear { valueText = Currency.formatForEditing(subExpense.value) }
    }

    private var displayBinding: Binding<String> {
        Binding(
            get: {
                isFocused || valueText.isEmpty ? valueText : Currency.format(subExpense.value)
            },
            set: { newValue in
                guard isFocused else { return }
                valueText = newValue
            }
        )
    }

    private func commit() {
        subExpense.value = Currency.parseAmount(valueText) ?? 0
        onCommit()
    }
}

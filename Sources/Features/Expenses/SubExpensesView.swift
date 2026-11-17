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
    @State private var newNameText = ""
    @State private var isConfirmingConversion = false
    @FocusState private var newEntryFocus: NewEntryField?

    private enum NewEntryField { case name, value }

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
                Text("Every value adds up to the total.")
            }

            Section {
                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    Text(Currency.format(expense.amount))
                        .font(.headline.monospacedDigit())
                }
                .accessibilityElement(children: .combine)
            }

            Section {
                TextField("Name (optional)", text: $newNameText)
                    .autocorrectionDisabled()
                    .focused($newEntryFocus, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { newEntryFocus = .value }
                HStack {
                    TextField("New value", text: $newValueText)
                        .keyboardType(.numbersAndPunctuation)
                        .focused($newEntryFocus, equals: .value)
                        .onSubmit { addSubExpense() }
                        // Tapping outside both fields (keyboard dismiss)
                        // also commits the pending value. Moving between
                        // the name and the value does not.
                        .onChange(of: newEntryFocus) { _, focus in
                            if focus == nil { addSubExpense() }
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
        .toolbar {
            if expense.canConvertToBudget {
                ToolbarItem(placement: .primaryAction) {
                    Button("Convert to budget") { isConfirmingConversion = true }
                }
            }
        }
        .confirmationDialog("Convert to budget?", isPresented: $isConfirmingConversion, titleVisibility: .visible) {
            Button("Convert") {
                expense.convertToBudget(in: modelContext)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The positive values become the budget amount and each negative value becomes a spend. What is left stays the same.")
        }
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
        expense.addSubValue(newValue, label: newNameText)
        newValueText = ""
        newNameText = ""
    }
}

/// Editable row for a single sub-expense: its optional name, and its value
/// as raw digits while editing, formatted pesos when idle. Calls `onCommit` after each change so the
/// parent expense's total stays in sync.
struct SubExpenseRow: View {
    @Bindable var subExpense: SubExpense
    var onCommit: () -> Void

    @State private var valueText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            // Optional name; an unnamed value reads "Spend".
            TextField("Spend", text: $subExpense.label)
                .autocorrectionDisabled()
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

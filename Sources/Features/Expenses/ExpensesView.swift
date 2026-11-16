import SwiftUI
import SwiftData

/// Tab for registering extra (non-fixed) expenses and incomes. The list
/// shows expenses first, then Incomming items below. Each row is editable in
/// place (Expense / Amount columns) and has a delete button. Expenses
/// discount from the balance; incomes are added to it.
struct ExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    /// Every entry of this view, expenses and incomes.
    @Query private var entries: [NonFixedExpense]

    @State private var viewModel = ExpensesViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No entries yet",
                        systemImage: "cart",
                        description: Text("Tap + to register a non-fixed expense or income.")
                    )
                } else {
                    entryList(viewModel.sections(entries))
                }
            }
            .navigationTitle("More expenses")
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowingAddSheet) {
                AddMoreExpenseView()
            }
        }
    }

    private func entryList(_ sections: ExtraEntrySections) -> some View {
        List {
            Section {
                // Special-category expenses first (Cumulative, Recurring).
                ForEach(sections.specialExpenses) { expense in
                    specialRow(for: expense)
                }
                ForEach(sections.plainExpenses) { expense in
                    NonFixedExpenseRow(expense: expense)
                }
            } header: {
                HStack {
                    Text("Expense")
                    Spacer()
                    Text("Amount")
                }
                .font(.subheadline.weight(.semibold))
                .textCase(nil)
            } footer: {
                Text("Total: \(Currency.format(sections.expensesTotal)). Positive amounts reduce the Balance; negative amounts are credits that increase it.")
            }

            // Incomming items, listed after the expenses. Special-category
            // incomes behave exactly like their expense counterparts.
            if sections.hasIncomes {
                Section {
                    ForEach(sections.specialIncomes) { income in
                        specialRow(for: income)
                    }
                    ForEach(sections.plainIncomes) { income in
                        NonFixedExpenseRow(expense: income)
                    }
                } header: {
                    HStack {
                        Text("Incomming")
                        Spacer()
                        Text("Amount")
                    }
                    .font(.subheadline.weight(.semibold))
                    .textCase(nil)
                } footer: {
                    Text("Total: \(Currency.format(sections.incomesTotal)). These amounts are added to the Balance on the Transactions view.")
                }
            }
        }
    }

    /// Row for a special-category entry: Cumulative navigates to its
    /// sub-values; Recurring shows the × multiplier stepper. Same styling
    /// for expenses and incomes.
    @ViewBuilder
    private func specialRow(for expense: NonFixedExpense) -> some View {
        if expense.isCumulative {
            NavigationLink {
                SubExpensesView(expense: expense)
            } label: {
                CumulativeExpenseRow(expense: expense)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                deleteButton(for: expense)
            }
            .listRowBackground(Color(hex: "00BCD4").opacity(0.25))
        } else {
            RecurringExpenseRow(expense: expense)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    deleteButton(for: expense)
                }
                .listRowBackground(Color(hex: "EC407A").opacity(0.25))
        }
    }

    private func deleteButton(for expense: NonFixedExpense) -> some View {
        Button(role: .destructive) {
            viewModel.delete(expense, context: modelContext)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Editable row

struct NonFixedExpenseRow: View {
    @Bindable var expense: NonFixedExpense
    @Environment(\.modelContext) private var modelContext

    @State private var amountText: String = ""
    @FocusState private var isAmountFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            TextField("Expense", text: $expense.name)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            Spacer()

            TextField("0", text: displayBinding)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(width: 140)
                .focused($isAmountFocused)
                .onSubmit { commitAmount() }
                .onChange(of: amountText) { _, _ in commitAmount() }

            Button {
                expense.delete(from: modelContext)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .onAppear { amountText = Currency.formatForEditing(expense.amount) }
    }

    /// Raw digits (with optional minus) while editing; formatted pesos when idle.
    private var displayBinding: Binding<String> {
        Binding(
            get: {
                if isAmountFocused || amountText.isEmpty { return amountText }
                return Currency.format(expense.amount)
            },
            set: { newValue in
                // Only accept writes while editing; see CurrencyField for why
                // (unfocused writes of the formatted string or "" zero the amount).
                guard isAmountFocused else { return }
                amountText = newValue
            }
        )
    }

    /// Keeps the model in sync with the text field (accepts negative values).
    private func commitAmount() {
        expense.amount = Currency.parseAmount(amountText) ?? 0
    }
}

// MARK: - Cumulative row

/// Read-only row for a cumulative expense: shows the special category color
/// and the running total of its sub-expenses. Tapping navigates to
/// `SubExpensesView` (handled by the parent's NavigationLink).
struct CumulativeExpenseRow: View {
    @Bindable var expense: NonFixedExpense

    var body: some View {
        HStack(spacing: 12) {
            Text(expense.name)

            Spacer()

            Text(Currency.format(expense.amount))
                .font(.body.monospacedDigit())
                .frame(width: 140)
        }
    }
}

// MARK: - Recurring row

/// Row for a recurring expense: shows the special category color, a
/// −/multiplier/+ stepper (starts at 1) and the amount, which is always
/// baseAmount × multiplier. Tapping the row opens a modal to edit the base
/// amount (the only editable value; the multiplied amount is derived).
struct RecurringExpenseRow: View {
    @Bindable var expense: NonFixedExpense

    @State private var isShowingBaseEditor = false

    var body: some View {
        HStack(spacing: 12) {
            Text(expense.name)

            Spacer()

            // − / multiplier / + stepper. The multiplier starts at 1 and the
            // Amount always reflects base × multiplier.
            HStack(spacing: 10) {
                Button {
                    expense.stepMultiplier(by: -1)
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .disabled(expense.multiplier <= 1)

                Text("\(expense.multiplier)")
                    .font(.body.monospacedDigit())
                    .frame(minWidth: 24)

                Button {
                    expense.stepMultiplier(by: 1)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }

            Text(Currency.format(expense.amount))
                .font(.body.monospacedDigit())
                .frame(width: 140)
        }
        .contentShape(Rectangle())
        .onTapGesture { isShowingBaseEditor = true }
        .sheet(isPresented: $isShowingBaseEditor) {
            EditRecurringBaseView(expense: expense)
        }
    }
}

/// Modal to edit the base amount of a recurring expense. Only the base is
/// editable; the row's amount is recomputed as base × multiplier.
struct EditRecurringBaseView: View {
    @Bindable var expense: NonFixedExpense
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var baseText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CurrencyField(storedText: $baseText)
                } header: {
                    Text("Base amount")
                } footer: {
                    Text("The total is the base amount × the multiplier (\(expense.multiplier)×).")
                }
            }
            .navigationTitle("Edit base amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        expense.setBaseAmount(Currency.parseAmount(baseText) ?? expense.baseAmount)
                        dismiss()
                    }
                }
            }
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
        .onAppear { baseText = Currency.formatForEditing(expense.baseAmount) }
    }
}

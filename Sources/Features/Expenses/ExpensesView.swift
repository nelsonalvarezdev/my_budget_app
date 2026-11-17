import SwiftUI
import SwiftData

/// Tab for registering extra (non-fixed) expenses and incomes. The list
/// opens with the entries' net effect on the Balance, then shows expenses
/// and incomes. Each row is editable in
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
                HeroCard {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Effect on balance")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HeroAmount(amount: Currency.formatSigned(sections.netEffect))
                        Text("Expenses \(Currency.format(sections.expensesTotal)) · Incomes \(Currency.format(sections.incomesTotal))")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                // Special-category expenses first (Cumulative, Recurring).
                ForEach(sections.specialExpenses) { expense in
                    specialRow(for: expense)
                }
                ForEach(sections.plainExpenses) { expense in
                    NonFixedExpenseRow(expense: expense)
                }
            } header: {
                SectionHeader(title: "Expenses", trailing: Currency.format(sections.expensesTotal))
            }

            // Incomes, listed after the expenses. Special-category incomes
            // behave exactly like their expense counterparts.
            if sections.hasIncomes {
                Section {
                    ForEach(sections.specialIncomes) { income in
                        specialRow(for: income)
                    }
                    ForEach(sections.plainIncomes) { income in
                        NonFixedExpenseRow(expense: income)
                    }
                } header: {
                    SectionHeader(title: "Incomes", trailing: Currency.format(sections.incomesTotal))
                }
            }
        }
    }

    /// Row for a special-category entry: Budget and Cumulative navigate to
    /// their values; Recurring shows its base × multiplier. Same styling for
    /// expenses and incomes.
    @ViewBuilder
    private func specialRow(for expense: NonFixedExpense) -> some View {
        if expense.isBudget {
            NavigationLink {
                BudgetDetailView(expense: expense)
            } label: {
                BudgetExpenseRow(expense: expense)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                deleteButton(for: expense)
            }
        } else if expense.isCumulative {
            NavigationLink {
                SubExpensesView(expense: expense)
            } label: {
                CumulativeExpenseRow(expense: expense)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                deleteButton(for: expense)
            }
        } else {
            RecurringExpenseRow(expense: expense)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    deleteButton(for: expense)
                }
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

/// Read-only row for a cumulative entry: its name, how many sub-values it
/// has and their running total. Tapping navigates to `SubExpensesView`
/// (handled by the parent's NavigationLink).
struct CumulativeExpenseRow: View {
    @Bindable var expense: NonFixedExpense

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.name)
                TagPill(text: "Cumulative · " + (expense.subExpenses.count == 1 ? "1 value" : "\(expense.subExpenses.count) values"))
            }

            Spacer()

            EntryAmount(expense: expense)
        }
    }
}

// MARK: - Recurring row

/// Row for a recurring entry: its name, a "base × multiplier" tag and the
/// amount, which is always baseAmount × multiplier. The + button adds one to
/// the multiplier; lowering it is in the leading swipe and the long-press
/// menu. Tapping the row opens a modal to edit the base amount (the only
/// editable value; the multiplied amount is derived).
struct RecurringExpenseRow: View {
    @Bindable var expense: NonFixedExpense
    @Environment(\.modelContext) private var modelContext

    @State private var isShowingBaseEditor = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.name)
                TagPill(text: "Recurring · \(Currency.format(expense.baseAmount)) × \(expense.multiplier)")
            }

            Spacer()

            EntryAmount(expense: expense)

            Button {
                expense.stepMultiplier(by: 1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Add one")
        }
        .contentShape(Rectangle())
        .onTapGesture { isShowingBaseEditor = true }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if expense.multiplier > 1 {
                removeOneButton
                    .tint(.orange)
            }
        }
        .contextMenu {
            Button {
                expense.stepMultiplier(by: 1)
            } label: {
                Label("Add one", systemImage: "plus")
            }
            removeOneButton
                .disabled(expense.multiplier <= 1)
            Button {
                expense.resetMultiplier()
            } label: {
                Label("Reset to 0", systemImage: "arrow.counterclockwise")
            }
            .disabled(expense.multiplier == 0)
            Button {
                isShowingBaseEditor = true
            } label: {
                Label("Edit base amount…", systemImage: "pencil")
            }
            Button(role: .destructive) {
                expense.delete(from: modelContext)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $isShowingBaseEditor) {
            EditRecurringBaseView(expense: expense)
        }
    }

    private var removeOneButton: some View {
        Button {
            expense.stepMultiplier(by: -1)
        } label: {
            Label("Remove one", systemImage: "minus")
        }
    }
}

/// Amount of a special entry: incomes are shown signed, in the accent colour.
private struct EntryAmount: View {
    let expense: NonFixedExpense

    var body: some View {
        Text(expense.isIncome ? Currency.formatSigned(expense.amount) : Currency.format(expense.amount))
            .font(.body.monospacedDigit())
            .foregroundStyle(expense.isIncome ? Color.brand : Color.primary)
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

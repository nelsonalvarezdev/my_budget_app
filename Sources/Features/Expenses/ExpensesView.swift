import SwiftUI
import SwiftData

/// Tab for registering non-fixed (variable) expenses and incomes. The list
/// shows expenses first, then Incomming items below. Each row is editable in
/// place (Expense / Amount columns) and has a delete button. Expenses
/// discount from the balance; incomes are added to it.
struct ExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [NonFixedExpense]

    @State private var isShowingAddSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if expenses.isEmpty {
                    ContentUnavailableView(
                        "No entries yet",
                        systemImage: "cart",
                        description: Text("Tap + to register a non-fixed expense or income.")
                    )
                } else {
                    entryList
                }
            }
            .navigationTitle("More expenses")
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddMoreExpenseView()
            }
            .task { seedMockDataIfNeeded() }
        }
    }

    /// Seeds a one-time mock list of 5 non-fixed expenses on first launch.
    private func seedMockDataIfNeeded() {
        let hasExpenses = (try? modelContext.fetchCount(FetchDescriptor<NonFixedExpense>())) ?? 0 > 0
        guard !hasExpenses else { return }

        // Original USD amounts converted at 1 USD = 3,200 COP.
        let mockExpenses: [(String, Decimal)] = [
            ("Dinner with friends", 120_000),   // $37.50
            ("Movie tickets", 64_000),          // $20
            ("Taxi rides", 96_000),             // $30
            ("Gift for a friend", 160_000),     // $50
            ("Home repair", 320_000),           // $50
        ]
        for (name, amount) in mockExpenses {
            modelContext.insert(NonFixedExpense(name: name, amount: amount))
        }
    }

    private var entryList: some View {
        List {
            Section {
                // Special-category expenses first (Cumulative, Recurring).
                ForEach(specialExpenses) { expense in
                    specialRow(for: expense)
                }
                ForEach(plainExpenses) { expense in
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
                Text("Total: \(Currency.format(expensesTotal)). Positive amounts reduce the Balance; negative amounts are credits that increase it.")
            }

            // Incomming items, listed after the expenses. Special-category
            // incomes behave exactly like their expense counterparts.
            if !incomes.isEmpty {
                Section {
                    ForEach(specialIncomes) { income in
                        specialRow(for: income)
                    }
                    ForEach(plainIncomes) { income in
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
                    Text("Total: \(Currency.format(incomesTotal)). These amounts are added to the Balance on the Transactions view.")
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
                Button(role: .destructive) {
                    deleteExpense(expense)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .listRowBackground(Color(hex: "00BCD4").opacity(0.25))
        } else {
            RecurringExpenseRow(expense: expense)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteExpense(expense)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .listRowBackground(Color(hex: "EC407A").opacity(0.25))
        }
    }

    private var specialExpenses: [NonFixedExpense] {
        expenses.filter { !$0.isIncome && ($0.isCumulative || $0.isRecurring) }
    }

    private var plainExpenses: [NonFixedExpense] {
        expenses.filter { !$0.isIncome && !$0.isCumulative && !$0.isRecurring }
    }

    private var specialIncomes: [NonFixedExpense] {
        incomes.filter { $0.isCumulative || $0.isRecurring }
    }

    private var plainIncomes: [NonFixedExpense] {
        incomes.filter { !$0.isCumulative && !$0.isRecurring }
    }

    private var incomes: [NonFixedExpense] {
        expenses.filter(\.isIncome)
    }

    private var expensesTotal: Decimal {
        expenses.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }

    private var incomesTotal: Decimal {
        incomes.reduce(0) { $0 + $1.amount }
    }

    /// Deletes a special expense. Cumulative expenses own their sub-expenses,
    /// so those are removed first to avoid orphaned rows in the store.
    private func deleteExpense(_ expense: NonFixedExpense) {
        for subExpense in expense.subExpenses {
            modelContext.delete(subExpense)
        }
        expense.subExpenses = []
        modelContext.delete(expense)
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
                modelContext.delete(expense)
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
        expense.amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
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
                    guard expense.multiplier > 1 else { return }
                    expense.multiplier -= 1
                    expense.amount = expense.baseAmount * Decimal(expense.multiplier)
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
                    expense.multiplier += 1
                    expense.amount = expense.baseAmount * Decimal(expense.multiplier)
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
                        expense.baseAmount = Decimal(string: baseText.replacingOccurrences(of: ",", with: ".")) ?? expense.baseAmount
                        expense.amount = expense.baseAmount * Decimal(expense.multiplier)
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(role: .destructive) {
                    modelContext.delete(expense)
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

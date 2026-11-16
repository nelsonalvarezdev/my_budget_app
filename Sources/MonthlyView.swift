import SwiftUI
import SwiftData

struct MonthlyView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("monthlyIncome") private var monthlyIncomeText = ""
    @Query private var fixedExpenses: [FixedExpense]
    @Query private var categories: [ExpenseCategory]

    @State private var isShowingAddSheet = false
    @State private var isShowingAddIncomeSheet = false
    @State private var editingExpense: FixedExpense?
    @State private var isShowingCategoryManager = false
    /// Set while the user holds tap on a summary row; shows the estimated
    /// figure with a brief description in a popover. One per row so each
    /// popover has its own anchor and binding.
    @State private var expensesDetails: EstimatedDetails?
    @State private var remainingDetails: EstimatedDetails?

    private var monthlyIncome: Decimal {
        Decimal(string: monthlyIncomeText) ?? 0
    }

    private var expenses: [FixedExpense] {
        fixedExpenses.filter { !$0.isIncome }
    }

    private var incomes: [FixedExpense] {
        fixedExpenses.filter(\.isIncome)
    }

    /// Net total of checked rows: checked expenses minus checked incomes.
    private var checkedTotal: Decimal {
        let checkedExpenses = expenses.filter(\.isChecked).reduce(0) { $0 + $1.amount }
        let checkedIncomes = incomes.filter(\.isChecked).reduce(0) { $0 + $1.amount }
        return checkedExpenses - checkedIncomes
    }

    /// Net total of every created row, regardless of checked state.
    /// Computed on creation, so it updates as soon as an item is added.
    private var createdNetTotal: Decimal {
        let createdExpenses = expenses.reduce(0) { $0 + $1.amount }
        let createdIncomes = incomes.reduce(0) { $0 + $1.amount }
        return createdExpenses - createdIncomes
    }

    private var remaining: Decimal {
        monthlyIncome - checkedTotal
    }

    /// Remaining if every created item were counted at once, without
    /// waiting for rows to be checked.
    private var onCreationRemaining: Decimal {
        monthlyIncome - createdNetTotal
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Monthly income")
                        Spacer()
                        CurrencyField(storedText: $monthlyIncomeText)
                            .font(.title3.monospacedDigit())
                            .frame(width: 160)
                    }

                    HStack {
                        Text("Monthly expenses")
                        Spacer()
                        Text(Currency.format(checkedTotal))
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .popover(item: $expensesDetails) { details in
                        EstimatedDetailsPopover(details: details)
                    }
                    .onLongPressGesture(minimumDuration: 0.4) {
                        expensesDetails = EstimatedDetails(
                            title: "Estimated monthly expenses",
                            amount: createdNetTotal
                        )
                    } onPressingChanged: { pressing in
                        if !pressing { expensesDetails = nil }
                    }

                    HStack {
                        Text("Remaining")
                            .font(.headline)
                        Spacer()
                        Text(Currency.format(remaining))
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(remaining >= 0 ? Color.green : Color.red)
                    }
                    .popover(item: $remainingDetails) { details in
                        EstimatedDetailsPopover(details: details)
                    }
                    .onLongPressGesture(minimumDuration: 0.4) {
                        remainingDetails = EstimatedDetails(
                            title: "Estimated monthly remains",
                            amount: onCreationRemaining
                        )
                    } onPressingChanged: { pressing in
                        if !pressing { remainingDetails = nil }
                    }
                } header: {
                    Text("Income")
                } footer: {
                    Text("Set your monthly income here (in pesos). Checked rows below are subtracted from it: \(Currency.format(checkedTotal)).")
                }

                Section {
                    ForEach(groupedExpenses, id: \.key) { group in
                        ForEach(group.expenses) { expense in
                            FixedExpenseRow(expense: expense)
                                .listRowBackground(rowBackground(for: expense))
                                .contentShape(Rectangle())
                                .onTapGesture { editingExpense = expense }
                                .contextMenu {
                                    Menu {
                                        Button {
                                            expense.category = nil
                                        } label: {
                                            Label {
                                                Text("None")
                                            } icon: {
                                                Image(uiImage: .categoryDot(color: .secondary, filled: false))
                                            }
                                        }
                                        ForEach(categories) { category in
                                            Button {
                                                expense.category = category
                                            } label: {
                                                Label {
                                                    Text(category.name)
                                                } icon: {
                                                    Image(uiImage: .categoryDot(color: category.color, filled: true))
                                                }
                                            }
                                        }
                                    } label: {
                                        Label("Assign to category", systemImage: "tag")
                                    }
                                    Button("Edit…") { editingExpense = expense }
                                    Button(role: .destructive) {
                                        deleteExpense(expense)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Edit") { editingExpense = expense }
                                        .tint(.blue)
                                    Button(role: .destructive) {
                                        deleteExpense(expense)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                } header: {
                    Text("Monthly expenses")
                }

                Section {
                    ForEach(incomes) { income in
                        FixedExpenseRow(expense: income)
                            .listRowBackground(Color.green.opacity(0.15))
                            .contentShape(Rectangle())
                            .onTapGesture { editingExpense = income }
                            .contextMenu {
                                Button("Edit…") { editingExpense = income }
                                Button(role: .destructive) {
                                    deleteExpense(income)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Edit") { editingExpense = income }
                                    .tint(.blue)
                                Button(role: .destructive) {
                                    deleteExpense(income)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text("Incomes")
                }
            }
            .navigationTitle("Monthly")
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            isShowingAddSheet = true
                        } label: {
                            Label("Add expense", systemImage: "minus.circle")
                        }
                        Button {
                            isShowingAddIncomeSheet = true
                        } label: {
                            Label("Add income", systemImage: "plus.circle")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        isShowingCategoryManager = true
                    } label: {
                        Label("Categories", systemImage: "tag")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        for expense in fixedExpenses where expense.isChecked {
                            expense.isChecked = false
                        }
                    } label: {
                        Label("Uncheck all", systemImage: "circle")
                    }
                    .disabled(checkedTotal == 0)
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddEditFixedExpenseView()
            }
            .sheet(isPresented: $isShowingAddIncomeSheet) {
                AddEditFixedExpenseView(createsIncome: true)
            }
            .sheet(item: $editingExpense) { expense in
                AddEditFixedExpenseView(expense: expense)
            }
            .sheet(isPresented: $isShowingCategoryManager) {
                CategoryManagerView()
            }
            .task { seedMockDataIfNeeded(); seedDefaultCategoriesIfNeeded() }
        }
    }

    /// Expenses grouped by category in category order; uncategorized last.
    private var groupedExpenses: [(key: String, color: Color?, expenses: [FixedExpense])] {
        let categorized = expenses.filter { $0.category != nil }
        let uncategorized = expenses.filter { $0.category == nil }

        // Group by category identity, preserving category order.
        var groups: [(key: String, color: Color?, expenses: [FixedExpense])] = []
        for expense in categorized {
            guard let category = expense.category else { continue }
            if let index = groups.firstIndex(where: { $0.key == category.name }) {
                groups[index].expenses.append(expense)
            } else {
                groups.append((key: category.name, color: category.color, expenses: [expense]))
            }
        }
        if !uncategorized.isEmpty {
            groups.append((key: "", color: nil, expenses: uncategorized))
        }
        return groups
    }

    /// Assigned category color takes precedence; unchecked uncategorized rows
    /// stay clear, and checked uncategorized rows keep the green "paid" tint.
    private func rowBackground(for expense: FixedExpense) -> Color {
        if let color = expense.category?.color { return color.opacity(0.22) }
        if expense.isChecked { return Color.green.opacity(0.18) }
        return Color.clear
    }

    /// Seeds a one-time mock list of fixed expenses on first launch.
    private func seedMockDataIfNeeded() {
        let hasExpenses = (try? modelContext.fetchCount(FetchDescriptor<FixedExpense>())) ?? 0 > 0
        guard !hasExpenses else { return }

        // Original USD amounts converted at 1 USD = 3,200 COP.
        let mockExpenses: [(String, Decimal)] = [
            ("Rent/Arriendo", 4_800_000),      // $1,500
            ("Groceries", 1_440_000),          // $450
            ("Utilities", 384_000),            // $120
            ("Internet", 192_000),             // $60
            ("Phone", 144_000),                // $45
            ("Transport", 352_000),            // $110
            ("Streaming services", 80_000),    // $25
            ("Gym membership", 112_000),       // $35
            ("Insurance", 480_000),            // $150
            ("Subscriptions", 96_000),         // $30
        ]
        for (name, amount) in mockExpenses {
            modelContext.insert(FixedExpense(name: name, amount: amount))
        }
    }

    private func deleteExpense(_ expense: FixedExpense) {
        expense.modelContext?.delete(expense)
    }

    /// Ensures the app's built-in default categories always exist.
    /// Runs on every launch: if the user deleted one, it is restored.
    private func seedDefaultCategoriesIfNeeded() {
        let existingNames = Set(categories.map(\.name))
        for (name, colorHex) in ExpenseCategory.defaults where !existingNames.contains(name) {
            modelContext.insert(ExpenseCategory(name: name, colorHex: colorHex))
        }
    }
}

// MARK: - Checklist row

struct FixedExpenseRow: View {
    @Bindable var expense: FixedExpense

    var body: some View {
        Button {
            expense.isChecked.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: expense.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(expense.isChecked ? Color.green : Color.secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(expense.name)
                        .font(.body)
                        .strikethrough(expense.isChecked, color: .secondary)
                    Text(Currency.format(expense.amount))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MonthlyView()
        .modelContainer(for: [Transaction.self, FixedExpense.self], inMemory: true)
}

/// Estimated figure shown when the user holds tap on a summary row.
struct EstimatedDetails: Identifiable {
    let title: String
    let amount: Decimal
    var id: String { title }
}

private struct EstimatedDetailsPopover: View {
    let details: EstimatedDetails

    var body: some View {
        VStack(spacing: 8) {
            Text(details.title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(Currency.format(details.amount))
                .font(.title3.bold().monospacedDigit())
        }
        .padding(16)
        .presentationCompactAdaptation(.popover)
    }
}

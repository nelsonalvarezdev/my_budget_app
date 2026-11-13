import SwiftUI
import SwiftData

struct MonthlyView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("monthlyIncome") private var monthlyIncomeText = ""
    @Query private var fixedExpenses: [FixedExpense]
    @Query private var categories: [ExpenseCategory]

    @State private var isShowingAddSheet = false
    @State private var editingExpense: FixedExpense?
    @State private var isShowingCategoryManager = false

    private var monthlyIncome: Decimal {
        Decimal(string: monthlyIncomeText) ?? 0
    }

    private var checkedTotal: Decimal {
        fixedExpenses.filter(\.isChecked).reduce(0) { $0 + $1.amount }
    }

    private var remaining: Decimal {
        monthlyIncome - checkedTotal
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
                        Text("Fixed expenses")
                        Spacer()
                        Text(Currency.format(checkedTotal))
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Remaining")
                            .font(.headline)
                        Spacer()
                        Text(Currency.format(remaining))
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(remaining >= 0 ? Color.green : Color.red)
                    }
                } header: {
                    Text("Income")
                } footer: {
                    Text("Set your monthly income here (in pesos). Checked expenses below are subtracted from it: \(Currency.format(checkedTotal)).")
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
                    Text("Fixed expenses")
                }
            }
            .navigationTitle("Monthly")
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingAddSheet = true
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
        let categorized = fixedExpenses.filter { $0.category != nil }
        let uncategorized = fixedExpenses.filter { $0.category == nil }

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

import SwiftUI
import SwiftData

/// Monthly tab: checklist of fixed expenses and fixed incomes against the
/// monthly income.
struct MonthlyView: View {
    @Environment(AccountsStore.self) private var accounts
    /// Every Monthly item: fixed expenses and fixed incomes.
    @Query private var items: [FixedExpense]
    @Query private var categories: [ExpenseCategory]

    @State private var viewModel = MonthlyViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        let totals = viewModel.totals(items: items, accounts: accounts)

        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Monthly income")
                        Spacer()
                        CurrencyField(storedText: Bindable(accounts).monthlyIncomeText)
                            .font(.title3.monospacedDigit())
                            .frame(width: 160)
                    }

                    HStack {
                        Text("Monthly expenses")
                        Spacer()
                        Text(Currency.format(totals.checkedNet))
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .popover(item: $viewModel.expensesDetails) { details in
                        EstimatedDetailsPopover(details: details)
                    }
                    .onLongPressGesture(minimumDuration: 0.4) {
                        viewModel.showEstimatedExpenses(totals)
                    } onPressingChanged: { pressing in
                        if !pressing { viewModel.expensesDetails = nil }
                    }

                    HStack {
                        Text("Remaining")
                            .font(.headline)
                        Spacer()
                        Text(Currency.format(totals.remaining))
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(totals.remaining >= 0 ? Color.green : Color.red)
                    }
                    .popover(item: $viewModel.remainingDetails) { details in
                        EstimatedDetailsPopover(details: details)
                    }
                    .onLongPressGesture(minimumDuration: 0.4) {
                        viewModel.showEstimatedRemaining(totals)
                    } onPressingChanged: { pressing in
                        if !pressing { viewModel.remainingDetails = nil }
                    }
                } header: {
                    Text("Income")
                } footer: {
                    Text("Set your monthly income here (in pesos). Checked rows below are subtracted from it: \(Currency.format(totals.checkedNet)).")
                }

                Section {
                    ForEach(viewModel.groupedExpenses(items)) { group in
                        ForEach(group.expenses) { expense in
                            FixedExpenseRow(expense: expense)
                                .listRowBackground(rowBackground(for: expense))
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
                                    editAndDeleteButtons(for: expense, editTitle: "Edit…")
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    editAndDeleteButtons(for: expense, editTitle: "Edit")
                                }
                        }
                    }
                } header: {
                    Text("Monthly expenses")
                }

                Section {
                    ForEach(viewModel.incomes(items)) { income in
                        FixedExpenseRow(expense: income)
                            .listRowBackground(Color.green.opacity(0.15))
                            .contextMenu {
                                editAndDeleteButtons(for: income, editTitle: "Edit…")
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                editAndDeleteButtons(for: income, editTitle: "Edit")
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
                    Button {
                        viewModel.isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        viewModel.isShowingCategoryManager = true
                    } label: {
                        Label("Categories", systemImage: "tag")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        viewModel.uncheckAll(items)
                    } label: {
                        Label("Uncheck all", systemImage: "circle")
                    }
                    .disabled(!viewModel.canUncheckAll(items))
                }
            }
            .sheet(isPresented: $viewModel.isShowingAddSheet) {
                AddEditFixedExpenseView()
            }
            .sheet(item: $viewModel.editingItem) { item in
                AddEditFixedExpenseView(expense: item)
            }
            .sheet(isPresented: $viewModel.isShowingCategoryManager) {
                CategoryManagerView()
            }
        }
    }

    /// Edit and Delete actions shared by the context menu and the swipe.
    @ViewBuilder
    private func editAndDeleteButtons(for item: FixedExpense, editTitle: String) -> some View {
        Button(editTitle) { viewModel.editingItem = item }
            .tint(.blue)
        Button(role: .destructive) {
            viewModel.delete(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    /// Assigned category color takes precedence; unchecked uncategorized rows
    /// stay clear, and checked uncategorized rows keep the green "paid" tint.
    private func rowBackground(for expense: FixedExpense) -> Color {
        if let color = expense.category?.color { return color.opacity(0.22) }
        if expense.isChecked { return Color.green.opacity(0.18) }
        return Color.clear
    }
}

// MARK: - Checklist row

/// Tapping anywhere on the row toggles its check. Editing is available
/// through the swipe actions and the long-press menu.
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

#Preview {
    MonthlyView()
        .environment(AccountsStore())
        .modelContainer(for: [Transaction.self, FixedExpense.self], inMemory: true)
}

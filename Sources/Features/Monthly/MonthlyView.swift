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
                    heroCard(totals)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                ForEach(viewModel.groupedExpenses(items)) { group in
                    Section {
                        ForEach(group.expenses) { expense in
                            FixedExpenseRow(expense: expense)
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
                    } header: {
                        SectionHeader(title: group.title, trailing: "\(group.checkedCount) of \(group.expenses.count) paid")
                    }
                }

                let incomes = viewModel.incomes(items)
                if !incomes.isEmpty {
                    Section {
                        ForEach(incomes) { income in
                            FixedExpenseRow(expense: income)
                                .contextMenu {
                                    editAndDeleteButtons(for: income, editTitle: "Edit…")
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    editAndDeleteButtons(for: income, editTitle: "Edit")
                                }
                        }
                    } header: {
                        SectionHeader(title: "Incomes", trailing: "\(incomes.filter(\.isChecked).count) of \(incomes.count) received")
                    }
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

    /// Headline card: what is left of the monthly income, a bar showing how
    /// much of it is paid (solid) and will be paid once everything is checked
    /// (lighter), and the editable monthly income. Holding the remaining
    /// amount or the paid label peeks at the estimated figures.
    private func heroCard(_ totals: MonthlyTotals) -> some View {
        @Bindable var viewModel = viewModel
        @Bindable var accounts = accounts
        return HeroCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remaining this month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HeroAmount(amount: Currency.format(totals.remaining), isNegative: totals.remaining < 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .popover(item: $viewModel.remainingDetails) { details in
                    EstimatedDetailsPopover(details: details)
                }
                .onLongPressGesture(minimumDuration: 0.4) {
                    viewModel.showEstimatedRemaining(totals)
                } onPressingChanged: { pressing in
                    if !pressing { viewModel.remainingDetails = nil }
                }

                MonthlyProgressBar(paid: totals.paidFraction, estimated: totals.estimatedFraction)

                HStack(spacing: 6) {
                    Text("Paid \(Currency.format(totals.checkedNet))")
                        .contentShape(Rectangle())
                        .popover(item: $viewModel.expensesDetails) { details in
                            EstimatedDetailsPopover(details: details)
                        }
                        .onLongPressGesture(minimumDuration: 0.4) {
                            viewModel.showEstimatedExpenses(totals)
                        } onPressingChanged: { pressing in
                            if !pressing { viewModel.expensesDetails = nil }
                        }
                    Spacer()
                    Text("of")
                        .foregroundStyle(.secondary)
                    CurrencyField(storedText: $accounts.monthlyIncomeText)
                        .fixedSize()
                        .accessibilityLabel("Monthly income")
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .font(.footnote.monospacedDigit())
            }
        }
    }
}

/// Share of the monthly income that is paid (solid) and that will be paid
/// once every item is checked (lighter segment behind it).
private struct MonthlyProgressBar: View {
    let paid: Double
    let estimated: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemBackground).opacity(0.75))
                Capsule().fill(Color.brand.opacity(0.35))
                    .frame(width: proxy.size.width * estimated)
                Capsule().fill(Color.brand)
                    .frame(width: proxy.size.width * paid)
            }
        }
        .frame(height: 10)
        .animation(.easeInOut(duration: 0.25), value: paid)
        .animation(.easeInOut(duration: 0.25), value: estimated)
        .accessibilityElement()
        .accessibilityLabel("Paid share of monthly income")
        .accessibilityValue("\(Int(paid * 100)) percent paid, \(Int(estimated * 100)) percent estimated")
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
                    .foregroundStyle(expense.isChecked ? Color.brand : Color.secondary)
                    .font(.title3)

                if !expense.isIncome {
                    CategoryDot(color: expense.category?.color)
                }

                Text(expense.name)
                    .strikethrough(expense.isChecked, color: .secondary)
                    .foregroundStyle(expense.isChecked ? Color.secondary : Color.primary)

                Spacer()

                Text(expense.isIncome ? Currency.formatSigned(expense.amount) : Currency.format(expense.amount))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(amountColor)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var amountColor: Color {
        if expense.isChecked { return .secondary }
        return expense.isIncome ? .brand : .primary
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

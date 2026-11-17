import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AccountsStore.self) private var accounts

    /// Every item of the Monthly view; its expenses are offered in the
    /// "Pays for" list to prefill the form.
    @Query private var monthlyItems: [FixedExpense]

    /// Expense categories from the same store the Monthly view uses, so both
    /// views always show the same list.
    @Query private var expenseCategories: [ExpenseCategory]

    /// Entries of the Expenses view; the budgets among them are offered in
    /// the "Pays for" list.
    @Query private var extraEntries: [NonFixedExpense]

    @State private var viewModel = AddTransactionViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Form {
                Picker("Type", selection: $viewModel.kind) {
                    ForEach(TransactionKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                if viewModel.kind == .expense {
                    NavigationLink {
                        PaysForList(
                            viewModel: viewModel,
                            monthlyItems: viewModel.paysForOrder(monthlyItems),
                            budgets: extraEntries.filter { $0.isBudget && !$0.isIncome },
                            storedCategories: expenseCategories
                        )
                    } label: {
                        LabeledContent("Pays for", value: viewModel.paysForTitle)
                    }
                }

                Section {
                    TextField("Name", text: $viewModel.name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Name")
                } footer: {
                    if viewModel.kind == .expense {
                        if viewModel.selectedMonthlyItem != nil {
                            Text("Saving marks this fixed expense as paid.")
                        } else if viewModel.selectedBudget != nil {
                            Text("Saving also records the amount as spent in this budget.")
                        } else {
                            Text("Required. Pick what it pays for above to fill it automatically, or type a name.")
                        }
                    }
                }

                HStack {
                    Text("Amount")
                    Spacer()
                    TextField("0.00", text: $viewModel.amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.title3.monospacedDigit())
                        .frame(width: 160)
                }

                Picker("Category", selection: $viewModel.category) {
                    ForEach(viewModel.categoryOptions(storedCategories: expenseCategories), id: \.self) { category in
                        Text(category).tag(category)
                    }
                }

                if viewModel.kind == .expense {
                    Picker("Paid with", selection: $viewModel.paidWith) {
                        ForEach(PaymentSource.allCases) { source in
                            Text(source.label).tag(source)
                        }
                    }
                } else {
                    Picker("Received by", selection: $viewModel.paidWith) {
                        ForEach(PaymentSource.incomeOptions) { source in
                            Text(source.incomeLabel).tag(source)
                        }
                    }
                }

                TextField("Note (optional)", text: $viewModel.note)

                DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
            }
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if viewModel.save(context: modelContext, accounts: accounts) {
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.isInputValid)
                }
            }
            .onChange(of: viewModel.kind) { _, _ in
                viewModel.resetCategory(storedCategories: expenseCategories)
            }
        }
    }
}

/// The "Pays for" choices: nothing, a Monthly item (marked as paid on save)
/// or a budget (the amount is recorded as a spend in it). Monthly items that
/// are already paid stay selectable, greyed out at the end of their group.
private struct PaysForList: View {
    let viewModel: AddTransactionViewModel
    let monthlyItems: [FixedExpense]
    let budgets: [NonFixedExpense]
    let storedCategories: [ExpenseCategory]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                row(title: "None", detail: nil, isSelected: viewModel.selectedMonthlyItem == nil && viewModel.selectedBudget == nil) {
                    viewModel.payForNothing()
                }
            }

            if !monthlyItems.isEmpty {
                Section("Fixed expenses") {
                    ForEach(monthlyItems) { item in
                        row(
                            title: item.name,
                            detail: item.isChecked ? "Paid · \(Currency.format(item.amount))" : Currency.format(item.amount),
                            isSelected: viewModel.selectedMonthlyItem === item,
                            isDimmed: item.isChecked
                        ) {
                            viewModel.payFor(monthlyItem: item, storedCategories: storedCategories)
                        }
                    }
                }
            }

            if !budgets.isEmpty {
                Section("Budgets") {
                    ForEach(budgets) { budget in
                        row(
                            title: budget.name,
                            detail: "\(Currency.format(budget.amount)) left",
                            isSelected: viewModel.selectedBudget === budget
                        ) {
                            viewModel.payFor(budget: budget)
                        }
                    }
                }
            }
        }
        .navigationTitle("Pays for")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(title: String, detail: String?, isSelected: Bool, isDimmed: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(isDimmed ? Color.secondary : Color.primary)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(isDimmed ? Color.secondary.opacity(0.7) : Color.secondary)
                }
                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.brand)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddTransactionView()
        .environment(AccountsStore())
        .modelContainer(for: [Transaction.self, FixedExpense.self], inMemory: true)
}

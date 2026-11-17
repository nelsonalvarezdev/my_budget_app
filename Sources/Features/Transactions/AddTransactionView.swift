import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AccountsStore.self) private var accounts

    /// Every item of the Monthly view, offered in the "Fixed expense" picker
    /// to prefill the form.
    @Query private var monthlyItems: [FixedExpense]

    /// Expense categories from the same store the Monthly view uses, so both
    /// views always show the same list.
    @Query private var expenseCategories: [ExpenseCategory]

    /// Entries of the Expenses view; the budgets among them are offered in
    /// the "From budget" picker.
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
                    Picker("Fixed expense", selection: $viewModel.selectedMonthlyItem) {
                        Text("None").tag(nil as FixedExpense?)
                        ForEach(monthlyItems) { item in
                            Text(item.name).tag(Optional(item))
                        }
                    }
                    .onChange(of: viewModel.selectedMonthlyItem) { _, _ in
                        viewModel.prefillFromSelectedMonthlyItem(storedCategories: expenseCategories)
                    }
                }

                Section {
                    TextField("Name", text: $viewModel.name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Name")
                } footer: {
                    if viewModel.kind == .expense && viewModel.selectedMonthlyItem == nil {
                        Text("Required. Pick a fixed expense above to fill it automatically, or type a name.")
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
                }

                let budgets = extraEntries.filter { $0.isBudget && !$0.isIncome }
                if viewModel.kind == .expense && !budgets.isEmpty {
                    Section {
                        Picker("From budget", selection: $viewModel.selectedBudget) {
                            Text("None").tag(nil as NonFixedExpense?)
                            ForEach(budgets) { budget in
                                Text("\(budget.name) · \(Currency.format(budget.amount)) left").tag(Optional(budget))
                            }
                        }
                    } footer: {
                        if viewModel.selectedBudget != nil {
                            Text("The amount is also recorded as spent in this budget.")
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

#Preview {
    AddTransactionView()
        .environment(AccountsStore())
        .modelContainer(for: [Transaction.self, FixedExpense.self], inMemory: true)
}

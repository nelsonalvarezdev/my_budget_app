import SwiftUI
import SwiftData

/// Row for a budget entry: its name, the amount set aside and what is left
/// of it (the part the Balance still reserves). Tapping navigates to
/// `BudgetDetailView` (handled by the parent's NavigationLink).
struct BudgetExpenseRow: View {
    @Bindable var expense: NonFixedExpense

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.name)
                TagPill(text: "of \(Currency.format(expense.budgetAmount))")
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(Currency.format(expense.amount))
                    .font(.body.monospacedDigit())
                if expense.budgetOverspend > 0 {
                    Text("Over by \(Currency.format(expense.budgetOverspend))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.red)
                } else {
                    Text("left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Detail view for a budget entry: what is left, the editable budget amount
/// and the list of spends. Spends can be added and deleted here; the budget
/// amount can be edited but not deleted.
struct BudgetDetailView: View {
    @Bindable var expense: NonFixedExpense
    @Environment(\.modelContext) private var modelContext

    @State private var budgetText = ""
    @State private var newSpendText = ""
    @FocusState private var isNewSpendFocused: Bool

    var body: some View {
        List {
            Section {
                HeroCard {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Left in budget")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HeroAmount(amount: Currency.format(expense.amount))
                        }
                        ShareBar(
                            solid: expense.budgetSpentFraction,
                            label: "Spent share of the budget",
                            tint: expense.budgetOverspend > 0 ? .red : .brand
                        )
                        HStack {
                            Text("Spent \(Currency.format(expense.budgetSpent))")
                            Spacer()
                            if expense.budgetOverspend > 0 {
                                Text("Over by \(Currency.format(expense.budgetOverspend))")
                                    .foregroundStyle(.red)
                            } else {
                                Text("of \(Currency.format(expense.budgetAmount))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.footnote.monospacedDigit())
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                HStack {
                    Text("Budget amount")
                    Spacer()
                    CurrencyField(storedText: $budgetText)
                        .font(.body.monospacedDigit())
                        .frame(width: 160)
                        .onChange(of: budgetText) { _, text in
                            expense.setBudgetAmount(Currency.parseAmount(text) ?? 0)
                        }
                }
            } footer: {
                Text("Tap the amount to change it. Your spends are kept.")
            }

            Section {
                if expense.subExpenses.isEmpty {
                    Text("No spends yet. Add one below, or pick this budget when you add a transaction.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(expense.subExpenses) { spend in
                        HStack {
                            Text(spend.label.isEmpty ? "Spend" : spend.label)
                            Spacer()
                            Text(Currency.format(spend.value))
                                .font(.body.monospacedDigit())
                        }
                    }
                    .onDelete { offsets in
                        expense.removeSubValues(offsets.map { expense.subExpenses[$0] }, in: modelContext)
                    }
                }
            } header: {
                SectionHeader(title: "Spends", trailing: Currency.format(expense.budgetSpent))
            } footer: {
                if !expense.subExpenses.isEmpty {
                    Text("Swipe a spend to delete it; its amount goes back to the budget.")
                }
            }

            Section {
                HStack {
                    TextField("New spend", text: $newSpendText)
                        .keyboardType(.numberPad)
                        .focused($isNewSpendFocused)
                        .onSubmit { addSpend() }
                    Button("Add") { addSpend() }
                        .disabled(newSpend == nil)
                }
            } header: {
                Text("Add spend")
            }
        }
        .navigationTitle(expense.name)
        .navigationBarTitleDisplayMode(.inline)
        .dismissKeyboardOnTap()
        .onAppear { budgetText = Currency.formatForEditing(expense.budgetAmount) }
    }

    /// A spend must be a number greater than zero.
    private var newSpend: Decimal? {
        guard let value = Currency.parseAmount(newSpendText), value > 0 else { return nil }
        return value
    }

    private func addSpend() {
        guard let newSpend else { return }
        expense.addSpend(newSpend)
        newSpendText = ""
        isNewSpendFocused = false
    }
}

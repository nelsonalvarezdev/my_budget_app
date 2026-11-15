import SwiftUI
import SwiftData

struct AddEditFixedExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [ExpenseCategory]

    /// Pass an existing expense to edit it; leave nil to create a new one.
    var expense: FixedExpense?
    /// True when the sheet creates a new income instead of an expense.
    var createsIncome = false

    /// Whether this sheet is handling an income (new or existing).
    private var isIncome: Bool { createsIncome || expense?.isIncome == true }

    @State private var name = ""
    @State private var amountText = ""
    @State private var selectedCategory: ExpenseCategory?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (e.g. Rent)", text: $name)
                    .autocorrectionDisabled()
                HStack {
                    Text("Amount")
                    Spacer()
                    TextField("0", text: $amountText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.title3.monospacedDigit())
                        .frame(width: 160)
                }

                if !isIncome {
                    Picker("Category", selection: $selectedCategory) {
                        Text("None").tag(ExpenseCategory?.none)
                        ForEach(categories) { category in
                            HStack {
                                Circle().fill(category.color).frame(width: 14, height: 14)
                                Text(category.name)
                            }
                            .tag(ExpenseCategory?.some(category))
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isInputValid)
                }
            }
            .onAppear(perform: populate)
        }
    }

    private var isInputValid: Bool {
        !name.isEmpty && (Decimal(string: amountText) ?? 0) > 0
    }

    private var title: String {
        let verb = expense == nil ? "Add" : "Edit"
        return isIncome ? "\(verb) Income" : "\(verb) Expense"
    }

    private func populate() {
        guard let expense else { return }
        name = expense.name
        amountText = Currency.formatForEditing(expense.amount)
        selectedCategory = expense.category
    }

    private func save() {
        guard let amount = Decimal(string: amountText), amount > 0 else { return }

        if let expense {
            expense.name = name
            expense.amount = amount
            expense.category = selectedCategory
        } else {
            modelContext.insert(FixedExpense(name: name, amount: amount, isIncome: isIncome, category: selectedCategory))
        }
        dismiss()
    }
}

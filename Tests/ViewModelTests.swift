import Foundation
import SwiftData
import Testing
@testable import BudgetApp

@MainActor
struct AddTransactionViewModelTests {
    @Test func requiresNameAndPositiveAmount() {
        let viewModel = AddTransactionViewModel()
        #expect(!viewModel.isInputValid)

        viewModel.name = "  "
        viewModel.amountText = "1000"
        #expect(!viewModel.isInputValid)

        viewModel.name = "Lunch"
        viewModel.amountText = "0"
        #expect(!viewModel.isInputValid)

        viewModel.amountText = "1000"
        #expect(viewModel.isInputValid)
    }

    @Test func savingACashExpenseInsertsItAndSubtractsFromCash() throws {
        let context = try makeTestContext()
        let accounts = makeTestAccounts(cash: "10000", savings: "5000")
        let viewModel = AddTransactionViewModel()
        viewModel.name = " Lunch "
        viewModel.amountText = "3000"

        #expect(viewModel.save(context: context, accounts: accounts))

        let saved = try context.fetch(FetchDescriptor<Transaction>())
        #expect(saved.count == 1)
        #expect(saved.first?.name == "Lunch")
        #expect(saved.first?.amount == 3_000)
        #expect(accounts.cash == 7_000)
        #expect(accounts.savings == 5_000)
    }

    @Test func expenseFromABudgetIsRecordedAsASpendInIt() throws {
        let context = try makeTestContext()
        let accounts = makeTestAccounts(cash: "10000")
        let budget = NonFixedExpense.make(name: "Groceries", isIncome: false, mode: .budget, value: 5_000)
        context.insert(budget)
        let viewModel = AddTransactionViewModel()
        viewModel.payFor(budget: budget)
        #expect(viewModel.name == "Groceries")
        viewModel.name = "Market"
        viewModel.amountText = "3000"

        viewModel.save(context: context, accounts: accounts)

        #expect(budget.amount == 2_000)
        #expect(budget.subExpenses.first?.label == "Market")
        #expect(accounts.cash == 7_000)
        // Cash dropped and the reserve shrank by the same amount.
        #expect(BalanceRules.balance(cash: accounts.cash, savings: accounts.savings, extraEntries: [budget]) == 5_000)
    }

    @Test func incomeIsNeverRecordedInABudget() throws {
        let context = try makeTestContext()
        let accounts = makeTestAccounts()
        let budget = NonFixedExpense.make(name: "Groceries", isIncome: false, mode: .budget, value: 5_000)
        context.insert(budget)
        let viewModel = AddTransactionViewModel()
        viewModel.kind = .income
        viewModel.payFor(budget: budget)
        viewModel.name = "Gift"
        viewModel.amountText = "3000"

        viewModel.save(context: context, accounts: accounts)

        #expect(budget.amount == 5_000)
    }

    @Test func paysForIsEitherAMonthlyItemOrABudgetNeverBoth() {
        let rent = FixedExpense(name: "Rent", amount: 1_000)
        let budget = NonFixedExpense.make(name: "Groceries", isIncome: false, mode: .budget, value: 5_000)
        let viewModel = AddTransactionViewModel()
        #expect(viewModel.paysForTitle == "None")

        viewModel.payFor(monthlyItem: rent, storedCategories: [])
        #expect(viewModel.paysForTitle == "Rent")

        viewModel.payFor(budget: budget)
        #expect(viewModel.selectedMonthlyItem == nil)
        #expect(viewModel.paysForTitle == "Groceries")

        viewModel.payFor(monthlyItem: rent, storedCategories: [])
        #expect(viewModel.selectedBudget == nil)

        viewModel.payForNothing()
        #expect(viewModel.paysForTitle == "None")
    }

    @Test func paysForListsPaidMonthlyItemsLast() {
        let viewModel = AddTransactionViewModel()
        let items = [
            FixedExpense(name: "Rent", amount: 1, isChecked: true),
            FixedExpense(name: "Phone", amount: 1),
            FixedExpense(name: "Gym", amount: 1, isChecked: true),
            FixedExpense(name: "Power", amount: 1),
        ]
        #expect(viewModel.paysForOrder(items).map(\.name) == ["Phone", "Power", "Rent", "Gym"])
    }

    @Test func paysForLeavesOutMonthlyIncomes() {
        let items = [
            FixedExpense(name: "Rent", amount: 1),
            FixedExpense(name: "Salary bonus", amount: 1, isIncome: true),
            FixedExpense(name: "Refund", amount: 1, isChecked: true, isIncome: true),
        ]
        #expect(AddTransactionViewModel().paysForOrder(items).map(\.name) == ["Rent"])
    }

    @Test func creditCardExpenseLeavesTheAccountsUntouched() throws {
        let context = try makeTestContext()
        let accounts = makeTestAccounts(cash: "10000", savings: "5000")
        let viewModel = AddTransactionViewModel()
        viewModel.name = "Shoes"
        viewModel.amountText = "3000"
        viewModel.paidWith = .creditCard

        viewModel.save(context: context, accounts: accounts)

        #expect(accounts.cash == 10_000)
        #expect(accounts.savings == 5_000)
    }

    @Test func incomeAddsToCash() throws {
        let context = try makeTestContext()
        let accounts = makeTestAccounts(cash: "10000")
        let viewModel = AddTransactionViewModel()
        viewModel.kind = .income
        viewModel.name = "Gift"
        viewModel.amountText = "2000"

        viewModel.save(context: context, accounts: accounts)

        #expect(accounts.cash == 12_000)
    }

    @Test func incomeByTransferAddsToSavings() throws {
        let context = try makeTestContext()
        let accounts = makeTestAccounts(cash: "10000", savings: "5000")
        let viewModel = AddTransactionViewModel()
        viewModel.kind = .income
        viewModel.paidWith = .savings
        viewModel.name = "Salary"
        viewModel.amountText = "2000"

        viewModel.save(context: context, accounts: accounts)

        #expect(accounts.cash == 10_000)
        #expect(accounts.savings == 7_000)
    }

    @Test func switchingToIncomeDropsTheCreditCard() {
        let viewModel = AddTransactionViewModel()
        viewModel.paidWith = .creditCard
        viewModel.kind = .income
        viewModel.resetCategory(storedCategories: [])
        #expect(viewModel.paidWith == .cash)

        viewModel.paidWith = .savings
        viewModel.kind = .expense
        viewModel.resetCategory(storedCategories: [])
        #expect(viewModel.paidWith == .savings)
    }

    @Test func incomeDefaultsToOtherAndOffersContribution() {
        let viewModel = AddTransactionViewModel()
        viewModel.kind = .income
        viewModel.resetCategory(storedCategories: [])
        #expect(viewModel.category == "Other")
        #expect(viewModel.categoryOptions(storedCategories: []).contains("Contribution"))

        viewModel.kind = .expense
        viewModel.resetCategory(storedCategories: [])
        #expect(viewModel.category == AddTransactionViewModel.noCategory)
    }

    @Test func expenseCategoryOptionsAreAlphabetical() {
        let viewModel = AddTransactionViewModel()
        let stored = [
            ExpenseCategory(name: "transport", colorHex: "#000000"),
            ExpenseCategory(name: "Food", colorHex: "#000000"),
            ExpenseCategory(name: "Ahorro", colorHex: "#000000"),
        ]
        #expect(viewModel.categoryOptions(storedCategories: stored) == ["None", "Ahorro", "Food", "transport"])
    }

    @Test func invalidInputSavesNothing() throws {
        let context = try makeTestContext()
        let accounts = makeTestAccounts(cash: "10000")
        let viewModel = AddTransactionViewModel()
        viewModel.amountText = "3000" // no name

        #expect(!viewModel.save(context: context, accounts: accounts))
        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 0)
        #expect(accounts.cash == 10_000)
    }

    @Test func pickingAMonthlyItemPrefillsAndSavingChecksIt() throws {
        let context = try makeTestContext()
        let accounts = makeTestAccounts(cash: "5000000")
        let housing = ExpenseCategory(name: "Housing", colorHex: "#4C7BE0")
        let rent = FixedExpense(name: "Rent", amount: 1_200_000, category: housing)
        context.insert(housing)
        context.insert(rent)

        let viewModel = AddTransactionViewModel()
        viewModel.payFor(monthlyItem: rent, storedCategories: [housing])

        #expect(viewModel.name == "Rent")
        #expect(viewModel.amountText == "1200000")
        #expect(viewModel.category == "Housing")

        // The amount can still be edited; the item is checked regardless.
        viewModel.amountText = "1000000"
        viewModel.save(context: context, accounts: accounts)

        #expect(rent.isChecked)
        #expect(accounts.cash == 4_000_000)
    }

    @Test func monthlyItemWithoutCategoryMapsToNone() {
        let item = FixedExpense(name: "Phone", amount: 100)
        let viewModel = AddTransactionViewModel()
        viewModel.category = "Housing"
        viewModel.payFor(monthlyItem: item, storedCategories: [])
        #expect(viewModel.category == AddTransactionViewModel.noCategory)
    }

    @Test func switchingKindResetsTheCategory() {
        let viewModel = AddTransactionViewModel()
        viewModel.kind = .income
        viewModel.resetCategory(storedCategories: [])
        #expect(viewModel.category == "Other")

        viewModel.kind = .expense
        viewModel.resetCategory(storedCategories: [])
        #expect(viewModel.category == AddTransactionViewModel.noCategory)
    }
}

@MainActor
struct TransactionsViewModelTests {
    @Test func cancelledExportDoesNotReshowAnOlderMessage() {
        let viewModel = TransactionsViewModel()
        viewModel.backupMessage = "Data imported successfully."

        viewModel.handleExportResult(.failure(CocoaError(.userCancelled)))

        #expect(viewModel.backupMessage == nil)
        #expect(!viewModel.isShowingBackupResult)
    }

    @Test func successfulExportShowsTheSavedFileName() {
        let viewModel = TransactionsViewModel()

        viewModel.handleExportResult(.success(URL(fileURLWithPath: "/tmp/Budget.json")))

        #expect(viewModel.backupMessage == "Backup saved to Budget.json.")
        #expect(viewModel.isShowingBackupResult)
    }

    @Test func balanceIgnoresTransactionsAndTheDisplayedMonth() throws {
        let accounts = makeTestAccounts(cash: "1000", savings: "500")
        let extras = [
            NonFixedExpense(name: "Dinner", amount: 200),
            NonFixedExpense(name: "Refund", amount: 50, isIncome: true),
        ]
        let transactions = [Transaction(amount: 400, kind: .expense, category: "Food", date: .now)]
        let viewModel = TransactionsViewModel()

        let current = viewModel.summary(transactions: transactions, extraEntries: extras, accounts: accounts)
        #expect(current.balance == 1_350)   // 1000 + 500 − 200 + 50
        #expect(current.expenses == 400)

        viewModel.showPreviousMonth()
        let previous = viewModel.summary(transactions: transactions, extraEntries: extras, accounts: accounts)
        #expect(previous.balance == 1_350)  // global, not month-scoped
        #expect(previous.expenses == 0)     // pills follow the month
    }

    @Test func deletingTransactionsDoesNotGiveTheMoneyBack() throws {
        let context = try makeTestContext()
        let accounts = makeTestAccounts(cash: "10000")
        let add = AddTransactionViewModel()
        add.name = "Lunch"
        add.amountText = "3000"
        add.save(context: context, accounts: accounts)
        #expect(accounts.cash == 7_000)

        let all = try context.fetch(FetchDescriptor<Transaction>())
        TransactionsViewModel().delete(all, context: context)

        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 0)
        #expect(accounts.cash == 7_000)
    }
}

@MainActor
struct MonthlyViewModelTests {
    @Test func groupsExpensesByCategoryWithUncategorizedLast() {
        let housing = ExpenseCategory(name: "Housing", colorHex: "#4C7BE0")
        let food = ExpenseCategory(name: "Food", colorHex: "#4CAF50")
        let items = [
            FixedExpense(name: "Phone", amount: 1),
            FixedExpense(name: "Rent", amount: 1, category: housing),
            FixedExpense(name: "Market", amount: 1, category: food),
            FixedExpense(name: "Admin fee", amount: 1, category: housing),
            FixedExpense(name: "Salary bonus", amount: 1, isIncome: true),
        ]

        let groups = MonthlyViewModel().groupedExpenses(items)

        #expect(groups.map(\.key) == ["Housing", "Food", ""])
        #expect(groups[0].expenses.map(\.name) == ["Rent", "Admin fee"])
        #expect(groups[2].expenses.map(\.name) == ["Phone"])
    }

    @Test func checkedExpensesMoveToPaidAndKeepTheirCategory() {
        let housing = ExpenseCategory(name: "Housing", colorHex: "#111111")
        let rent = FixedExpense(name: "Rent", amount: 1, isChecked: true, category: housing)
        let admin = FixedExpense(name: "Admin fee", amount: 1, category: housing)
        let bonus = FixedExpense(name: "Bonus", amount: 1, isChecked: true, isIncome: true)
        let viewModel = MonthlyViewModel()
        let items = [rent, admin, bonus]

        let group = viewModel.groupedExpenses(items)[0]
        #expect(group.unpaidExpenses.map(\.name) == ["Admin fee"])
        #expect(group.checkedCount == 1)
        #expect(viewModel.paidExpenses(items).map(\.name) == ["Rent"])
        #expect(rent.category === housing)

        rent.isChecked = false
        #expect(viewModel.paidExpenses(items).isEmpty)
        #expect(viewModel.groupedExpenses(items)[0].unpaidExpenses.count == 2)
    }

    @Test func uncheckAllIsAvailableWhenCheckedItemsNetToZero() {
        let viewModel = MonthlyViewModel()
        let items = [
            FixedExpense(name: "Rent", amount: 100, isChecked: true),
            FixedExpense(name: "Bonus", amount: 100, isChecked: true, isIncome: true),
        ]
        #expect(viewModel.canUncheckAll(items))
        #expect(!viewModel.canUncheckAll([FixedExpense(name: "Phone", amount: 100)]))
        #expect(!viewModel.canUncheckAll([]))
    }

    @Test func uncheckAllResetsExpensesAndIncomes() {
        let items = [
            FixedExpense(name: "Rent", amount: 1, isChecked: true),
            FixedExpense(name: "Bonus", amount: 1, isChecked: true, isIncome: true),
            FixedExpense(name: "Phone", amount: 1),
        ]
        MonthlyViewModel().uncheckAll(items)
        #expect(items.allSatisfy { !$0.isChecked })
    }

    @Test func totalsUseTheStoredMonthlyIncome() {
        let accounts = makeTestAccounts(monthlyIncome: "5000")
        let items = [FixedExpense(name: "Rent", amount: 1_000, isChecked: true)]
        let totals = MonthlyViewModel().totals(items: items, accounts: accounts)
        #expect(totals.remaining == 4_000)
    }
}

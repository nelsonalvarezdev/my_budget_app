import Foundation
import SwiftData
import Testing
@testable import BudgetApp

@MainActor
struct BackupServiceTests {
    @Test func budgetEntriesSurviveAnExportAndImport() throws {
        let source = try makeTestContext()
        let accounts = makeTestAccounts(cash: "100")
        let budget = NonFixedExpense.make(name: "Groceries", isIncome: false, mode: .budget, value: 1_000)
        source.insert(budget)
        budget.addSpend(300, label: "Market")

        let data = try BackupService.encode(BackupService.makeSnapshot(context: source, accounts: accounts))
        let target = try makeTestContext()
        try BackupService.restore(BackupService.decode(data), context: target, accounts: makeTestAccounts())

        let restored = try #require(try target.fetch(FetchDescriptor<NonFixedExpense>()).first)
        #expect(restored.isBudget)
        #expect(restored.budgetAmount == 1_000)
        #expect(restored.amount == 700)
        #expect(restored.subExpenses.map(\.value) == [300])
        #expect(restored.subExpenses.map(\.label) == ["Market"])
    }

    @Test func backupsFromBeforeBudgetsStillImport() throws {
        let json = """
        {"version":1,"exportedAt":"2026-11-17T01:33:35Z","transactions":[],"fixedExpenses":[],"categories":[],
         "monthlyIncome":"","cashBalance":"","savingsBalance":"",
         "nonFixedExpenses":[{"name":"Trip","amount":50,"isCumulative":true,"subExpenses":[20,30]}]}
        """
        let context = try makeTestContext()
        try BackupService.restore(BackupService.decode(Data(json.utf8)), context: context, accounts: makeTestAccounts())

        let restored = try #require(try context.fetch(FetchDescriptor<NonFixedExpense>()).first)
        #expect(!restored.isBudget)
        #expect(restored.amount == 50)
        #expect(restored.subExpenses.count == 2)
    }
}

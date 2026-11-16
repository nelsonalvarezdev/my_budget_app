import Foundation
import SwiftData
import Testing
@testable import BudgetApp

/// Rules of the Expenses-view entries (`NonFixedExpense`).
@MainActor
struct ExtraEntryRulesTests {
    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Transaction.self, FixedExpense.self, NonFixedExpense.self, SubExpense.self, ExpenseCategory.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    // MARK: Recurring

    @Test func recurringStartsAtBaseTimesOne() {
        let entry = NonFixedExpense(name: "Gym", amount: 50, isRecurring: true)
        #expect(entry.baseAmount == 50)
        #expect(entry.multiplier == 1)
        #expect(entry.amount == 50)
    }

    @Test func recurringAmountIsBaseTimesMultiplier() {
        let entry = NonFixedExpense(name: "Gym", amount: 50, isRecurring: true)
        entry.stepMultiplier(by: 1)
        entry.stepMultiplier(by: 1)
        #expect(entry.multiplier == 3)
        #expect(entry.amount == 150)

        entry.stepMultiplier(by: -1)
        #expect(entry.amount == 100)
    }

    @Test func recurringMultiplierNeverGoesBelowOne() {
        let entry = NonFixedExpense(name: "Gym", amount: 50, isRecurring: true)
        entry.stepMultiplier(by: -1)
        #expect(entry.multiplier == 1)
        #expect(entry.amount == 50)
    }

    @Test func editingTheBaseKeepsTheMultiplier() {
        let entry = NonFixedExpense(name: "Gym", amount: 50, isRecurring: true)
        entry.stepMultiplier(by: 2)
        entry.setBaseAmount(70)
        #expect(entry.multiplier == 3)
        #expect(entry.amount == 210)
    }

    // MARK: Cumulative

    @Test func cumulativeAmountIsTheSumOfSubValues() throws {
        let context = try makeContext()
        let entry = NonFixedExpense(name: "Trip", amount: 0, isCumulative: true)
        context.insert(entry)

        entry.addSubValue(100)
        entry.addSubValue(250)
        entry.addSubValue(-50)

        #expect(entry.subExpenses.count == 3)
        #expect(entry.amount == 300)
    }

    @Test func zeroSubValuesAreIgnored() throws {
        let context = try makeContext()
        let entry = NonFixedExpense(name: "Trip", amount: 0, isCumulative: true)
        context.insert(entry)

        entry.addSubValue(0)

        #expect(entry.subExpenses.isEmpty)
        #expect(entry.amount == 0)
    }

    @Test func removingSubValuesUpdatesTheTotalAndTheStore() throws {
        let context = try makeContext()
        let entry = NonFixedExpense(name: "Trip", amount: 0, isCumulative: true)
        context.insert(entry)
        entry.addSubValue(100)
        entry.addSubValue(250)
        try context.save()

        let removed = entry.subExpenses.filter { $0.value == 100 }
        entry.removeSubValues(removed, in: context)
        try context.save()

        #expect(entry.amount == 250)
        #expect(try context.fetchCount(FetchDescriptor<SubExpense>()) == 1)
    }

    // MARK: Deletion

    @Test func deletingAnEntryLeavesNoOrphanedSubValues() throws {
        let context = try makeContext()
        let entry = NonFixedExpense(name: "Trip", amount: 0, isCumulative: true)
        context.insert(entry)
        entry.addSubValue(100)
        entry.addSubValue(250)
        try context.save()

        entry.delete(from: context)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<NonFixedExpense>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SubExpense>()) == 0)
    }
}

import Foundation
import SwiftData
import Testing
@testable import BudgetApp

/// Rules of the Expenses-view entries (`NonFixedExpense`).
@MainActor
struct ExtraEntryRulesTests {
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
        let context = try makeTestContext()
        let entry = NonFixedExpense(name: "Trip", amount: 0, isCumulative: true)
        context.insert(entry)

        entry.addSubValue(100)
        entry.addSubValue(250)
        entry.addSubValue(-50)

        #expect(entry.subExpenses.count == 3)
        #expect(entry.amount == 300)
    }

    @Test func zeroSubValuesAreIgnored() throws {
        let context = try makeTestContext()
        let entry = NonFixedExpense(name: "Trip", amount: 0, isCumulative: true)
        context.insert(entry)

        entry.addSubValue(0)

        #expect(entry.subExpenses.isEmpty)
        #expect(entry.amount == 0)
    }

    @Test func removingSubValuesUpdatesTheTotalAndTheStore() throws {
        let context = try makeTestContext()
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
        let context = try makeTestContext()
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

    // MARK: Creation

    @Test func plainEntryUsesTheTypedAmount() {
        let entry = NonFixedExpense.make(name: "Taxi", isIncome: false, mode: .plain, value: 96_000)
        #expect(entry.amount == 96_000)
        #expect(!entry.isSpecial)
        #expect(!entry.isIncome)
    }

    @Test func cumulativeEntryStartsWithItsInitialSubValue() {
        let entry = NonFixedExpense.make(name: "Trip", isIncome: false, mode: .cumulative, value: 100)
        #expect(entry.isCumulative)
        #expect(entry.amount == 100)
        #expect(entry.subExpenses.map(\.value) == [100])
    }

    @Test func cumulativeEntryWithoutInitialValueStartsEmptyAtZero() {
        let entry = NonFixedExpense.make(name: "Trip", isIncome: true, mode: .cumulative, value: 0)
        #expect(entry.amount == 0)
        #expect(entry.subExpenses.isEmpty)
        #expect(entry.isIncome)
    }

    @Test func recurringEntryUsesTheValueAsBase() {
        let entry = NonFixedExpense.make(name: "Gym", isIncome: false, mode: .recurring, value: 50)
        #expect(entry.isRecurring)
        #expect(entry.baseAmount == 50)
        #expect(entry.multiplier == 1)
        #expect(entry.amount == 50)
    }

    // MARK: Sections of the Expenses view

    @Test func sectionsSplitByTypeWithSpecialEntriesFirst() {
        let taxi = NonFixedExpense(name: "Taxi", amount: 10)
        let trip = NonFixedExpense(name: "Trip", amount: 20, isCumulative: true)
        let gym = NonFixedExpense(name: "Gym", amount: 30, isRecurring: true)
        let refund = NonFixedExpense(name: "Refund", amount: 5, isIncome: true)
        let rentIn = NonFixedExpense(name: "Rent in", amount: 7, isRecurring: true, isIncome: true)

        let sections = ExtraEntrySections(entries: [taxi, trip, gym, refund, rentIn])

        #expect(sections.specialExpenses.map(\.name) == ["Trip", "Gym"])
        #expect(sections.plainExpenses.map(\.name) == ["Taxi"])
        #expect(sections.specialIncomes.map(\.name) == ["Rent in"])
        #expect(sections.plainIncomes.map(\.name) == ["Refund"])
        #expect(sections.expensesTotal == 60)
        #expect(sections.incomesTotal == 12)
        #expect(sections.hasIncomes)
    }

    @Test func incomeSectionIsHiddenWithoutIncomes() {
        let sections = ExtraEntrySections(entries: [NonFixedExpense(name: "Taxi", amount: 10)])
        #expect(!sections.hasIncomes)
    }
}

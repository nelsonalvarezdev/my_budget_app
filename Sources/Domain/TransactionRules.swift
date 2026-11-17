import Foundation

/// Change to apply to the Cash / Savings account fields.
struct AccountDelta: Equatable {
    var cash: Decimal = 0
    var savings: Decimal = 0
}

/// Figures shown on the Transactions summary card.
struct MonthSummary: Equatable {
    /// Sum of the displayed month's income transactions (informational).
    var income: Decimal = 0
    /// Sum of the displayed month's expense transactions (informational).
    var expenses: Decimal = 0
    /// Global balance, see `BalanceRules.balance`. Transactions do not feed
    /// this directly; they move Cash / Savings when they are created.
    var balance: Decimal = 0
}

/// Transactions of a single day, for the grouped list.
struct DayGroup: Identifiable {
    let day: Date
    let dayLabel: String
    let transactions: [Transaction]

    var id: Date { day }

    /// Income − expenses of the day.
    var net: Decimal {
        let totals = TransactionRules.totals(transactions)
        return totals.income - totals.expenses
    }
}

/// Total of one category, for the monthly report.
struct CategoryTotal: Equatable {
    let category: String
    let total: Decimal
}

/// Rules for the Transactions view (day-to-day movements of real money).
enum TransactionRules {
    /// What creating a transaction does to the account fields:
    /// - Cash / Savings expenses subtract from their field.
    /// - Credit-card expenses subtract from nothing (deferred payment).
    /// - Income adds to Cash.
    /// Applied once, when the transaction is created. Deleting a transaction
    /// intentionally does NOT revert it.
    static func accountEffect(amount: Decimal, kind: TransactionKind, paidWith: PaymentSource) -> AccountDelta {
        switch (kind, paidWith) {
        case (.expense, .cash): return AccountDelta(cash: -amount)
        case (.expense, .savings): return AccountDelta(savings: -amount)
        case (.expense, .creditCard): return AccountDelta()
        case (.income, _): return AccountDelta(cash: amount)
        }
    }

    /// Transactions dated in the same month as `month`.
    static func transactions(_ all: [Transaction], inMonthOf month: Date, calendar: Calendar = .current) -> [Transaction] {
        all.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
    }

    /// Income and expense sums of the given transactions.
    static func totals(_ transactions: [Transaction]) -> (income: Decimal, expenses: Decimal) {
        var income: Decimal = 0
        var expenses: Decimal = 0
        for transaction in transactions {
            switch transaction.kind {
            case .income: income += transaction.amount
            case .expense: expenses += transaction.amount
            }
        }
        return (income, expenses)
    }

    /// Groups transactions by day, newest day first and newest first within
    /// each day.
    static func dayGroups(_ transactions: [Transaction], calendar: Calendar = .current) -> [DayGroup] {
        Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.date) }
            .map { day, dayTransactions in
                DayGroup(
                    day: day,
                    dayLabel: day.formatted(.dateTime.weekday(.wide).day()),
                    transactions: dayTransactions.sorted { $0.date > $1.date }
                )
            }
            .sorted { $0.day > $1.day }
    }

    /// Per-category totals of one kind, largest first.
    static func totalsByCategory(_ transactions: [Transaction], kind: TransactionKind) -> [CategoryTotal] {
        Dictionary(grouping: transactions.filter { $0.kind == kind }, by: \.category)
            .map { category, group in
                CategoryTotal(category: category, total: group.reduce(0) { $0 + $1.amount })
            }
            .sorted { $0.total > $1.total }
    }
}

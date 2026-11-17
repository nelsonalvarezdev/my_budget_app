import Foundation
import SwiftData

enum TransactionKind: String, Codable, CaseIterable, Identifiable {
    case income
    case expense

    var id: Self { self }

    var label: String {
        switch self {
        case .income: return "Income"
        case .expense: return "Expense"
        }
    }

    var symbolName: String {
        switch self {
        case .income: return "arrow.down.forward.circle.fill"
        case .expense: return "arrow.up.forward.circle.fill"
        }
    }
}

/// Where an expense was paid from, or where an income was received.
/// Incomes only use `cash` and `savings` (received by transfer).
enum PaymentSource: String, Codable, CaseIterable, Identifiable {
    case cash
    case savings
    case creditCard

    var id: Self { self }

    var label: String {
        switch self {
        case .cash: return "Cash"
        case .savings: return "Savings account"
        case .creditCard: return "Credit card"
        }
    }

    /// The choices offered for an income.
    static let incomeOptions: [PaymentSource] = [.cash, .savings]

    /// How an income received this way is named.
    var incomeLabel: String {
        switch self {
        case .cash, .creditCard: return "Cash"
        case .savings: return "Transfer"
        }
    }
}

@Model
final class Transaction {
    /// Always stored as a positive value; sign is implied by `kind`.
    var amount: Decimal
    /// User-visible title of the transaction (e.g. the fixed expense's name,
    /// or a free-form name). The default lets SwiftData lightweight-migrate
    /// rows created before this field existed.
    var name: String = ""
    var kind: TransactionKind
    var category: String
    var note: String
    var date: Date
    /// How this expense was paid. Only meaningful for expenses.
    /// The initial value lets SwiftData lightweight-migrate rows created
    /// before this field existed (without it, the app crashes on launch).
    var paidWith: PaymentSource = PaymentSource.cash

    init(name: String = "", amount: Decimal, kind: TransactionKind, category: String, note: String = "", date: Date = .now, paidWith: PaymentSource = .cash) {
        self.name = name
        self.amount = amount
        self.kind = kind
        self.category = category
        self.note = note
        self.date = date
        self.paidWith = paidWith
    }
}

// MARK: - Categories

extension Transaction {
    static let incomeCategories = ["Salary", "Freelance", "Gift", "Investment", "Other"]
    static let expenseCategories = ["Groceries", "Rent", "Transport", "Dining", "Entertainment", "Health", "Utilities", "Other"]

    static func categories(for kind: TransactionKind) -> [String] {
        switch kind {
        case .income: return incomeCategories
        case .expense: return expenseCategories
        }
    }
}

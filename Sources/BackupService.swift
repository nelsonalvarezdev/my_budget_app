import Foundation
import SwiftData

/// Full-data backup: every model plus the AppStorage settings.
/// IMPORTANT: when adding a new model or persisted field to the app,
/// update this snapshot (and `restore`) so backups stay complete.
struct BackupSnapshot: Codable {
    var version = 1
    var exportedAt = Date()

    var transactions: [TransactionDTO] = []
    var fixedExpenses: [FixedExpenseDTO] = []
    var nonFixedExpenses: [NonFixedExpenseDTO] = []
    var categories: [CategoryDTO] = []

    // AppStorage settings
    var monthlyIncome: String = ""
    var cashBalance: String = ""
    var savingsBalance: String = ""
}

struct TransactionDTO: Codable {
    var amount: Decimal
    var kind: String
    var category: String
    var note: String
    var date: Date
    /// Optional so backups made before this field existed still import.
    var paidWith: String?
    /// Optional so backups made before this field existed still import.
    var name: String?
}

struct FixedExpenseDTO: Codable {
    var name: String
    var amount: Decimal
    var isChecked: Bool
    /// Optional so backups made before this field existed still import.
    var isIncome: Bool?
    /// Name of the assigned category; nil = uncategorized.
    var categoryName: String?
}

struct NonFixedExpenseDTO: Codable {
    var name: String
    var amount: Decimal
    /// Optional so backups made before this field existed still import.
    var isCumulative: Bool?
    /// Optional so backups made before this model existed still import.
    var subExpenses: [Decimal]?
    /// Optional so backups made before these fields existed still import.
    var isRecurring: Bool?
    var baseAmount: Decimal?
    var multiplier: Int?
    /// Optional so backups made before this field existed still import.
    var isIncome: Bool?
}

struct CategoryDTO: Codable {
    var name: String
    var colorHex: String
}

// MARK: - Snapshot <-> SwiftData

enum BackupService {
    static let defaultFileName = "budgetapp-backup.json"

    /// Builds a snapshot from the current store and settings.
    static func makeSnapshot(context: ModelContext) throws -> BackupSnapshot {
        var snapshot = BackupSnapshot()

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        snapshot.transactions = transactions.map {
            TransactionDTO(amount: $0.amount, kind: $0.kind.rawValue, category: $0.category, note: $0.note, date: $0.date, paidWith: $0.paidWith.rawValue, name: $0.name)
        }

        let fixedExpenses = try context.fetch(FetchDescriptor<FixedExpense>())
        snapshot.fixedExpenses = fixedExpenses.map {
            FixedExpenseDTO(name: $0.name, amount: $0.amount, isChecked: $0.isChecked, isIncome: $0.isIncome, categoryName: $0.category?.name)
        }

        let nonFixedExpenses = try context.fetch(FetchDescriptor<NonFixedExpense>())
        snapshot.nonFixedExpenses = nonFixedExpenses.map {
            NonFixedExpenseDTO(
                name: $0.name,
                amount: $0.amount,
                isCumulative: $0.isCumulative,
                subExpenses: $0.subExpenses.map(\.value),
                isRecurring: $0.isRecurring,
                baseAmount: $0.baseAmount,
                multiplier: $0.multiplier,
                isIncome: $0.isIncome
            )
        }

        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        snapshot.categories = categories.map {
            CategoryDTO(name: $0.name, colorHex: $0.colorHex)
        }

        let defaults = UserDefaults.standard
        snapshot.monthlyIncome = defaults.string(forKey: "monthlyIncome") ?? ""
        snapshot.cashBalance = defaults.string(forKey: "cashBalance") ?? ""
        snapshot.savingsBalance = defaults.string(forKey: "savingsBalance") ?? ""

        return snapshot
    }

    /// Replaces the entire store with the snapshot's contents.
    /// Categories are recreated first so expense→category links can be rebuilt.
    static func restore(_ snapshot: BackupSnapshot, context: ModelContext) throws {
        try context.transaction {
            // Wipe current data. SubExpense is deleted before its parent
            // model so no orphaned values are left in the store.
            try context.delete(model: Transaction.self)
            try context.delete(model: FixedExpense.self)
            try context.delete(model: SubExpense.self)
            try context.delete(model: NonFixedExpense.self)
            try context.delete(model: ExpenseCategory.self)

            // Categories first (expenses reference them by name).
            var categoriesByName: [String: ExpenseCategory] = [:]
            for dto in snapshot.categories {
                let category = ExpenseCategory(name: dto.name, colorHex: dto.colorHex)
                context.insert(category)
                categoriesByName[dto.name] = category
            }

            for dto in snapshot.transactions {
                guard let kind = TransactionKind(rawValue: dto.kind) else { continue }
                let paidWith = dto.paidWith.flatMap { PaymentSource(rawValue: $0) } ?? .cash
                context.insert(Transaction(name: dto.name ?? "", amount: dto.amount, kind: kind, category: dto.category, note: dto.note, date: dto.date, paidWith: paidWith))
            }

            for dto in snapshot.fixedExpenses {
                context.insert(FixedExpense(
                    name: dto.name,
                    amount: dto.amount,
                    isChecked: dto.isChecked,
                    isIncome: dto.isIncome ?? false,
                    category: dto.categoryName.flatMap { categoriesByName[$0] }
                ))
            }

            for dto in snapshot.nonFixedExpenses {
                let expense = NonFixedExpense(
                    name: dto.name,
                    amount: dto.amount,
                    isCumulative: dto.isCumulative ?? false,
                    isRecurring: dto.isRecurring ?? false,
                    isIncome: dto.isIncome ?? false
                )
                for value in dto.subExpenses ?? [] {
                    expense.subExpenses.append(SubExpense(value: value))
                }
                if let baseAmount = dto.baseAmount {
                    expense.baseAmount = baseAmount
                }
                if let multiplier = dto.multiplier {
                    expense.multiplier = multiplier
                }
                context.insert(expense)
            }
        }

        let defaults = UserDefaults.standard
        defaults.set(snapshot.monthlyIncome, forKey: "monthlyIncome")
        defaults.set(snapshot.cashBalance, forKey: "cashBalance")
        defaults.set(snapshot.savingsBalance, forKey: "savingsBalance")
    }

    /// Encodes a snapshot to pretty-printed JSON data.
    static func encode(_ snapshot: BackupSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    /// Decodes snapshot JSON data.
    static func decode(_ data: Data) throws -> BackupSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupSnapshot.self, from: data)
    }
}

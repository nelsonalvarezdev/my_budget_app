import Foundation
import Observation

/// Single owner of the manually entered money fields: Cash, Savings account
/// and Monthly income. They are persisted in UserDefaults as plain-digit
/// strings (same keys and format the app has always used, so existing data
/// and backups keep working).
@MainActor
@Observable
final class AccountsStore {
    private enum Key {
        static let cash = "cashBalance"
        static let savings = "savingsBalance"
        static let monthlyIncome = "monthlyIncome"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Raw stored text of each field; bind text fields to these.
    var cashText: String {
        didSet { defaults.set(cashText, forKey: Key.cash) }
    }
    var savingsText: String {
        didSet { defaults.set(savingsText, forKey: Key.savings) }
    }
    var monthlyIncomeText: String {
        didSet { defaults.set(monthlyIncomeText, forKey: Key.monthlyIncome) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        cashText = defaults.string(forKey: Key.cash) ?? ""
        savingsText = defaults.string(forKey: Key.savings) ?? ""
        monthlyIncomeText = defaults.string(forKey: Key.monthlyIncome) ?? ""
    }

    var cash: Decimal { Decimal(string: cashText) ?? 0 }
    var savings: Decimal { Decimal(string: savingsText) ?? 0 }
    var monthlyIncome: Decimal { Decimal(string: monthlyIncomeText) ?? 0 }

    /// Moves Cash / Savings by the given amounts (see
    /// `TransactionRules.accountEffect`). Fields with no change are left
    /// untouched.
    func apply(_ delta: AccountDelta) {
        if delta.cash != 0 {
            cashText = Currency.formatForEditing(cash + delta.cash)
        }
        if delta.savings != 0 {
            savingsText = Currency.formatForEditing(savings + delta.savings)
        }
    }
}

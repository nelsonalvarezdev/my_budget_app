import Foundation
import Observation
import SwiftData

/// State and actions of the Transactions view: the displayed month, the
/// summary card, the day-grouped list and the backup / delete-all actions.
/// The view owns the `@Query` results and passes them in.
@MainActor
@Observable
final class TransactionsViewModel {
    var displayedMonth: Date = .now

    var isShowingAddSheet = false
    var isShowingReport = false
    var isShowingDeleteAllConfirmation = false

    // Backup
    var isShowingExporter = false
    var backupFile: BackupFile?
    var isShowingImporter = false
    var pendingImportURL: URL?
    var isShowingImportConfirmation = false
    var backupMessage: String?
    var isShowingBackupResult = false

    // MARK: - Month navigation

    var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    func showPreviousMonth() { shiftMonth(by: -1) }
    func showNextMonth() { shiftMonth(by: 1) }
    func showCurrentMonth() { displayedMonth = .now }

    private func shiftMonth(by value: Int) {
        displayedMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
    }

    // MARK: - Derived data

    func monthTransactions(_ transactions: [Transaction]) -> [Transaction] {
        TransactionRules.transactions(transactions, inMonthOf: displayedMonth)
    }

    func dayGroups(_ transactions: [Transaction]) -> [DayGroup] {
        TransactionRules.dayGroups(monthTransactions(transactions))
    }

    /// Income / Expenses are the displayed month's transactions; the Balance
    /// is global (Cash + Savings adjusted by the Expenses-view entries).
    func summary(transactions: [Transaction], extraEntries: [NonFixedExpense], accounts: AccountsStore) -> MonthSummary {
        let totals = TransactionRules.totals(monthTransactions(transactions))
        return MonthSummary(
            income: totals.income,
            expenses: totals.expenses,
            balance: BalanceRules.balance(cash: accounts.cash, savings: accounts.savings, extraEntries: extraEntries)
        )
    }

    // MARK: - Deleting

    /// Removes transactions from the log. By design this does not revert
    /// their effect on Cash / Savings, and the Balance is unaffected.
    func delete(_ transactions: [Transaction], context: ModelContext) {
        for transaction in transactions {
            context.delete(transaction)
        }
    }

    // MARK: - Backup

    func exportBackup(context: ModelContext, accounts: AccountsStore) {
        do {
            let snapshot = try BackupService.makeSnapshot(context: context, accounts: accounts)
            backupFile = BackupFile(data: try BackupService.encode(snapshot))
            isShowingExporter = true
        } catch {
            backupMessage = "Export failed: \(error.localizedDescription)"
            isShowingBackupResult = true
        }
    }

    func handleExportResult(_ result: Result<URL, Error>) {
        // Start clean so a cancelled export doesn't re-show an older message.
        backupMessage = nil
        switch result {
        case .success(let url):
            backupMessage = "Backup saved to \(url.lastPathComponent)."
        case .failure(let error):
            if (error as? CocoaError)?.code != .userCancelled {
                backupMessage = "Export failed: \(error.localizedDescription)"
            }
        }
        isShowingBackupResult = backupMessage != nil
    }

    /// The user picked a backup file: ask for confirmation before replacing.
    func handleImportSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        pendingImportURL = url
        isShowingImportConfirmation = true
    }

    func cancelImport() {
        pendingImportURL = nil
    }

    func importBackup(context: ModelContext, accounts: AccountsStore) {
        guard let url = pendingImportURL else { return }
        pendingImportURL = nil
        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            let snapshot = try BackupService.decode(data)
            try BackupService.restore(snapshot, context: context, accounts: accounts)
            backupMessage = "Data imported successfully."
        } catch {
            backupMessage = "Import failed: \(error.localizedDescription)"
        }
        isShowingBackupResult = true
    }
}

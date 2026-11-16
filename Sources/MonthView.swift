import SwiftUI
import SwiftData

struct MonthView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]

    /// Observable reads of the balance fields, so the summary card updates
    /// live while the user edits Cash / Savings (plain UserDefaults reads
    /// don't trigger SwiftUI updates).
    @AppStorage("cashBalance") private var cashBalanceText = ""
    @AppStorage("savingsBalance") private var savingsBalanceText = ""

    @State private var displayedMonth: Date = .now
    @State private var isShowingAddSheet = false
    @State private var isShowingReport = false
    @State private var isShowingDeleteAllConfirmation = false
    @State private var isShowingBackupMenu = false
    @State private var backupFile: BackupFile?
    @State private var isShowingImporter = false
    @State private var pendingImportURL: URL?
    @State private var isShowingImportConfirmation = false
    @State private var backupMessage: String?
    @State private var isShowingBackupResult = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Pinned balance card: stays visible even when the list is scrolled.
                SummaryCard(summary: monthSummary)
                    .background(Color(.systemGroupedBackground))

                List {
                    BalanceDistributionSection()

                ForEach(dayGroups) { group in
                    Section(group.dayLabel) {
                        ForEach(group.transactions) { transaction in
                            TransactionRow(transaction: transaction)
                        }
                        .onDelete { offsets in
                            deleteTransactions(group: group, at: offsets)
                        }
                    }
                }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle(monthTitle)
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Button {
                        displayedMonth = .now
                    } label: {
                        Text(monthTitle).font(.headline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            isShowingReport = true
                        } label: {
                            Label("Monthly report", systemImage: "doc.text")
                        }
                        Button {
                            exportBackup()
                        } label: {
                            Label("Export data…", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            isShowingImporter = true
                        } label: {
                            Label("Import data…", systemImage: "square.and.arrow.down")
                        }
                        Divider()
                        Button(role: .destructive) {
                            isShowingDeleteAllConfirmation = true
                        } label: {
                            Label("Delete all transactions", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddTransactionView()
            }
            .sheet(isPresented: $isShowingReport) {
                MonthlyReportView(month: displayedMonth, transactions: monthTransactions)
            }
            .fileExporter(
                isPresented: $isShowingBackupMenu,
                document: backupFile,
                contentType: .json,
                defaultFilename: BackupService.defaultFileName
            ) { result in
                handleExportResult(result)
            }
            .fileImporter(
                isPresented: $isShowingImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    pendingImportURL = url
                    isShowingImportConfirmation = true
                case .failure:
                    break
                }
            }
            .alert("Replace all data?", isPresented: $isShowingImportConfirmation) {
                Button("Cancel", role: .cancel) { pendingImportURL = nil }
                Button("Import", role: .destructive) { importBackup() }
            } message: {
                Text("Importing replaces everything currently in the app with the backup's contents.")
            }
            .alert("Delete all transactions?", isPresented: $isShowingDeleteAllConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete all", role: .destructive) { deleteAllTransactions() }
            } message: {
                Text("Every transaction in the app will be removed. This does not change the Balance.")
            }
            .alert(backupMessage ?? "", isPresented: $isShowingBackupResult) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    // MARK: - Backup actions

    private func exportBackup() {
        do {
            let snapshot = try BackupService.makeSnapshot(context: modelContext)
            backupFile = BackupFile(data: try BackupService.encode(snapshot))
            isShowingBackupMenu = true
        } catch {
            backupMessage = "Export failed: \(error.localizedDescription)"
            isShowingBackupResult = true
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
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

    private func importBackup() {
        guard let url = pendingImportURL else { return }
        pendingImportURL = nil
        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            let snapshot = try BackupService.decode(data)
            try BackupService.restore(snapshot, context: modelContext)
            backupMessage = "Data imported successfully."
        } catch {
            backupMessage = "Import failed: \(error.localizedDescription)"
        }
        isShowingBackupResult = true
    }

    // MARK: - Derived data

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var monthTransactions: [Transaction] {
        transactions.filter { Calendar.current.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) }
    }

    private var monthSummary: MonthSummary {
        var summary = MonthSummary()
        for transaction in monthTransactions {
            switch transaction.kind {
            case .income: summary.income += transaction.amount
            case .expense: summary.expenses += transaction.amount
            }
        }

        // Balance = (Cash + Savings) − Expenses-tab total + Incomes-tab total.
        let cash = Decimal(string: cashBalanceText) ?? 0
        let savings = Decimal(string: savingsBalanceText) ?? 0
        let nonFixed = (try? modelContext.fetch(FetchDescriptor<NonFixedExpense>())) ?? []
        let nonFixedExpenses = nonFixed.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        let nonFixedIncomes = nonFixed.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        summary.balance = cash + savings - nonFixedExpenses + nonFixedIncomes
        return summary
    }

    private var dayGroups: [DayGroup] {
        let grouped = Dictionary(grouping: monthTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
        return grouped
            .map { day, dayTransactions in
                DayGroup(
                    day: day,
                    dayLabel: day.formatted(.dateTime.weekday(.wide).day()),
                    transactions: dayTransactions.sorted { $0.date > $1.date }
                )
            }
            .sorted { $0.day > $1.day }
    }

    // MARK: - Actions

    private func deleteTransactions(group: DayGroup, at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(group.transactions[index])
        }
    }

    /// Removes every transaction in the store. The Balance is unaffected:
    /// it is computed from Cash/Savings and the non-fixed items, not from
    /// transactions.
    private func deleteAllTransactions() {
        for transaction in transactions {
            modelContext.delete(transaction)
        }
    }
}

#Preview {
    MonthView()
        .modelContainer(for: Transaction.self, inMemory: true)
}

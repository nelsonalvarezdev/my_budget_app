import SwiftUI
import SwiftData

/// Transactions tab: the day-to-day log. Creating a transaction moves the
/// Cash / Savings fields; the pinned card shows the global Balance.
struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountsStore.self) private var accounts
    @Query private var transactions: [Transaction]
    /// Entries of the Expenses view; they adjust the Balance.
    @Query private var extraEntries: [NonFixedExpense]

    @State private var viewModel = TransactionsViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        let summary = viewModel.summary(transactions: transactions, extraEntries: extraEntries, accounts: accounts)
        NavigationStack {
            VStack(spacing: 0) {
                // Pinned balance card: stays visible even when the list is scrolled.
                BalanceHeroCard(balance: summary.balance)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemGroupedBackground))

                List {
                    Section {
                        MonthStatsRow(income: summary.income, expenses: summary.expenses)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }

                    ForEach(viewModel.dayGroups(transactions)) { group in
                        Section {
                            ForEach(group.transactions) { transaction in
                                TransactionRow(transaction: transaction)
                            }
                            .onDelete { offsets in
                                viewModel.delete(offsets.map { group.transactions[$0] }, context: modelContext)
                            }
                        } header: {
                            SectionHeader(title: group.dayLabel, trailing: Currency.formatSigned(group.net))
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .floatingAddButtonMargin()
                .contentMargins(.top, 4, for: .scrollContent)
            }
            .floatingAddButton("Add transaction") {
                viewModel.isShowingAddSheet = true
            }
            .navigationTitle(viewModel.monthTitle)
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.showPreviousMonth()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Button {
                        viewModel.showCurrentMonth()
                    } label: {
                        Text(viewModel.monthTitle).font(.headline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showNextMonth()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            viewModel.isShowingReport = true
                        } label: {
                            Label("Monthly report", systemImage: "doc.text")
                        }
                        Button {
                            viewModel.exportBackup(context: modelContext, accounts: accounts)
                        } label: {
                            Label("Export data…", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            viewModel.isShowingImporter = true
                        } label: {
                            Label("Import data…", systemImage: "square.and.arrow.down")
                        }
                        Divider()
                        Button(role: .destructive) {
                            viewModel.isShowingDeleteAllConfirmation = true
                        } label: {
                            Label("Delete all transactions", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowingAddSheet) {
                AddTransactionView()
            }
            .sheet(isPresented: $viewModel.isShowingReport) {
                MonthlyReportView(month: viewModel.displayedMonth, transactions: viewModel.monthTransactions(transactions))
            }
            .fileExporter(
                isPresented: $viewModel.isShowingExporter,
                document: viewModel.backupFile,
                contentType: .json,
                defaultFilename: BackupService.defaultFileName
            ) { result in
                viewModel.handleExportResult(result)
            }
            .fileImporter(
                isPresented: $viewModel.isShowingImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                viewModel.handleImportSelection(result)
            }
            .alert("Replace all data?", isPresented: $viewModel.isShowingImportConfirmation) {
                Button("Cancel", role: .cancel) { viewModel.cancelImport() }
                Button("Import", role: .destructive) {
                    viewModel.importBackup(context: modelContext, accounts: accounts)
                }
            } message: {
                Text("Importing replaces everything currently in the app with the backup's contents.")
            }
            .alert("Delete all transactions?", isPresented: $viewModel.isShowingDeleteAllConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete all", role: .destructive) {
                    viewModel.delete(transactions, context: modelContext)
                }
            } message: {
                Text("Every transaction in the app will be removed. This does not change the Balance.")
            }
            .alert(viewModel.backupMessage ?? "", isPresented: $viewModel.isShowingBackupResult) {
                Button("OK", role: .cancel) {}
            }
        }
    }
}

#Preview {
    TransactionsView()
        .environment(AccountsStore())
        .modelContainer(for: [Transaction.self, NonFixedExpense.self], inMemory: true)
}

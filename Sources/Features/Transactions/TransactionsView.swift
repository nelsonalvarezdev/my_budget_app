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
    /// Stored categories, used to colour each transaction's dot.
    @Query private var categories: [ExpenseCategory]

    @State private var viewModel = TransactionsViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        let summary = viewModel.summary(transactions: transactions, extraEntries: extraEntries, accounts: accounts)
        let categoryColors = Dictionary(categories.map { ($0.name, $0.color) }, uniquingKeysWith: { first, _ in first })
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
                                TransactionRow(transaction: transaction, categoryColor: categoryColors[transaction.category])
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
                // Room for the floating add button below the last row.
                .contentMargins(.bottom, 88, for: .scrollContent)
                .contentMargins(.top, 4, for: .scrollContent)
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    viewModel.isShowingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.brand, in: Circle())
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                }
                .padding(20)
                .accessibilityLabel("Add transaction")
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

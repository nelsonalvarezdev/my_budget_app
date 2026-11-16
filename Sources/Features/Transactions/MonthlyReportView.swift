import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Modal report for the Transactions view: totals every transaction of the
/// selected month (income, expenses, net) and breaks expenses/incomes down
/// by category. The report can be downloaded as a CSV file.
struct MonthlyReportView: View {
    let month: Date
    let transactions: [Transaction]

    @Environment(\.dismiss) private var dismiss

    @State private var isShowingExporter = false
    @State private var reportFile: ReportFile?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    reportRow(label: "Total income", amount: totalIncome, color: .green)
                    reportRow(label: "Total expenses", amount: totalExpenses, color: .red)
                    reportRow(label: "Net", amount: totalIncome - totalExpenses, color: .primary)
                } footer: {
                    Text("\(transactions.count) transactions in \(monthTitle).")
                }

                if !expenseByCategory.isEmpty {
                    Section {
                        ForEach(expenseByCategory, id: \.category) { group in
                            HStack {
                                Text(group.category)
                                Spacer()
                                Text(Currency.format(group.total))
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Expenses by category")
                    }
                }

                if !incomeByCategory.isEmpty {
                    Section {
                        ForEach(incomeByCategory, id: \.category) { group in
                            HStack {
                                Text(group.category)
                                Spacer()
                                Text(Currency.format(group.total))
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Income by category")
                    }
                }
            }
            .navigationTitle("Monthly report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        exportCSV()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
            .fileExporter(
                isPresented: $isShowingExporter,
                document: reportFile,
                contentType: .commaSeparatedText,
                defaultFilename: defaultFileName
            ) { _ in }
        }
    }

    // MARK: - Totals

    private func reportRow(label: String, amount: Decimal, color: Color) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(color)
            Spacer()
            Text(Currency.format(amount))
                .font(.title3.monospacedDigit().weight(color == .primary ? .bold : .regular))
                .foregroundStyle(color)
        }
    }

    private var totalIncome: Decimal {
        TransactionRules.totals(transactions).income
    }

    private var totalExpenses: Decimal {
        TransactionRules.totals(transactions).expenses
    }

    private var expenseByCategory: [CategoryTotal] {
        TransactionRules.totalsByCategory(transactions, kind: .expense)
    }

    private var incomeByCategory: [CategoryTotal] {
        TransactionRules.totalsByCategory(transactions, kind: .income)
    }

    private var monthTitle: String {
        month.formatted(.dateTime.month(.wide).year())
    }

    private var defaultFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return "report-\(formatter.string(from: month))"
    }

    // MARK: - CSV export

    private func exportCSV() {
        var lines = ["Type,Category,Name,Amount,Date,Paid with"]
        let formatter = ISO8601DateFormatter()
        for transaction in transactions.sorted(by: { $0.date > $1.date }) {
            let fields = [
                transaction.kind.label,
                transaction.category,
                transaction.name,
                "\(transaction.amount)",
                formatter.string(from: transaction.date),
                transaction.paidWith.label,
            ]
            lines.append(fields.map(csvField).joined(separator: ","))
        }
        lines.append("")
        lines.append("Total income,\(totalIncome)")
        lines.append("Total expenses,\(totalExpenses)")
        lines.append("Net,\(totalIncome - totalExpenses)")

        reportFile = ReportFile(csv: lines.joined(separator: "\n"))
        isShowingExporter = true
    }

    /// Quotes a field for CSV, escaping embedded quotes.
    private func csvField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
}

/// Thin wrapper so a CSV string can be handed to `fileExporter`.
struct ReportFile: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var csv: String

    init(csv: String) {
        self.csv = csv
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        csv = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(csv.utf8))
    }
}

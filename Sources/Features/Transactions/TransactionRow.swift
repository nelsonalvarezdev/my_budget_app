import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                // Main title: the transaction's name. Falls back to the
                // category for rows created before the name field existed.
                Text(transaction.name.isEmpty ? transaction.category : transaction.name)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(Currency.formatSigned(transaction.kind == .income ? transaction.amount : -transaction.amount))
                .font(.body.monospacedDigit())
                .foregroundStyle(transaction.kind == .income ? Color.brand : Color.primary)
        }
        .padding(.vertical, 2)
    }

    /// Category, plus how an expense was paid or an income received.
    private var detail: String {
        let source = transaction.kind == .expense ? transaction.paidWith.label : transaction.paidWith.incomeLabel
        return "\(transaction.category) · \(source)"
    }
}

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.kind.symbolName)
                .foregroundStyle(transaction.kind == .income ? .green : .red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                // Main title: the transaction's name. Falls back to the
                // category for rows created before the name field existed.
                Text(transaction.name.isEmpty ? transaction.category : transaction.name)
                    .font(.body)
                Text(transaction.category)
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

            if transaction.kind == .expense {
                Text(transaction.paidWith.label)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(badgeColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(badgeColor)
            }

            Text(Currency.format(transaction.amount))
                .font(.body.monospacedDigit())
                .foregroundStyle(transaction.kind == .income ? .green : .primary)
        }
        .padding(.vertical, 2)
    }

    private var badgeColor: Color {
        switch transaction.paidWith {
        case .cash: return .orange
        case .savings: return .teal
        case .creditCard: return .purple
        }
    }
}

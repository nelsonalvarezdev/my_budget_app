import SwiftUI

struct SummaryCard: View {
    let summary: MonthSummary

    private func peso(_ amount: Decimal) -> String {
        Currency.format(amount)
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(peso(summary.balance))
                    .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(summary.balance >= 0 ? Color.primary : Color.red)
            }

            HStack(spacing: 0) {
                summaryPill(
                    title: "Income",
                    amount: summary.income,
                    color: .green,
                    symbol: "arrow.down.forward"
                )
                Divider()
                    .frame(height: 32)
                summaryPill(
                    title: "Expenses",
                    amount: summary.expenses,
                    color: .red,
                    symbol: "arrow.up.forward"
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func summaryPill(title: String, amount: Decimal, color: Color, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(peso(amount))
                    .font(.headline.monospacedDigit())
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    SummaryCard(summary: MonthSummary(income: 4200, expenses: 1230.55))
        .background(Color(.systemGroupedBackground))
}

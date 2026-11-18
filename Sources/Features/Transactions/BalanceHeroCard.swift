import SwiftUI

/// Headline card of the Transactions tab: the global Balance, with the Cash
/// and Savings account fields (manually entered, moved by new transactions)
/// and their sum, the money available to spend.
struct BalanceHeroCard: View {
    let balance: Decimal
    /// While true (e.g. the New Transaction sheet is open), a change of the
    /// Balance is held back and plays once it turns false, so it is seen.
    var holdsChanges = false
    @Environment(AccountsStore.self) private var accounts

    var body: some View {
        @Bindable var accounts = accounts
        HeroCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Balance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    LiveBalanceAmount(balance: balance, holdsChanges: holdsChanges)
                }

                HStack(spacing: 10) {
                    AccountTile(title: "Cash", systemImage: "banknote", storedText: $accounts.cashText)
                    AccountTile(title: "Savings", systemImage: "building.columns", storedText: $accounts.savingsText)
                }

                HStack {
                    Text("Available to spend")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Currency.format(BalanceRules.availableToSpend(cash: accounts.cash, savings: accounts.savings)))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .font(.footnote)
            }
        }
    }
}

/// The Balance figure, animated "live": when the Balance changes, the
/// number counts from the old value to the new one while the changing
/// digits roll, tinted green when it goes up and red when it goes down.
struct LiveBalanceAmount: View {
    let balance: Decimal
    var holdsChanges = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The value currently drawn; animated towards `balance`.
    @State private var shown: Double?
    @State private var tint: Color?

    /// Time the sheet needs to slide away before the count starts.
    private static let sheetDismissDelay: Duration = .milliseconds(350)
    private static let countDuration = 0.9

    var body: some View {
        CountingAmount(value: shown ?? Self.double(balance), target: balance, tint: tint)
            .onAppear { shown = Self.double(balance) }
            .onChange(of: balance) { _, _ in
                if !holdsChanges { playChange() }
            }
            .onChange(of: holdsChanges) { _, holding in
                guard !holding else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: Self.sheetDismissDelay)
                    playChange()
                }
            }
    }

    private func playChange() {
        let target = Self.double(balance)
        guard let from = shown, from != target else { return }
        guard !reduceMotion else {
            shown = target
            return
        }
        tint = target > from ? Color.brand : Color.red
        withAnimation(.easeOut(duration: Self.countDuration)) {
            shown = target
        } completion: {
            withAnimation(.easeOut(duration: 0.4)) { tint = nil }
        }
    }

    private static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}

/// Draws an animated amount: SwiftUI interpolates `value` frame by frame,
/// and each frame shows it rounded to whole pesos. Once it lands on the
/// target, the exact amount is shown.
private struct CountingAmount: View, @preconcurrency Animatable {
    var value: Double
    let target: Decimal
    let tint: Color?

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    private var amount: Decimal {
        let targetDouble = NSDecimalNumber(decimal: target).doubleValue
        return abs(value - targetDouble) < 0.5 ? target : Decimal(value.rounded())
    }

    var body: some View {
        HeroAmount(amount: Currency.format(amount), isNegative: amount < 0, tint: tint)
            .contentTransition(.numericText(value: value))
    }
}

/// Editable account balance inside the hero card: shows pesos when idle, raw
/// digits while editing. The value is only committed to storage when editing
/// ends (tap outside or Enter), so the Balance updates at that moment instead
/// of on every keystroke.
struct AccountTile: View {
    let title: String
    let systemImage: String
    @Binding var storedText: String
    @FocusState private var isFocused: Bool
    /// Digits typed while editing; written to `storedText` only on commit.
    @State private var editingText = ""

    private var value: Decimal {
        Decimal(string: storedText) ?? 0
    }

    private var displayBinding: Binding<String> {
        Binding(
            get: {
                isFocused ? editingText : Currency.format(value)
            },
            set: { newValue in
                // Only accept plain digit strings while editing; see
                // CurrencyField for why (the formatted-string echo on blur
                // would otherwise zero the value).
                guard isFocused, newValue.isEmpty || Currency.isPlainAmount(newValue) else {
                    return
                }
                editingText = newValue
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(text: displayBinding) { Text("0") }
                .keyboardType(.numberPad)
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(value < 0 ? Color.red : Color.primary)
                .focused($isFocused)
                .onSubmit(commit)
                .onChange(of: isFocused) { _, focused in
                    if focused {
                        // Start editing from the stored raw digits.
                        editingText = storedText
                    } else {
                        commit()
                    }
                }
                .accessibilityLabel(title)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }

    /// Writes the typed digits to storage; called when editing ends.
    private func commit() {
        storedText = editingText.trimmingCharacters(in: .whitespaces)
        editingText = ""
    }
}

/// Income and spending of the displayed month (informational).
struct MonthStatsRow: View {
    let income: Decimal
    let expenses: Decimal

    var body: some View {
        HStack(spacing: 10) {
            stat(title: "Income", amount: Currency.formatSigned(income), color: .brand)
            stat(title: "Spent", amount: Currency.formatSigned(-expenses), color: .red)
        }
    }

    private func stat(title: String, amount: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(amount)
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

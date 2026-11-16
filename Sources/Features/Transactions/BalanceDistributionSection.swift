import SwiftUI

/// Section on the Transactions tab showing how the available balance is
/// distributed: Cash and Savings account balances (manually entered),
/// plus the total available to spend (Cash + Savings).
struct BalanceDistributionSection: View {
    @Environment(AccountsStore.self) private var accounts

    /// Cash + Savings: the money available to expend.
    private var availableToSpend: Decimal {
        BalanceRules.availableToSpend(cash: accounts.cash, savings: accounts.savings)
    }

    var body: some View {
        @Bindable var accounts = accounts
        Section {
            BalanceField(title: "Cash", storedText: $accounts.cashText)
            BalanceField(title: "Savings account", storedText: $accounts.savingsText)

            HStack {
                Text("Available to spend")
                    .font(.headline)
                Spacer()
                Text(Currency.format(availableToSpend))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color.accentColor)
            }
        } header: {
            Text("Balance distribution")
        } footer: {
            Text("Enter how much of your money is in cash and in your savings account. \"Available to spend\" is their sum.")
        }
    }
}

/// Currency-formatted balance field: shows pesos when idle, raw digits while
/// editing. The value is only committed to storage when editing ends (tap
/// outside or Enter), so dependent views (e.g. the balance card) update at
/// that moment instead of on every keystroke.
struct BalanceField: View {
    let title: String
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
        HStack {
            Text(title)
            Spacer()
            TextField(text: displayBinding) { Text("0") }
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(width: 160)
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
        }
    }

    /// Writes the typed digits to storage; called when editing ends.
    private func commit() {
        storedText = editingText.trimmingCharacters(in: .whitespaces)
        editingText = ""
    }
}

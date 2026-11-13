import SwiftUI

/// Currency-formatted numeric field: shows the formatted peso value when
/// idle and raw digits while editing.
struct CurrencyField: View {
    @Binding var storedText: String
    @FocusState private var isFocused: Bool

    private var value: Decimal {
        Decimal(string: storedText) ?? 0
    }

    private var displayBinding: Binding<String> {
        Binding(
            get: {
                isFocused || storedText.isEmpty ? storedText : Currency.format(value)
            },
            set: { newValue in
                // Only accept plain digit strings while the field is being
                // edited. When focus is lost, SwiftUI can echo the displayed
                // *formatted* string (e.g. "$ 2.000.000") back through the
                // binding — sometimes before the focus change is delivered,
                // so checking `isFocused` alone is not enough. Storing that
                // echo would make `Decimal(string:)` fail → the idle field
                // would show 0 even though the value reappears on re-focus.
                guard isFocused, newValue.isEmpty || Currency.isPlainAmount(newValue) else {
                    return
                }
                storedText = newValue
            }
        )
    }

    var body: some View {
        TextField("0", text: displayBinding)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .focused($isFocused)
    }
}

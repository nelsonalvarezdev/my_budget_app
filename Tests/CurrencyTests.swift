import Foundation
import Testing
@testable import BudgetApp

struct CurrencyTests {
    @Test func formatsPesosWithDotGrouping() {
        #expect(Currency.format(1_500_000) == "$ 1.500.000")
        #expect(Currency.format(0) == "$ 0")
    }

    @Test func signedFormatPutsTheSignBeforeTheSymbol() {
        #expect(Currency.formatSigned(250_000) == "+ $ 250.000")
        #expect(Currency.formatSigned(-64_000) == "− $ 64.000")
        #expect(Currency.formatSigned(0) == "$ 0")
    }

    @Test func editingFormatIsPlainDigitsAndEmptyForZero() {
        #expect(Currency.formatForEditing(1_500_000) == "1500000")
        #expect(Currency.formatForEditing(0) == "")
    }

    @Test func parsesTypedAmounts() {
        #expect(Currency.parseAmount("1500000") == 1_500_000)
        #expect(Currency.parseAmount("-200") == -200)
        #expect(Currency.parseAmount("") == nil)
        #expect(Currency.parseAmount("abc") == nil)
    }

    @Test func recognisesPlainAmountsVersusFormattedText() {
        #expect(Currency.isPlainAmount("1500000"))
        #expect(!Currency.isPlainAmount("$ 1.500.000"))
        #expect(!Currency.isPlainAmount(""))
    }
}

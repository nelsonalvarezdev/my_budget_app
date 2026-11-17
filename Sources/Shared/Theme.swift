import SwiftUI

extension Color {
    /// The app's single accent: the green of the app icon. Used for money
    /// coming in and for things that are done; red stays for money going out.
    static let brand = Color.accentColor
}

/// Tinted card that opens each tab with its headline figure.
struct HeroCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brand.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Headline amount of a hero card.
struct HeroAmount: View {
    let amount: String
    var isNegative = false

    var body: some View {
        Text(amount)
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(isNegative ? Color.red : Color.primary)
    }
}

/// List section header with a title and an optional trailing figure.
struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let trailing {
                Text(trailing).monospacedDigit()
            }
        }
        .font(.subheadline.weight(.semibold))
        .textCase(nil)
    }
}

/// Small coloured dot marking a row's category.
struct CategoryDot: View {
    let color: Color?

    var body: some View {
        Circle()
            .fill(color ?? Color.secondary.opacity(0.35))
            .frame(width: 10, height: 10)
            .accessibilityHidden(true)
    }
}

/// Small grey tag under a row's name.
struct TagPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color(.tertiarySystemFill), in: Capsule())
    }
}

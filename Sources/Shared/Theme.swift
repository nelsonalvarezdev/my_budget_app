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

/// Progress bar for a share between 0 and 1. `solid` is the share reached so
/// far; `light` is an optional lighter segment behind it (e.g. an estimate).
struct ShareBar: View {
    let solid: Double
    var light: Double = 0
    var label = "Progress"
    var tint: Color = .brand

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemBackground).opacity(0.75))
                Capsule().fill(tint.opacity(0.35))
                    .frame(width: proxy.size.width * light)
                Capsule().fill(tint)
                    .frame(width: proxy.size.width * solid)
            }
        }
        .frame(height: 10)
        .animation(.easeInOut(duration: 0.25), value: solid)
        .animation(.easeInOut(duration: 0.25), value: light)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(solid * 100)) percent")
    }
}

/// Round accent-coloured + button that floats over the bottom-trailing corner
/// of a tab; the one way to add something on every tab.
struct FloatingAddButton: View {
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.brand, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
        .padding(20)
        .accessibilityLabel(accessibilityLabel)
    }
}

extension View {
    /// Adds the floating + button. Lists under it should also use
    /// `floatingAddButtonMargin()` so their last row can scroll clear of it.
    func floatingAddButton(_ accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        overlay(alignment: .bottomTrailing) {
            FloatingAddButton(accessibilityLabel: accessibilityLabel, action: action)
        }
    }

    /// Room below a list's last row for the floating + button.
    func floatingAddButtonMargin() -> some View {
        contentMargins(.bottom, 88, for: .scrollContent)
    }
}

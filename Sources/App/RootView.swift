import SwiftUI
import SwiftData

/// The app's three views (Transactions, Monthly, Expenses) laid out side by
/// side in a horizontal pager with a custom tab bar. All three stay alive.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    /// Selected view, also driven by the swipe gesture so the user can move
    /// between views by dragging horizontally.
    @State private var selectedView = ProcessInfo.processInfo.arguments.contains("-monthlyTab") ? 1 : 0
    /// Live horizontal offset while the user is dragging between views.
    @State private var dragOffset: CGFloat = 0

    private let pages: [(label: String, systemImage: String)] = [
        ("Transactions", "list.bullet.rectangle"),
        ("Monthly", "calendar.badge.checkmark"),
        ("Expenses", "cart"),
    ]

    var body: some View {
        GeometryReader { proxy in
            let pageWidth = proxy.size.width
            // Paged content constrained to one screen width so the wide
            // HStack can slide between views. The tab bar is a VStack
            // sibling (not an overlay/inset): the pages physically get
            // the remaining height, so list rows can never scroll or
            // rest behind the bar regardless of scroll position.
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    TransactionsView()
                        .frame(width: pageWidth)
                    MonthlyView()
                        .frame(width: pageWidth)
                    ExpensesView()
                        .frame(width: pageWidth)
                }
                .offset(x: -CGFloat(selectedView) * pageWidth + dragOffset)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedView)
                .frame(width: pageWidth, alignment: .leading)

                tabBar
            }
        }
        .background {
            PageSwipeGesture(onChanged: pageSwipeChanged, onEnded: pageSwipeEnded)
        }
        .task { ExpenseCategory.ensureDefaultsExist(in: modelContext) }
    }

    // MARK: - Tab bar

    /// Custom tab bar pinned to the bottom of the screen. Tapping an item
    /// animates the page slide.
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<pages.count, id: \.self) { index in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selectedView = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: pages[index].systemImage)
                            .font(.system(size: 20))
                        Text(pages[index].label)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(index == selectedView ? Color.brand : Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.bar)
    }

    // MARK: - Swipe between views

    /// The views follow the finger while it drags horizontally; see
    /// `PageSwipeGesture` for where a swipe can start.
    private func pageSwipeChanged(_ horizontal: CGFloat) {
        // Rubber-band when there is no adjacent page in that direction.
        let atEdge = (selectedView == 0 && horizontal > 0)
            || (selectedView == pages.count - 1 && horizontal < 0)
        dragOffset = atEdge ? horizontal * 0.3 : horizontal
    }

    /// Settles on the adjacent page when the drag went far enough.
    private func pageSwipeEnded(_ horizontal: CGFloat) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if horizontal < -60, selectedView < pages.count - 1 {
                selectedView += 1
            } else if horizontal > 60, selectedView > 0 {
                selectedView -= 1
            }
            dragOffset = 0
        }
    }
}

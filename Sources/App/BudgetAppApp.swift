import SwiftUI
import SwiftData

@main
struct BudgetAppApp: App {
    /// Selected view, also driven by the swipe gesture so the user can move
    /// between views by dragging horizontally from the title area.
    @State private var selectedView = ProcessInfo.processInfo.arguments.contains("-monthlyTab") ? 1 : 0
    /// Live horizontal offset while the user is dragging between views.
    @State private var dragOffset: CGFloat = 0
    /// Cash, Savings and Monthly income, shared by every view.
    @State private var accounts = AccountsStore()

    private let pages: [(label: String, systemImage: String)] = [
        ("Transactions", "list.bullet.rectangle"),
        ("Monthly", "calendar.badge.checkmark"),
        ("Expenses", "cart"),
    ]

    var body: some Scene {
        WindowGroup {
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
                    .overlay(alignment: .top) {
                        titleSwipeStrip
                    }

                    tabBar
                }
            }
        }
        .environment(accounts)
        .modelContainer(for: [Transaction.self, FixedExpense.self, NonFixedExpense.self, SubExpense.self, ExpenseCategory.self])
    }

    // MARK: - Swipe surfaces

    /// Transparent strip over the center of the navigation bar — the area
    /// around the view's title. It deliberately covers only the middle half
    /// of the width so the toolbar buttons at the leading/trailing edges
    /// (month arrows, plus button) stay fully tappable. This is a swipe
    /// surface: dragging horizontally here moves between views.
    private var titleSwipeStrip: some View {
        Color.clear
            .frame(width: 180, height: 52)
            .contentShape(Rectangle())
            .gesture(swipeGesture)
            .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - Tab bar

    /// Custom tab bar pinned to the bottom of the screen. Tapping an item
    /// animates the page slide; it is also a swipe surface.
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
                    .foregroundStyle(index == selectedView ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.bar)
        .simultaneousGesture(swipeGesture)
    }

    // MARK: - Swipe gesture

    /// Horizontal drag that slides the views live with the finger and settles
    /// on the adjacent page. It is only attached to safe surfaces — the title
    /// strip at the top and the tab bar at the bottom — so list rows keep
    /// their own gestures (swipe-to-delete, taps, scrolling) untouched.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) else { return }
                // Rubber-band when there is no adjacent page in that direction.
                let atEdge = (selectedView == 0 && horizontal > 0)
                    || (selectedView == pages.count - 1 && horizontal < 0)
                dragOffset = atEdge ? horizontal * 0.3 : horizontal
            }
            .onEnded { value in
                let horizontal = value.translation.width
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
}

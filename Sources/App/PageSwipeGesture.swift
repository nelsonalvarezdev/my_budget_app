import SwiftUI
import UIKit

/// Horizontal swipe between the app's views that works from anywhere on the
/// screen that has nothing else to do with a horizontal drag: empty space,
/// headers, cards, the title area and the tab bar.
///
/// SwiftUI gestures cannot see touches that land on a `List`, so this installs
/// a UIKit pan recogniser on the root view instead. It stays out of the way of:
/// - buttons in the navigation bar and text fields (it ignores those touches),
/// - a row's own swipe actions (it waits for the list's swipe to give up),
/// - pushed detail screens, where a horizontal swipe means "go back".
/// Sheets are presented outside the root view, so they never reach it.
struct PageSwipeGesture: UIViewRepresentable {
    /// Called while dragging, with the horizontal distance so far.
    var onChanged: (CGFloat) -> Void
    /// Called when the drag ends, with the final horizontal distance
    /// (0 when the drag was cancelled).
    var onEnded: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ view: InstallerView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }

    /// Invisible view whose only job is to find the root view once it is on
    /// screen and attach the recogniser there.
    final class InstallerView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            coordinator?.install(on: window?.rootViewController?.view)
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGFloat) -> Void = { _ in }
        var onEnded: (CGFloat) -> Void = { _ in }

        private lazy var pan: UIPanGestureRecognizer = {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.delegate = self
            return pan
        }()

        func install(on view: UIView?) {
            guard pan.view !== view else { return }
            pan.view?.removeGestureRecognizer(pan)
            view?.addGestureRecognizer(pan)
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let horizontal = recognizer.translation(in: recognizer.view).x
            switch recognizer.state {
            case .changed: onChanged(horizontal)
            case .ended: onEnded(horizontal)
            case .cancelled, .failed: onEnded(0)
            default: break
            }
        }

        // MARK: UIGestureRecognizerDelegate

        /// Only mostly-horizontal drags; vertical ones belong to scrolling.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                // Toolbar buttons and text fields keep their touches.
                if current is UIControl { return false }
                view = current.superview
            }
            // On a pushed detail screen a horizontal swipe means "back".
            var responder: UIResponder? = touch.view
            while let current = responder {
                if let navigation = current as? UINavigationController {
                    return navigation.viewControllers.count <= 1
                }
                responder = current.next
            }
            return true
        }

        /// Scrolling may run alongside; it only moves vertically.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        /// A list's own horizontal pan (the one that reveals a row's swipe
        /// actions) goes first: this swipe only starts once that one gives up,
        /// which it does when the row has no action in that direction.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            guard otherGestureRecognizer is UIPanGestureRecognizer,
                  let scrollView = otherGestureRecognizer.view as? UIScrollView else { return false }
            return otherGestureRecognizer !== scrollView.panGestureRecognizer
        }
    }
}

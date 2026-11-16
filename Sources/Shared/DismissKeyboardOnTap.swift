import SwiftUI
import UIKit

/// Ends editing (resigns first responder) when the user taps anywhere
/// outside the active field.
///
/// Implemented with a window-level UIKit tap recognizer instead of a SwiftUI
/// `simultaneousGesture(TapGesture())`: the SwiftUI version competes with
/// NavigationLink / Button taps (forcing long presses), while the UIKit
/// recognizer with `cancelsTouchesInView = false` never consumes touches.
struct DismissKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content.background(KeyboardDismissAnchor())
    }
}

extension View {
    /// Tap anywhere outside a field to finish editing it.
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTap())
    }
}

/// Invisible anchor view that installs the tap recognizer on the window.
private struct KeyboardDismissAnchor: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        // Install on the next runloop turn, once the view is in a window.
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            let tap = UITapGestureRecognizer(
                target: KeyboardDismissTarget.shared,
                action: #selector(KeyboardDismissTarget.handleTap(_:))
            )
            tap.cancelsTouchesInView = false
            tap.delegate = KeyboardDismissTarget.shared
            window.addGestureRecognizer(tap)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

/// Resigns first responder on tap, unless the tap landed inside the view
/// that currently holds first responder (the active field itself).
private final class KeyboardDismissTarget: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissTarget()

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let responderView = UIResponder.currentFirstResponder as? UIView else { return }
        let location = gesture.location(in: gesture.view)
        let responderFrame = responderView.convert(responderView.bounds, to: gesture.view)
        // Tapping inside the active field keeps editing; anything else resigns.
        guard !responderFrame.insetBy(dx: -8, dy: -8).contains(location) else { return }
        responderView.resignFirstResponder()
    }
}

extension UIResponder {
    private weak static var _currentFirstResponder: UIResponder?

    /// The responder that currently holds first responder status, if any.
    static var currentFirstResponder: UIResponder? {
        _currentFirstResponder = nil
        UIApplication.shared.sendAction(
            #selector(findFirstResponder(_:)), to: nil, from: nil, for: nil
        )
        return _currentFirstResponder
    }

    @objc private func findFirstResponder(_ sender: Any) {
        UIResponder._currentFirstResponder = self
    }
}

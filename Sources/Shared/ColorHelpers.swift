import SwiftUI
import UIKit

// MARK: - Menu icon rendering

extension UIImage {
    /// Renders a small circle as a UIImage. Context menus (UIKit) strip
    /// SwiftUI color styling, so colored menu icons must be real images.
    static func categoryDot(color: Color, filled: Bool) -> UIImage {
        let diameter: CGFloat = 18
        let inset: CGFloat = 1.5
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter), format: format)
            .image { _ in
                let rect = CGRect(x: 0, y: 0, width: diameter, height: diameter)
                    .insetBy(dx: inset, dy: inset)
                let path = UIBezierPath(ovalIn: rect)
                if filled {
                    UIColor(color).setFill()
                    path.fill()
                } else {
                    UIColor(color).setStroke()
                    path.lineWidth = 1.5
                    path.stroke()
                }
            }
    }
}

// MARK: - Hex color helpers

extension Color {
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespaces)
        if hex.hasPrefix("#") { hex.removeFirst() }

        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)

        let red, green, blue: Double
        switch hex.count {
        case 6:
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
        default:
            red = 1; green = 1; blue = 1
        }
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    var hexString: String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X",
                      Int(round(red * 255)),
                      Int(round(green * 255)),
                      Int(round(blue * 255)))
    }
}

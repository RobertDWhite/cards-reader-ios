import SwiftUI
import UIKit

/// The site's paper-and-ink palette, light and dark.
enum Theme {
    static let paper = dynamic(light: 0xf6f1e7, dark: 0x16140f)
    static let paper2 = dynamic(light: 0xfffdf8, dark: 0x1f1c16)
    static let ink = dynamic(light: 0x23201c, dark: 0xefe8db)
    static let ink2 = dynamic(light: 0x5e574d, dark: 0xa79c8a)
    static let line = dynamic(light: 0xe0d7c6, dark: 0x332e25)
    static let accent = dynamic(light: 0x8c5a3c, dark: 0xd5a06a)
    static let warn = dynamic(light: 0xb4552f, dark: 0xe08055)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xff) / 255,
                  green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255, alpha: 1)
    }
}

extension Font {
    static func serif(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif, weight: weight)
    }
}

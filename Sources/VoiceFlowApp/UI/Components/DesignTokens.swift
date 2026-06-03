import SwiftUI
import AppKit

enum DS {
    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let pill: CGFloat = 999
    }

    // MARK: - Typography

    enum Font {
        static let caption = SwiftUI.Font.system(size: 11, weight: .medium)
        static let body = SwiftUI.Font.system(size: 13, weight: .regular)
        static let bodyMedium = SwiftUI.Font.system(size: 13, weight: .medium)
        static let headline = SwiftUI.Font.system(size: 15, weight: .semibold)
        static let title = SwiftUI.Font.system(size: 17, weight: .bold)
        static let hudStatus = SwiftUI.Font.system(size: 12, weight: .semibold)
        static let hudTranscript = SwiftUI.Font.system(size: 14, weight: .medium)
    }

    // MARK: - Colors

    enum Colors {
        static let primary = Color.primary
        static let secondary = Color.secondary
        static let recording = Color.red
        static let processing = Color.orange
        static let success = Color.green
        static let error = Color.red
        static let accent = Color.accentColor

        static let windowBg = Color(nsColor: .init(name: nil) { ap in
            ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 0.098, green: 0.082, blue: 0.071, alpha: 1)  // #191412
                : NSColor(srgbRed: 0.969, green: 0.957, blue: 0.941, alpha: 1)  // #F7F4F0
        })
        static let cardBg = Color(nsColor: .init(name: nil) { ap in
            ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 0.145, green: 0.125, blue: 0.114, alpha: 1)  // #25201D
                : NSColor(srgbRed: 1.0, green: 0.992, blue: 0.98, alpha: 1)     // #FFFDFB
        })
        static let sidebarBg = Color(nsColor: .init(name: nil) { ap in
            ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 0.075, green: 0.063, blue: 0.055, alpha: 1)  // #13100E
                : NSColor(srgbRed: 0.933, green: 0.914, blue: 0.89, alpha: 1)   // #EDE9E3
        })
    }

    // MARK: - Animation

    enum Animation {
        static let appear = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
        static let disappear = SwiftUI.Animation.easeOut(duration: 0.2)
        static let content = SwiftUI.Animation.easeInOut(duration: 0.15)
    }

    // MARK: - Shadow

    enum Shadow {
        static let panel = (color: Color.black.opacity(0.25), radius: 20.0, y: 8.0)
        static let hud = (color: Color.black.opacity(0.3), radius: 10.0, y: 4.0)
    }

    // MARK: - Panel

    enum Panel {
        static let hudHeight: CGFloat = 76
        static let hudMinWidth: CGFloat = 240
        static let hudMaxWidth: CGFloat = 620
        static let hudBottomOffset: CGFloat = 48
        static let settingsWidth: CGFloat = 480
        static let settingsHeight: CGFloat = 400
        static let historyWidth: CGFloat = 360
        static let historyHeight: CGFloat = 480
    }
}

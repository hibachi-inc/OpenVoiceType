import SwiftUI

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

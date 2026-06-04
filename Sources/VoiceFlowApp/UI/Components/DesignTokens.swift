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
        // Coffee palette — base colors
        static let espresso = Color(red: 0.361, green: 0.224, blue: 0.157)      // #5c3928
        static let darkCoffee = Color(red: 0.435, green: 0.298, blue: 0.243)    // #6f4c3e
        static let latte = Color(red: 0.757, green: 0.627, blue: 0.482)         // #c1a07b
        static let cream = Color(red: 0.910, green: 0.835, blue: 0.632)         // #e8d5a1
        static let milk = Color(red: 0.949, green: 0.878, blue: 0.753)          // #f2e0c0

        // Semantic colors — mapped to coffee palette
        static let primary = espresso                                            // テキスト主色
        static let secondary = darkCoffee.opacity(0.6)                           // テキスト副色
        static let accent = darkCoffee                                           // ボタン・リンク
        static let recording = Color(red: 0.8, green: 0.25, blue: 0.2)          // 暖かみのある赤
        static let processing = Color(red: 0.75, green: 0.5, blue: 0.2)         // アンバー
        static let success = Color(red: 0.35, green: 0.6, blue: 0.3)            // 落ち着いた緑
        static let error = Color(red: 0.8, green: 0.25, blue: 0.2)              // recording同色

        // Surface colors
        static let fieldBg = Color(red: 0.984, green: 0.980, blue: 0.973)       // #FBFAF8
        static let windowBg = Color(red: 0.992, green: 0.949, blue: 0.824)      // #FDF2D2
        static let cardBg = Color.white.opacity(0.5)                             // 半透明白
        static let sidebarBg = darkCoffee                                        // #6f4c3e
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

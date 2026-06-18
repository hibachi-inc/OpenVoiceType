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
        static let espresso = Color(red: 0.169, green: 0.129, blue: 0.114)      // #2b211d
        static let darkCoffee = Color(red: 0.420, green: 0.290, blue: 0.243)    // #6b4a3e
        static let latte = Color(red: 0.541, green: 0.353, blue: 0.267)         // #8a5a44
        static let cream = Color(red: 0.882, green: 0.843, blue: 0.800)         // #e1d7cc
        static let milk = Color(red: 0.965, green: 0.945, blue: 0.918)          // #f6f1ea

        // Semantic colors — mapped to coffee palette
        static let primary = espresso                                            // テキスト主色
        static let secondary = darkCoffee.opacity(0.6)                           // テキスト副色
        static let accent = latte                                                // ボタン・リンク
        static let recording = darkCoffee                                        // コーヒーブラウン
        static let processing = Color(red: 0.612, green: 0.420, blue: 0.247)    // ローストアンバー
        static let success = Color(red: 0.35, green: 0.6, blue: 0.3)            // 落ち着いた緑
        static let error = Color(red: 0.8, green: 0.25, blue: 0.2)              // recording同色

        // Surface colors
        static let fieldBg = Color(red: 1.000, green: 0.992, blue: 0.973)       // #fffdf8
        static let windowBg = Color(red: 0.953, green: 0.937, blue: 0.910)      // #f3efe8
        static let cardBg = Color(red: 1.000, green: 0.992, blue: 0.973).opacity(0.72)
        static let sidebarBg = darkCoffee                                        // #6b4a3e
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

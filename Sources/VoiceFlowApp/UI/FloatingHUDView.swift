import SwiftUI

struct FloatingHUDView: View {
    let status: HUDStatus
    let transcript: String
    let audioLevel: Float
    var shortcutLabel: String = "⌥Space"
    var engineLabel: String = ""
    var onTap: (() -> Void)? = nil

    private var displayTranscript: String {
        String(transcript.suffix(80))
    }

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                statusIndicator

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(status.title)
                            .font(DS.Font.hudStatus)
                            .foregroundStyle(.white.opacity(0.7))
                        if status == .listening, !engineLabel.isEmpty {
                            Text(engineLabel)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.white.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    if !displayTranscript.isEmpty {
                        Text(displayTranscript)
                            .font(DS.Font.hudTranscript)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                }
            }

            if status == .listening || status == .processing {
                ZStack {
                    if status == .listening {
                        WaveformView(level: audioLevel)
                            .frame(width: 64, height: 14)
                    }
                    HStack {
                        Spacer()
                        Text("hud.stop \(shortcutLabel)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background {
            ZStack {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                status.color.opacity(0.12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        }
        .shadow(
            color: DS.Shadow.hud.color,
            radius: DS.Shadow.hud.radius,
            y: DS.Shadow.hud.y
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .animation(DS.Animation.content, value: status)
        .animation(DS.Animation.content, value: transcript)
    }

    // MARK: - Status indicator

    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(status.color.opacity(0.2))
                .frame(width: 26, height: 26)

            Image(systemName: status.iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(status.color)
                .symbolEffect(.pulse, isActive: status == .listening)
                .contentTransition(.symbolEffect(.replace))
        }
    }

}

// MARK: - Waveform visualizer

struct WaveformView: View {
    let level: Float
    private let barCount = 7
    private let weights: [Float] = [0.4, 0.65, 0.85, 1.0, 0.85, 0.65, 0.4]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.white.opacity(0.75))
                    .frame(width: 3, height: barHeight(for: i))
                    .animation(
                        .spring(response: 0.15, dampingFraction: 0.6),
                        value: level
                    )
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let weighted = level * weights[index]
        return CGFloat(max(0.08, min(1.0, weighted))) * 24 + 3
    }
}

// MARK: - Status enum

enum HUDStatus: Equatable {
    case listening
    case processing
    case copied
    case inserted
    case error(String)

    var iconName: String {
        switch self {
        case .listening: "mic.fill"
        case .processing: "sparkles"
        case .copied, .inserted: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    var title: String {
        switch self {
        case .listening: String(localized: "hud.listening")
        case .processing: String(localized: "hud.processing")
        case .copied: String(localized: "hud.copied")
        case .inserted: String(localized: "hud.inserted")
        case .error(let msg): msg
        }
    }

    var color: Color {
        switch self {
        case .listening: DS.Colors.recording
        case .processing: DS.Colors.processing
        case .copied, .inserted: DS.Colors.success
        case .error: DS.Colors.error
        }
    }
}

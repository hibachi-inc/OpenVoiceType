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

    private var glowIntensity: Double {
        guard status == .listening else { return 0 }
        return Double(max(0.15, min(1.0, audioLevel * 1.5)))
    }

    private var glowRadius: CGFloat {
        guard status == .listening else { return 0 }
        return CGFloat(6 + audioLevel * 16)
    }

    private var isSuccess: Bool {
        status == .copied || status == .inserted
    }

    private var hasText: Bool {
        !displayTranscript.isEmpty
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            statusIndicator

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(status.title)
                        .font(DS.Font.hudStatus)
                        .foregroundStyle(.white.opacity(0.7))
                    if status == .listening, !engineLabel.isEmpty {
                        Text(engineLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                if hasText {
                    Text(displayTranscript)
                        .font(DS.Font.hudTranscript)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .leading)))

            if status == .listening {
                WaveformView(level: audioLevel)
                    .frame(width: hasText ? 50 : 40, height: 18)
            }

            if status == .listening || status == .processing {
                Text("hud.stop \(shortcutLabel)")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.25))
                    .fixedSize()
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, 8)
        .background {
            ZStack {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                status.color.opacity(status == .listening ? 0.05 + glowIntensity * 0.10 : 0.06)
            }
        }
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(
                    status == .listening
                        ? AnyShapeStyle(status.color.opacity(0.2 + glowIntensity * 0.5))
                        : AnyShapeStyle(LinearGradient(
                            colors: [.white.opacity(0.18), .white.opacity(0.05)],
                            startPoint: .top, endPoint: .bottom
                        )),
                    lineWidth: status == .listening ? 1.0 : 0.5
                )
        }
        .shadow(
            color: status == .listening
                ? status.color.opacity(0.12 + glowIntensity * 0.3)
                : isSuccess ? status.color.opacity(0.15) : .black.opacity(0.2),
            radius: status == .listening ? glowRadius : isSuccess ? 10 : 8,
            y: 3
        )
        .contentShape(Capsule())
        .onTapGesture { onTap?() }
        .animation(.spring(response: 0.12, dampingFraction: 0.7), value: audioLevel)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: status)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasText)
        .animation(DS.Animation.content, value: transcript)
    }

    // MARK: - Status indicator

    private var statusIndicator: some View {
        ZStack {
            if status == .listening {
                Circle()
                    .fill(status.color.opacity(glowIntensity * 0.25))
                    .frame(width: 30, height: 30)
                    .blur(radius: 3)
            }

            Circle()
                .fill(status.color.opacity(status == .listening ? 0.1 + glowIntensity * 0.12 : 0.15))
                .frame(width: 22, height: 22)

            if status == .processing {
                SpinnerRing(color: status.color)
                    .frame(width: 26, height: 26)
            }

            if isSuccess {
                SuccessRing(color: status.color)
                    .frame(width: 30, height: 30)
            }

            Image(systemName: status.iconName)
                .font(.system(size: isSuccess ? 12 : 11, weight: .semibold))
                .foregroundStyle(status.color)
                .symbolEffect(.pulse, isActive: status == .listening)
                .contentTransition(.symbolEffect(.replace))
                .scaleEffect(isSuccess ? 1.15 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isSuccess)
        }
    }

}

// MARK: - Success ring animation

struct SuccessRing: View {
    let color: Color
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1.0

    var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: 2)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    scale = 1.4
                    opacity = 0
                }
            }
    }
}

// MARK: - Spinner ring for processing

struct SpinnerRing: View {
    let color: Color
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.3)
            .stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Waveform visualizer

struct WaveformView: View {
    let level: Float
    private let barCount = 11
    private let barWidth: CGFloat = 2
    private let barSpacing: CGFloat = 1.5

    private var weights: [Float] {
        (0..<barCount).map { i in
            let center = Float(barCount - 1) / 2.0
            let dist = abs(Float(i) - center) / center
            return 1.0 - dist * 0.55
        }
    }

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { i in
                let h = barHeight(for: i)
                VStack(spacing: 0.5) {
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(barGradient)
                        .frame(width: barWidth, height: h)
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(barGradient.opacity(0.2))
                        .frame(width: barWidth, height: h * 0.3)
                        .scaleEffect(y: -1, anchor: .top)
                }
                .animation(
                    .spring(response: 0.1, dampingFraction: 0.65),
                    value: level
                )
            }
        }
    }

    private var barGradient: some ShapeStyle {
        LinearGradient(
            colors: [.white.opacity(0.85), .white.opacity(0.4)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func barHeight(for index: Int) -> CGFloat {
        let weighted = level * weights[index]
        return CGFloat(max(0.08, min(1.0, weighted))) * 16 + 2
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

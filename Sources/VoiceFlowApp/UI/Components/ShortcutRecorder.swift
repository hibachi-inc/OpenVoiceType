import SwiftUI
import Carbon.HIToolbox

struct ShortcutRecorder: View {
    let label: String
    @Binding var modifier: HotkeyModifier
    @Binding var key: HotkeyKey
    var onChange: () -> Void = {}

    @State private var isRecording = false

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Button(action: { isRecording.toggle() }) {
                if isRecording {
                    Text("Press shortcut...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(DS.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Text("\(modifier.symbol)\(key.label)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .buttonStyle(.plain)
        }
        .background {
            if isRecording {
                KeyCaptureView { capturedModifier, capturedKey in
                    if let capturedModifier, let capturedKey {
                        modifier = capturedModifier
                        key = capturedKey
                        onChange()
                    }
                    isRecording = false
                }
                .frame(width: 0, height: 0)
            }
        }
    }
}

struct KeyCaptureView: NSViewRepresentable {
    let onCapture: (HotkeyModifier?, HotkeyKey?) -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onCapture = onCapture
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {}
}

class KeyCaptureNSView: NSView {
    var onCapture: ((HotkeyModifier?, HotkeyKey?) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let mod = parseModifier(event.modifierFlags)
        let key = parseKey(event.keyCode)

        if mod != nil && key != nil {
            onCapture?(mod, key)
        } else if event.keyCode == 53 { // Escape
            onCapture?(nil, nil)
        }
    }

    private func parseModifier(_ flags: NSEvent.ModifierFlags) -> HotkeyModifier? {
        if flags.contains(.option) { return .option }
        if flags.contains(.control) { return .control }
        if flags.contains(.command) { return .command }
        return nil
    }

    private func parseKey(_ keyCode: UInt16) -> HotkeyKey? {
        HotkeyKey.from(keyCode: keyCode)
    }
}

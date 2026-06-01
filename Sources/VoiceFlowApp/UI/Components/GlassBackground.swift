import SwiftUI
import AppKit

struct GlassBackground<Content: View>: View {
    let cornerRadius: CGFloat
    @ViewBuilder let content: Content

    init(cornerRadius: CGFloat = DS.Radius.lg, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background { glassLayer }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: DS.Shadow.panel.color,
                radius: DS.Shadow.panel.radius,
                y: DS.Shadow.panel.y
            )
    }

    @ViewBuilder
    private var glassLayer: some View {
        if #available(macOS 26, *) {
            glassEffect()
        } else {
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
        }
    }

    @available(macOS 26, *)
    @ViewBuilder
    private func glassEffect() -> some View {
        Rectangle()
            .fill(.ultraThinMaterial)
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

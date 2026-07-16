import SwiftUI
import AinkradAppKit

/// Leyline's settings surface — an info blurb plus a "Presentation"
/// (pane/overlay) control on the Cardinal HUD kit. Backed by
/// `HostServices.presentation` (`PluginPresentationControl`): the override
/// takes effect the next time Leyline is opened, mirroring the host's own
/// contract (never morphs an already-open window).
struct LeylineSettingsView: View {
    let presentation: any PluginPresentationControl

    @Environment(\.ainkradTheme) private var theme
    @Environment(\.ainkradTypography) private var typo
    @State private var mode: PluginPresentation

    init(presentation: any PluginPresentationControl) {
        self.presentation = presentation
        _mode = State(initialValue: presentation.current)
    }

    var body: some View {
        AinkradCard {
            VStack(alignment: .leading, spacing: AinkradSpacing.md) {
                Text("Leyline stores connections and keys per workspace.")
                    .font(AinkradFontResolver.font(.body, typography: typo))
                    .foregroundStyle(theme.foreground)

                AinkradFormRow(title: "Presentation", help: "Applies the next time Leyline opens.") {
                    AinkradSegmentedPicker(items: [PluginPresentation.pane, .overlay], selection: $mode) {
                        $0 == .pane ? "Pane" : "Overlay"
                    }
                }
            }
        }
        .padding()
        .onChange(of: mode) { _, newValue in presentation.set(newValue) }
    }
}

import SwiftUI
import AinkradAppKit

/// Leyline's settings surface. Hosts the presentation toggle (pane vs overlay);
/// the choice is persisted host-side and applies the next time Leyline opens.
struct LeylineSettingsView: View {
    let host: HostServices
    @State private var presentation: PluginPresentation

    init(host: HostServices) {
        self.host = host
        _presentation = State(initialValue: host.presentation.current)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Leyline stores connections and keys per workspace.")
                .foregroundStyle(host.theme.tokens.foreground)

            Text("Presentation")
                .font(.headline)
                .foregroundStyle(host.theme.tokens.foreground)

            Picker("Presentation", selection: $presentation) {
                Text("Overlay").tag(PluginPresentation.overlay)
                Text("Pane").tag(PluginPresentation.pane)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: presentation) { _, newValue in
                host.presentation.set(newValue)
            }

            Text("Applies the next time you open Leyline.")
                .font(.footnote)
                .foregroundStyle(host.theme.tokens.foreground.opacity(0.6))
        }
        .padding()
    }
}

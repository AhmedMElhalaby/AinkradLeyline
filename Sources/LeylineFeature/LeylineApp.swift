import SwiftUI
import AinkradAppKit

public struct LeylineApp: AinkradApp {
    public static let id = "leyline"
    public static let displayName = "Leyline"
    public static let icon = "point.3.connected.trianglepath.dotted"

    @MainActor private static var stores: [ObjectIdentifier: LeylineStore] = [:]

    @MainActor private static func store(for host: HostServices) -> LeylineStore {
        let key = ObjectIdentifier(host as AnyObject)
        if let existing = stores[key] { return existing }
        let store = LeylineStore(documents: host.documents, secrets: host.secrets)
        stores[key] = store
        return store
    }

    public static func makeRootView(host: HostServices) -> AnyView {
        AnyView(LeylineRootView(store: store(for: host), theme: host.theme, launcher: host.apps))
    }

    public static func makeSettingsView(host: HostServices) -> AnyView {
        AnyView(Text("Leyline stores connections and keys per workspace.")
            .foregroundStyle(host.theme.tokens.foreground).padding())
    }

    public static func chromeFill(host: HostServices) -> Color? {
        host.theme.tokens.background
    }
}

import SwiftUI
import AinkradAppKit

public struct LeylineApp: AinkradApp {
    public static let id = "leyline"
    public static let displayName = "Leyline"
    public static let icon = "point.3.connected.trianglepath.dotted"

    /// Keyed by the host-minted instance id rather than
    /// `ObjectIdentifier(host)` — an address of a box around a non-class-bound
    /// existential, reusable after free, and never evicted. See
    /// `PluginInstanceStorage`.
    @MainActor private static let stores = PluginInstanceStorage<LeylineStore>()

    /// The instance key for `host`.
    ///
    /// A generation-8 host mints one. A generation-7 host does not implement
    /// `PluginInstanceIdentity`, so fall back to the OLD per-host object
    /// identity rather than to one shared id — collapsing every legacy host
    /// onto a single key would make two hosts share a store, which is a
    /// regression rather than a fallback. The address-reuse hazard stays only
    /// on the legacy path, exactly as before, and is gone on generation 8.
    @MainActor private static func instance(of host: HostServices) -> PluginInstanceID {
        if let identified = host as? PluginInstanceIdentity { return identified.instanceID }
        let key = ObjectIdentifier(host as AnyObject)
        if let existing = legacyIDs[key] { return existing }
        let minted = PluginInstanceID()
        legacyIDs[key] = minted
        return minted
    }
    @MainActor private static var legacyIDs: [ObjectIdentifier: PluginInstanceID] = [:]

    @MainActor private static func store(for host: HostServices) -> LeylineStore {
        stores.value(for: instance(of: host)) {
            LeylineStore(documents: host.documents, secrets: host.secrets)
        }
    }

    public static func makeRootView(host: HostServices) -> AnyView {
        AnyView(LeylineRootView(store: store(for: host), theme: host.theme, launcher: host.apps))
    }

    public static func makeSettingsView(host: HostServices) -> AnyView {
        AnyView(LeylineSettingsView(presentation: host.presentation))
    }

    public static func chromeFill(host: HostServices) -> Color? {
        host.theme.tokens.background
    }
}

/// Generation 8: purge materialized private keys when this instance closes.
///
/// `SSHKeyMaterializer` writes plaintext private keys to Application Support so
/// the system `ssh` binary can read them. Without a teardown hook they simply
/// stayed there — the audit's "materialized private keys written to disk in
/// plaintext, never deleted". Removing the key from the vault now purges its
/// copy (Wave 2); closing the app purges all of them.
extension LeylineApp: AinkradAppTeardown {
    public static func teardown(instance: PluginInstanceID) {
        stores.remove(instance)
        SSHKeyMaterializer.purgeAll()
    }
}

import SwiftUI
import AinkradAppKit

struct LeylineRootView: View {
    @Bindable var store: LeylineStore
    let theme: HostTheme
    let launcher: PluginAppLauncher

    @State private var query = ""
    @State private var editing: LeylineConnection?
    @State private var showingNew = false
    @State private var showingKeys = false
    @State private var copied: UUID?
    @State private var hovered: UUID?
    /// Non-nil when the last connect attempt failed. Surfaces what used to be
    /// discarded: `apps.open` returned Void, so a missing or disabled Rune
    /// looked exactly like a successful launch.
    @State private var launchError: String?

    private var t: HostThemeTokens { theme.tokens }
    private var filtered: [LeylineConnection] { ConnectionFilter.matching(query, in: store.connections) }

    var body: some View {
        VStack(spacing: 0) {
            header
            AinkradSearchField(text: $query, placeholder: "Search connections")
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            LeylineHUD.glowRule(t).padding(.horizontal, 14)
            if let launchError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10))
                    Text(launchError).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    AinkradIconButton(systemName: "xmark", size: 18) { self.launchError = nil }
                }
                .foregroundStyle(t.accentTertiary)
                .padding(.horizontal, 14).padding(.top, 8)
            }
            content
        }
        .background(Color.clear)                       // let the host HUD panel blur show through
        // In-surface HUD overlays (chamfer + dim + scrim/Esc dismiss), scoped
        // to this root view — never a native `.sheet`. The `editing` modal is
        // driven by the item's presence; `editing` itself stays available to
        // the hosted content for the duration the modal is up.
        .ainkradModal(isPresented: $showingNew) {
            ConnectionEditorView(store: store, theme: theme, existing: nil, onClose: { showingNew = false })
        }
        .ainkradModal(isPresented: Binding(
            get: { editing != nil },
            set: { isPresented in if !isPresented { editing = nil } }
        )) {
            if let editing {
                ConnectionEditorView(store: store, theme: theme, existing: editing, onClose: { self.editing = nil })
            }
        }
        .ainkradModal(isPresented: $showingKeys) {
            KeyVaultView(store: store, theme: theme, onClose: { showingKeys = false })
        }
    }

    // MARK: Header (wordmark + HUD actions)

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(t.accentSecondary)
                .shadow(color: t.accentSecondary.opacity(0.5), radius: 5)
            Text("LEYLINE")
                .font(.system(size: 12, weight: .bold, design: .monospaced)).kerning(3)
                .foregroundStyle(t.foreground.opacity(0.85))
            Spacer()
            AinkradIconButton(systemName: "key.fill") { showingKeys = true }.help("SSH Keys")
            AinkradIconButton(systemName: "plus") { showingNew = true }.help("New Connection")
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        if filtered.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(filtered) { conn in row(conn) }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
            }
        }
    }

    private var emptyState: some View {
        AinkradEmptyState(
            icon: store.connections.isEmpty ? "point.3.connected.trianglepath.dotted" : "magnifyingglass",
            title: store.connections.isEmpty ? "No connections yet" : "No matches",
            message: store.connections.isEmpty ? "Add a host with  +" : "Try a different search"
        )
    }

    // MARK: Row

    @ViewBuilder private func row(_ conn: LeylineConnection) -> some View {
        let isHover = hovered == conn.id
        let authColor = conn.authMode == .key ? t.accentTertiary : t.accentSecondary
        AinkradListRow(
            isSelected: isHover,
            leading: {
                Image(systemName: conn.authMode == .key ? "key.fill" : "lock.fill")   // auth badge
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(authColor)
                    .frame(width: 24, height: 24)
                    .background(ChamferShape(cut: AinkradRadius.sm).fill(authColor.opacity(0.14)))
                    .overlay(ChamferShape(cut: AinkradRadius.sm).strokeBorder(authColor.opacity(0.3), lineWidth: 0.5))
            },
            title: conn.label.isEmpty ? conn.host : conn.label,
            subtitle: SSHCommand.string(for: conn),
            trailing: {
                HStack(spacing: 6) {
                    HStack(spacing: 6) {                                    // hover-revealed secondary actions
                        AinkradIconButton(systemName: copied == conn.id ? "checkmark" : "doc.on.doc") { copyCommand(conn) }
                            .help("Copy ssh command")
                        AinkradIconButton(systemName: "pencil") { editing = conn }.help("Edit")
                        AinkradIconButton(systemName: "trash") { store.removeConnection(conn) }.help("Delete")
                    }
                    .opacity(isHover ? 1 : 0)
                    .allowsHitTesting(isHover)

                    AinkradButton(title: "Connect", style: .primary, icon: "bolt.fill") { connect(conn) }   // always-visible primary action
                }
            }
        )
        .onHover { h in hovered = h ? conn.id : nil }
    }

    // MARK: Actions

    private func copyCommand(_ conn: LeylineConnection) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(SSHCommand.string(for: conn), forType: .string)
        copied = conn.id
    }

    private func connect(_ conn: LeylineConnection) {
        // One implementation of "make this connection's key readable by ssh",
        // shared with the agent-initiated connect in `LeylineMCPOperations`.
        // While it lived here, the tool path had to either duplicate it or go
        // without a key — it went without, and users got Permission denied.
        let identityFile = SSHIdentityResolver.resolve(conn, store: store).path
        // `SSHLaunchPayload` is now the SHARED SDK type — one definition,
        // versioned, and validated on both sides. Leyline previously had its
        // own `Encodable` struct and Rune its own `Decodable` mirror, kept
        // in sync by hand across two repos.
        let payload = SSHLaunchPayload(
            host: conn.host, port: conn.port, username: conn.username, identityFile: identityFile
        )
        // Validate before sending. Every field lands in an `ssh` argv, and
        // `ssh`'s option surface (`-o ProxyCommand=…`) runs shell commands — so
        // a hostile hostname or username is code execution. Refusing here means
        // the malformed connection never leaves this process.
        guard let safe = try? payload.validated() else {
            launchError = "This connection has an unsafe host, username or key path."
            return
        }
        // Report the outcome instead of discarding it. `open(appID:payload:)`
        // returns Void, so this button looked identical whether Rune opened
        // or was not installed at all.
        let outcome = (launcher as? PluginAppLauncherResult)?
            .openReportingOutcome(appID: "rune", payload: safe.json)
            ?? { launcher.open(appID: "rune", payload: safe.json); return .opened }()
        switch outcome {
        case .opened:            launchError = nil
        case .unknownApp:        launchError = "Rune isn't installed — install it from the App Store."
        case .disabled:          launchError = "Rune is disabled — enable it in the App Store."
        case .refused(let why):  launchError = "Couldn't open Rune: \(why)"
        // `PluginLaunchOutcome` lives in a resilient module, so the compiler
        // requires a default: a newer SDK may add a case this build has never
        // seen. Treat anything unknown as a failure rather than as success.
        @unknown default:        launchError = "Couldn't open Rune."
        }
    }
}

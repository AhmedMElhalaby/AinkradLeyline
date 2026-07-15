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
    @FocusState private var searchFocused: Bool

    private var t: HostThemeTokens { theme.tokens }
    private var filtered: [LeylineConnection] { ConnectionFilter.matching(query, in: store.connections) }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            LeylineHUD.glowRule(t).padding(.horizontal, 14)
            content
        }
        .background(Color.clear)                       // let the host HUD panel blur show through
        .sheet(isPresented: $showingNew) { ConnectionEditorView(store: store, theme: theme, existing: nil) }
        .sheet(item: $editing) { ConnectionEditorView(store: store, theme: theme, existing: $0) }
        .sheet(isPresented: $showingKeys) { KeyVaultView(store: store, theme: theme) }
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
            HudIconButton(systemName: "key.fill", help: "SSH Keys", tokens: t) { showingKeys = true }
            HudIconButton(systemName: "plus", help: "New Connection", tokens: t) { showingNew = true }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(t.accentSecondary.opacity(0.85))
                .shadow(color: t.accentSecondary.opacity(searchFocused ? 0.5 : 0.2), radius: 4)
            TextField("Search connections", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(t.foreground)
                .focused($searchFocused)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(t.surface.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(t.accentPrimary.opacity(searchFocused ? 0.55 : 0.18), lineWidth: 1))
        .shadow(color: t.accentPrimary.opacity(searchFocused ? 0.2 : 0), radius: 8)
        .animation(.easeOut(duration: 0.14), value: searchFocused)
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
        VStack(spacing: 10) {
            Image(systemName: store.connections.isEmpty ? "point.3.connected.trianglepath.dotted" : "magnifyingglass")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(t.accentSecondary.opacity(0.7))
                .shadow(color: t.accentSecondary.opacity(0.4), radius: 8)
            Text(store.connections.isEmpty ? "No connections yet" : "No matches")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(t.foreground.opacity(0.8))
            if store.connections.isEmpty {
                Text("Add a host with  +")
                    .font(.system(size: 11))
                    .foregroundStyle(t.foreground.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 24)
    }

    // MARK: Row

    @ViewBuilder private func row(_ conn: LeylineConnection) -> some View {
        let isHover = hovered == conn.id
        let authColor = conn.authMode == .key ? t.accentTertiary : t.accentSecondary
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)                       // glowing selection spine
                .fill(t.accentSecondary)
                .frame(width: 3, height: 26)
                .shadow(color: t.accentSecondary.opacity(0.8), radius: 4)
                .opacity(isHover ? 1 : 0)

            Image(systemName: conn.authMode == .key ? "key.fill" : "lock.fill")   // auth badge
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(authColor)
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(authColor.opacity(0.14)))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(authColor.opacity(0.3), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(conn.label.isEmpty ? conn.host : conn.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(t.foreground)
                Text(SSHCommand.string(for: conn))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(t.foreground.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {                                    // hover-revealed secondary actions
                HudIconButton(systemName: copied == conn.id ? "checkmark" : "doc.on.doc",
                              help: "Copy ssh command", tokens: t) { copyCommand(conn) }
                HudIconButton(systemName: "pencil", help: "Edit", tokens: t) { editing = conn }
                HudIconButton(systemName: "trash", help: "Delete", tokens: t) { store.removeConnection(conn) }
            }
            .opacity(isHover ? 1 : 0)
            .allowsHitTesting(isHover)

            ConnectChip(tokens: t) { connect(conn) }               // always-visible primary action
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: LeylineHUD.rowRadius, style: .continuous)
            .fill(isHover ? t.surfaceElevated.opacity(0.5) : .clear))
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.14)) { hovered = h ? conn.id : nil } }
    }

    // MARK: Actions

    private func copyCommand(_ conn: LeylineConnection) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(SSHCommand.string(for: conn), forType: .string)
        copied = conn.id
    }

    private func connect(_ conn: LeylineConnection) {
        var identityFile: String?
        if conn.authMode == .key, let keyID = conn.keyID,
           let key = store.keys.first(where: { $0.id == keyID }),
           let material = store.privateKey(for: key) {
            identityFile = try? SSHKeyMaterializer.materialize(keyID: keyID, privateKey: material)
        }
        let payload = SSHLaunchPayload(
            host: conn.host, port: conn.port, username: conn.username, identityFile: identityFile
        ).json
        launcher.open(appID: "terminal", payload: payload)
    }
}

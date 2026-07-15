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

    private var filtered: [LeylineConnection] {
        ConnectionFilter.matching(query, in: store.connections)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(theme.tokens.foreground.opacity(0.5))
                TextField("Search connections", text: $query)
                    .textFieldStyle(.plain)
                Button { showingKeys = true } label: { Image(systemName: "key.fill") }
                    .buttonStyle(.plain).help("SSH Keys")
                Button { showingNew = true } label: { Image(systemName: "plus") }
                    .buttonStyle(.plain).help("New Connection")
            }
            .padding(12)
            .foregroundStyle(theme.tokens.foreground)

            List {
                ForEach(filtered) { conn in
                    row(conn)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(theme.tokens.background)
        .sheet(isPresented: $showingNew) {
            ConnectionEditorView(store: store, theme: theme, existing: nil)
        }
        .sheet(item: $editing) { conn in
            ConnectionEditorView(store: store, theme: theme, existing: conn)
        }
        .sheet(isPresented: $showingKeys) {
            KeyVaultView(store: store, theme: theme)
        }
    }

    @ViewBuilder private func row(_ conn: LeylineConnection) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(conn.label.isEmpty ? conn.host : conn.label).fontWeight(.medium)
                Text(SSHCommand.string(for: conn)).font(.caption)
                    .foregroundStyle(theme.tokens.foreground.opacity(0.6))
            }
            Spacer()
            Image(systemName: conn.authMode == .key ? "key.fill" : "lock.fill")
                .foregroundStyle(theme.tokens.foreground.opacity(0.4))
            Button {
                connect(conn)
            } label: {
                Image(systemName: "bolt.horizontal.circle")
            }
            .buttonStyle(.plain).help("Connect (opens Terminal)")
            Button {
                copyCommand(conn)
            } label: {
                Image(systemName: copied == conn.id ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.plain).help("Copy ssh command")
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { editing = conn }
        .listRowBackground(Color.clear)
        .swipeActions {
            Button(role: .destructive) { store.removeConnection(conn) } label: { Label("Delete", systemImage: "trash") }
        }
    }

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

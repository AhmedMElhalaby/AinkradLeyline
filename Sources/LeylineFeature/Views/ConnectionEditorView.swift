import SwiftUI
import AinkradAppKit

struct ConnectionEditorView: View {
    @Bindable var store: LeylineStore
    let theme: HostTheme
    let existing: LeylineConnection?

    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var authMode: LeylineConnection.AuthMode = .password
    @State private var password = ""
    @State private var keyID: UUID?

    private var t: HostThemeTokens { theme.tokens }
    private var selectedKeyLabel: String { store.keys.first(where: { $0.id == keyID })?.label ?? "None" }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HudTitle(text: existing == nil ? "New Connection" : "Edit Connection", tokens: t)

            HudField(label: "Label", placeholder: "Prod Web", text: $label, tokens: t)
            HStack(alignment: .bottom, spacing: 10) {
                HudField(label: "Host", placeholder: "example.com", text: $host, tokens: t)
                HudField(label: "Port", placeholder: "22", text: $port, tokens: t).frame(width: 84)
            }
            HudField(label: "Username", placeholder: "deploy", text: $username, tokens: t)

            labeled("Auth") {
                HudSegmented(options: [(LeylineConnection.AuthMode.password, "Password"),
                                       (.key, "Key")], selection: $authMode, tokens: t)
            }

            if authMode == .password {
                HudField(label: "Password", text: $password, secure: true, tokens: t)
            } else {
                labeled("Key") { keyMenu }
            }

            HStack(spacing: 10) {
                Spacer()
                HudButton(title: "Cancel", tokens: t) { dismiss() }.keyboardShortcut(.cancelAction)
                HudButton(title: "Save", systemImage: "checkmark", kind: .primary,
                          disabled: host.isEmpty, tokens: t) { save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(18)
        .frame(width: 400)
        .background(LeylineHUD.sheetBackground(t))
        .foregroundStyle(t.foreground)
        .onAppear(perform: load)
    }

    @ViewBuilder private func labeled<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced)).kerning(1.5)
                .foregroundStyle(t.foreground.opacity(0.5))
            content()
        }
    }

    private var keyMenu: some View {
        Menu {
            Button("None") { keyID = nil }
            ForEach(store.keys) { k in Button(k.label) { keyID = k.id } }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "key.fill").font(.system(size: 10)).foregroundStyle(t.accentTertiary)
                Text(selectedKeyLabel).font(.system(size: 13)).foregroundStyle(t.foreground)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9)).foregroundStyle(t.foreground.opacity(0.5))
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(t.surface.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(t.accentPrimary.opacity(0.18), lineWidth: 1))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    private func load() {
        guard let c = existing else { return }
        label = c.label; host = c.host; port = String(c.port); username = c.username
        authMode = c.authMode; keyID = c.keyID
        if c.authMode == .password { password = store.password(for: c) ?? "" }
    }

    private func save() {
        let portValue = Int(port) ?? 22
        if var c = existing {
            c.label = label; c.host = host; c.port = portValue; c.username = username
            c.authMode = authMode; c.keyID = authMode == .key ? keyID : nil
            store.updateConnection(c)
            store.setPassword(authMode == .password ? password : nil, for: c)
        } else {
            store.addConnection(label: label, host: host, port: portValue, username: username,
                                authMode: authMode, keyID: authMode == .key ? keyID : nil,
                                password: authMode == .password ? password : nil)
        }
        dismiss()
    }
}

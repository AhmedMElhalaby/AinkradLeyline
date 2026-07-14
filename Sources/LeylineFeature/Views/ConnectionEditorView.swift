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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(existing == nil ? "New Connection" : "Edit Connection").font(.headline)
            Form {
                TextField("Label", text: $label)
                TextField("Host", text: $host)
                TextField("Port", text: $port)
                TextField("Username", text: $username)
                Picker("Auth", selection: $authMode) {
                    Text("Password").tag(LeylineConnection.AuthMode.password)
                    Text("Key").tag(LeylineConnection.AuthMode.key)
                }.pickerStyle(.segmented)
                if authMode == .password {
                    SecureField("Password", text: $password)
                } else {
                    Picker("Key", selection: $keyID) {
                        Text("None").tag(UUID?.none)
                        ForEach(store.keys) { k in Text(k.label).tag(UUID?.some(k.id)) }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }.keyboardShortcut(.defaultAction).disabled(host.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 380)
        .background(theme.tokens.surface)
        .onAppear(perform: load)
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

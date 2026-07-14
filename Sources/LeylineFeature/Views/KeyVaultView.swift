import SwiftUI
import AinkradAppKit

struct KeyVaultView: View {
    @Bindable var store: LeylineStore
    let theme: HostTheme

    @Environment(\.dismiss) private var dismiss
    @State private var showingPaste = false
    @State private var pasteLabel = ""
    @State private var pasteBody = ""
    @State private var pastePassphrase = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SSH Keys").font(.headline)
                Spacer()
                Button("Import File…") { presentImportPanel() }
                Button("Paste…") { showingPaste = true }
            }
            List {
                ForEach(store.keys) { key in
                    HStack {
                        Image(systemName: "key.fill")
                        Text(key.label)
                        if key.hasPassphrase { Image(systemName: "lock").font(.caption) }
                        Spacer()
                        Button(role: .destructive) { store.removeKey(key) } label: { Image(systemName: "trash") }
                            .buttonStyle(.plain)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain).scrollContentBackground(.hidden)
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(16)
        .frame(width: 420, height: 360)
        .background(theme.tokens.surface)
        .foregroundStyle(theme.tokens.foreground)
        .sheet(isPresented: $showingPaste) { pasteSheet }
    }

    /// Uses `NSOpenPanel` (not SwiftUI's `.fileImporter`) so hidden files are
    /// shown by default — SSH keys live in `~/.ssh`, a dotfile directory the
    /// stock importer hides. The panel selection also grants read access.
    private func presentImportPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.treatsFilePackagesAsDirectories = true
        panel.message = "Choose an SSH private key"
        panel.prompt = "Import"
        if panel.runModal() == .OK, let url = panel.url { importFile(url) }
    }

    private var pasteSheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Paste Private Key").font(.headline)
            TextField("Label", text: $pasteLabel)
            TextEditor(text: $pasteBody).frame(height: 140).font(.system(.body, design: .monospaced))
            SecureField("Passphrase (optional)", text: $pastePassphrase)
            HStack {
                Spacer()
                Button("Cancel") { showingPaste = false }
                Button("Import") {
                    store.importKey(label: pasteLabel.isEmpty ? "Imported Key" : pasteLabel,
                                    privateKey: pasteBody,
                                    passphrase: pastePassphrase.isEmpty ? nil : pastePassphrase)
                    pasteLabel = ""; pasteBody = ""; pastePassphrase = ""; showingPaste = false
                }.keyboardShortcut(.defaultAction).disabled(pasteBody.isEmpty)
            }
        }.padding(16).frame(width: 420)
    }

    private func importFile(_ url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        guard let body = try? String(contentsOf: url, encoding: .utf8) else { return }
        store.importKey(label: url.lastPathComponent, privateKey: body, passphrase: nil)
    }
}

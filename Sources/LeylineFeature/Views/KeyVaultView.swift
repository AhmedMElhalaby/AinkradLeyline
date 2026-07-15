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
    @State private var hovered: UUID?

    private var t: HostThemeTokens { theme.tokens }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HudTitle(text: "SSH Keys", tokens: t)
                Spacer()
                HudButton(title: "Import File", systemImage: "folder", tokens: t) { presentImportPanel() }
                HudButton(title: "Paste", systemImage: "doc.on.clipboard", tokens: t) { showingPaste = true }
            }
            LeylineHUD.glowRule(t)

            if store.keys.isEmpty {
                emptyKeys
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(store.keys) { key in keyRow(key) }
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack {
                Spacer()
                HudButton(title: "Done", kind: .primary, tokens: t) { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 440, height: 380)
        .background(LeylineHUD.sheetBackground(t))
        .foregroundStyle(t.foreground)
        .sheet(isPresented: $showingPaste) { pasteSheet }
    }

    @ViewBuilder private func keyRow(_ key: LeylineKey) -> some View {
        let isHover = hovered == key.id
        HStack(spacing: 10) {
            Image(systemName: "key.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(t.accentTertiary)
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(t.accentTertiary.opacity(0.14)))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(t.accentTertiary.opacity(0.3), lineWidth: 0.5))
            Text(key.label).font(.system(size: 13, weight: .medium)).foregroundStyle(t.foreground)
            if key.hasPassphrase {
                Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(t.foreground.opacity(0.5))
            }
            Spacer()
            HudIconButton(systemName: "trash", help: "Delete key", tokens: t) { store.removeKey(key) }
                .opacity(isHover ? 1 : 0)
                .allowsHitTesting(isHover)
        }
        .padding(.horizontal, 9).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: LeylineHUD.rowRadius, style: .continuous)
            .fill(isHover ? t.surfaceElevated.opacity(0.5) : .clear))
        .onHover { h in withAnimation(.easeOut(duration: 0.14)) { hovered = h ? key.id : nil } }
    }

    private var emptyKeys: some View {
        VStack(spacing: 8) {
            Image(systemName: "key")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(t.accentTertiary.opacity(0.6))
                .shadow(color: t.accentTertiary.opacity(0.35), radius: 7)
            Text("No keys imported").font(.system(size: 13, weight: .medium)).foregroundStyle(t.foreground.opacity(0.8))
            Text("Import a private key by file or paste").font(.system(size: 11)).foregroundStyle(t.foreground.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pasteSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HudTitle(text: "Paste Private Key", tokens: t)
            HudField(label: "Label", placeholder: "id_ed25519", text: $pasteLabel, tokens: t)
            VStack(alignment: .leading, spacing: 5) {
                Text("PRIVATE KEY")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced)).kerning(1.5)
                    .foregroundStyle(t.foreground.opacity(0.5))
                TextEditor(text: $pasteBody)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(t.foreground)
                    .scrollContentBackground(.hidden)
                    .frame(height: 130)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(t.surface.opacity(0.6)))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(t.accentPrimary.opacity(0.18), lineWidth: 1))
            }
            HudField(label: "Passphrase (optional)", text: $pastePassphrase, secure: true, tokens: t)
            HStack(spacing: 10) {
                Spacer()
                HudButton(title: "Cancel", tokens: t) { showingPaste = false }.keyboardShortcut(.cancelAction)
                HudButton(title: "Import", systemImage: "checkmark", kind: .primary,
                          disabled: pasteBody.isEmpty, tokens: t) { importPasted() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 440)
        .background(LeylineHUD.sheetBackground(t))
        .foregroundStyle(t.foreground)
    }

    private func importPasted() {
        store.importKey(label: pasteLabel.isEmpty ? "Imported Key" : pasteLabel,
                        privateKey: pasteBody,
                        passphrase: pastePassphrase.isEmpty ? nil : pastePassphrase)
        pasteLabel = ""; pasteBody = ""; pastePassphrase = ""; showingPaste = false
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

    private func importFile(_ url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        guard let body = try? String(contentsOf: url, encoding: .utf8) else { return }
        store.importKey(label: url.lastPathComponent, privateKey: body, passphrase: nil)
    }
}

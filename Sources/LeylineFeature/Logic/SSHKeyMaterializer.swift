import Foundation

/// Writes a Keychain-held private key to a 0600 file so the system `ssh` binary
/// (spawned by Terminal) can read it. Lives in Application Support; a rebuildable
/// cache — the Keychain remains source of truth.
enum SSHKeyMaterializer {
    static func materialize(keyID: UUID, privateKey: String) throws -> String {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appendingPathComponent("Leyline/keys", isDirectory: true)
        try FileManager.default.createDirectory(
            at: base, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let url = base.appendingPathComponent(keyID.uuidString)
        var body = privateKey
        if !body.hasSuffix("\n") { body.append("\n") }        // ssh requires a trailing newline
        try Data(body.utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return url.path
    }
}

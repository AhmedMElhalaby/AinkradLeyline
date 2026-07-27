import Testing
import Foundation
@testable import LeylineFeature

@Suite("SSHKeyMaterializer")
struct SSHKeyMaterializerTests {
    @Test("writes the key with 0600 perms and a trailing newline")
    func writes() throws {
        let id = UUID()
        let path = try SSHKeyMaterializer.materialize(keyID: id, privateKey: "PRIVATE-KEY-BODY")
        defer { try? FileManager.default.removeItem(atPath: path) }
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        #expect((attrs[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        let body = try String(contentsOfFile: path, encoding: .utf8)
        #expect(body.hasPrefix("PRIVATE-KEY-BODY"))
        #expect(body.hasSuffix("\n"))
    }
}

/// Wave 2: the key file must never exist at readable permissions, and a
/// materialized key must be removable.
@Suite("SSHKeyMaterializer lifecycle and permissions")
struct SSHKeyMaterializerLifecycleTests {

    @Test("The containing directory is 0700 even if it already existed")
    func directoryPermissionsAreReasserted() throws {
        let dir = try SSHKeyMaterializer.keysDirectory()
        // Simulate a directory left by an older build at a looser mode.
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path)

        _ = try SSHKeyMaterializer.keysDirectory()

        let mode = (try FileManager.default.attributesOfItem(atPath: dir.path)[.posixPermissions] as? NSNumber)?.intValue
        #expect(mode == 0o700, "an existing keys directory kept its loose permissions")
    }

    @Test("Rematerializing over an existing file keeps 0600")
    func rewriteStaysPrivate() throws {
        let id = UUID()
        let first = try SSHKeyMaterializer.materialize(keyID: id, privateKey: "ONE")
        defer { SSHKeyMaterializer.purge(keyID: id) }
        // Loosen it the way the old `.atomic` + chmod ordering could leave it.
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: first)

        let second = try SSHKeyMaterializer.materialize(keyID: id, privateKey: "TWO")

        let mode = (try FileManager.default.attributesOfItem(atPath: second)[.posixPermissions] as? NSNumber)?.intValue
        #expect(mode == 0o600)
        #expect(try String(contentsOfFile: second, encoding: .utf8).hasPrefix("TWO"))
    }

    @Test("purge removes the plaintext key from disk")
    func purgeRemovesTheFile() throws {
        let id = UUID()
        let path = try SSHKeyMaterializer.materialize(keyID: id, privateKey: "SECRET")
        #expect(FileManager.default.fileExists(atPath: path))

        SSHKeyMaterializer.purge(keyID: id)

        // Before this existed, deleting a key from the vault cleared the
        // Keychain entry and left this file behind forever.
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test("purge on an absent key is a no-op, not a failure")
    func purgeIsIdempotent() {
        let id = UUID()
        SSHKeyMaterializer.purge(keyID: id)
        SSHKeyMaterializer.purge(keyID: id)
    }

    @Test("purgeAll clears every materialized key")
    func purgeAllClearsDirectory() throws {
        let ids = [UUID(), UUID(), UUID()]
        for id in ids { _ = try SSHKeyMaterializer.materialize(keyID: id, privateKey: "K") }

        SSHKeyMaterializer.purgeAll()

        let dir = try SSHKeyMaterializer.keysDirectory()
        let remaining = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        #expect(remaining.isEmpty)
    }
}

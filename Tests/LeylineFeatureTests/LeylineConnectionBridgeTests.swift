import Testing
import Foundation
import AinkradAppKit
@testable import LeylineFeature

/// A local mirror of the host's `SSHConnectionInfo`
/// (`Sources/Ainkrad/Core/AgentKit/Sandbox/SSHConnectionInfo.swift`). The point
/// of the bridge's contract is that the host side is a straight decode, so the
/// test decodes with the host's exact field names and nothing else.
private struct SSHConnectionInfo: Codable, Equatable {
    var host: String
    var user: String
    var port: Int?
    var identityPath: String?
    var remoteWorkingDir: String?
}

/// The same recognisable fake secrets the MCP leak test uses.
private let secretMarker = "AINKRAD-FAKE-SECRET-MATERIAL-DO-NOT-LEAK-8F2A"

/// Builds a bridge over an in-memory store. **Never touches the user's real
/// Leyline store or Keychain**: `FakeDocs` is in-memory and `FakeSecrets` stands
/// in for the host's Keychain-backed store.
@MainActor
private func makeFixture() -> (bridge: LeylineConnectionBridge, store: LeylineStore,
                               keyConn: LeylineConnection, passwordConn: LeylineConnection,
                               key: LeylineKey) {
    let store = LeylineStore(documents: FakeDocs(), secrets: FakeSecrets())
    let key = store.importKey(
        label: "Prod deploy key",
        privateKey: "-----BEGIN OPENSSH PRIVATE KEY-----\n\(secretMarker)\n"
            + "-----END OPENSSH PRIVATE KEY-----",
        passphrase: nil)
    let keyConn = store.addConnection(label: "Prod web", host: "web.example.com", port: 2222,
                                      username: "deploy", authMode: .key, keyID: key.id,
                                      password: nil)
    let passwordConn = store.addConnection(label: "Legacy box", host: "legacy.example.com",
                                           port: 22, username: "root", authMode: .password,
                                           keyID: nil, password: "password-\(secretMarker)")
    let bridge = LeylineConnectionBridge(
        connections: { store.connections },
        identity: { SSHIdentityResolver.resolve($0, store: store) })
    return (bridge, store, keyConn, passwordConn, key)
}

@MainActor
private func resolve(_ bridge: LeylineConnectionBridge, _ id: String) -> AgentActionResult {
    let payload = try! JSONSerialization.data(withJSONObject: ["connection": id])
    return bridge.resolve(String(decoding: payload, as: UTF8.self))
}

@Suite("leyline.resolve_connection — the host-side connection bridge",
       .timeLimit(.minutes(1)))
@MainActor
struct LeylineConnectionBridgeTests {

    @Test("a key-backed connection resolves to decodable SSHConnectionInfo")
    func keyBackedConnectionResolves() throws {
        let fixture = makeFixture()
        let reply = resolve(fixture.bridge, fixture.keyConn.id.uuidString)
        #expect(!reply.isError)

        let info = try JSONDecoder().decode(SSHConnectionInfo.self, from: Data(reply.text.utf8))
        #expect(info.host == "web.example.com")
        #expect(info.user == "deploy")
        #expect(info.port == 2222)
        // Leyline stores no remote working directory; the field is optional and
        // absent, which must decode rather than fail.
        #expect(info.remoteWorkingDir == nil)

        // The identity is a real, owner-only file — otherwise `ssh` refuses it
        // ("UNPROTECTED PRIVATE KEY FILE") and the headless run fails.
        let path = try #require(info.identityPath)
        #expect(FileManager.default.fileExists(atPath: path))
        let mode = (try FileManager.default.attributesOfItem(atPath: path))[.posixPermissions] as? Int
        #expect(mode == 0o600)
        // The response references the key; it never carries it.
        #expect(!reply.text.contains(secretMarker))
    }

    /// The constraint this change surfaces rather than papers over: the host's
    /// `SSHArgsBuilder` bakes in `BatchMode=yes`, so no prompt can ever be
    /// answered. Handing back a password connection would fail later as an
    /// opaque `Permission denied`.
    @Test("a password-only connection is refused, naming the BatchMode limitation")
    func passwordOnlyConnectionIsRefused() {
        let fixture = makeFixture()
        let reply = resolve(fixture.bridge, fixture.passwordConn.id.uuidString)
        #expect(reply.isError)
        #expect(reply.text.contains("BatchMode=yes"))
        #expect(reply.text.contains("password"))
        // Actionable, not just a refusal: it says what to do instead.
        #expect(reply.text.contains("Leyline app"))
        #expect(reply.text.contains("connect"))
        #expect(reply.text.contains("Legacy box"))
        // And it is a refusal, not a connection that will fail later.
        #expect(!reply.text.contains("identityPath"))
        #expect(!reply.text.contains(secretMarker))
    }

    @Test("an unknown id is a clear error and resolves nothing")
    func unknownID() {
        let fixture = makeFixture()
        let reply = resolve(fixture.bridge, UUID().uuidString)
        #expect(reply.isError)
        #expect(reply.text.contains("no saved connection has that id"))
        #expect(!reply.text.contains("identityPath"))
    }

    @Test("malformed, missing and empty input are refused by name")
    func malformedInput() {
        let fixture = makeFixture()
        #expect(fixture.bridge.resolve("not json").isError)
        #expect(fixture.bridge.resolve("{}").isError)
        #expect(fixture.bridge.resolve("{}").text.contains("\"connection\""))
        #expect(resolve(fixture.bridge, "   ").isError)
        // The caller's own text is never reflected back — this reply can reach
        // the host's logs, and a credential pasted into the wrong field must not
        // ride along.
        let reply = resolve(fixture.bridge, secretMarker)
        #expect(reply.isError)
        #expect(!reply.text.contains(secretMarker))
    }

    @Test("a key-auth connection whose key is gone is refused, not silently downgraded")
    func keyRemovedFromVault() {
        let fixture = makeFixture()
        fixture.store.removeKey(fixture.key)
        let reply = resolve(fixture.bridge, fixture.keyConn.id.uuidString)
        #expect(reply.isError)
        #expect(reply.text.contains("no key selected") || reply.text.contains("no longer in Leyline's vault"))
    }

    @Test("ids match case-insensitively, but never by label or host")
    func matchesByIDOnly() {
        let fixture = makeFixture()
        #expect(!resolve(fixture.bridge, fixture.keyConn.id.uuidString.lowercased()).isError)
        for identifier in ["Prod web", "web.example.com"] {
            #expect(resolve(fixture.bridge, identifier).isError)
        }
    }

    /// The bridge's identity is a namespaced action id, in the style of
    /// `terminal.echo` and `gitmage.git_op` — never an MCP tool name.
    @Test("the action id is namespaced to Leyline")
    func actionIDIsNamespaced() {
        #expect(LeylineConnectionBridge.actionID == "leyline.resolve_connection")
        #expect(!LeylineMCPServer.tools.map(\.name).contains(LeylineConnectionBridge.actionID))
    }
}

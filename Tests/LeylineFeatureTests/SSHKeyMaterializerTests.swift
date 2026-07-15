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

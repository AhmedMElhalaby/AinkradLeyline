import Foundation
import Observation
import AinkradAppKit

/// Owns the connection + key lists and mediates their secrets. Metadata is
/// persisted as one document via `host.documents`; secrets go to `host.secrets`
/// (Keychain) only — never into the document JSON or logs.
@MainActor
@Observable
public final class LeylineStore {
    public private(set) var connections: [LeylineConnection]
    public private(set) var keys: [LeylineKey]
    private let documents: PluginDocumentStore
    private let secrets: PluginSecretStore

    public init(documents: PluginDocumentStore, secrets: PluginSecretStore) {
        self.documents = documents
        self.secrets = secrets
        let doc = Self.load(from: documents)
        self.connections = doc.connections
        self.keys = doc.keys
    }

    private static func load(from documents: PluginDocumentStore) -> LeylineDocument {
        guard let data = documents.data(forKey: LeylineDocument.documentID),
              let doc = try? JSONDecoder().decode(LeylineDocument.self, from: data)
        else { return LeylineDocument() }
        return doc
    }

    // MARK: Keys

    @discardableResult
    public func importKey(label: String, privateKey: String, passphrase: String?) -> LeylineKey {
        let hasPassphrase = !(passphrase ?? "").isEmpty
        let key = LeylineKey(id: UUID(), label: label, hasPassphrase: hasPassphrase, createdAt: Date())
        secrets.setSecret(privateKey, forKey: key.privateKeySecretID)
        if hasPassphrase { secrets.setSecret(passphrase, forKey: key.passphraseSecretID) }
        keys.append(key)
        persist()
        return key
    }

    public func privateKey(for key: LeylineKey) -> String? { secrets.secret(forKey: key.privateKeySecretID) }
    public func passphrase(for key: LeylineKey) -> String? { secrets.secret(forKey: key.passphraseSecretID) }

    public func removeKey(_ key: LeylineKey) {
        secrets.setSecret(nil, forKey: key.privateKeySecretID)
        secrets.setSecret(nil, forKey: key.passphraseSecretID)
        keys.removeAll { $0.id == key.id }
        for i in connections.indices where connections[i].keyID == key.id {
            connections[i].keyID = nil
        }
        persist()
    }

    // MARK: Connections

    @discardableResult
    public func addConnection(label: String, host: String, port: Int, username: String,
                              authMode: LeylineConnection.AuthMode, keyID: UUID?,
                              password: String?) -> LeylineConnection {
        let conn = LeylineConnection(id: UUID(), label: label, host: host, port: port,
                                     username: username, authMode: authMode, keyID: keyID, createdAt: Date())
        if authMode == .password, let password, !password.isEmpty {
            secrets.setSecret(password, forKey: conn.passwordSecretID)
        }
        connections.append(conn)
        persist()
        return conn
    }

    public func updateConnection(_ conn: LeylineConnection) {
        guard let idx = connections.firstIndex(where: { $0.id == conn.id }) else { return }
        connections[idx] = conn
        persist()
    }

    public func password(for conn: LeylineConnection) -> String? { secrets.secret(forKey: conn.passwordSecretID) }

    public func setPassword(_ password: String?, for conn: LeylineConnection) {
        let value = (password?.isEmpty ?? true) ? nil : password
        secrets.setSecret(value, forKey: conn.passwordSecretID)
    }

    public func removeConnection(_ conn: LeylineConnection) {
        secrets.setSecret(nil, forKey: conn.passwordSecretID)
        connections.removeAll { $0.id == conn.id }
        persist()
    }

    private func persist() {
        let doc = LeylineDocument(connections: connections, keys: keys)
        documents.setData(try? JSONEncoder().encode(doc), forKey: LeylineDocument.documentID)
    }
}

import Foundation
import AinkradAppKit

/// The sink behind Leyline's MCP tools: decodes one `{"operation": ..., ...}`
/// payload and answers it from the `LeylineCatalog`.
///
/// ## The hard constraint
///
/// **No code in this file can reach credential material.** Not by discipline —
/// by construction: this type holds a `LeylineCatalog`, which is three closures
/// over value types, and never a `LeylineStore`. `privateKey(for:)`,
/// `passphrase(for:)` and `password(for:)` are not in scope here, so no
/// success text, error text or diagnostic can be derived from them. See
/// `LeylineCatalog` for the full argument.
///
/// The published surface is correspondingly small, and the omissions are
/// deliberate rather than unfinished:
///
/// - No `add_connection` / `update_connection` / `remove_connection`, and no
///   key management. Editing the connection store is the user's job through the
///   UI. The value of the MCP surface is letting the assistant *find* a host and
///   offer to connect to it.
/// - Nothing that takes credential material as an ARGUMENT (`importKey`,
///   `setPassword`). Tool-call arguments land in the transcript exactly as tool
///   results do, so an "import this key" tool would leak by a different door.
/// - `connect` does NOT materialize a private key. `LeylineRootView.connect`
///   does (it calls `store.privateKey` and writes a 0600 file for `ssh`), and
///   that is right for a click the user made. It is not right for a tool call:
///   materializing means an agent decision causes plaintext key material to be
///   written to disk, and the identity path itself is derived from a secret.
///   An agent-initiated connect therefore sends `identityFile: nil` and leans
///   on the user's own `ssh-agent` / `~/.ssh/config`, which is exactly what a
///   bare `ssh user@host` in a terminal would do. `describeKeyAuth` tells the
///   model when that applies so it does not report a silent difference.
@MainActor
struct LeylineMCPOperations {
    let catalog: LeylineCatalog

    /// What `connect` and `list_connections` say when nothing is saved yet.
    ///
    /// This is the fresh-install state and the assistant WILL hit it. No tool
    /// can fix it — adding a connection is deliberately not published — so the
    /// only useful answer names what is missing and who can supply it.
    static let noConnectionsMessage =
        "Leyline has no saved connections. Open the Leyline app and add a host with the "
        + "+ button (connections and credentials are managed there, not from here)."

    func run(_ json: String) async -> AgentActionResult {
        guard let data = json.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let operation = object["operation"] as? String else {
            return .failure("Leyline: malformed request")
        }
        switch operation {
        case "listConnections": return listConnections(object)
        case "listKeys":        return listKeys()
        case "connect":         return connect(object)
        default:                return .failure("Leyline: unknown operation \"\(operation)\"")
        }
    }

    // MARK: - read

    /// Id, label, host, port, username — and nothing else.
    ///
    /// Explicitly NOT included: any secret, and any materialized key path. The
    /// key path is the subtle one: it is a filesystem path, so it looks like
    /// harmless metadata, but it names a plaintext copy of a private key and
    /// hands any tool with filesystem read a one-step route to the key itself.
    /// `authMode` and the key's *label* are safe and genuinely useful — they
    /// tell the model whether a password prompt is coming — so those are in.
    private func listConnections(_ object: [String: Any]) -> AgentActionResult {
        let all = catalog.connections()
        guard !all.isEmpty else { return .success(Self.noConnectionsMessage) }
        let query = (object["query"] as? String) ?? ""
        // Reuses the app's own filter so search from the assistant and search
        // in the sidebar can never disagree about what matches.
        let matches = ConnectionFilter.matching(query, in: all)
        guard !matches.isEmpty else {
            // The query is deliberately NOT echoed back — see `connect` below
            // for the reasoning. The caller knows what it asked for.
            return .success("No saved connection matches that query. "
                            + "Call list_connections with no query to see all \(all.count).")
        }
        let keyLabels = Dictionary(uniqueKeysWithValues: catalog.keys().map { ($0.id, $0.label) })
        let rows = matches.map { conn -> String in
            var line = "\(conn.id.uuidString)  \(conn.label.isEmpty ? "(unlabelled)" : conn.label)"
            line += "  —  \(conn.username.isEmpty ? "" : "\(conn.username)@")\(conn.host):\(conn.port)"
            line += "  [\(describeKeyAuth(conn, keyLabels: keyLabels))]"
            return line
        }
        return .success(rows.joined(separator: "\n"))
    }

    /// Id and label — and nothing else.
    ///
    /// Not `hasPassphrase`: whether a key is passphrase-protected is a property
    /// OF the secret, and publishing it tells an attacker which key is the
    /// cheap one to steal. It buys the model nothing, because it cannot use a
    /// key either way.
    private func listKeys() -> AgentActionResult {
        let keys = catalog.keys()
        guard !keys.isEmpty else {
            return .success("Leyline has no imported SSH keys. Import one from the key vault "
                            + "in the Leyline app (key material cannot be handled from here).")
        }
        return .success(keys
            .map { "\($0.id.uuidString)  \($0.label.isEmpty ? "(unlabelled)" : $0.label)" }
            .joined(separator: "\n"))
    }

    /// A short, secret-free description of how a connection authenticates.
    private func describeKeyAuth(_ conn: LeylineConnection,
                                 keyLabels: [UUID: String]) -> String {
        switch conn.authMode {
        case .password:
            return "password auth"
        case .key:
            guard let keyID = conn.keyID else { return "key auth, no key selected" }
            let label = keyLabels[keyID].flatMap { $0.isEmpty ? nil : $0 } ?? keyID.uuidString
            return "key auth: \(label)"
        }
    }

    // MARK: - connect

    private func connect(_ object: [String: Any]) -> AgentActionResult {
        guard let identifier = (object["connection"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !identifier.isEmpty else {
            return .failure("connect requires a \"connection\" (an id from list_connections).")
        }
        let all = catalog.connections()
        guard !all.isEmpty else { return .failure(Self.noConnectionsMessage) }
        // Id only. A label or hostname would be tempting, but they are not
        // unique — two connections can share a host with different usernames —
        // and picking the wrong one here opens a session to the wrong machine.
        guard let conn = all.first(where: { $0.id.uuidString.caseInsensitiveCompare(identifier) == .orderedSame }) else {
            // The rejected identifier is deliberately NOT echoed back.
            //
            // This looks like lost actionability, and it costs almost nothing:
            // the caller supplied the value, so it already knows it. What it
            // buys is that "no tool output ever contains secret material"
            // becomes an UNCONDITIONAL property of this file. An error that
            // echoes its input is the classic way a secret escapes a surface
            // that "doesn't return secrets" — it only takes one caller passing
            // a credential into the wrong field, and reflecting arbitrary
            // caller text also gives a prompt-injection payload a free ride
            // back into the transcript. `LeylineMCPCredentialLeakTests` calls
            // every tool with the seeded secret as its argument and pins this.
            return .failure("No saved connection has that id. "
                            + "Call list_connections to get the id of the host you mean.")
        }

        // `identityFile` is deliberately nil — see this type's doc comment.
        let payload = SSHLaunchPayload(host: conn.host, port: conn.port,
                                       username: conn.username, identityFile: nil)
        // Validate before launching. Every field lands in an `ssh` argv, and
        // `ssh`'s option surface (`-o ProxyCommand=…`) runs shell commands, so
        // a hostile hostname is code execution. The same guard the UI applies.
        guard let safe = try? payload.validated() else {
            return .failure("Connection \"\(label(conn))\" has an unsafe host, username or port "
                            + "and was not opened. Fix it in the Leyline app.")
        }

        // Surface the outcome instead of discarding it, and say what the user
        // can DO about each one — a tool result the model relays as "couldn't
        // connect" with no reason is a dead end for the person reading it.
        switch catalog.launch(safe) {
        case .opened:
            var text = "Opened a Terminal session to \(label(conn)) "
                + "(\(conn.username.isEmpty ? "" : "\(conn.username)@")\(conn.host):\(conn.port))."
            if conn.authMode == .key {
                // Say this plainly rather than let it look like a bug. The UI's
                // connect button passes `-i <materialized key>`; this one does
                // not, so a key that exists ONLY in Leyline's vault will not be
                // offered and `ssh` will fall through to the user's own agent.
                text += " This connection uses key auth, but tool-initiated connects do not "
                    + "materialize Leyline's stored key — ssh will use your ssh-agent or "
                    + "~/.ssh/config. Use the Connect button in the Leyline app to use the "
                    + "stored key."
            } else {
                text += " Terminal will prompt for the password."
            }
            return .success(text)
        case .unknownApp:
            return .failure("Couldn't connect to \(label(conn)): the Terminal app isn't installed. "
                            + "Install it from Ainkrad's App Store, then try again.")
        case .disabled:
            return .failure("Couldn't connect to \(label(conn)): the Terminal app is disabled. "
                            + "Enable it in Ainkrad's App Store, then try again.")
        case .refused(let why):
            return .failure("Couldn't connect to \(label(conn)): the host refused to open "
                            + "Terminal — \(why)")
        // `PluginLaunchOutcome` lives in a resilient module, so a newer SDK may
        // add a case this build has never seen. Treat unknown as FAILURE: a
        // false "connected" is worse than a false "didn't".
        @unknown default:
            return .failure("Couldn't connect to \(label(conn)): the host reported an "
                            + "unrecognised launch outcome.")
        }
    }

    private func label(_ conn: LeylineConnection) -> String {
        conn.label.isEmpty ? conn.host : conn.label
    }
}

private extension AgentActionResult {
    static func success(_ text: String) -> AgentActionResult { .init(text: text, isError: false) }
    static func failure(_ text: String) -> AgentActionResult { .init(text: text, isError: true) }
}

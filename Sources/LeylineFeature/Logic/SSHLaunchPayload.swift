import Foundation

/// The JSON payload Leyline hands Terminal via `host.apps.open`. Mirror of
/// Terminal's `SSHLaunch` (separate repos → duplicated contract on purpose).
struct SSHLaunchPayload: Encodable {
    let kind = "ssh"
    let host: String
    let port: Int
    let username: String
    let identityFile: String?

    var json: String {
        (try? String(data: JSONEncoder().encode(self), encoding: .utf8)) ?? "{\"kind\":\"ssh\"}"
    }
}

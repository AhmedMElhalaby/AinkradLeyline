import Foundation

/// Builds the `ssh` invocation for a connection. `identityFile` is nil in Slice 1
/// (keys aren't materialized to disk yet); Slice 2 passes the materialized
/// 600-file path so the command gains `-i <path>`.
public enum SSHCommand {
    public static func string(for c: LeylineConnection, identityFile: String? = nil) -> String {
        var parts = ["ssh"]
        if c.port != 22 { parts += ["-p", String(c.port)] }
        if let identityFile, !identityFile.isEmpty { parts += ["-i", shellQuote(identityFile)] }
        parts.append(c.username.isEmpty ? c.host : "\(c.username)@\(c.host)")
        return parts.joined(separator: " ")
    }

    /// Minimal POSIX single-quote escaping for display/paste of a path.
    static func shellQuote(_ s: String) -> String {
        if s.range(of: "[^A-Za-z0-9_./@:-]", options: .regularExpression) == nil { return s }
        return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

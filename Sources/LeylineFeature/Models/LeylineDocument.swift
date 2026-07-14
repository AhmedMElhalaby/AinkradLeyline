import Foundation

/// The single persisted, non-secret document for Leyline.
public struct LeylineDocument: Codable, Equatable {
    public static let documentID = "leyline"
    public var connections: [LeylineConnection]
    public var keys: [LeylineKey]

    public init(connections: [LeylineConnection] = [], keys: [LeylineKey] = []) {
        self.connections = connections
        self.keys = keys
    }
}

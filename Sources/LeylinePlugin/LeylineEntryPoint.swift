import Foundation
import AinkradAppKit
import LeylineFeature

/// The bundle's principal class (matches `NSPrincipalClass` in Info.plist).
@objc(LeylineEntryPoint)
final class LeylineEntryPoint: NSObject, AinkradPluginEntryPoint {
    static func app() -> any AinkradApp.Type { LeylineApp.self }
}

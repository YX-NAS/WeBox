import Foundation

public struct WeChatInfo: Equatable, Sendable {
    public let path: String
    public let bundleId: String
    public let version: String
    public init(path: String, bundleId: String, version: String) { self.path = path; self.bundleId = bundleId; self.version = version }
}

import Foundation

public struct WeChatInfo: Equatable, Sendable {
    public let application: ManagedApplication
    public let path: String
    public let bundleId: String
    public let version: String
    public init(application: ManagedApplication = .wechat, path: String, bundleId: String, version: String) {
        self.application = application; self.path = path; self.bundleId = bundleId; self.version = version
    }
}

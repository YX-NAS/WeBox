import Foundation

public struct WeChatDetector: Sendable {
    public static let defaultPath = "/Applications/WeChat.app"
    public init() {}
    public func detect(at path: String = defaultPath) throws -> WeChatInfo {
        try ApplicationDetector().detect(application: .wechat, at: path)
    }
}

public struct ApplicationDetector: Sendable {
    public init() {}

    public func detect(application: ManagedApplication) throws -> WeChatInfo {
        guard let path = application.candidatePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw WeBoxError.applicationNotFound(application.displayName)
        }
        return try detect(application: application, at: path)
    }

    public func detect(application: ManagedApplication, at path: String) throws -> WeChatInfo {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { throw WeBoxError.applicationNotFound(application.displayName) }
        guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier,
              let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { throw WeBoxError.invalidAppBundle(path) }
        return WeChatInfo(application: application, path: path, bundleId: identifier, version: version)
    }
}

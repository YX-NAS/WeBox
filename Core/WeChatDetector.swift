import Foundation

public struct WeChatDetector: Sendable {
    public static let defaultPath = "/Applications/WeChat.app"
    public init() {}
    public func detect(at path: String = defaultPath) throws -> WeChatInfo {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { throw WeBoxError.weChatNotFound }
        guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier,
              let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { throw WeBoxError.invalidAppBundle(path) }
        return WeChatInfo(path: path, bundleId: identifier, version: version)
    }
}

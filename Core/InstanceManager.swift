import Foundation

public struct InstanceManager: Sendable {
    private let repository: InstanceRepository
    private let cloneEngine = CloneEngine(); private let bundleManager = BundleManager(); private let signatureManager = SignatureManager()
    public init(repository: InstanceRepository) { self.repository = repository }
    @discardableResult public func createInstance(name: String, sourceInfo: WeChatInfo, installDirectory: String = "/Applications") throws -> WeChatInstance {
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        let target = URL(fileURLWithPath: installDirectory).appendingPathComponent("WeBox_\(safeName).app").path
        let identifier = bundleManager.bundleIdentifier(for: name)
        try cloneEngine.clone(sourceApp: sourceInfo.path, targetApp: target)
        do {
            try bundleManager.updateBundleIdentifier(appPath: target, bundleIdentifier: identifier)
            try signatureManager.sign(appPath: target)
            let instance = WeChatInstance(name: name, bundleIdentifier: identifier, appPath: target, version: sourceInfo.version, status: .ready)
            try repository.save(instance)
            return instance
        } catch {
            try? FileManager.default.removeItem(atPath: target)
            throw error
        }
    }
}

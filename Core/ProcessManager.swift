import AppKit
import Foundation

public struct ProcessManager: Sendable {
    public init() {}
    public func start(instance: WeChatInstance) throws {
        guard NSWorkspace.shared.open(URL(fileURLWithPath: instance.appPath)) else { throw WeBoxError.commandFailed("无法启动 \(instance.name)。") }
    }
    public func stop(instance: WeChatInstance) throws {
        let applications = NSRunningApplication.runningApplications(withBundleIdentifier: instance.bundleIdentifier)
        guard !applications.isEmpty else { throw WeBoxError.processNotRunning }
        applications.forEach { $0.terminate() }
    }
    public func restart(instance: WeChatInstance) throws { try? stop(instance: instance); try start(instance: instance) }
    public func pid(instance: WeChatInstance) -> pid_t? { NSRunningApplication.runningApplications(withBundleIdentifier: instance.bundleIdentifier).first?.processIdentifier }
}

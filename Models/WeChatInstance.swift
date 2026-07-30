import Foundation

public enum InstanceStatus: String, Codable, CaseIterable, Sendable {
    case created, ready, running, stopped, needUpdate, error

    public var displayName: String {
        switch self { case .created: "已创建"; case .ready: "就绪"; case .running: "运行中"; case .stopped: "已关闭"; case .needUpdate: "需要更新"; case .error: "异常" }
    }
}

public struct WeChatInstance: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var application: ManagedApplication
    public var name: String
    public var bundleIdentifier: String
    public var appPath: String
    public var version: String
    public var status: InstanceStatus
    public let createdAt: Date

    public init(id: UUID = UUID(), application: ManagedApplication = .wechat, name: String, bundleIdentifier: String = "", appPath: String = "", version: String = "", status: InstanceStatus = .created, createdAt: Date = Date()) {
        self.id = id; self.application = application; self.name = name; self.bundleIdentifier = bundleIdentifier; self.appPath = appPath; self.version = version; self.status = status; self.createdAt = createdAt
    }
}

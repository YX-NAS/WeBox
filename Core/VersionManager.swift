import Foundation

public struct VersionManager: Sendable {
    public init() {}
    public func status(for instance: WeChatInstance, currentWeChat: WeChatInfo) -> InstanceStatus { instance.version == currentWeChat.version ? instance.status : .needUpdate }
    public func refreshStatuses(repository: InstanceRepository, detector: WeChatDetector = WeChatDetector()) throws {
        let current = try detector.detect()
        for instance in try repository.all() { try repository.updateStatus(id: instance.id, status: status(for: instance, currentWeChat: current)) }
    }
}

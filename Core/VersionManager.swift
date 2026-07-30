import Foundation

public struct VersionManager: Sendable {
    public init() {}
    public func status(for instance: WeChatInstance, currentWeChat: WeChatInfo) -> InstanceStatus { instance.version == currentWeChat.version ? instance.status : .needUpdate }
    public func refreshStatuses(repository: InstanceRepository, detector: ApplicationDetector = ApplicationDetector()) throws {
        let sources = Dictionary(uniqueKeysWithValues: ManagedApplication.allCases.compactMap { application in
            (try? detector.detect(application: application)).map { (application, $0) }
        })
        for instance in try repository.all() {
            guard let current = sources[instance.application] else { continue }
            try repository.updateStatus(id: instance.id, status: status(for: instance, currentWeChat: current))
        }
    }
}

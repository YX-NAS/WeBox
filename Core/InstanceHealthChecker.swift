import Foundation

public enum InstanceIssue: String, Codable, CaseIterable, Sendable {
    case missingApplication
    case bundleIdentifierMismatch
    case invalidSignature
    case sourceVersionChanged

    public var displayName: String {
        switch self {
        case .missingApplication: "应用副本不存在"
        case .bundleIdentifierMismatch: "Bundle Identifier 不匹配"
        case .invalidSignature: "代码签名无效"
        case .sourceVersionChanged: "源应用已升级"
        }
    }
}

public struct InstanceHealthReport: Equatable, Sendable {
    public let instanceID: UUID
    public let status: InstanceStatus
    public let issues: [InstanceIssue]

    public var summary: String {
        issues.isEmpty ? "检查通过" : issues.map(\.displayName).joined(separator: "、")
    }

    public var canRepair: Bool {
        !issues.contains(.missingApplication) && !issues.contains(.sourceVersionChanged)
    }
}

public struct InstanceHealthChecker: Sendable {
    private let signatureManager = SignatureManager()

    public init() {}

    public func check(instance: WeChatInstance, currentWeChat: WeChatInfo? = nil) -> InstanceHealthReport {
        let appURL = URL(fileURLWithPath: instance.appPath)
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            return InstanceHealthReport(instanceID: instance.id, status: .error, issues: [.missingApplication])
        }

        var issues: [InstanceIssue] = []
        if Bundle(url: appURL)?.bundleIdentifier != instance.bundleIdentifier {
            issues.append(.bundleIdentifierMismatch)
        }
        if (try? signatureManager.verify(appPath: instance.appPath)) == nil {
            issues.append(.invalidSignature)
        }
        if let currentWeChat, currentWeChat.version != instance.version {
            issues.append(.sourceVersionChanged)
        }

        let status: InstanceStatus
        if issues.contains(.sourceVersionChanged) {
            status = .needUpdate
        } else if !issues.isEmpty {
            status = .error
        } else {
            status = instance.status == .running ? .running : .ready
        }
        return InstanceHealthReport(instanceID: instance.id, status: status, issues: issues)
    }
}

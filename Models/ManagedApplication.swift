import Foundation

public enum CloneCompatibility: Equatable, Sendable {
    case supported
    case experimental
    case restricted(String)

    public var canCreate: Bool {
        switch self {
        case .supported, .experimental: true
        case .restricted: false
        }
    }

    public var displayName: String {
        switch self {
        case .supported: "支持独立副本"
        case .experimental: "实验性支持"
        case .restricted(let reason): reason
        }
    }
}

public enum ManagedApplication: String, Codable, CaseIterable, Sendable {
    case wechat
    case qq
    case chatgpt
    case whatsapp
    case discord

    public static var catalogCases: [ManagedApplication] {
        allCases.filter(\.isVisibleInCatalog)
    }

    public var isVisibleInCatalog: Bool {
        self != .chatgpt
    }

    public var displayName: String {
        switch self {
        case .wechat: "微信"
        case .qq: "QQ"
        case .chatgpt: "ChatGPT"
        case .whatsapp: "WhatsApp"
        case .discord: "Discord"
        }
    }

    public var symbolName: String {
        switch self {
        case .wechat: "message.fill"
        case .qq: "bubble.left.and.bubble.right.fill"
        case .chatgpt: "sparkles"
        case .whatsapp: "phone.bubble.fill"
        case .discord: "person.2.fill"
        }
    }

    public var candidatePaths: [String] {
        switch self {
        case .wechat: ["/Applications/WeChat.app"]
        case .qq: ["/Applications/QQ.app"]
        case .chatgpt: ["/Applications/ChatGPT.app", "/Applications/ChatGPT Classic.app"]
        case .whatsapp: ["/Applications/WhatsApp.app"]
        case .discord: ["/Applications/Discord.app"]
        }
    }

    public var clonePrefix: String {
        self == .wechat ? "WeBox" : "WeBox_\(displayName)"
    }

    public var cloneCompatibility: CloneCompatibility {
        switch self {
        case .wechat:
            .supported
        case .qq:
            .experimental
        case .chatgpt:
            .restricted("受 OpenAI 签名、Keychain 与应用群组保护，不能创建独立副本")
        case .whatsapp:
            .experimental
        case .discord:
            .experimental
        }
    }
}

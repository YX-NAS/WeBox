import Foundation

public enum ManagedApplication: String, Codable, CaseIterable, Sendable {
    case wechat
    case chatgpt
    case whatsapp
    case discord

    public var displayName: String {
        switch self {
        case .wechat: "微信"
        case .chatgpt: "ChatGPT"
        case .whatsapp: "WhatsApp"
        case .discord: "Discord"
        }
    }

    public var symbolName: String {
        switch self {
        case .wechat: "message.fill"
        case .chatgpt: "sparkles"
        case .whatsapp: "phone.bubble.fill"
        case .discord: "person.2.fill"
        }
    }

    public var candidatePaths: [String] {
        switch self {
        case .wechat: ["/Applications/WeChat.app"]
        case .chatgpt: ["/Applications/ChatGPT.app", "/Applications/ChatGPT Classic.app"]
        case .whatsapp: ["/Applications/WhatsApp.app"]
        case .discord: ["/Applications/Discord.app"]
        }
    }

    public var clonePrefix: String {
        self == .wechat ? "WeBox" : "WeBox_\(displayName)"
    }
}

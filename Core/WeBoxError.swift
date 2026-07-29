import Foundation

public enum WeBoxError: LocalizedError {
    case weChatNotFound, invalidAppBundle(String), commandFailed(String), instanceAlreadyExists(String), databaseUnavailable, processNotRunning
    public var errorDescription: String? {
        switch self {
        case .weChatNotFound: "未在 /Applications 找到 WeChat.app。"
        case .invalidAppBundle(let path): "无效的应用包：\(path)"
        case .commandFailed(let message): message
        case .instanceAlreadyExists(let path): "目标实例已存在：\(path)"
        case .databaseUnavailable: "实例数据库不可用。"
        case .processNotRunning: "该实例当前没有运行。"
        }
    }
}

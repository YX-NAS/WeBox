import Foundation

public enum WeBoxError: LocalizedError {
    case weChatNotFound, applicationNotFound(String), applicationNotSupported(String), invalidAppBundle(String), commandFailed(String), instanceAlreadyExists(String), databaseUnavailable, processNotRunning, instanceIsRunning(String)
    public var errorDescription: String? {
        switch self {
        case .weChatNotFound: "未在 /Applications 找到 WeChat.app。"
        case .applicationNotFound(let name): "未在 /Applications 找到 \(name)。"
        case .applicationNotSupported(let message): message
        case .invalidAppBundle(let path): "无效的应用包：\(path)"
        case .commandFailed(let message): message
        case .instanceAlreadyExists(let path): "目标实例已存在：\(path)"
        case .databaseUnavailable: "实例数据库不可用。"
        case .processNotRunning: "该实例当前没有运行。"
        case .instanceIsRunning(let name): "“\(name)”正在运行，请先关闭后再修复。"
        }
    }
}

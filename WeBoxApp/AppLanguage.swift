import SwiftUI
import WeBoxCore

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }
    var name: String { self == .chinese ? "中文" : "English" }
    var isEnglish: Bool { self == .english }
}

func tr(_ chinese: String, _ english: String, _ language: AppLanguage) -> String {
    language.isEnglish ? english : chinese
}

extension InstanceStatus {
    func localizedName(_ language: AppLanguage) -> String {
        guard language.isEnglish else { return displayName }
        return switch self {
        case .created: "Created"; case .ready: "Ready"; case .running: "Running"
        case .stopped: "Stopped"; case .needUpdate: "Update needed"; case .error: "Error"
        }
    }
}

extension ManagedApplication {
    func localizedName(_ language: AppLanguage) -> String {
        self == .wechat && language.isEnglish ? "WeChat" : displayName
    }
}

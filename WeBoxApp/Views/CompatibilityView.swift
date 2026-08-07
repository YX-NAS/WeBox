import SwiftUI
import WeBoxCore

struct CompatibilityView: View {
    let installedApplications: [ManagedApplication]
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("应用兼容性", "App compatibility", language)).font(.title2.bold())
            Text(tr("仅列出本机应用副本的兼容性；不会检查或读取任何聊天、账号数据。", "Compatibility applies only to local app copies. No chat or account data is inspected.", language))
                .font(.caption).foregroundStyle(.secondary)
            ForEach(ManagedApplication.catalogCases, id: \.self) { application in
                HStack(spacing: 12) {
                    Image(systemName: application.symbolName).frame(width: 22).foregroundStyle(application.cloneCompatibility.canCreate ? Color.accentColor : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(application.localizedName(language)).font(.headline)
                        Text(status(for: application)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(installedApplications.contains(application) ? tr("已安装", "Installed", language) : tr("未安装", "Not installed", language))
                        .font(.caption.weight(.medium))
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            HStack { Spacer(); Button(tr("完成", "Done", language)) { dismiss() } }
        }
        .padding(24)
        .frame(width: 500)
    }

    private func status(for application: ManagedApplication) -> String {
        switch application.cloneCompatibility {
        case .supported: tr("已验证支持", "Verified", language)
        case .experimental: tr("实验性支持，需实际登录验证", "Experimental; verify with a real login", language)
        case .restricted: tr("不支持独立副本", "Not supported for independent copies", language)
        }
    }
}

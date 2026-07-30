import AppKit
import SwiftUI
import WeBoxCore

@MainActor
final class InstanceListViewModel: ObservableObject {
    @Published var instances: [WeChatInstance] = []
    @Published var healthReports: [UUID: InstanceHealthReport] = [:]
    @Published var errorMessage: String?
    @Published var isCreating = false

    private let repository: InstanceRepository?
    private let detector = ApplicationDetector()
    private let processManager = ProcessManager()

    init() {
        do {
            let database = try Database.defaultDatabase()
            let repository = try InstanceRepository(database: database)
            try InstanceManager(repository: repository).repairLegacyBundleIdentifiers()
            self.repository = repository
        } catch {
            self.repository = nil
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    var availableApplications: [ManagedApplication] {
        ManagedApplication.catalogCases.filter { (try? detector.detect(application: $0)) != nil }
    }

    func refresh() {
        do {
            guard let repository else { instances = []; return }
            let sources = Dictionary(uniqueKeysWithValues: ManagedApplication.allCases.compactMap { app in
                (try? detector.detect(application: app)).map { (app, $0) }
            })
            for instance in try repository.all() {
                let appExists = FileManager.default.fileExists(atPath: instance.appPath)
                let isRunning = appExists && processManager.pid(instance: instance) != nil
                let nextStatus: InstanceStatus
                if !instance.application.cloneCompatibility.canCreate { nextStatus = .error }
                else if !appExists { nextStatus = .error }
                else if isRunning { nextStatus = .running }
                else if let source = sources[instance.application], instance.version != source.version { nextStatus = .needUpdate }
                else { nextStatus = instance.status == .running ? .stopped : instance.status }
                if nextStatus != instance.status { try repository.updateStatus(id: instance.id, status: nextStatus) }
            }
            instances = try repository.all()
        }
        catch { errorMessage = error.localizedDescription }
    }

    func createInstance(application: ManagedApplication, named name: String) {
        guard !isCreating else { return }
        guard let repository else { errorMessage = WeBoxError.databaseUnavailable.localizedDescription; return }
        isCreating = true
        let detector = detector
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result {
                let info = try detector.detect(application: application)
                return try InstanceManager(repository: repository).createInstance(name: name, sourceInfo: info)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isCreating = false
                if case let .failure(error) = result { self.errorMessage = error.localizedDescription }
                self.refresh()
            }
        }
    }

    func start(_ instance: WeChatInstance) {
        do { try processManager.start(instance: instance); refreshAfterProcessChange() }
        catch { errorMessage = error.localizedDescription }
    }

    func stop(_ instance: WeChatInstance) {
        do { try processManager.stop(instance: instance); refreshAfterProcessChange() }
        catch { errorMessage = error.localizedDescription }
    }

    func delete(_ instance: WeChatInstance) {
        do {
            guard let repository else { throw WeBoxError.databaseUnavailable }
            try InstanceManager(repository: repository).deleteInstance(instance)
            refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func repair(_ instance: WeChatInstance) {
        do {
            guard let repository else { throw WeBoxError.databaseUnavailable }
            try InstanceManager(repository: repository).repairInstance(instance)
            refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func checkAll() {
        guard let repository else { errorMessage = WeBoxError.databaseUnavailable.localizedDescription; return }
        let detector = detector
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let sources = Dictionary(uniqueKeysWithValues: ManagedApplication.allCases.compactMap { app in
                (try? detector.detect(application: app)).map { (app, $0) }
            })
            let reports = (try? repository.all().map { InstanceHealthChecker().check(instance: $0, currentWeChat: sources[$0.application]) }) ?? []
            for report in reports { try? repository.updateStatus(id: report.instanceID, status: report.status) }
            DispatchQueue.main.async {
                self?.healthReports = Dictionary(uniqueKeysWithValues: reports.map { ($0.instanceID, $0) })
                self?.refresh()
            }
        }
    }

    func startAll(_ target: [WeChatInstance]) {
        for instance in target where processManager.pid(instance: instance) == nil {
            do { try processManager.start(instance: instance) } catch { errorMessage = error.localizedDescription; break }
        }
        refreshAfterProcessChange()
    }

    func stopAll(_ target: [WeChatInstance]) {
        for instance in target where processManager.pid(instance: instance) != nil {
            do { try processManager.stop(instance: instance) } catch { errorMessage = error.localizedDescription; break }
        }
        refreshAfterProcessChange()
    }

    func diagnosticsText() -> String {
        let header = ["WeBox v\(AppVersion.current) (\(AppVersion.build))", "生成时间：\(ISO8601DateFormatter().string(from: Date()))", "实例数：\(instances.count)"]
        let rows = instances.map { instance in
            let report = healthReports[instance.id]
            let healthSummary = report?.summary ?? "未执行完整检查"
            return ["应用：\(instance.application.displayName)", "名称：\(instance.name)", "状态：\(instance.status.displayName)", "版本：\(instance.version)", "Bundle ID：\(instance.bundleIdentifier)", "路径：\(instance.appPath)", "检查：\(healthSummary)"].joined(separator: "\n")
        }
        return (header + [""] + rows).joined(separator: "\n\n")
    }

    private func refreshAfterProcessChange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.refresh() }
    }
}

struct InstanceListView: View {
    @ObservedObject var model: InstanceListViewModel
    @AppStorage("appLanguage") private var languageRaw = AppLanguage.chinese.rawValue
    @State private var isShowingCreateSheet = false
    @State private var instancePendingDeletion: WeChatInstance?
    @State private var searchText = ""
    @State private var selectedStatus: InstanceStatus?
    @State private var isShowingDiagnostics = false
    @State private var selectedApplication: ManagedApplication?

    private var language: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .chinese }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.98, blue: 1.0), Color.white, Color(red: 0.95, green: 0.97, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider()

                if model.instances.isEmpty {
                    EmptyInstanceView(createAction: { isShowingCreateSheet = true })
                } else {
                    ScrollView {
                        SummaryStrip(
                            instances: model.instances,
                            searchText: $searchText,
                            selectedStatus: $selectedStatus,
                            selectedApplication: $selectedApplication,
                            language: language,
                            checkAction: model.checkAll
                        )
                            .padding(.bottom, 12)
                        LazyVStack(spacing: 10) {
                            ForEach(visibleInstances) { instance in
                                InstanceCard(
                                    instance: instance,
                                    language: language,
                                    healthReport: model.healthReports[instance.id],
                                    startAction: { model.start(instance) },
                                    stopAction: { model.stop(instance) },
                                    repairAction: { model.repair(instance) },
                                    deleteAction: { instancePendingDeletion = instance }
                                )
                            }
                        }
                        .padding(18)
                    }
                }

                footer
            }
        }
        .sheet(isPresented: $isShowingCreateSheet) {
            CreateInstanceSheet(installedApplications: model.availableApplications, language: language, isCreating: model.isCreating) { application, name in
                isShowingCreateSheet = false
                model.createInstance(application: application, named: name)
            }
        }
        .alert(tr("操作失败", "Action failed", language), isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button(tr("好", "OK", language), role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .confirmationDialog(tr("删除应用实例？", "Delete app instance?", language), isPresented: Binding(get: { instancePendingDeletion != nil }, set: { if !$0 { instancePendingDeletion = nil } })) {
            Button(tr("移入废纸篓并删除记录", "Move to Trash and remove record", language), role: .destructive) {
                if let instancePendingDeletion { model.delete(instancePendingDeletion) }
                instancePendingDeletion = nil
            }
            Button(tr("取消", "Cancel", language), role: .cancel) { instancePendingDeletion = nil }
        } message: {
            Text(tr("将关闭并把“\(instancePendingDeletion?.name ?? "")”移入废纸篓。", "This closes and moves “\(instancePendingDeletion?.name ?? "")” to Trash.", language))
        }
        .sheet(isPresented: $isShowingDiagnostics) {
            DiagnosticsView(text: model.diagnosticsText())
        }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            model.refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            BrandIconView()
                .frame(width: 58, height: 58)
                .shadow(color: Color.blue.opacity(0.22), radius: 10, y: 5)

            VStack(alignment: .leading, spacing: 3) {
                Text("WeBox").font(.system(size: 28, weight: .bold, design: .rounded))
                Text(tr("多应用实例 · 独立运行 · 受保护应用不复制", "Multi-app · isolated · local only", language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(language.isEnglish ? "\(model.instances.count) instances" : "\(model.instances.count) 个实例")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.trailing, 4)
            Button { isShowingCreateSheet = true } label: {
                Label(tr("创建实例", "Create", language), systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.isCreating)
            Menu {
                Button { model.checkAll() } label: { Label(tr("检查全部实例", "Check all instances", language), systemImage: "checkmark.shield") }
                Button { model.startAll(visibleInstances) } label: { Label(tr("启动可见实例", "Start visible", language), systemImage: "play.fill") }
                Button { model.stopAll(visibleInstances) } label: { Label(tr("关闭可见实例", "Stop visible", language), systemImage: "stop.fill") }
                Divider()
                Button { isShowingDiagnostics = true } label: { Label(tr("查看诊断信息", "Diagnostics", language), systemImage: "stethoscope") }
                Divider()
                Picker(tr("语言", "Language", language), selection: $languageRaw) {
                    ForEach(AppLanguage.allCases) { option in Text(option.name).tag(option.rawValue) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .help(tr("更多操作", "More actions", language))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var visibleInstances: [WeChatInstance] {
        model.instances.filter { instance in
            let matchesText = searchText.isEmpty || instance.name.localizedCaseInsensitiveContains(searchText) || instance.application.displayName.localizedCaseInsensitiveContains(searchText) || instance.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            let matchesStatus = selectedStatus == nil || instance.status == selectedStatus
            let matchesApplication = selectedApplication == nil || instance.application == selectedApplication
            return matchesText && matchesStatus && matchesApplication
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Label(tr("本地管理，不读取聊天内容", "Local only · no message access", language), systemImage: "lock.shield")
            Divider().frame(height: 12)
            Text("© 2026 YX-NAS")
            Spacer()
            Text(language.isEnglish ? "v\(AppVersion.current) (\(AppVersion.build))" : "开发版 v\(AppVersion.current) (\(AppVersion.build))")
            Text(language.isEnglish ? "Released \(AppReleaseInfo.date)" : "发布于 \(AppReleaseInfo.date)")
            Button(action: AppReleaseInfo.openReleasePage) {
                Label(tr("检查更新", "Check updates", language), systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderless)
            .help(tr("在 GitHub Releases 中查看最新版本", "View releases on GitHub", language))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

private struct EmptyInstanceView: View {
    let createAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(LinearGradient(colors: [.blue.opacity(0.18), .purple.opacity(0.13)], startPoint: .topLeading, endPoint: .bottomTrailing))
                BrandIconView().padding(12)
            }
            .frame(width: 132, height: 132)
            Text("还没有应用实例").font(.title2.bold())
            Text("创建独立副本后，可分别管理已安装的应用。")
                .foregroundStyle(.secondary)
            Button(action: createAction) {
                Label("创建第一个实例", systemImage: "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct InstanceCard: View {
    let instance: WeChatInstance
    let language: AppLanguage
    let healthReport: InstanceHealthReport?
    let startAction: () -> Void
    let stopAction: () -> Void
    let repairAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(LinearGradient(colors: [instance.application.tint.opacity(0.20), instance.application.secondaryTint.opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing))
                ManagedApplicationIconView(application: instance.application)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label(instance.application.localizedName(language), systemImage: instance.application.symbolName)
                        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    Text(instance.name).font(.headline).lineLimit(1)
                    Spacer(minLength: 4)
                    StatusBadge(status: instance.status, language: language)
                }
                Text("\(instance.application.localizedName(language)) \(instance.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(instance.bundleIdentifier)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                if let healthReport, !healthReport.issues.isEmpty {
                    Text(healthReport.summary)
                        .font(.caption)
                        .foregroundStyle(instance.status == .needUpdate ? .orange : .red)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 6) {
                CompactActionButton(title: tr("启动", "Start", language), icon: "play.fill", tint: .green, action: startAction)
                CompactActionButton(title: tr("关闭", "Stop", language), icon: "stop.fill", tint: .orange, action: stopAction)
                if instance.application.cloneCompatibility.canCreate && (healthReport?.canRepair == true || (healthReport == nil && instance.status == .error)) {
                    CompactActionButton(title: tr("修复", "Repair", language), icon: "wrench.and.screwdriver", tint: .blue, action: repairAction)
                }
                CompactActionButton(title: tr("删除", "Delete", language), icon: "trash", tint: .red, action: deleteAction)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).strokeBorder(LinearGradient(colors: [.white.opacity(0.9), .blue.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .shadow(color: Color.blue.opacity(0.06), radius: 8, y: 4)
    }

    private var statusColor: Color {
        switch instance.status {
        case .running: .green
        case .needUpdate, .error: .red
        case .stopped: .orange
        default: .blue
        }
    }
}

private struct StatusBadge: View {
    let status: InstanceStatus
    let language: AppLanguage
    var body: some View {
        Text(status.localizedName(language))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.quaternary, in: Capsule())
    }
}

private struct CompactActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.body.weight(.semibold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .help(title)
    }
}

private struct CreateInstanceSheet: View {
    let installedApplications: [ManagedApplication]
    let language: AppLanguage
    let isCreating: Bool
    let createAction: (ManagedApplication, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedApplication: ManagedApplication = .wechat

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.isEnglish ? "Create \(selectedApplication.localizedName(language)) instance" : "创建\(selectedApplication.localizedName(language))实例").font(.title2.bold())
                    Text(tr("每个实例都是独立的本机应用副本。", "Each instance is an independent local app copy.", language))
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(tr("应用", "Application", language)).font(.headline)
                Picker(tr("应用", "Application", language), selection: $selectedApplication) {
                    ForEach(ManagedApplication.catalogCases, id: \.self) { application in
                        if !installedApplications.contains(application) {
                            Text(language.isEnglish ? "\(application.localizedName(language)) (Not installed)" : "\(application.localizedName(language))（未安装）").tag(application).disabled(true)
                        } else if !application.cloneCompatibility.canCreate {
                            Text(language.isEnglish ? "\(application.localizedName(language)) (Protected)" : "\(application.localizedName(language))（受保护，不能创建副本）").tag(application).disabled(true)
                        } else {
                            Label(application.localizedName(language), systemImage: application.symbolName).tag(application)
                        }
                    }
                }
                .labelsHidden()
                Text(tr("实例名称", "Instance name", language)).font(.headline)
                TextField(tr("例如：工作", "e.g. Work", language), text: $name)
                    .textFieldStyle(.roundedBorder)
                Text(tr("同一应用内同名时会自动添加编号，例如“工作 2”。", "Duplicate names are numbered within the same app, e.g. Work 2.", language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button(tr("取消", "Cancel", language)) { dismiss() }
                Button {
                    createAction(selectedApplication, name)
                } label: {
                    Label(tr("创建实例", "Create instance", language), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!selectedApplication.cloneCompatibility.canCreate || installedApplications.filter(\.cloneCompatibility.canCreate).isEmpty || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
            }
        }
        .padding(28)
        .frame(width: 460)
        .onAppear {
            if let first = installedApplications.first(where: { $0.cloneCompatibility.canCreate }) { selectedApplication = first }
        }
    }
}

private struct BrandIconView: View {
    var body: some View {
        if let url = Bundle.main.url(forResource: "WeBoxIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .scaleEffect(1.27)
                .clipped()
        } else {
            Image(systemName: "message.badge.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.blue)
        }
    }
}

private struct ManagedApplicationIconView: View {
    let application: ManagedApplication
    let symbolSize: CGFloat
    let cornerRadius: CGFloat
    let inset: CGFloat

    init(application: ManagedApplication, symbolSize: CGFloat = 28, cornerRadius: CGFloat = 17, inset: CGFloat = 6) {
        self.application = application
        self.symbolSize = symbolSize
        self.cornerRadius = cornerRadius
        self.inset = inset
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(LinearGradient(colors: [application.tint, application.secondaryTint], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: application.symbolName)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
        }
        .padding(inset)
    }
}

private struct SummaryStrip: View {
    let instances: [WeChatInstance]
    @Binding var searchText: String
    @Binding var selectedStatus: InstanceStatus?
    @Binding var selectedApplication: ManagedApplication?
    let language: AppLanguage
    let checkAction: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            metric(title: tr("全部", "All", language), value: instances.count, color: .blue)
            metric(title: tr("运行中", "Running", language), value: instances.filter { $0.status == .running }.count, color: .green)
            metric(title: tr("待更新", "Updates", language), value: instances.filter { $0.status == .needUpdate }.count, color: .orange)
            Spacer(minLength: 18)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(tr("搜索实例", "Search instances", language), text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 210)
                Picker(tr("状态", "Status", language), selection: $selectedStatus) {
                    Text(tr("全部", "All", language)).tag(InstanceStatus?.none)
                    ForEach(InstanceStatus.allCases, id: \.self) { status in
                        Text(status.localizedName(language)).tag(Optional(status))
                    }
                }
                .labelsHidden()
                .frame(width: 84)
                Picker(tr("应用", "App", language), selection: $selectedApplication) {
                    Text(tr("所有应用", "All apps", language)).tag(ManagedApplication?.none)
                    ForEach(ManagedApplication.catalogCases, id: \.self) { application in
                        Text(application.localizedName(language)).tag(Optional(application))
                    }
                }
                .labelsHidden()
                .frame(width: 96)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.quaternary, in: Capsule())
            Spacer(minLength: 18)
            Button(tr("检查全部", "Check all", language), action: checkAction)
                .buttonStyle(.borderless)
            Text(tr("状态每 3 秒自动刷新", "Status refreshes every 3 seconds", language))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func metric(title: String, value: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(value)").font(.headline.monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct DiagnosticsView: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("诊断信息").font(.title2.bold())
            Text("仅包含 WeBox 版本与实例技术状态，不包含微信账号或聊天内容。")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                Text(text)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            HStack {
                Button("复制") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
                Spacer()
                Button("完成") { dismiss() }
            }
        }
        .padding(24)
        .frame(width: 620, height: 440)
    }
}

struct StatusBarView: View {
    @ObservedObject var model: InstanceListViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                BrandIconView().frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("WeBox").font(.headline)
                    Text(summary).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("v\(AppVersion.current)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Divider()

            if model.instances.isEmpty {
                Label("暂无应用实例", systemImage: "app.badge")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.instances.prefix(5)) { instance in
                    HStack(spacing: 9) {
                        ManagedApplicationIconView(application: instance.application, symbolSize: 11, cornerRadius: 6, inset: 2)
                            .frame(width: 24, height: 24)
                        Circle().fill(statusColor(instance.status)).frame(width: 8, height: 8)
                        Text("\(instance.application.displayName) · \(instance.name)").lineLimit(1)
                        Spacer()
                        Text(instance.status.displayName).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            Button { openWindow(id: "main") } label: {
                Label("打开 WeBox", systemImage: "macwindow")
            }
            Button { model.refresh() } label: {
                Label("刷新实例状态", systemImage: "arrow.clockwise")
            }
            Button(action: AppReleaseInfo.openReleasePage) {
                Label("检查更新", systemImage: "arrow.triangle.2.circlepath")
            }
            Button("退出 WeBox", role: .destructive) { NSApplication.shared.terminate(nil) }
        }
        .padding(16)
        .frame(width: 270)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var summary: String {
        let running = model.instances.filter { $0.status == .running }.count
        return running == 0 ? "\(model.instances.count) 个账号待命" : "\(running) 个账号正在运行"
    }

    private func statusColor(_ status: InstanceStatus) -> Color {
        switch status { case .running: .green; case .needUpdate, .error: .red; case .stopped: .orange; default: .blue }
    }
}

enum AppVersion {
    static var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}

enum AppReleaseInfo {
    static let date = "2026-07-30"
    static let releasesURL = URL(string: "https://github.com/YX-NAS/WeBox/releases")!

    static func openReleasePage() {
        NSWorkspace.shared.open(releasesURL)
    }
}

private extension ManagedApplication {
    var tint: Color {
        switch self {
        case .wechat: .green
        case .qq: Color(red: 0.18, green: 0.55, blue: 0.95)
        case .chatgpt: .teal
        case .whatsapp: Color(red: 0.13, green: 0.70, blue: 0.37)
        case .discord: Color(red: 0.35, green: 0.36, blue: 0.92)
        }
    }

    var secondaryTint: Color {
        switch self {
        case .wechat: .mint
        case .qq: .cyan
        case .chatgpt: .cyan
        case .whatsapp: .mint
        case .discord: .purple
        }
    }
}

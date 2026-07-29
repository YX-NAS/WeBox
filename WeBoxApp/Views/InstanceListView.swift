import AppKit
import SwiftUI
import WeBoxCore

@MainActor
final class InstanceListViewModel: ObservableObject {
    @Published var instances: [WeChatInstance] = []
    @Published var errorMessage: String?
    @Published var isCreating = false

    private let repository: InstanceRepository?
    private let detector = WeChatDetector()
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

    func refresh() {
        do {
            guard let repository else { instances = []; return }
            for instance in try repository.all() {
                let appExists = FileManager.default.fileExists(atPath: instance.appPath)
                let isRunning = appExists && processManager.pid(instance: instance) != nil
                let nextStatus: InstanceStatus = !appExists ? .error : (isRunning ? .running : (instance.status == .running ? .stopped : instance.status))
                if nextStatus != instance.status { try repository.updateStatus(id: instance.id, status: nextStatus) }
            }
            instances = try repository.all()
        }
        catch { errorMessage = error.localizedDescription }
    }

    func createInstance(named name: String) {
        guard !isCreating else { return }
        guard let repository else { errorMessage = WeBoxError.databaseUnavailable.localizedDescription; return }
        isCreating = true
        let detector = detector
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result {
                let info = try detector.detect()
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

    private func refreshAfterProcessChange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.refresh() }
    }
}

struct InstanceListView: View {
    @ObservedObject var model: InstanceListViewModel
    @State private var isShowingCreateSheet = false
    @State private var instancePendingDeletion: WeChatInstance?

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
                        SummaryStrip(instances: model.instances)
                            .padding(.bottom, 12)
                        LazyVStack(spacing: 10) {
                            ForEach(model.instances) { instance in
                                InstanceCard(
                                    instance: instance,
                                    startAction: { model.start(instance) },
                                    stopAction: { model.stop(instance) },
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
            CreateInstanceSheet(isCreating: model.isCreating) { name in
                isShowingCreateSheet = false
                model.createInstance(named: name)
            }
        }
        .alert("操作失败", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("好", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .confirmationDialog("删除微信实例？", isPresented: Binding(get: { instancePendingDeletion != nil }, set: { if !$0 { instancePendingDeletion = nil } })) {
            Button("移入废纸篓并删除记录", role: .destructive) {
                if let instancePendingDeletion { model.delete(instancePendingDeletion) }
                instancePendingDeletion = nil
            }
            Button("取消", role: .cancel) { instancePendingDeletion = nil }
        } message: {
            Text("将关闭并把“\(instancePendingDeletion?.name ?? "")”移入废纸篓。")
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
                Text("微信多开 · 独立运行 · 安全隔离")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(model.instances.count) 个实例")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.trailing, 4)
            Button { isShowingCreateSheet = true } label: {
                Label("创建实例", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.isCreating)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var footer: some View {
        HStack {
            Label("本地管理，不读取聊天内容", systemImage: "lock.shield")
            Spacer()
            Text("WeBox v\(AppVersion.current) · macOS 13+")
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
            Text("还没有微信实例").font(.title2.bold())
            Text("创建独立副本后，可分别登录和管理多个微信账号。")
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
    let startAction: () -> Void
    let stopAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(LinearGradient(colors: [.blue.opacity(0.16), .purple.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                BrandIconView()
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(instance.name).font(.headline).lineLimit(1)
                    Spacer(minLength: 4)
                    StatusBadge(status: instance.status)
                }
                Text("微信 \(instance.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(instance.bundleIdentifier)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                CompactActionButton(title: "启动", icon: "play.fill", tint: .green, action: startAction)
                CompactActionButton(title: "关闭", icon: "stop.fill", tint: .orange, action: stopAction)
                CompactActionButton(title: "删除", icon: "trash", tint: .red, action: deleteAction)
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
    var body: some View {
        Text(status.displayName)
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
    let isCreating: Bool
    let createAction: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("创建微信实例").font(.title2.bold())
                    Text("每个实例都是独立的微信应用副本。")
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("实例名称").font(.headline)
                TextField("例如：工作微信", text: $name)
                    .textFieldStyle(.roundedBorder)
                Text("同名时会自动添加编号，例如“工作微信 2”。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button {
                    createAction(name)
                } label: {
                    Label("创建实例", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
            }
        }
        .padding(28)
        .frame(width: 460)
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

private struct SummaryStrip: View {
    let instances: [WeChatInstance]

    var body: some View {
        HStack(spacing: 18) {
            metric(title: "全部", value: instances.count, color: .blue)
            metric(title: "运行中", value: instances.filter { $0.status == .running }.count, color: .green)
            metric(title: "待更新", value: instances.filter { $0.status == .needUpdate }.count, color: .orange)
            Spacer()
            Text("状态每 3 秒自动刷新")
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
                Label("暂无微信实例", systemImage: "message")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.instances.prefix(5)) { instance in
                    HStack(spacing: 9) {
                        Circle().fill(statusColor(instance.status)).frame(width: 8, height: 8)
                        Text(instance.name).lineLimit(1)
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
}

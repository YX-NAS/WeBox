import Foundation
import WeBoxCore

private var failures = 0

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        failures += 1
        fputs("FAIL: \(message)\n", stderr)
    }
}

private func temporaryDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("WeBoxTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

do {
    let bundleManager = BundleManager()
    expect(bundleManager.bundleIdentifier(for: "工作") != bundleManager.bundleIdentifier(for: "生活"), "中文名称必须生成不同 Bundle Identifier")
    expect(bundleManager.bundleIdentifier(for: "工作微信 2") == "com.webox.wechat.u5de5u4f5cu5faeu4fe1-2", "中文 Bundle Identifier 规则错误")
    expect(bundleManager.bundleIdentifier(for: "work", application: .chatgpt) == "com.webox.chatgpt.work", "ChatGPT Bundle Identifier 规则错误")

    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let databasePath = root.appendingPathComponent("webox.sqlite").path
    let repository = try InstanceRepository(database: Database(path: databasePath))
    var instance = WeChatInstance(name: "测试", bundleIdentifier: "com.webox.wechat.test", appPath: root.appendingPathComponent("Missing.app").path, version: "1.0", status: .ready)
    try repository.save(instance)
    let savedInstances = try repository.all()
    expect(savedInstances.count == 1, "SQLite 保存实例失败")
    instance.status = .stopped
    try repository.save(instance)
    let updatedInstances = try repository.all()
    expect(updatedInstances.first?.status == .stopped, "SQLite 更新实例失败")
    let chatGPTInstance = WeChatInstance(application: .chatgpt, name: "测试", bundleIdentifier: "com.webox.chatgpt.test", appPath: root.appendingPathComponent("ChatGPT.app").path, version: "1.0", status: .ready)
    try repository.save(chatGPTInstance)
    let multiAppInstances = try repository.all()
    expect(multiAppInstances.contains(where: { $0.id == chatGPTInstance.id && $0.application == .chatgpt }), "SQLite 必须保存应用类型")

    let legacyPath = root.appendingPathComponent("legacy.sqlite").path
    let legacyID = UUID().uuidString
    let legacySQL = "CREATE TABLE instances (id TEXT PRIMARY KEY, name TEXT NOT NULL, bundle_id TEXT NOT NULL, app_path TEXT NOT NULL, version TEXT NOT NULL, status TEXT NOT NULL, created_at REAL NOT NULL); INSERT INTO instances VALUES ('\(legacyID)', '旧微信', 'com.webox.wechat.legacy', '/tmp/Legacy.app', '1.0', 'ready', 0);"
    _ = try CommandRunner().run("/usr/bin/sqlite3", arguments: [legacyPath, legacySQL])
    let legacyRepository = try InstanceRepository(database: Database(path: legacyPath))
    let legacyInstances = try legacyRepository.all()
    expect(legacyInstances.first?.application == .wechat, "旧数据库记录必须迁移为微信类型")

    let source = root.appendingPathComponent("Source.app")
    let target = root.appendingPathComponent("Target.app")
    try FileManager.default.createDirectory(at: source.appendingPathComponent("Contents"), withIntermediateDirectories: true)
    try "fixture".write(to: source.appendingPathComponent("Contents/value"), atomically: true, encoding: .utf8)
    try CloneEngine().clone(sourceApp: source.path, targetApp: target.path)
    expect(FileManager.default.fileExists(atPath: target.appendingPathComponent("Contents/value").path), "应用副本复制失败")

    let report = InstanceHealthChecker().check(instance: instance)
    expect(report.status == .error && report.issues == [.missingApplication], "缺失副本必须报告异常")

    let fixture = root.appendingPathComponent("Fixture.app")
    let fixtureContents = fixture.appendingPathComponent("Contents")
    try FileManager.default.createDirectory(at: fixtureContents, withIntermediateDirectories: true)
    let fixturePlist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.example.wrong</string></dict></plist>
    """
    try fixturePlist.write(to: fixtureContents.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
    let mismatched = WeChatInstance(name: "错误副本", bundleIdentifier: "com.webox.wechat.expected", appPath: fixture.path, version: "1.0", status: .ready)
    let mismatchReport = InstanceHealthChecker().check(instance: mismatched)
    expect(mismatchReport.issues.contains(.bundleIdentifierMismatch), "Bundle Identifier 不匹配必须被检测")
    expect(mismatchReport.issues.contains(.invalidSignature), "无效签名必须被检测")

    try repository.delete(id: instance.id)
    try repository.delete(id: chatGPTInstance.id)
    let finalInstances = try repository.all()
    expect(finalInstances.isEmpty, "SQLite 删除实例失败")
} catch {
    failures += 1
    fputs("FAIL: \(error.localizedDescription)\n", stderr)
}

if failures == 0 {
    print("WeBox acceptance tests passed")
    exit(EXIT_SUCCESS)
}
exit(EXIT_FAILURE)

import Foundation
import WeBoxCore

private var failures = 0

private func fail(_ message: String) {
    failures += 1
    fputs("FAIL: \(message)\n", stderr)
}

private func temporaryDirectory() throws -> URL {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("WeBoxIntegration-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

let detector = ApplicationDetector()
var testedApplications: [ManagedApplication] = []

for application in ManagedApplication.allCases {
    guard let source = try? detector.detect(application: application) else {
        print("SKIP: \(application.displayName) 未安装")
        continue
    }

    do {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try InstanceRepository(database: Database(path: root.appendingPathComponent("webox.sqlite").path))
        let instance = try InstanceManager(repository: repository).createInstance(
            name: "Integration",
            sourceInfo: source,
            installDirectory: root.path
        )
        guard FileManager.default.fileExists(atPath: instance.appPath) else {
            fail("\(application.displayName) 副本未创建")
            continue
        }
        guard Bundle(url: URL(fileURLWithPath: instance.appPath))?.bundleIdentifier == instance.bundleIdentifier else {
            fail("\(application.displayName) Bundle Identifier 未写入")
            continue
        }
        try SignatureManager().verify(appPath: instance.appPath)
        guard try repository.all().first?.application == application else {
            fail("\(application.displayName) 应用类型未持久化")
            continue
        }
        testedApplications.append(application)
        print("PASS: \(application.displayName) 复制、标识符、签名与存储")
    } catch {
        fail("\(application.displayName)：\(error.localizedDescription)")
    }
}

if testedApplications.isEmpty {
    fail("未检测到可执行真实副本测试的受支持应用")
}

if failures == 0 {
    print("WeBox installed-app integration tests passed (\(testedApplications.map(\.displayName).joined(separator: ", ")))")
    exit(EXIT_SUCCESS)
}
exit(EXIT_FAILURE)

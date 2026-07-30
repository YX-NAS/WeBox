import XCTest
@testable import WeBoxCore

final class WeBoxTests: XCTestCase {
    func testInstanceCanBeCreated() {
        let instance = WeChatInstance(name: "工作微信")
        XCTAssertEqual(instance.name, "工作微信")
        XCTAssertEqual(instance.status, .created)
    }
    func testBundleIdentifierRule() {
        XCTAssertEqual(BundleManager().bundleIdentifier(for: "work"), "com.webox.wechat.work")
        XCTAssertEqual(BundleManager().bundleIdentifier(for: "工作微信 2"), "com.webox.wechat.u5de5u4f5cu5faeu4fe1-2")
        XCTAssertNotEqual(BundleManager().bundleIdentifier(for: "工作"), BundleManager().bundleIdentifier(for: "生活"))
        XCTAssertEqual(BundleManager().bundleIdentifier(for: "work", application: .discord), "com.webox.discord.work")
    }
    func testRepositoryPersistsInstance() throws {
        let path = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let repository = try InstanceRepository(database: Database(path: path))
        let instance = WeChatInstance(name: "测试")
        try repository.save(instance)
        XCTAssertEqual(try repository.all().first?.id, instance.id)
        try repository.delete(id: instance.id)
        XCTAssertTrue(try repository.all().isEmpty)
    }
    func testRepositoryPersistsApplicationType() throws {
        let path = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let repository = try InstanceRepository(database: Database(path: path))
        let instance = WeChatInstance(application: .whatsapp, name: "家庭", bundleIdentifier: "com.webox.whatsapp.u5bb6u5ead", appPath: "/tmp/WhatsApp.app", version: "1.0")
        try repository.save(instance)
        XCTAssertEqual(try repository.all().first?.application, .whatsapp)
    }
    func testCloneCopiesApplicationBundle() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("WeChat.app"); let target = root.appendingPathComponent("WeBox_Work.app")
        try FileManager.default.createDirectory(at: source.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        try "test".write(to: source.appendingPathComponent("Contents/value"), atomically: true, encoding: .utf8)
        try CloneEngine().clone(sourceApp: source.path, targetApp: target.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.appendingPathComponent("Contents/value").path))
    }
}

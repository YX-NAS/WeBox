import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class InstanceRepository: @unchecked Sendable {
    private let database: Database
    public init(database: Database) throws { self.database = database; try createTable() }
    private func createTable() throws {
        try database.execute("""
        CREATE TABLE IF NOT EXISTS instances (
            id TEXT PRIMARY KEY, name TEXT NOT NULL, bundle_id TEXT NOT NULL, app_path TEXT NOT NULL,
            version TEXT NOT NULL, status TEXT NOT NULL, created_at REAL NOT NULL,
            app_type TEXT NOT NULL DEFAULT 'wechat'
        );
        """)
        try? database.execute("ALTER TABLE instances ADD COLUMN app_type TEXT NOT NULL DEFAULT 'wechat';")
    }
    public func save(_ instance: WeChatInstance) throws {
        let sql = "INSERT OR REPLACE INTO instances (id,name,bundle_id,app_path,version,status,created_at,app_type) VALUES (?,?,?,?,?,?,?,?);"
        var statement: OpaquePointer?; defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database.handle, sql, -1, &statement, nil) == SQLITE_OK else { throw WeBoxError.commandFailed("无法写入实例。") }
        sqlite3_bind_text(statement, 1, instance.id.uuidString, -1, SQLITE_TRANSIENT); sqlite3_bind_text(statement, 2, instance.name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, instance.bundleIdentifier, -1, SQLITE_TRANSIENT); sqlite3_bind_text(statement, 4, instance.appPath, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, instance.version, -1, SQLITE_TRANSIENT); sqlite3_bind_text(statement, 6, instance.status.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 7, instance.createdAt.timeIntervalSince1970)
        sqlite3_bind_text(statement, 8, instance.application.rawValue, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw WeBoxError.commandFailed("无法保存实例。") }
    }
    public func all() throws -> [WeChatInstance] {
        var statement: OpaquePointer?; defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database.handle, "SELECT id,name,bundle_id,app_path,version,status,created_at,app_type FROM instances ORDER BY created_at DESC;", -1, &statement, nil) == SQLITE_OK else { throw WeBoxError.commandFailed("无法读取实例。") }
        var result: [WeChatInstance] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idText = sqlite3_column_text(statement, 0), let id = UUID(uuidString: String(cString: idText)) else { continue }
            let value: (Int32) -> String = { String(cString: sqlite3_column_text(statement, $0)) }
            let appType = sqlite3_column_text(statement, 7).map { ManagedApplication(rawValue: String(cString: $0)) } ?? nil
            result.append(WeChatInstance(id: id, application: appType ?? .wechat, name: value(1), bundleIdentifier: value(2), appPath: value(3), version: value(4), status: InstanceStatus(rawValue: value(5)) ?? .error, createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))))
        }
        return result
    }
    public func updateStatus(id: UUID, status: InstanceStatus) throws {
        try update("UPDATE instances SET status = ? WHERE id = ?;", status.rawValue, id.uuidString)
    }
    public func delete(id: UUID) throws { try update("DELETE FROM instances WHERE id = ?;", id.uuidString) }
    private func update(_ sql: String, _ values: String...) throws {
        var statement: OpaquePointer?; defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database.handle, sql, -1, &statement, nil) == SQLITE_OK else { throw WeBoxError.commandFailed("无法更新实例。") }
        for (index, value) in values.enumerated() { sqlite3_bind_text(statement, Int32(index + 1), value, -1, SQLITE_TRANSIENT) }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw WeBoxError.commandFailed("无法更新实例。") }
    }
}

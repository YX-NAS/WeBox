import Foundation
import SQLite3

public final class Database: @unchecked Sendable {
    fileprivate var handle: OpaquePointer?
    public init(path: String) throws {
        guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else { throw WeBoxError.commandFailed("无法打开实例数据库。") }
        try execute("PRAGMA foreign_keys = ON;")
    }
    deinit { sqlite3_close(handle) }
    public static func defaultDatabase() throws -> Database {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("WeBox", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return try Database(path: support.appendingPathComponent("webox.sqlite").path)
    }
    fileprivate func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(handle, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "SQLite error"; sqlite3_free(error); throw WeBoxError.commandFailed(message)
        }
    }
}

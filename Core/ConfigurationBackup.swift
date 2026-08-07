import Foundation

public struct WeBoxConfigurationBackup: Codable, Sendable {
    public let schemaVersion: Int
    public let exportedAt: Date
    public let instances: [WeChatInstance]

    public init(schemaVersion: Int = 1, exportedAt: Date = Date(), instances: [WeChatInstance]) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.instances = instances
    }
}

public struct ConfigurationBackupManager: Sendable {
    private let repository: InstanceRepository
    public init(repository: InstanceRepository) { self.repository = repository }

    public func exportData() throws -> Data {
        let backup = WeBoxConfigurationBackup(instances: try repository.all())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    @discardableResult public func importData(_ data: Data) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(WeBoxConfigurationBackup.self, from: data)
        guard backup.schemaVersion == 1 else { throw WeBoxError.commandFailed("不支持的 WeBox 配置备份版本。") }
        for instance in backup.instances { try repository.save(instance) }
        return backup.instances.count
    }
}

import Foundation

public struct TerminasBackupData: Codable {
    public var version: Int
    public var exportedAt: Date
    public var workspaces: [WorkspaceItem]
    public var hosts: [HostItem]
    public var snippets: [SnippetItem]
    public var tunnels: [TunnelItem]
    
    public init(
        version: Int = 1,
        exportedAt: Date = Date(),
        workspaces: [WorkspaceItem],
        hosts: [HostItem],
        snippets: [SnippetItem],
        tunnels: [TunnelItem]
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.workspaces = workspaces
        self.hosts = hosts
        self.snippets = snippets
        self.tunnels = tunnels
    }
}

public enum BackupService {
    public static func createBackup(
        workspaces: [WorkspaceItem],
        hosts: [HostItem],
        snippets: [SnippetItem],
        tunnels: [TunnelItem]
    ) -> Data? {
        let backup = TerminasBackupData(
            workspaces: workspaces,
            hosts: hosts,
            snippets: snippets,
            tunnels: tunnels
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(backup)
    }
    
    public static func loadBackup(from data: Data) -> TerminasBackupData? {
        // If encrypted with CryptoService, try decrypt first
        let decrypted = CryptoService.decrypt(data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let result = try? decoder.decode(TerminasBackupData.self, from: decrypted) {
            return result
        }
        return try? decoder.decode(TerminasBackupData.self, from: data)
    }
}

import Foundation

public struct SnippetItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var command: String
    public var category: String
    public var runImmediately: Bool
    public var createdAt: Date
    public var workspaceId: UUID?
    
    public init(
        id: UUID = UUID(),
        title: String,
        command: String,
        category: String = "General",
        runImmediately: Bool = true,
        createdAt: Date = Date(),
        workspaceId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.command = command
        self.category = category
        self.runImmediately = runImmediately
        self.createdAt = createdAt
        self.workspaceId = workspaceId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        command = try container.decode(String.self, forKey: .command)
        category = try container.decode(String.self, forKey: .category)
        runImmediately = try container.decode(Bool.self, forKey: .runImmediately)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        workspaceId = try container.decodeIfPresent(UUID.self, forKey: .workspaceId)
    }
}

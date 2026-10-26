import Foundation

public struct WorkspaceItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var iconName: String
    public var colorHex: String
    public var isProduction: Bool
    public var createdAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "briefcase.fill",
        colorHex: String = "#0A84FF",
        isProduction: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.isProduction = isProduction
        self.createdAt = createdAt
    }
}

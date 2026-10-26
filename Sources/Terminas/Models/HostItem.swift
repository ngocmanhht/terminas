import Foundation

public enum AuthType: String, Codable, CaseIterable, Identifiable, Sendable {
    case password = "Password"
    case keyFile = "SSH Key File"
    case agent = "SSH Agent"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .password: return "key.fill"
        case .keyFile: return "doc.badge.key"
        case .agent: return "shield.lefthalf.filled"
        }
    }
}

public enum ElevateMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case su = "su - [user]"
    case sudo = "sudo -i"
    case custom = "Custom Command"
    
    public var id: String { rawValue }
}

public struct HostItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var label: String
    public var hostname: String
    public var port: Int
    public var username: String
    public var authType: AuthType
    public var keyPath: String
    public var tags: [String]
    public var colorHex: String
    public var iconName: String
    public var notes: String
    public var createdAt: Date
    public var lastConnectedAt: Date?
    
    // Auto Elevate (su / sudo) settings
    public var autoElevate: Bool
    public var elevateMethod: ElevateMethod
    public var elevateUser: String
    public var customElevateCommand: String
    
    // Workspace association
    public var workspaceId: UUID?
    
    // Proxy Jump / Bastion Host association
    public var jumpHostId: UUID?
    
    public init(
        id: UUID = UUID(),
        label: String,
        hostname: String,
        port: Int = 22,
        username: String = "root",
        authType: AuthType = .keyFile,
        keyPath: String = "~/.ssh/id_ed25519",
        tags: [String] = [],
        colorHex: String = "#0A84FF",
        iconName: String = "server.rack",
        notes: String = "",
        createdAt: Date = Date(),
        lastConnectedAt: Date? = nil,
        autoElevate: Bool = false,
        elevateMethod: ElevateMethod = .su,
        elevateUser: String = "root",
        customElevateCommand: String = "",
        workspaceId: UUID? = nil,
        jumpHostId: UUID? = nil
    ) {
        self.id = id
        self.label = label
        self.hostname = hostname
        self.port = port
        self.username = username
        self.authType = authType
        self.keyPath = keyPath
        self.tags = tags
        self.colorHex = colorHex
        self.iconName = iconName
        self.notes = notes
        self.createdAt = createdAt
        self.lastConnectedAt = lastConnectedAt
        self.autoElevate = autoElevate
        self.elevateMethod = elevateMethod
        self.elevateUser = elevateUser
        self.customElevateCommand = customElevateCommand
        self.workspaceId = workspaceId
        self.jumpHostId = jumpHostId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        hostname = try container.decode(String.self, forKey: .hostname)
        port = try container.decode(Int.self, forKey: .port)
        username = try container.decode(String.self, forKey: .username)
        authType = try container.decode(AuthType.self, forKey: .authType)
        keyPath = try container.decode(String.self, forKey: .keyPath)
        tags = try container.decode([String].self, forKey: .tags)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        iconName = try container.decode(String.self, forKey: .iconName)
        notes = try container.decode(String.self, forKey: .notes)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastConnectedAt = try container.decodeIfPresent(Date.self, forKey: .lastConnectedAt)
        
        autoElevate = try container.decodeIfPresent(Bool.self, forKey: .autoElevate) ?? false
        elevateMethod = try container.decodeIfPresent(ElevateMethod.self, forKey: .elevateMethod) ?? .su
        elevateUser = try container.decodeIfPresent(String.self, forKey: .elevateUser) ?? "root"
        customElevateCommand = try container.decodeIfPresent(String.self, forKey: .customElevateCommand) ?? ""
        workspaceId = try container.decodeIfPresent(UUID.self, forKey: .workspaceId)
        jumpHostId = try container.decodeIfPresent(UUID.self, forKey: .jumpHostId)
    }
    
    public var displayTitle: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "\(username)@\(hostname)" : label
    }
    
    public var connectionString: String {
        "\(username)@\(hostname)\(port == 22 ? "" : ":\(port)")"
    }
}

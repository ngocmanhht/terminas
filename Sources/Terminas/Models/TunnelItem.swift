import Foundation

public enum TunnelType: String, Codable, CaseIterable, Identifiable, Sendable {
    case local = "Local Port Forwarding (-L)"
    case remote = "Remote Port Forwarding (-R)"
    case socks = "Dynamic SOCKS5 (-D)"
    
    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .local: return "Local (-L)"
        case .remote: return "Remote (-R)"
        case .socks: return "SOCKS5 (-D)"
        }
    }
}

public struct TunnelItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var hostId: UUID
    public var tunnelType: TunnelType
    public var localPort: Int
    public var remoteHost: String
    public var remotePort: Int
    public var isAutoStart: Bool
    public var createdAt: Date
    public var workspaceId: UUID?
    
    public init(
        id: UUID = UUID(),
        name: String,
        hostId: UUID,
        tunnelType: TunnelType = .local,
        localPort: Int = 8080,
        remoteHost: String = "127.0.0.1",
        remotePort: Int = 8080,
        isAutoStart: Bool = false,
        createdAt: Date = Date(),
        workspaceId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.hostId = hostId
        self.tunnelType = tunnelType
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.isAutoStart = isAutoStart
        self.createdAt = createdAt
        self.workspaceId = workspaceId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        hostId = try container.decode(UUID.self, forKey: .hostId)
        tunnelType = try container.decode(TunnelType.self, forKey: .tunnelType)
        localPort = try container.decode(Int.self, forKey: .localPort)
        remoteHost = try container.decode(String.self, forKey: .remoteHost)
        remotePort = try container.decode(Int.self, forKey: .remotePort)
        isAutoStart = try container.decode(Bool.self, forKey: .isAutoStart)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        workspaceId = try container.decodeIfPresent(UUID.self, forKey: .workspaceId)
    }
    
    public var forwardingSummary: String {
        switch tunnelType {
        case .local:
            return "127.0.0.1:\(localPort) ➔ \(remoteHost):\(remotePort)"
        case .remote:
            return "\(remoteHost):\(remotePort) ➔ 127.0.0.1:\(localPort)"
        case .socks:
            return "SOCKS5 Proxy on 127.0.0.1:\(localPort)"
        }
    }
}

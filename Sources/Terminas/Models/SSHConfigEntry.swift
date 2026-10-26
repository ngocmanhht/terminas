import Foundation

public struct SSHConfigEntry: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var host: String
    public var hostName: String
    public var user: String
    public var port: Int
    public var identityFile: String
    public var proxyJump: String
    public var forwardAgent: Bool
    
    public init(
        id: UUID = UUID(),
        host: String,
        hostName: String = "",
        user: String = "",
        port: Int = 22,
        identityFile: String = "",
        proxyJump: String = "",
        forwardAgent: Bool = false
    ) {
        self.id = id
        self.host = host
        self.hostName = hostName
        self.user = user
        self.port = port
        self.identityFile = identityFile
        self.proxyJump = proxyJump
        self.forwardAgent = forwardAgent
    }
}

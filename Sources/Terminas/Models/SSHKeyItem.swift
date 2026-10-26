import Foundation

public enum KeyAlgorithm: String, CaseIterable, Identifiable, Sendable {
    case ed25519 = "ED25519 (Recommended)"
    case rsa4096 = "RSA 4096-bit"
    case rsa2048 = "RSA 2048-bit"
    case ecdsa256 = "ECDSA 256-bit"
    case ecdsa521 = "ECDSA 521-bit"
    
    public var id: String { rawValue }
    
    public var typeFlag: String {
        switch self {
        case .ed25519: return "ed25519"
        case .rsa4096, .rsa2048: return "rsa"
        case .ecdsa256, .ecdsa521: return "ecdsa"
        }
    }
    
    public var bits: Int? {
        switch self {
        case .rsa4096: return 4096
        case .rsa2048: return 2048
        case .ecdsa256: return 256
        case .ecdsa521: return 521
        case .ed25519: return nil
        }
    }
    
    public var defaultFilename: String {
        switch self {
        case .ed25519: return "id_ed25519"
        case .rsa4096, .rsa2048: return "id_rsa"
        case .ecdsa256, .ecdsa521: return "id_ecdsa"
        }
    }
}

public struct SSHKeyItem: Identifiable, Hashable, Sendable {
    public var id: String { path }
    public var name: String
    public var path: String
    public var pubPath: String
    public var algorithm: String
    public var fingerprint: String
    public var comment: String
    public var publicKeyContent: String
    public var createdAt: Date
    
    public init(
        name: String,
        path: String,
        pubPath: String,
        algorithm: String,
        fingerprint: String,
        comment: String,
        publicKeyContent: String,
        createdAt: Date = Date()
    ) {
        self.name = name
        self.path = path
        self.pubPath = pubPath
        self.algorithm = algorithm
        self.fingerprint = fingerprint
        self.comment = comment
        self.publicKeyContent = publicKeyContent
        self.createdAt = createdAt
    }
}

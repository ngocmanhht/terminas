import Foundation

public struct ZshEnvItem: Identifiable, Hashable, Sendable {
    public var id: String { key }
    public var key: String
    public var value: String
    public var isExported: Bool
    public var lineNumber: Int
    
    public init(key: String, value: String, isExported: Bool = true, lineNumber: Int = 0) {
        self.key = key
        self.value = value
        self.isExported = isExported
        self.lineNumber = lineNumber
    }
}

public struct ZshAliasItem: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public var name: String
    public var command: String
    public var lineNumber: Int
    
    public init(name: String, command: String, lineNumber: Int = 0) {
        self.name = name
        self.command = command
        self.lineNumber = lineNumber
    }
}

public struct ZshPathItem: Identifiable, Hashable, Sendable {
    public var id: String { directory }
    public var directory: String
    public var existsOnDisk: Bool
    
    public init(directory: String, existsOnDisk: Bool = true) {
        self.directory = directory
        self.existsOnDisk = existsOnDisk
    }
}

public struct ZshPluginItem: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public var name: String
    
    public init(name: String) {
        self.name = name
    }
}

public enum ShellFileTarget: String, CaseIterable, Identifiable, Sendable {
    case zshrc = ".zshrc"
    case zprofile = ".zprofile"
    case zshenv = ".zshenv"
    case bashProfile = ".bash_profile"
    case bashrc = ".bashrc"
    
    public var id: String { rawValue }
    
    public var filename: String { rawValue }
    
    public var description: String {
        switch self {
        case .zshrc: return "Main interactive shell config (Recommended)"
        case .zprofile: return "Login shell configuration"
        case .zshenv: return "Environment variables for all zsh shells"
        case .bashProfile: return "Legacy bash login profile"
        case .bashrc: return "Legacy bash interactive config"
        }
    }
    
    public var fileURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(rawValue)
    }
}

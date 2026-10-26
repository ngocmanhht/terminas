import Foundation

public struct RemoteFileItem: Identifiable, Hashable, Sendable {
    public var id: String { path }
    public var name: String
    public var path: String
    public var isDirectory: Bool
    public var sizeBytes: Int64
    public var permissions: String
    public var modifiedDate: String
    
    public init(
        name: String,
        path: String,
        isDirectory: Bool,
        sizeBytes: Int64 = 0,
        permissions: String = "",
        modifiedDate: String = ""
    ) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.sizeBytes = sizeBytes
        self.permissions = permissions
        self.modifiedDate = modifiedDate
    }
    
    public var formattedSize: String {
        if isDirectory { return "--" }
        return ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    
    public var iconName: String {
        if isDirectory { return "folder.fill" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "sh", "bash", "zsh": return "terminal"
        case "py", "js", "ts", "swift", "go", "rs", "c", "cpp", "java", "php", "html", "css": return "chevron.left.forwardslash.chevron.right"
        case "json", "yaml", "yml", "xml", "toml", "conf", "ini", "env": return "gearshape.fill"
        case "log", "txt", "md": return "doc.text"
        case "zip", "tar", "gz", "bz2", "xz", "7z": return "archivebox.fill"
        case "png", "jpg", "jpeg", "gif", "webp", "svg": return "photo"
        case "key", "pem", "pub": return "key.fill"
        default: return "doc"
        }
    }
}

import Foundation

public enum SSHConfigParser {
    public static func parseDefaultConfigFile() -> [HostItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let configPath = (home as NSString).appendingPathComponent(".ssh/config")
        guard FileManager.default.fileExists(atPath: configPath) else { return [] }
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else { return [] }
        return parse(content: content)
    }
    
    public static func parse(content: String) -> [HostItem] {
        var hosts: [HostItem] = []
        let lines = content.components(separatedBy: .newlines)
        
        var currentAliases: [String] = []
        var currentHostName: String?
        var currentUser: String = "root"
        var currentPort: Int = 22
        var currentKeyPath: String = ""
        
        func flushCurrent() {
            guard !currentAliases.isEmpty else { return }
            for alias in currentAliases {
                // Skip wildcard patterns
                if alias.contains("*") || alias.contains("?") { continue }
                
                let targetHost = currentHostName ?? alias
                let auth: AuthType = !currentKeyPath.isEmpty ? .keyFile : .agent
                
                let item = HostItem(
                    label: alias,
                    hostname: targetHost,
                    port: currentPort,
                    username: currentUser,
                    authType: auth,
                    keyPath: currentKeyPath,
                    tags: ["Imported", "ssh-config"],
                    colorHex: "#0A84FF",
                    iconName: "server.rack"
                )
                hosts.append(item)
            }
            currentAliases = []
            currentHostName = nil
            currentUser = "root"
            currentPort = 22
            currentKeyPath = ""
        }
        
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 2 else { continue }
            
            let key = parts[0].lowercased()
            let value = parts.dropFirst().joined(separator: " ")
            
            if key == "host" {
                flushCurrent()
                currentAliases = Array(parts.dropFirst())
            } else if key == "hostname" {
                currentHostName = value
            } else if key == "user" {
                currentUser = value
            } else if key == "port" {
                currentPort = Int(value) ?? 22
            } else if key == "identityfile" {
                currentKeyPath = value
            }
        }
        flushCurrent()
        
        return hosts
    }
}

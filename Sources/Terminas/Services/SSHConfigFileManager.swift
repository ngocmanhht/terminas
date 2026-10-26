import Foundation
import Combine

@MainActor
public class SSHConfigFileManager: ObservableObject {
    @Published public var entries: [SSHConfigEntry] = []
    @Published public var rawConfigText: String = ""
    @Published public var errorMessage: String? = nil
    
    private let configURL: URL
    
    public init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let sshDir = home.appendingPathComponent(".ssh", isDirectory: true)
        try? FileManager.default.createDirectory(at: sshDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        self.configURL = sshDir.appendingPathComponent("config")
        load()
    }
    
    public func load() {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            self.entries = []
            self.rawConfigText = "# ~/.ssh/config\n"
            return
        }
        
        do {
            let content = try String(contentsOf: configURL, encoding: .utf8)
            self.rawConfigText = content
            self.entries = parseEntries(from: content)
        } catch {
            self.errorMessage = "Failed to load config: \(error.localizedDescription)"
        }
    }
    
    public func saveEntries() {
        var output = "# Generated & Managed by Terminas\n\n"
        for entry in entries {
            output += "Host \(entry.host)\n"
            if !entry.hostName.isEmpty {
                output += "    HostName \(entry.hostName)\n"
            }
            if !entry.user.isEmpty {
                output += "    User \(entry.user)\n"
            }
            if entry.port != 22 {
                output += "    Port \(entry.port)\n"
            }
            if !entry.identityFile.isEmpty {
                output += "    IdentityFile \(entry.identityFile)\n"
            }
            if !entry.proxyJump.isEmpty {
                output += "    ProxyJump \(entry.proxyJump)\n"
            }
            if entry.forwardAgent {
                output += "    ForwardAgent yes\n"
            }
            output += "\n"
        }
        
        saveRaw(output)
    }
    
    public func saveRaw(_ text: String) {
        do {
            try text.write(to: configURL, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)
            self.rawConfigText = text
            self.entries = parseEntries(from: text)
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    public func addEntry(_ entry: SSHConfigEntry) {
        entries.append(entry)
        saveEntries()
    }
    
    public func updateEntry(_ entry: SSHConfigEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
            saveEntries()
        }
    }
    
    public func deleteEntry(_ entry: SSHConfigEntry) {
        entries.removeAll { $0.id == entry.id }
        saveEntries()
    }
    
    private func parseEntries(from text: String) -> [SSHConfigEntry] {
        var result: [SSHConfigEntry] = []
        let lines = text.components(separatedBy: .newlines)
        
        var currentHost: String? = nil
        var hostName: String = ""
        var user: String = ""
        var port: Int = 22
        var identityFile: String = ""
        var proxyJump: String = ""
        var forwardAgent: Bool = false
        
        func flush() {
            guard let h = currentHost else { return }
            result.append(SSHConfigEntry(
                host: h,
                hostName: hostName,
                user: user,
                port: port,
                identityFile: identityFile,
                proxyJump: proxyJump,
                forwardAgent: forwardAgent
            ))
            currentHost = nil
            hostName = ""
            user = ""
            port = 22
            identityFile = ""
            proxyJump = ""
            forwardAgent = false
        }
        
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 2 else { continue }
            
            let key = parts[0].lowercased()
            let val = parts.dropFirst().joined(separator: " ")
            
            if key == "host" {
                flush()
                currentHost = val
            } else if key == "hostname" {
                hostName = val
            } else if key == "user" {
                user = val
            } else if key == "port" {
                port = Int(val) ?? 22
            } else if key == "identityfile" {
                identityFile = val
            } else if key == "proxyjump" {
                proxyJump = val
            } else if key == "forwardagent" {
                forwardAgent = (val.lowercased() == "yes" || val.lowercased() == "true")
            }
        }
        flush()
        
        return result
    }
}

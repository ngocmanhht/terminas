import Foundation
import Combine

@MainActor
public class SSHKeyManager: ObservableObject {
    @Published public var keys: [SSHKeyItem] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    
    public init() {
        scanKeys()
    }
    
    public func scanKeys() {
        isLoading = true
        errorMessage = nil
        
        Task.detached(priority: .userInitiated) {
            let found = Self.scanSSHDirectory()
            await MainActor.run {
                self.keys = found
                self.isLoading = false
            }
        }
    }
    
    public func generateKey(
        algorithm: KeyAlgorithm,
        filename: String,
        comment: String,
        passphrase: String
    ) async throws -> SSHKeyItem {
        let sshDir = (FileManager.default.homeDirectoryForCurrentUser.path as NSString).appendingPathComponent(".ssh")
        try? FileManager.default.createDirectory(atPath: sshDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        
        let safeName = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyPath = (sshDir as NSString).appendingPathComponent(safeName)
        let pubPath = keyPath + ".pub"
        
        guard !FileManager.default.fileExists(atPath: keyPath) else {
            throw NSError(domain: "SSHKeyManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "A key with the name '\(safeName)' already exists."])
        }
        
        var args = [
            "-t", algorithm.typeFlag,
            "-C", comment.trimmingCharacters(in: .whitespacesAndNewlines),
            "-f", keyPath,
            "-N", passphrase
        ]
        if let bits = algorithm.bits {
            args.append(contentsOf: ["-b", "\(bits)"])
        }
        
        let proc = Process()
        let errPipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
        proc.arguments = args
        proc.standardError = errPipe
        
        try proc.run()
        proc.waitUntilExit()
        
        guard proc.terminationStatus == 0 else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "Failed to generate SSH key"
            throw NSError(domain: "SSHKeyManager", code: Int(proc.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errMsg.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
        
        // Ensure private key has 0600 permissions
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyPath)
        
        let pubContent = (try? String(contentsOfFile: pubPath, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fingerprint = Self.readFingerprint(of: pubPath)
        
        let newItem = SSHKeyItem(
            name: safeName,
            path: keyPath,
            pubPath: pubPath,
            algorithm: algorithm.rawValue,
            fingerprint: fingerprint,
            comment: comment,
            publicKeyContent: pubContent,
            createdAt: Date()
        )
        
        scanKeys()
        return newItem
    }
    
    public func deleteKey(_ item: SSHKeyItem) {
        try? FileManager.default.removeItem(atPath: item.path)
        try? FileManager.default.removeItem(atPath: item.pubPath)
        scanKeys()
    }
    
    nonisolated private static func scanSSHDirectory() -> [SSHKeyItem] {
        let sshDir = (FileManager.default.homeDirectoryForCurrentUser.path as NSString).appendingPathComponent(".ssh")
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: sshDir) else { return [] }
        
        var items: [SSHKeyItem] = []
        let pubFiles = files.filter { $0.hasSuffix(".pub") }
        
        for pubFile in pubFiles {
            let pubPath = (sshDir as NSString).appendingPathComponent(pubFile)
            let privateName = String(pubFile.dropLast(4))
            let privatePath = (sshDir as NSString).appendingPathComponent(privateName)
            
            guard let pubContent = try? String(contentsOfFile: pubPath, encoding: .utf8) else { continue }
            let trimmedPub = pubContent.trimmingCharacters(in: .whitespacesAndNewlines)
            let fingerprint = readFingerprint(of: pubPath)
            
            // Parse algorithm & comment from pub content
            let parts = trimmedPub.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            var algo = "SSH Key"
            var comment = ""
            if parts.count >= 1 {
                let typeStr = parts[0]
                if typeStr.contains("ed25519") { algo = "ED25519" }
                else if typeStr.contains("rsa") { algo = "RSA" }
                else if typeStr.contains("ecdsa") { algo = "ECDSA" }
            }
            if parts.count >= 3 {
                comment = parts.dropFirst(2).joined(separator: " ")
            }
            
            let attrs = try? FileManager.default.attributesOfItem(atPath: pubPath)
            let created = (attrs?[.creationDate] as? Date) ?? Date()
            
            items.append(SSHKeyItem(
                name: privateName,
                path: privatePath,
                pubPath: pubPath,
                algorithm: algo,
                fingerprint: fingerprint,
                comment: comment,
                publicKeyContent: trimmedPub,
                createdAt: created
            ))
        }
        
        return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    nonisolated private static func readFingerprint(of path: String) -> String {
        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
        proc.arguments = ["-lf", path]
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let out = String(data: data, encoding: .utf8) {
            let parts = out.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespaces)
            if parts.count >= 2 {
                return parts[1] // Usually SHA256:...
            }
        }
        return "N/A"
    }
}

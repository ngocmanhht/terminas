import Foundation

@MainActor
public class SFTPService: ObservableObject {
    @Published public var currentPath: String = "/root"
    @Published public var files: [RemoteFileItem] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var activeTransfer: String? = nil
    
    public init() {}
    
    public func listDirectory(host: HostItem, jumpHost: HostItem? = nil, path: String) {
        isLoading = true
        errorMessage = nil
        let targetPath = path.isEmpty ? "~" : path
        
        Task {
            let result = await Self.fetchFiles(host: host, jumpHost: jumpHost, path: targetPath)
            self.isLoading = false
            switch result {
            case .success(let (resolvedPath, items)):
                self.currentPath = resolvedPath
                self.files = items
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    public func createDirectory(host: HostItem, jumpHost: HostItem? = nil, folderName: String) async -> Bool {
        let newPath = (currentPath as NSString).appendingPathComponent(folderName)
        let cmd = "mkdir -p '\(newPath)'"
        let success = await Self.runSSH(host: host, jumpHost: jumpHost, command: cmd)
        if success {
            listDirectory(host: host, jumpHost: jumpHost, path: currentPath)
        }
        return success
    }
    
    public func deleteItem(host: HostItem, jumpHost: HostItem? = nil, item: RemoteFileItem) async -> Bool {
        let cmd = "rm -rf '\(item.path)'"
        let success = await Self.runSSH(host: host, jumpHost: jumpHost, command: cmd)
        if success {
            listDirectory(host: host, jumpHost: jumpHost, path: currentPath)
        }
        return success
    }
    
    public func downloadFile(host: HostItem, jumpHost: HostItem? = nil, item: RemoteFileItem, localURL: URL) async -> Bool {
        activeTransfer = "Downloading \(item.name)..."
        var args = Self.scpArgs(host: host, jumpHost: jumpHost)
        let remoteSpec = "\(host.username)@\(host.hostname):'\(item.path)'"
        args.append(remoteSpec)
        args.append(localURL.path)
        
        let (proc, tempFile) = Self.prepareProcess(executable: "/usr/bin/scp", args: args, host: host, jumpHost: jumpHost)
        let success = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                defer {
                    if let tempFile { try? FileManager.default.removeItem(at: tempFile) }
                }
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    continuation.resume(returning: proc.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
        activeTransfer = nil
        return success
    }
    
    public func uploadFile(host: HostItem, jumpHost: HostItem? = nil, localURL: URL, remoteFolder: String) async -> Bool {
        activeTransfer = "Uploading \(localURL.lastPathComponent)..."
        var args = Self.scpArgs(host: host, jumpHost: jumpHost)
        args.append(localURL.path)
        let remoteSpec = "\(host.username)@\(host.hostname):'\(remoteFolder)/'"
        args.append(remoteSpec)
        
        let (proc, tempFile) = Self.prepareProcess(executable: "/usr/bin/scp", args: args, host: host, jumpHost: jumpHost)
        let success = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                defer {
                    if let tempFile { try? FileManager.default.removeItem(at: tempFile) }
                }
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    continuation.resume(returning: proc.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
        
        activeTransfer = nil
        if success {
            listDirectory(host: host, jumpHost: jumpHost, path: remoteFolder)
        }
        return success
    }
    
    public func readFilePreview(host: HostItem, jumpHost: HostItem? = nil, path: String) async -> String? {
        let cmd = "head -n 300 '\(path)'"
        var args = Self.sshArgs(host: host, jumpHost: jumpHost)
        args.append("\(host.username)@\(host.hostname)")
        args.append(cmd)
        
        let (proc, tempFile) = Self.prepareProcess(executable: "/usr/bin/ssh", args: args, host: host, jumpHost: jumpHost)
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                defer {
                    if let tempFile { try? FileManager.default.removeItem(at: tempFile) }
                }
                let pipe = Pipe()
                proc.standardOutput = pipe
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let text = String(data: data, encoding: .utf8)
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    nonisolated private static func runSSH(host: HostItem, jumpHost: HostItem? = nil, command: String) async -> Bool {
        var args = sshArgs(host: host, jumpHost: jumpHost)
        args.append("\(host.username)@\(host.hostname)")
        args.append(command)
        
        let (proc, tempFile) = prepareProcess(executable: "/usr/bin/ssh", args: args, host: host, jumpHost: jumpHost)
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                defer {
                    if let tempFile { try? FileManager.default.removeItem(at: tempFile) }
                }
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    continuation.resume(returning: proc.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    nonisolated private static func prepareProcess(
        executable: String,
        args: [String],
        host: HostItem,
        jumpHost: HostItem? = nil
    ) -> (proc: Process, tempFile: URL?) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        
        let authPrep = SSHAuthHelper.prepareAuth(for: host, jumpHost: jumpHost, oneTime: false)
        proc.environment = authPrep.environment
        
        var finalArgs = args
        finalArgs.append(contentsOf: authPrep.extraArgs)
        proc.arguments = finalArgs
        
        return (proc, authPrep.tempFile)
    }
    
    nonisolated private static func scpArgs(host: HostItem, jumpHost: HostItem? = nil) -> [String] {
        var args = [
            "-o", "ConnectTimeout=10",
            "-o", "StrictHostKeyChecking=accept-new"
        ]
        if host.authType == .password {
            args.append(contentsOf: [
                "-o", "BatchMode=no",
                "-o", "NumberOfPasswordPrompts=1"
            ])
        } else {
            args.append(contentsOf: [
                "-o", "BatchMode=yes"
            ])
        }
        if let jh = jumpHost {
            let jumpTarget = "\(jh.username)@\(jh.hostname)\(jh.port == 22 ? "" : ":\(jh.port)")"
            args.append(contentsOf: ["-J", jumpTarget])
        }
        if host.port != 22 {
            args.append(contentsOf: ["-P", "\(host.port)"])
        }
        if host.authType == .keyFile && !host.keyPath.isEmpty {
            let expanded = (host.keyPath as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expanded) {
                args.append(contentsOf: ["-i", expanded, "-o", "IdentitiesOnly=yes"])
            }
        }
        return args
    }
    
    nonisolated private static func sshArgs(host: HostItem, jumpHost: HostItem? = nil) -> [String] {
        var args = [
            "-o", "ConnectTimeout=7",
            "-o", "StrictHostKeyChecking=accept-new"
        ]
        if host.authType == .password {
            args.append(contentsOf: [
                "-o", "BatchMode=no",
                "-o", "NumberOfPasswordPrompts=1"
            ])
        } else {
            args.append(contentsOf: [
                "-o", "BatchMode=yes"
            ])
        }
        if let jh = jumpHost {
            let jumpTarget = "\(jh.username)@\(jh.hostname)\(jh.port == 22 ? "" : ":\(jh.port)")"
            args.append(contentsOf: ["-J", jumpTarget])
        }
        if host.port != 22 {
            args.append(contentsOf: ["-p", "\(host.port)"])
        }
        if host.authType == .keyFile && !host.keyPath.isEmpty {
            let expanded = (host.keyPath as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expanded) {
                args.append(contentsOf: ["-i", expanded, "-o", "IdentitiesOnly=yes"])
            }
        }
        return args
    }
    
    nonisolated private static func fetchFiles(host: HostItem, jumpHost: HostItem? = nil, path: String) async -> Result<(String, [RemoteFileItem]), Error> {
        let script = "cd '\(path)' 2>/dev/null && pwd && ls -la"
        var args = sshArgs(host: host, jumpHost: jumpHost)
        args.append("\(host.username)@\(host.hostname)")
        args.append(script)
        
        let (proc, tempFile) = prepareProcess(executable: "/usr/bin/ssh", args: args, host: host, jumpHost: jumpHost)
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                defer {
                    if let tempFile { try? FileManager.default.removeItem(at: tempFile) }
                }
                let pipe = Pipe()
                let errPipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = errPipe
                
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
                        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                        let errMsg = String(data: errData, encoding: .utf8) ?? "Failed to connect"
                        continuation.resume(returning: .failure(NSError(domain: "SFTPService", code: 1, userInfo: [NSLocalizedDescriptionKey: errMsg])))
                        return
                    }
                    
                    let lines = output.components(separatedBy: "\n")
                    guard let resolvedPath = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines), !resolvedPath.isEmpty else {
                        continuation.resume(returning: .failure(NSError(domain: "SFTPService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid remote path"])))
                        return
                    }
                    
                    var items: [RemoteFileItem] = []
                    for line in lines.dropFirst() {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, !trimmed.hasPrefix("total") else { continue }
                        
                        let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        guard tokens.count >= 9 else { continue }
                        
                        let permissions = tokens[0]
                        let isDir = permissions.hasPrefix("d")
                        let size = Int64(tokens[4]) ?? 0
                        let modified = "\(tokens[5]) \(tokens[6]) \(tokens[7])"
                        let name = tokens.dropFirst(8).joined(separator: " ")
                        
                        if name == "." || name == ".." { continue }
                        
                        let fullPath = (resolvedPath as NSString).appendingPathComponent(name)
                        items.append(RemoteFileItem(
                            name: name,
                            path: fullPath,
                            isDirectory: isDir,
                            sizeBytes: size,
                            permissions: permissions,
                            modifiedDate: modified
                        ))
                    }
                    
                    // Sort directories first, then alphabetical
                    items.sort { a, b in
                        if a.isDirectory != b.isDirectory {
                            return a.isDirectory && !b.isDirectory
                        }
                        return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                    }
                    
                    continuation.resume(returning: .success((resolvedPath, items)))
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }
}

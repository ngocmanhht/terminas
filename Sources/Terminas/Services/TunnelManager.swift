import Foundation
import Combine

@MainActor
public class TunnelManager: ObservableObject {
    @Published public var tunnels: [TunnelItem] = []
    @Published public var activeTunnelIds: Set<UUID> = []
    @Published public var tunnelErrors: [UUID: String] = [:]
    
    private var processes: [UUID: Process] = [:]
    private let fileURL: URL
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("Terminas", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        self.fileURL = appFolder.appendingPathComponent("tunnels.json")
        load()
    }
    
    public func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            save()
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decrypted = CryptoService.decrypt(data)
            self.tunnels = try JSONDecoder().decode([TunnelItem].self, from: decrypted)
        } catch {
            print("Failed to load tunnels: \(error)")
        }
    }
    
    public func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(tunnels)
            let encrypted = CryptoService.encrypt(data)
            try encrypted.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save tunnels: \(error)")
        }
    }
    
    public func add(_ item: TunnelItem) {
        tunnels.insert(item, at: 0)
        save()
    }
    
    public func update(_ item: TunnelItem) {
        if let idx = tunnels.firstIndex(where: { $0.id == item.id }) {
            tunnels[idx] = item
            save()
        }
    }
    
    public func delete(_ item: TunnelItem) {
        stop(item)
        tunnels.removeAll { $0.id == item.id }
        save()
    }
    
    public func isTunnelActive(_ item: TunnelItem) -> Bool {
        activeTunnelIds.contains(item.id)
    }
    
    public func toggleTunnel(_ item: TunnelItem, host: HostItem?) {
        if isTunnelActive(item) {
            stop(item)
        } else if let host = host {
            start(item, host: host)
        }
    }
    
    public func start(_ item: TunnelItem, host: HostItem) {
        stop(item)
        tunnelErrors.removeValue(forKey: item.id)
        
        let authPrep = SSHAuthHelper.prepareAuth(for: host, jumpHost: nil, oneTime: false)
        
        var args = [
            "-N", // Do not execute a remote command (tunnel only)
            "-o", "ExitOnForwardFailure=yes",
            "-o", "ServerAliveInterval=15",
            "-o", "StrictHostKeyChecking=accept-new"
        ]
        if host.authType == .password {
            args.append(contentsOf: [
                "-o", "BatchMode=no",
                "-o", "NumberOfPasswordPrompts=1"
            ])
        }
        args.append(contentsOf: authPrep.extraArgs)
        
        switch item.tunnelType {
        case .local:
            args.append(contentsOf: ["-L", "\(item.localPort):\(item.remoteHost):\(item.remotePort)"])
        case .remote:
            args.append(contentsOf: ["-R", "\(item.remotePort):\(item.remoteHost):\(item.localPort)"])
        case .socks:
            args.append(contentsOf: ["-D", "\(item.localPort)"])
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
        
        args.append("\(host.username)@\(host.hostname)")
        
        let proc = Process()
        let errPipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        proc.environment = authPrep.environment
        proc.arguments = args
        proc.standardError = errPipe
        
        proc.terminationHandler = { [weak self] p in
            if let tempFile = authPrep.tempFile {
                try? FileManager.default.removeItem(at: tempFile)
            }
            Task { @MainActor in
                self?.processes.removeValue(forKey: item.id)
                self?.activeTunnelIds.remove(item.id)
                if p.terminationStatus != 0 {
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let msg = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    self?.tunnelErrors[item.id] = msg?.isEmpty == false ? msg : "Port forward failed with exit code \(p.terminationStatus)"
                }
            }
        }
        
        do {
            try proc.run()
            processes[item.id] = proc
            activeTunnelIds.insert(item.id)
        } catch {
            tunnelErrors[item.id] = error.localizedDescription
        }
    }
    
    public func stop(_ item: TunnelItem) {
        if let proc = processes.removeValue(forKey: item.id) {
            proc.terminate()
        }
        activeTunnelIds.remove(item.id)
    }
    
    public func stopAll() {
        for (_, proc) in processes {
            proc.terminate()
        }
        processes.removeAll()
        activeTunnelIds.removeAll()
    }
}

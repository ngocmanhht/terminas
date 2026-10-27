import Foundation
import SwiftTerm
import AppKit
import Combine

public enum PaneOrientation: String, Codable, Sendable {
    case vertical
    case horizontal
}

@MainActor
public class TerminalPane: NSObject, ObservableObject, Identifiable, LocalProcessTerminalViewDelegate {
    public let id: UUID
    @Published public var title: String
    @Published public var status: SessionStatus = .connecting
    @Published public var terminalViewID = UUID()
    public let host: HostItem?
    public let jumpHost: HostItem?
    public let isLocal: Bool
    public let monitor = ServerMonitorService()
    
    public var terminalView: LocalProcessTerminalView!
    public weak var parentTab: SessionTab?
    private var activeTempPassFile: URL?
    
    deinit {
        if let tempFile = activeTempPassFile {
            try? FileManager.default.removeItem(at: tempFile)
        }
    }
    
    public init(id: UUID = UUID(), title: String, host: HostItem? = nil, jumpHost: HostItem? = nil, isLocal: Bool = false) {
        self.id = id
        self.title = title
        self.host = host
        self.jumpHost = jumpHost
        self.isLocal = isLocal
        super.init()
        createTerminalView()
    }
    
    public func createTerminalView() {
        let view = LocalProcessTerminalView(frame: .zero)
        view.processDelegate = self
        TerminalThemeApplicator.apply(to: view)
        
        self.terminalView = view
        self.terminalViewID = UUID()
    }
    
    public func reconnect() {
        close()
        createTerminalView()
        start()
    }
    
    public func start() {
        status = .connecting
        
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        let envArray = env.map { "\($0.key)=\($0.value)" }
        
        if isLocal || host == nil {
            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            terminalView.startProcess(
                executable: shell,
                args: ["-l"],
                environment: envArray
            )
            status = .connected
        } else if let host = host {
            let authPrep = SSHAuthHelper.prepareAuth(for: host, jumpHost: jumpHost, oneTime: true, baseEnv: env)
            self.activeTempPassFile = authPrep.tempFile
            
            var args = [
                "-o", "ServerAliveInterval=30",
                "-o", "ServerAliveCountMax=3",
                "-o", "StrictHostKeyChecking=accept-new"
            ]
            args.append(contentsOf: authPrep.extraArgs)
            
            // Proxy Jump (Bastion) Support
            if let jumpHost = jumpHost {
                let jumpTarget = "\(jumpHost.username)@\(jumpHost.hostname)\(jumpHost.port == 22 ? "" : ":\(jumpHost.port)")"
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
            
            let target = "\(host.username)@\(host.hostname)"
            args.append(target)
            
            let finalEnvArray = authPrep.environment.map { "\($0.key)=\($0.value)" }
            terminalView.startProcess(
                executable: "/usr/bin/ssh",
                args: args,
                environment: finalEnvArray
            )
            status = .connected
            
            if let tempFile = authPrep.tempFile {
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 15) {
                    try? FileManager.default.removeItem(at: tempFile)
                }
            }
            
            if host.autoElevate {
                performAutoElevate(host: host)
            }
        }
        
        // Start monitoring server metrics
        monitor.startMonitoring(for: self)
    }
    
    private func performAutoElevate(host: HostItem) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            guard let self = self, self.status == .connected else { return }
            
            let cmd: String
            switch host.elevateMethod {
            case .su:
                let targetUser = host.elevateUser.trimmingCharacters(in: .whitespaces).isEmpty ? "root" : host.elevateUser
                cmd = "su - \(targetUser)"
            case .sudo:
                cmd = "sudo -i"
            case .custom:
                cmd = host.customElevateCommand.trimmingCharacters(in: .whitespaces)
            }
            
            guard !cmd.isEmpty else { return }
            self.send(text: cmd, appendNewline: true)
            
            if let elevatePass = KeychainService.getElevatePassword(for: host.id), !elevatePass.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    guard let self = self, self.status == .connected else { return }
                    self.send(text: elevatePass, appendNewline: true)
                }
            }
        }
    }
    
    public func send(text: String, appendNewline: Bool = true) {
        let toSend = appendNewline ? "\(text)\n" : text
        let bytes = Array(toSend.utf8)
        terminalView.send(data: ArraySlice(bytes))
    }
    
    public func close() {
        monitor.stopMonitoring()
        if let tempFile = activeTempPassFile {
            try? FileManager.default.removeItem(at: tempFile)
            activeTempPassFile = nil
        }
    }
    
    // MARK: - LocalProcessTerminalViewDelegate
    public func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    
    public func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        if !title.isEmpty {
            self.title = title
        }
    }
    
    public func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    
    public func processTerminated(source: TerminalView, exitCode: Int32?) {
        self.status = .terminated(exitCode: exitCode)
    }
}

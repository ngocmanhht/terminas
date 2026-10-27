import Foundation

@MainActor
public class ServerMonitorService: ObservableObject {
    @Published public var metrics: ServerMetrics = ServerMetrics()
    @Published public var isFetching: Bool = false
    
    private var timer: Timer?
    private var host: HostItem?
    private var jumpHost: HostItem?
    private var isLocal: Bool = true
    
    public init() {}
    
    public func startMonitoring(for pane: TerminalPane) {
        startMonitoring(host: pane.host, jumpHost: pane.jumpHost, isLocal: pane.isLocal)
    }
    
    public func startMonitoring(for tab: SessionTab) {
        startMonitoring(host: tab.host, jumpHost: tab.jumpHost, isLocal: tab.isLocal)
    }
    
    public func startMonitoring(host: HostItem?, jumpHost: HostItem? = nil, isLocal: Bool = false) {
        self.host = host
        self.jumpHost = jumpHost
        self.isLocal = isLocal
        stopMonitoring()
        
        fetchMetrics()
        
        // Poll every 8 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchMetrics()
            }
        }
    }
    
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    public func fetchMetrics() {
        guard !isFetching else { return }
        isFetching = true
        
        let local = isLocal
        let h = host
        let jh = jumpHost
        
        Task.detached(priority: .background) {
            let result: ServerMetrics
            if local || h == nil {
                result = await Self.fetchLocalMetrics()
            } else if let h = h {
                result = await Self.fetchRemoteMetrics(host: h, jumpHost: jh)
            } else {
                result = ServerMetrics()
            }
            
            await MainActor.run {
                self.metrics = result
                self.isFetching = false
            }
        }
    }
    
    // MARK: - Local macOS Metrics
    nonisolated private static func fetchLocalMetrics() async -> ServerMetrics {
        var m = ServerMetrics()
        
        // Date
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss dd/MM"
        m.serverTime = formatter.string(from: Date())
        
        // Local Disk
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            let total = (attrs[.systemSize] as? NSNumber)?.int64Value ?? 0
            let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
            let used = total - free
            m.diskTotalGB = Double(total) / 1_073_741_824.0
            m.diskUsedGB = Double(used) / 1_073_741_824.0
        }
        
        // Local RAM
        let memSize = ProcessInfo.processInfo.physicalMemory
        m.ramTotalMB = Double(memSize) / 1_048_576.0
        
        // VM Stat for RAM used
        m.latencyMs = 1
        let vmPipe = Pipe()
        let vmProc = Process()
        vmProc.executableURL = URL(fileURLWithPath: "/usr/bin/vm_stat")
        vmProc.standardOutput = vmPipe
        try? vmProc.run()
        vmProc.waitUntilExit()
        let vmData = vmPipe.fileHandleForReading.readDataToEndOfFile()
        if let vmOutput = String(data: vmData, encoding: .utf8) {
            var activePages: Double = 0
            var wiredPages: Double = 0
            var compressedPages: Double = 0
            for line in vmOutput.components(separatedBy: "\n") {
                if line.contains("Pages active:") {
                    activePages = parsePageCount(line)
                } else if line.contains("Pages wired down:") {
                    wiredPages = parsePageCount(line)
                } else if line.contains("Pages occupied by compressor:") {
                    compressedPages = parsePageCount(line)
                }
            }
            let usedPages = activePages + wiredPages + compressedPages
            let pageSize = Double(sysconf(_SC_PAGESIZE))
            m.ramUsedMB = (usedPages * pageSize) / 1_048_576.0
        }
        
        // CPU via ps
        let cpuPipe = Pipe()
        let cpuProc = Process()
        cpuProc.executableURL = URL(fileURLWithPath: "/bin/ps")
        cpuProc.arguments = ["-A", "-o", "%cpu"]
        cpuProc.standardOutput = cpuPipe
        try? cpuProc.run()
        cpuProc.waitUntilExit()
        let cpuData = cpuPipe.fileHandleForReading.readDataToEndOfFile()
        if let cpuOutput = String(data: cpuData, encoding: .utf8) {
            let lines = cpuOutput.components(separatedBy: "\n").dropFirst()
            var totalCpu: Double = 0
            for line in lines {
                if let val = Double(line.trimmingCharacters(in: .whitespaces)) {
                    totalCpu += val
                }
            }
            let coreCount = Double(ProcessInfo.processInfo.activeProcessorCount)
            m.cpuPercent = min(100.0, totalCpu / max(1.0, coreCount))
        }
        
        return m
    }
    
    nonisolated private static func parsePageCount(_ line: String) -> Double {
        let parts = line.components(separatedBy: ":")
        if parts.count >= 2 {
            let numStr = parts[1].replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces)
            return Double(numStr) ?? 0
        }
        return 0
    }
    
    // MARK: - Remote SSH Metrics
    nonisolated private static func fetchRemoteMetrics(host: HostItem, jumpHost: HostItem? = nil) async -> ServerMetrics {
        var m = ServerMetrics()
        
        // Compound remote shell command
        let cmd = "printf '===TIME=== '; date +'%H:%M:%S %d/%m'; " +
                  "printf '===UPTIME=== '; uptime | sed 's/.*up \\([^,]*\\), .*/\\1/'; " +
                  "printf '===MEM=== '; free -m 2>/dev/null | awk 'NR==2{printf \"%s %s\", $3,$2}' || true; echo ''; " +
                  "printf '===DISK=== '; df -m / 2>/dev/null | awk 'NR==2{printf \"%s %s\", $3,$2}' || true; echo ''; " +
                  "printf '===CPU=== '; top -bn1 2>/dev/null | grep 'Cpu(s)' | awk '{print $2}' || top -l 1 2>/dev/null | grep 'CPU usage' | awk '{print $3}' || true"
        
        let authPrep = SSHAuthHelper.prepareAuth(for: host, jumpHost: jumpHost, oneTime: false)
        defer {
            if let tempFile = authPrep.tempFile {
                try? FileManager.default.removeItem(at: tempFile)
            }
        }
        
        var args = [
            "-o", "ConnectTimeout=5",
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
        args.append(contentsOf: authPrep.extraArgs)
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
        args.append("\(host.username)@\(host.hostname)")
        args.append(cmd)
        
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        proc.environment = authPrep.environment
        proc.arguments = args
        proc.standardOutput = pipe
        
        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            try proc.run()
            proc.waitUntilExit()
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            if proc.terminationStatus == 0 {
                m.latencyMs = max(1, Int(elapsed * 1000))
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                for line in output.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("===TIME===") {
                        m.serverTime = trimmed.replacingOccurrences(of: "===TIME===", with: "").trimmingCharacters(in: .whitespaces)
                    } else if trimmed.hasPrefix("===UPTIME===") {
                        m.uptime = trimmed.replacingOccurrences(of: "===UPTIME===", with: "").trimmingCharacters(in: .whitespaces)
                    } else if trimmed.hasPrefix("===MEM===") {
                        let memStr = trimmed.replacingOccurrences(of: "===MEM===", with: "").trimmingCharacters(in: .whitespaces)
                        let parts = memStr.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        if parts.count >= 2, let used = Double(parts[0]), let total = Double(parts[1]) {
                            m.ramUsedMB = used
                            m.ramTotalMB = total
                        }
                    } else if trimmed.hasPrefix("===DISK===") {
                        let diskStr = trimmed.replacingOccurrences(of: "===DISK===", with: "").trimmingCharacters(in: .whitespaces)
                        let parts = diskStr.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        if parts.count >= 2, let used = Double(parts[0]), let total = Double(parts[1]) {
                            m.diskUsedGB = used / 1024.0
                            m.diskTotalGB = total / 1024.0
                        }
                    } else if trimmed.hasPrefix("===CPU===") {
                        let cpuStr = trimmed.replacingOccurrences(of: "===CPU===", with: "")
                            .replacingOccurrences(of: "%", with: "")
                            .replacingOccurrences(of: "us", with: "")
                            .trimmingCharacters(in: .whitespaces)
                        if let cpu = Double(cpuStr) {
                            m.cpuPercent = cpu
                        }
                    }
                }
            }
        } catch {
            print("Remote monitor failed: \(error)")
        }
        
        return m
    }
}

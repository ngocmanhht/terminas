import Foundation

public struct ServerMetrics: Equatable, Sendable {
    public var cpuPercent: Double
    public var ramUsedMB: Double
    public var ramTotalMB: Double
    public var diskUsedGB: Double
    public var diskTotalGB: Double
    public var serverTime: String
    public var uptime: String
    public var latencyMs: Int?
    public var lastUpdated: Date
    
    public init(
        cpuPercent: Double = 0.0,
        ramUsedMB: Double = 0.0,
        ramTotalMB: Double = 0.0,
        diskUsedGB: Double = 0.0,
        diskTotalGB: Double = 0.0,
        serverTime: String = "--:--:--",
        uptime: String = "",
        latencyMs: Int? = nil,
        lastUpdated: Date = Date()
    ) {
        self.cpuPercent = cpuPercent
        self.ramUsedMB = ramUsedMB
        self.ramTotalMB = ramTotalMB
        self.diskUsedGB = diskUsedGB
        self.diskTotalGB = diskTotalGB
        self.serverTime = serverTime
        self.uptime = uptime
        self.latencyMs = latencyMs
        self.lastUpdated = lastUpdated
    }
    
    public var ramPercent: Double {
        guard ramTotalMB > 0 else { return 0 }
        return (ramUsedMB / ramTotalMB) * 100
    }
    
    public var diskPercent: Double {
        guard diskTotalGB > 0 else { return 0 }
        return (diskUsedGB / diskTotalGB) * 100
    }
    
    public var ramDisplay: String {
        guard ramTotalMB > 0 else { return "N/A" }
        if ramTotalMB >= 1024 {
            let usedGB = ramUsedMB / 1024.0
            let totalGB = ramTotalMB / 1024.0
            return String(format: "%.1f/%.1f GB (%.0f%%)", usedGB, totalGB, ramPercent)
        } else {
            return String(format: "%.0f/%.0f MB (%.0f%%)", ramUsedMB, ramTotalMB, ramPercent)
        }
    }
    
    public var diskDisplay: String {
        guard diskTotalGB > 0 else { return "N/A" }
        return String(format: "%.1f/%.1f GB (%.0f%%)", diskUsedGB, diskTotalGB, diskPercent)
    }
    
    public var cpuDisplay: String {
        return String(format: "%.1f%%", cpuPercent)
    }
    
    public var latencyDisplay: String {
        guard let latency = latencyMs else { return "--" }
        return "\(latency) ms"
    }
}

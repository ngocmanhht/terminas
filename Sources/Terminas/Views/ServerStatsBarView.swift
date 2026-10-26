import SwiftUI

public struct ServerStatsBarView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var navManager: AppNavigationManager
    @ObservedObject var monitor: ServerMonitorService
    let tabTitle: String
    let host: HostItem?
    
    public init(monitor: ServerMonitorService, tabTitle: String, host: HostItem? = nil) {
        self.monitor = monitor
        self.tabTitle = tabTitle
        self.host = host
    }
    
    private var isProductionHost: Bool {
        guard let wsId = host?.workspaceId else { return false }
        return workspaceStore.workspaces.first(where: { $0.id == wsId })?.isProduction == true
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Production Warning Badge if applicable
            if isProductionHost {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 9))
                    Text("PROD")
                        .font(.system(size: 9, weight: .heavy))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.red))
                .foregroundColor(.white)
            }
            
            // Server Name
            HStack(spacing: 6) {
                Image(systemName: host?.iconName ?? "server.rack")
                    .foregroundColor(isProductionHost ? .red : .accentColor)
                Text(tabTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
            
            Divider()
                .frame(height: 12)
            
            // Current Server Date & Time
            StatBadge(
                icon: "clock.fill",
                title: "Time",
                value: monitor.metrics.serverTime.isEmpty ? "--:--:--" : monitor.metrics.serverTime,
                color: .blue
            )
            
            // CPU
            StatBadge(
                icon: "cpu",
                title: "CPU",
                value: monitor.metrics.cpuDisplay,
                color: cpuColor(monitor.metrics.cpuPercent)
            )
            
            // RAM
            StatBadge(
                icon: "memorychip",
                title: "RAM",
                value: monitor.metrics.ramDisplay,
                color: ramColor(monitor.metrics.ramPercent)
            )
            
            // Disk
            StatBadge(
                icon: "internaldrive",
                title: "Disk",
                value: monitor.metrics.diskDisplay,
                color: diskColor(monitor.metrics.diskPercent)
            )
            
            if !monitor.metrics.uptime.isEmpty {
                StatBadge(
                    icon: "arrow.clockwise.circle",
                    title: "Up",
                    value: monitor.metrics.uptime,
                    color: .secondary
                )
            }
            
            // Ping / Latency
            if let latency = monitor.metrics.latencyMs {
                StatBadge(
                    icon: "wifi",
                    title: "Ping",
                    value: "\(latency) ms",
                    color: latencyColor(latency)
                )
            }
            
            Spacer()
            
            // Quick SFTP button for remote host
            if let h = host {
                Button(action: { navManager.navigateToSFTP(for: h.id) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.gear")
                            .font(.system(size: 10))
                        Text("SFTP")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.12)))
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Open SFTP File Browser for \(h.displayTitle)")
            }
            
            // Refresh Button
            Button(action: { monitor.fetchMetrics() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
                    .rotationEffect(.degrees(monitor.isFetching ? 360 : 0))
                    .animation(monitor.isFetching ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: monitor.isFetching)
            }
            .buttonStyle(.plain)
            .help("Refresh Server Stats")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
    }
    
    private func cpuColor(_ val: Double) -> Color {
        if val > 80 { return .red }
        if val > 50 { return .orange }
        return .green
    }
    
    private func ramColor(_ val: Double) -> Color {
        if val > 85 { return .red }
        if val > 65 { return .orange }
        return .purple
    }
    
    private func diskColor(_ val: Double) -> Color {
        if val > 90 { return .red }
        if val > 75 { return .orange }
        return .cyan
    }
    
    private func latencyColor(_ ms: Int) -> Color {
        if ms < 80 { return .green }
        if ms < 200 { return .orange }
        return .red
    }
}

private struct StatBadge: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color)
            
            Text(title + ":")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

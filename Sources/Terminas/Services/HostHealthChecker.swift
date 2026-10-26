import Foundation
import Network
import Combine

public enum HostHealthState: Equatable, Sendable {
    case checking
    case online(latencyMs: Int)
    case offline(reason: String)
}

public struct HostHealthStatus: Equatable, Sendable {
    public let state: HostHealthState
    public let lastChecked: Date
    
    public init(state: HostHealthState, lastChecked: Date = Date()) {
        self.state = state
        self.lastChecked = lastChecked
    }
}

@MainActor
public class HostHealthChecker: ObservableObject {
    public static let shared = HostHealthChecker()
    
    @Published public var statuses: [UUID: HostHealthStatus] = [:]
    private var activeConnections: [UUID: NWConnection] = [:]
    
    public init() {}
    
    public func checkHost(_ host: HostItem) {
        let hostId = host.id
        
        // Cancel existing check for this host if any
        activeConnections[hostId]?.cancel()
        activeConnections.removeValue(forKey: hostId)
        
        statuses[hostId] = HostHealthStatus(state: .checking)
        
        let targetHost = NWEndpoint.Host(host.hostname)
        let targetPort = NWEndpoint.Port(rawValue: UInt16(host.port > 0 ? host.port : 22)) ?? .ssh
        
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 2 // 2 seconds timeout
        
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        let connection = NWConnection(host: targetHost, port: targetPort, using: params)
        activeConnections[hostId] = connection
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let queue = DispatchQueue(label: "com.terminas.healthcheck.\(hostId.uuidString)")
        
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self = self, let conn = connection else { return }
            
            switch state {
            case .ready:
                let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)
                conn.cancel()
                DispatchQueue.main.async {
                    self.activeConnections.removeValue(forKey: hostId)
                    self.statuses[hostId] = HostHealthStatus(state: .online(latencyMs: max(1, elapsed)))
                }
                
            case .failed(let error):
                conn.cancel()
                DispatchQueue.main.async {
                    self.activeConnections.removeValue(forKey: hostId)
                    self.statuses[hostId] = HostHealthStatus(state: .offline(reason: error.localizedDescription))
                }
                
            case .waiting(let error):
                conn.cancel()
                DispatchQueue.main.async {
                    self.activeConnections.removeValue(forKey: hostId)
                    self.statuses[hostId] = HostHealthStatus(state: .offline(reason: error.localizedDescription))
                }
                
            case .cancelled:
                break
                
            default:
                break
            }
        }
        
        connection.start(queue: queue)
        
        // Fallback timeout after 2.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self = self, let conn = self.activeConnections[hostId] else { return }
            conn.cancel()
            self.activeConnections.removeValue(forKey: hostId)
            if case .checking = self.statuses[hostId]?.state {
                self.statuses[hostId] = HostHealthStatus(state: .offline(reason: "Connection timed out (2.5s)"))
            }
        }
    }
    
    public func checkAll(hosts: [HostItem]) {
        for host in hosts {
            checkHost(host)
        }
    }
}

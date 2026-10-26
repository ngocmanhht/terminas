import Foundation
import Combine
import SwiftUI

@MainActor
public class TerminalSessionManager: ObservableObject {
    @Published public var tabs: [SessionTab] = []
    @Published public var activeTabId: UUID?
    @Published public var isGlobalBroadcastEnabled: Bool = false
    
    public init() {}
    
    public var activeTab: SessionTab? {
        guard let activeTabId = activeTabId else { return tabs.first }
        return tabs.first { $0.id == activeTabId }
    }
    
    public func openHost(_ host: HostItem, jumpHost: HostItem? = nil) {
        let newTab = SessionTab(
            title: host.displayTitle,
            host: host,
            jumpHost: jumpHost,
            isLocal: false
        )
        tabs.append(newTab)
        activeTabId = newTab.id
        newTab.start()
    }
    
    public func openLocalSession() {
        let newTab = SessionTab(
            title: "Local Shell",
            host: nil,
            isLocal: true
        )
        tabs.append(newTab)
        activeTabId = newTab.id
        newTab.start()
    }
    
    public func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].close()
        tabs.remove(at: index)
        if activeTabId == id {
            activeTabId = tabs.indices.contains(index) ? tabs[index].id : tabs.last?.id
        }
    }
    
    public func duplicateTab(id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        if let host = tab.host {
            openHost(host, jumpHost: tab.jumpHost)
        } else {
            openLocalSession()
        }
    }
    
    public func closeOtherTabs(id: UUID) {
        let toClose = tabs.filter { $0.id != id }
        for tab in toClose {
            closeTab(id: tab.id)
        }
        activeTabId = id
    }
    
    public func selectTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        activeTabId = tabs[index].id
    }
    
    public func splitActiveTabVertically(host: HostItem? = nil, jumpHost: HostItem? = nil) {
        activeTab?.splitVertically(host: host, jumpHost: jumpHost)
    }
    
    public func splitActiveTabHorizontally(host: HostItem? = nil, jumpHost: HostItem? = nil) {
        activeTab?.splitHorizontally(host: host, jumpHost: jumpHost)
    }
    
    public func toggleActiveTabBroadcast() {
        if let tab = activeTab {
            tab.isBroadcastEnabled.toggle()
        }
    }
    
    public func broadcastToAllTabs(command: String) {
        for tab in tabs {
            tab.broadcastCommand(command)
        }
    }
    
    public func sendSnippet(_ snippet: SnippetItem) {
        guard let active = activeTab else { return }
        if isGlobalBroadcastEnabled {
            broadcastToAllTabs(command: snippet.command)
        } else {
            active.send(text: snippet.command, appendNewline: snippet.runImmediately)
        }
    }
}

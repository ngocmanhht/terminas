import Foundation
import Combine

@MainActor
public class WorkspaceStore: ObservableObject {
    @Published public var workspaces: [WorkspaceItem] = []
    @Published public var activeWorkspaceId: UUID? = nil
    
    private let fileURL: URL
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("Terminas", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        self.fileURL = appFolder.appendingPathComponent("workspaces.json")
        load()
    }
    
    public var activeWorkspace: WorkspaceItem? {
        guard let id = activeWorkspaceId else { return nil }
        return workspaces.first { $0.id == id }
    }
    
    public func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let defaultWs = WorkspaceItem(
                name: "Default",
                iconName: "briefcase.fill",
                colorHex: "#0A84FF",
                isProduction: false
            )
            self.workspaces = [defaultWs]
            self.activeWorkspaceId = nil
            save()
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decrypted = CryptoService.decrypt(data)
            self.workspaces = try JSONDecoder().decode([WorkspaceItem].self, from: decrypted)
        } catch {
            print("Failed to load workspaces: \(error)")
        }
    }
    
    public func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(workspaces)
            let encrypted = CryptoService.encrypt(data)
            try encrypted.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save workspaces: \(error)")
        }
    }
    
    public func add(_ item: WorkspaceItem) {
        workspaces.append(item)
        activeWorkspaceId = item.id
        save()
    }
    
    public func update(_ item: WorkspaceItem) {
        if let idx = workspaces.firstIndex(where: { $0.id == item.id }) {
            workspaces[idx] = item
            save()
        }
    }
    
    public func delete(_ item: WorkspaceItem) {
        workspaces.removeAll { $0.id == item.id }
        if activeWorkspaceId == item.id {
            activeWorkspaceId = nil
        }
        save()
    }
}

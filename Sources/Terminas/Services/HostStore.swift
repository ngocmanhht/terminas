import Foundation
import Combine

@MainActor
public class HostStore: ObservableObject {
    @Published public var hosts: [HostItem] = []
    
    private let fileURL: URL
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("Terminas", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        self.fileURL = appFolder.appendingPathComponent("hosts.json")
        load()
    }
    
    public func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            self.hosts = []
            save()
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decrypted = CryptoService.decrypt(data)
            self.hosts = try JSONDecoder().decode([HostItem].self, from: decrypted)
        } catch {
            print("Failed to load hosts: \(error)")
        }
    }
    
    public func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(hosts)
            let encrypted = CryptoService.encrypt(data)
            try encrypted.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save hosts: \(error)")
        }
    }
    
    public func add(_ host: HostItem) {
        hosts.insert(host, at: 0)
        save()
    }
    
    public func update(_ host: HostItem) {
        if let idx = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[idx] = host
            save()
        }
    }
    
    public func delete(at offsets: IndexSet) {
        for idx in offsets {
            let id = hosts[idx].id
            KeychainService.deletePassword(for: id)
            KeychainService.deleteElevatePassword(for: id)
        }
        hosts.remove(atOffsets: offsets)
        save()
    }
    
    public func delete(_ host: HostItem) {
        KeychainService.deletePassword(for: host.id)
        KeychainService.deleteElevatePassword(for: host.id)
        hosts.removeAll { $0.id == host.id }
        save()
    }
    
    public func duplicate(_ host: HostItem) {
        var copy = host
        copy.id = UUID()
        copy.label = "\(host.label) (Copy)"
        copy.createdAt = Date()
        
        if let pwd = KeychainService.getPassword(for: host.id) {
            _ = KeychainService.savePassword(for: copy.id, password: pwd)
        }
        if let elPwd = KeychainService.getElevatePassword(for: host.id) {
            _ = KeychainService.saveElevatePassword(for: copy.id, password: elPwd)
        }
        
        hosts.insert(copy, at: 0)
        save()
    }
    
    public var allTags: [String] {
        Array(Set(hosts.flatMap { $0.tags })).sorted()
    }
}

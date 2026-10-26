import Foundation
import Combine

@MainActor
public class SnippetStore: ObservableObject {
    @Published public var snippets: [SnippetItem] = []
    
    private let fileURL: URL
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("Terminas", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        self.fileURL = appFolder.appendingPathComponent("snippets.json")
        load()
    }
    
    public func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            self.snippets = []
            save()
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decrypted = CryptoService.decrypt(data)
            self.snippets = try JSONDecoder().decode([SnippetItem].self, from: decrypted)
        } catch {
            print("Failed to load snippets: \(error)")
        }
    }
    
    public func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(snippets)
            let encrypted = CryptoService.encrypt(data)
            try encrypted.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save snippets: \(error)")
        }
    }
    
    public func add(_ snippet: SnippetItem) {
        snippets.insert(snippet, at: 0)
        save()
    }
    
    public func update(_ snippet: SnippetItem) {
        if let idx = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[idx] = snippet
            save()
        }
    }
    
    public func delete(_ snippet: SnippetItem) {
        snippets.removeAll { $0.id == snippet.id }
        save()
    }
    
    public var categories: [String] {
        Array(Set(snippets.map { $0.category })).sorted()
    }
}

import Foundation
import CryptoKit
import Security
import IOKit

public enum KeychainService {
    private static let serviceName = "com.terminas.app"
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: String] = [:]
    nonisolated(unsafe) private static var isInitialized = false
    
    private static var vaultURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Terminas", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent("vault.enc")
    }
    
    private static var saltURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Terminas", isDirectory: true)
        return appSupport.appendingPathComponent(".vault_salt")
    }
    
    // MARK: - Public API
    public static func savePassword(for hostId: UUID, password: String) -> Bool {
        saveRaw(account: hostId.uuidString, value: password)
    }
    
    public static func getPassword(for hostId: UUID) -> String? {
        getRaw(account: hostId.uuidString)
    }
    
    public static func deletePassword(for hostId: UUID) {
        deleteRaw(account: hostId.uuidString)
    }
    
    // MARK: - Elevate / SU Password
    public static func saveElevatePassword(for hostId: UUID, password: String) -> Bool {
        saveRaw(account: "\(hostId.uuidString)_elevate", value: password)
    }
    
    public static func getElevatePassword(for hostId: UUID) -> String? {
        getRaw(account: "\(hostId.uuidString)_elevate")
    }
    
    public static func deleteElevatePassword(for hostId: UUID) {
        deleteRaw(account: "\(hostId.uuidString)_elevate")
    }
    
    // MARK: - Internal Storage & Caching
    private static func ensureLoaded() {
        lock.lock()
        defer { lock.unlock() }
        guard !isInitialized else { return }
        isInitialized = true
        
        // 1. Try loading from local AES-256 encrypted vault
        if FileManager.default.fileExists(atPath: vaultURL.path),
           let rawData = try? Data(contentsOf: vaultURL),
           let key = getVaultKey(),
           let decrypted = try? AES.GCM.open(AES.GCM.SealedBox(combined: rawData), using: key),
           let dict = try? JSONDecoder().decode([String: String].self, from: decrypted) {
            self.cache = dict
        }
    }
    
    private static func saveVaultToDisk() {
        guard let key = getVaultKey() else { return }
        do {
            let data = try JSONEncoder().encode(cache)
            let sealed = try AES.GCM.seal(data, using: key)
            if let combined = sealed.combined {
                try combined.write(to: vaultURL, options: .atomic)
                chmod(vaultURL.path, S_IRUSR | S_IWUSR)
            }
        } catch {
            print("Failed to save vault: \(error)")
        }
    }
    
    private static func saveRaw(account: String, value: String) -> Bool {
        ensureLoaded()
        lock.lock()
        cache[account] = value
        saveVaultToDisk()
        lock.unlock()
        return true
    }
    
    private static func getRaw(account: String) -> String? {
        ensureLoaded()
        lock.lock()
        defer { lock.unlock() }
        
        return cache[account]
    }
    
    private static func deleteRaw(account: String) {
        ensureLoaded()
        lock.lock()
        cache.removeValue(forKey: account)
        saveVaultToDisk()
        lock.unlock()
    }
    
    // MARK: - Vault Encryption Key Derivation (Hardware-Bound AES-256-GCM)
    private static func getVaultKey() -> SymmetricKey? {
        let hwUUID = getHardwareUUID() ?? "TerminasFallbackUUID"
        let username = NSUserName()
        let salt = getOrCreateSalt()
        let inputMaterial = "\(hwUUID):\(username):com.terminas.vault".data(using: .utf8)!
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: inputMaterial),
            salt: salt,
            outputByteCount: 32
        )
    }
    
    private static func getOrCreateSalt() -> Data {
        if let data = try? Data(contentsOf: saltURL), data.count >= 16 {
            return data
        }
        var randomBytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let data = Data(randomBytes)
        try? data.write(to: saltURL, options: .atomic)
        chmod(saltURL.path, S_IRUSR | S_IWUSR)
        return data
    }
    
    private static func getHardwareUUID() -> String? {
        let dev = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard dev != 0 else { return nil }
        defer { IOObjectRelease(dev) }
        guard let prop = IORegistryEntryCreateCFProperty(dev, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        return prop.takeRetainedValue() as? String
    }
    
    // MARK: - Legacy Keychain Migration Helpers
    private static func getFromLegacyKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private static func deleteFromLegacyKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

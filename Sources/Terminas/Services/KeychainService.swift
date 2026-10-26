import Foundation
import Security

public enum KeychainService {
    private static let serviceName = "com.terminas.app"
    
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
    
    // MARK: - Raw Keychain Helpers
    private static func saveRaw(account: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private static func getRaw(account: String) -> String? {
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
    
    private static func deleteRaw(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

import Foundation
import CryptoKit
import Security

public enum CryptoService {
    private static let keyAccount = "com.terminas.masterkey"
    private static let serviceName = "com.terminas.app"
    private static let magicHeader = Data("TENC".utf8) // Terminas Encrypted magic prefix
    
    // MARK: - Encryption
    public static func encrypt(_ data: Data) -> Data {
        guard let key = getOrCreateMasterKey() else { return data }
        do {
            let sealed = try AES.GCM.seal(data, using: key)
            guard let combined = sealed.combined else { return data }
            var result = magicHeader
            result.append(combined)
            return result
        } catch {
            print("Encryption failed: \(error)")
            return data
        }
    }
    
    // MARK: - Decryption
    public static func decrypt(_ data: Data) -> Data {
        // Check for magic header
        guard data.count > magicHeader.count, data.prefix(magicHeader.count) == magicHeader else {
            // Not encrypted (or legacy plain text), return as-is
            return data
        }
        guard let key = getOrCreateMasterKey() else { return data }
        let payload = data.dropFirst(magicHeader.count)
        do {
            let sealed = try AES.GCM.SealedBox(combined: payload)
            return try AES.GCM.open(sealed, using: key)
        } catch {
            print("Decryption failed: \(error)")
            return data
        }
    }
    
    // MARK: - Keychain Master Key Management
    private static func getOrCreateMasterKey() -> SymmetricKey? {
        if let keyData = getKeyFromKeychain() {
            return SymmetricKey(data: keyData)
        }
        
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        if saveKeyToKeychain(keyData: keyData) {
            return newKey
        }
        return nil
    }
    
    private static func getKeyFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: keyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return data
    }
    
    private static func saveKeyToKeychain(keyData: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: keyAccount
        ]
        SecItemDelete(query as CFDictionary)
        
        var attributes = query
        attributes[kSecValueData as String] = keyData
        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }
}

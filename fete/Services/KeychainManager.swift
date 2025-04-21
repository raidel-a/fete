import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    // MARK: - Access Token
    
    func saveAccessToken(_ token: String) {
        saveToKeychain(value: token, forKey: "spotify_access_token")
    }
    
    func getAccessToken() -> String? {
        return getFromKeychain(forKey: "spotify_access_token")
    }
    
    func removeAccessToken() {
        removeFromKeychain(forKey: "spotify_access_token")
    }
    
    // MARK: - Refresh Token
    
    func saveRefreshToken(_ token: String) {
        saveToKeychain(value: token, forKey: "spotify_refresh_token")
    }
    
    func getRefreshToken() -> String? {
        return getFromKeychain(forKey: "spotify_refresh_token")
    }
    
    func removeRefreshToken() {
        removeFromKeychain(forKey: "spotify_refresh_token")
    }
    
    // MARK: - Token Expiration
    
    func saveTokenExpirationDate(_ date: Date) {
        let dateString = ISO8601DateFormatter().string(from: date)
        saveToKeychain(value: dateString, forKey: "spotify_token_expiration")
    }
    
    func getTokenExpirationDate() -> Date? {
        guard let dateString = getFromKeychain(forKey: "spotify_token_expiration") else {
            return nil
        }
        return ISO8601DateFormatter().date(from: dateString)
    }
    
    func removeTokenExpirationDate() {
        removeFromKeychain(forKey: "spotify_token_expiration")
    }
    
    // MARK: - Spotify DC Cookie
    
    func saveSpotifyDCCookie(_ cookie: String) {
        print("💾 Attempting to save sp_dc cookie to keychain: \(String(cookie.prefix(5)))...")
        saveToKeychain(value: cookie, forKey: "spotify_sp_dc")
        
        // Verify save
        if let savedCookie = getSpotifyDCCookie() {
            print("✅ Successfully saved and verified sp_dc cookie")
        } else {
            print("❌ Failed to verify saved sp_dc cookie")
        }
    }
    
    func getSpotifyDCCookie() -> String? {
        print("🔍 Attempting to retrieve sp_dc cookie from keychain")
        if let cookie = getFromKeychain(forKey: "spotify_sp_dc") {
            print("✅ Found sp_dc cookie in keychain: \(String(cookie.prefix(5)))...")
            return cookie
        } else {
            print("❌ No sp_dc cookie found in keychain")
            return nil
        }
    }
    
    func removeSpotifyDCCookie() {
        removeFromKeychain(forKey: "spotify_sp_dc")
    }
    
    // MARK: - Private Methods
    
    private func saveToKeychain(value: String, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: value.data(using: .utf8)!
        ]
        
        // First try to update existing item
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: value.data(using: .utf8)!] as CFDictionary)
        
        // If item doesn't exist, add it
        if status == errSecItemNotFound {
            SecItemAdd(query as CFDictionary, nil)
        }
    }
    
    private func getFromKeychain(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    private func removeFromKeychain(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
} 
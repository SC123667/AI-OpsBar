import Foundation
import Security

enum KeychainHelper {
    static func loadAPIKey(account: String = AppConfig.keychainAccount) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: AppConfig.keychainService,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }

        return value
    }

    @discardableResult
    static func saveAPIKey(_ apiKey: String, account: String = AppConfig.keychainAccount) -> OSStatus {
        let data = Data(apiKey.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: AppConfig.keychainService,
            kSecAttrAccount: account,
        ]

        let attributes: [CFString: Any] = [
            kSecValueData: data,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return updateStatus
        }

        var newItem = query
        newItem[kSecValueData] = data
        newItem[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock

        return SecItemAdd(newItem as CFDictionary, nil)
    }

    @discardableResult
    static func deleteAPIKey(account: String = AppConfig.keychainAccount) -> OSStatus {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: AppConfig.keychainService,
            kSecAttrAccount: account,
        ]

        return SecItemDelete(query as CFDictionary)
    }
}

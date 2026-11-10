import Foundation
import Security

/// The user's GitHub token, kept in the login Keychain: never in
/// user defaults, the App Group or logs.
enum GitHubTokenStore {
    static let SERVICE = "com.morsetechnologies.devwidgets.github"
    static let ACCOUNT = "api-token"

    enum StoreError: Error {
        case keychain(status: OSStatus)
    }

    static func readToken() -> String? {
        var query = makeQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var found_Item: CFTypeRef?
        let status = SecItemCopyMatching(
            query as CFDictionary,
            &found_Item
        )
        guard status == errSecSuccess,
            let token_Data = found_Item as? Data
        else { return nil }
        return String(data: token_Data, encoding: .utf8)
    }

    static func saveToken(_ token: String) throws {
        deleteToken()
        var query = makeQuery()
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrAccessible as String] =
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw StoreError.keychain(status: status)
        }
    }

    static func deleteToken() {
        SecItemDelete(makeQuery() as CFDictionary)
    }

    private static func makeQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: SERVICE,
            kSecAttrAccount as String: ACCOUNT,
        ]
    }
}

//
//  KeychainHelper.swift
//  Aidea
//

import Foundation
import Security

/// macOS Keychain への読み書きを行うヘルパー。
/// API キー等のシークレットを安全に保管する。
enum KeychainHelper {
    /// Keychain に文字列を保存する (既存なら上書き)
    static func save(key: String, service: String) {
        let data = key.data(using: .utf8)!
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
        ]
        // 既存を削除してから追加 (upsert)
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    /// Keychain から文字列を取得する (存在しなければ nil)
    static func load(service: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Keychain からエントリを削除する
    static func delete(service: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

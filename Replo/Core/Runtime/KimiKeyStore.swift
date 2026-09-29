import Foundation

/// Moonshot API Key 的存取门面。界面（MainActor）用它写钥匙串，
/// 运行时（`@ContextTreeActor`）自己另有一份 `KeychainCredentials` 读同一把 Key。
enum KimiKeyStore {
    /// 现在钥匙串里有没有可用的 Key。
    static func isSaved() -> Bool {
        (try? current())?.isEmpty == false
    }

    /// 已保存的 Key，只用来显示尾部几位，明文不进界面。
    static func fingerprint() -> String? {
        guard let key = try? current(), !key.isEmpty else { return nil }
        return KeychainStore.fingerprint(key)
    }

    /// 写入一把新 Key。空串等价于清除。
    static func save(_ key: String) throws {
        try KeychainStore.write(
            key.trimmingCharacters(in: .whitespacesAndNewlines),
            service: KimiConfig.keychainService,
            account: KimiConfig.credentialKey
        )
    }

    static func clear() throws {
        try KeychainStore.delete(
            service: KimiConfig.keychainService,
            account: KimiConfig.credentialKey
        )
    }

    private static func current() throws -> String? {
        try KeychainStore.read(
            service: KimiConfig.keychainService,
            account: KimiConfig.credentialKey
        )
    }
}

//
//  OllamaServiceMigration.swift
//  Easydict
//
//  Slim build: the Ollama service was removed. An installation that still lists it gets a
//  Custom OpenAI instance with the same settings, list position and enabled state instead.
//

import Foundation

enum OllamaServiceMigration {
    // MARK: Internal

    /// Replaces the Ollama service in every window's service list; does nothing once it is gone.
    /// The old Ollama settings are left in place, so an older build still finds them.
    static func migrateIfNeeded() {
        let storage = LocalStorage.shared()
        let windowTypes: [EZWindowType] = [.main, .mini, .fixed]
        let ollamaID = ServiceType.ollama.rawValue
        guard windowTypes.contains(where: { storage.allServiceTypes($0).contains(ollamaID) }) else {
            return
        }

        let uuid = UUID().uuidString
        let customID = "\(ServiceType.customOpenAI.rawValue)#\(uuid)"
        copySettings(toCustomOpenAIInstance: uuid)

        for windowType in windowTypes {
            var typeIDs = storage.allServiceTypes(windowType)
            guard let index = typeIDs.firstIndex(of: ollamaID) else { continue }
            typeIDs[index] = customID
            typeIDs.removeAll { $0 == ollamaID }

            let ollamaInfo = storage.serviceInfo(withType: .ollama, serviceId: "", windowType: windowType)
            storage.setServiceInfo(
                QueryServiceConfiguration(
                    uuid: uuid,
                    type: .customOpenAI,
                    enabled: ollamaInfo?.enabled ?? true,
                    enabledQuery: ollamaInfo?.enabledQuery ?? true,
                    windowType: windowType
                ),
                windowType: windowType
            )
            storage.setAllServiceTypes(typeIDs, windowType: windowType)
        }
        logInfo("Migrated the Ollama service to \(customID)")
    }

    // MARK: Private

    /// Copies each `EZOllama<Setting>Key` (endpoint, model, prompts, ...) to the instance's
    /// `EZCustomOpenAI<Setting>_<uuid>_Key`, the layout of `serivceConfigurationKey`.
    private static func copySettings(toCustomOpenAIInstance uuid: String) {
        let defaults = UserDefaults.standard
        let prefix = "EZ" + ServiceType.ollama.rawValue
        let suffix = "Key"
        for (key, value) in defaults.dictionaryRepresentation()
            where key.hasPrefix(prefix) && key.hasSuffix(suffix) {
            let setting = key.dropFirst(prefix.count).dropLast(suffix.count)
            guard !setting.isEmpty, !setting.contains("_") else { continue }
            defaults.set(value, forKey: "EZ\(ServiceType.customOpenAI.rawValue)\(setting)_\(uuid)_Key")
        }
    }
}

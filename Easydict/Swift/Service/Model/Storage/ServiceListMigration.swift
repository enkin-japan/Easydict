//
//  ServiceListMigration.swift
//  Easydict
//
//  Slim build: the service list is fixed and Custom OpenAI has a single instance. Older builds
//  could add Custom OpenAI several times (`CustomOpenAI#<uuid>`) and had an Ollama service; this
//  moves the settings of the instance in use to the single Custom OpenAI.
//

import Foundation

enum ServiceListMigration {
    // MARK: Internal

    /// Rewrites every window's stored service list once; does nothing when no list has an old entry.
    /// Runs before `LocalStorage` drops unknown service types from the lists.
    /// The old settings are left in place, so an older build still finds them.
    static func migrateIfNeeded() {
        let defaults = UserDefaults.standard
        let storedLists = windowTypes.map { windowType in
            (windowType, defaults.stringArray(forKey: LocalStorage.serviceTypesKey(of: windowType)) ?? [])
        }
        let oldIDs = storedLists.flatMap(\.1).filter(isOldCustomOpenAIEntry)
        guard !oldIDs.isEmpty else { return }

        // An existing single instance wins; otherwise the first old entry in window order is kept.
        let hasSingleInstance = storedLists.contains { $0.1.contains(customOpenAIID) }
        let sourceID = hasSingleInstance ? nil : oldIDs.first
        if let sourceID {
            copySettings(from: sourceID)
        }

        for (windowType, typeIDs) in storedLists {
            guard let index = typeIDs.firstIndex(where: { $0 == customOpenAIID || isOldCustomOpenAIEntry($0) })
            else { continue }

            // A window that already lists the single instance keeps its enabled state.
            if !typeIDs.contains(customOpenAIID) {
                let windowSourceID = sourceID.flatMap { typeIDs.contains($0) ? $0 : nil } ?? typeIDs[index]
                copyServiceInfo(from: windowSourceID, windowType: windowType)
            }

            var newTypeIDs = typeIDs
            newTypeIDs[index] = customOpenAIID
            newTypeIDs = newTypeIDs.enumerated().filter { offset, typeID in
                offset == index || (typeID != customOpenAIID && !isOldCustomOpenAIEntry(typeID))
            }.map(\.element)
            defaults.set(newTypeIDs, forKey: LocalStorage.serviceTypesKey(of: windowType))
        }
        logInfo("Migrated \(sourceID ?? customOpenAIID) to the single Custom OpenAI service")
    }

    // MARK: Private

    private static let windowTypes: [EZWindowType] = [.main, .fixed, .mini]
    private static let customOpenAIID = ServiceType.customOpenAI.rawValue
    private static let ollamaID = ServiceType.ollama.rawValue
    private static let instancePrefix = "\(customOpenAIID)#"

    private static func isOldCustomOpenAIEntry(_ typeID: String) -> Bool {
        typeID == ollamaID || typeID.hasPrefix(instancePrefix)
    }

    /// Copies the source's `EZ<Service><Setting>[_<uuid>_]Key` values (endpoint, model, prompts, ...)
    /// to `EZCustomOpenAI<Setting>Key`, the layout of `serivceConfigurationKey` without an id.
    private static func copySettings(from sourceID: String) {
        let defaults = UserDefaults.standard
        let prefix: String
        let suffix: String
        if sourceID == ollamaID {
            prefix = "EZ\(ollamaID)"
            suffix = "Key"
        } else {
            prefix = "EZ\(customOpenAIID)"
            suffix = "_\(sourceID.dropFirst(instancePrefix.count))_Key"
        }

        for (key, value) in defaults.dictionaryRepresentation()
            where key.hasPrefix(prefix) && key.hasSuffix(suffix) {
            let setting = key.dropFirst(prefix.count).dropLast(suffix.count)
            guard !setting.isEmpty, !setting.contains("_") else { continue }
            defaults.set(value, forKey: "EZ\(customOpenAIID)\(setting)Key")
        }
    }

    /// Copies whether the source entry was enabled and joined queries in `windowType`.
    private static func copyServiceInfo(from sourceID: String, windowType: EZWindowType) {
        let defaults = UserDefaults.standard
        let sourceKey = if sourceID == ollamaID {
            LocalStorage.serviceInfoKey(type: .ollama, windowType: windowType)
        } else {
            LocalStorage.legacyServiceInfoKey(
                type: .customOpenAI,
                instanceID: String(sourceID.dropFirst(instancePrefix.count)),
                windowType: windowType
            )
        }

        let stored = defaults.data(forKey: sourceKey)
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        let info = QueryServiceConfiguration(
            type: .customOpenAI,
            enabled: stored?["enabled"] as? Bool ?? true,
            enabledQuery: stored?["enabledQuery"] as? Bool ?? true,
            windowType: windowType
        )
        if let data = try? JSONEncoder().encode(info) {
            defaults.set(data, forKey: LocalStorage.serviceInfoKey(type: .customOpenAI, windowType: windowType))
        }
    }
}

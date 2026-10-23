//
//  LocalStorage.swift
//  Easydict
//
//  Created by tisfeng on 2022/11/22.
//

import Defaults
import Foundation

// MARK: - LocalStorage

/// Local persistence layer for service metadata and usage stats.
@objc(EZLocalStorage)
@objcMembers
final class LocalStorage: NSObject {
    // MARK: Lifecycle

    private override init() {
        super.init()
        ServiceListMigration.migrateIfNeeded()
        setup()
    }

    // MARK: Internal

    // MARK: Public API

    /// Disabled app trigger configurations for select-text.
    var selectTextTypeAppModelList: [AppTriggerConfig] {
        get {
            let storedArray = userDefaults.array(forKey: Constants.appModelTriggerListKey) as? [NSDictionary]
            let appModels = AppTriggerConfig.appModels(from: storedArray ?? [])

            if storedArray == nil {
                let keychainApp = AppTriggerConfig(appBundleID: "com.apple.keychainaccess", triggerType: [])
                return [keychainApp]
            }

            return appModels
        }
        set {
            let dictArray = AppTriggerConfig.dictionaryArray(from: newValue)
            userDefaults.set(dictArray, forKey: Constants.appModelTriggerListKey)
        }
    }

    /// Total query character count.

    var queryCharacterCount: Int {
        get { userDefaults.integer(forKey: Constants.queryCharacterCountKey) }
        set { userDefaults.set(newValue, forKey: Constants.queryCharacterCountKey) }
    }

    /// Total query count.

    var queryCount: Int {
        get { userDefaults.integer(forKey: Constants.queryCountKey) }
        set { userDefaults.set(newValue, forKey: Constants.queryCountKey) }
    }

    // MARK: Singleton

    /// Shared storage instance matching the Objective-C API.
    @objc(shared)
    static func shared() -> LocalStorage {
        if let instance = sharedInstance {
            return instance
        }
        let instance = LocalStorage()
        sharedInstance = instance
        return instance
    }

    /// Destroys the shared storage instance (used for testing or hard resets).
    @objc(destroySharedInstance)
    static func destroySharedInstance() {
        sharedInstance = nil
    }

    /// Returns the service type identifiers of the given window, in the user's order.
    ///
    /// Every registered service is listed: stored types that are no longer registered are dropped,
    /// and services missing from the stored list are appended disabled.
    /// - Parameter windowType: Window type to query.
    /// - Returns: Ordered service type identifiers.
    @objc(allServiceTypes:)
    func allServiceTypes(_ windowType: EZWindowType) -> [String] {
        let allServiceTypesKey = Self.serviceTypesKey(of: windowType)
        let registeredTypes = QueryServiceFactory.shared.allServiceTypeIDs

        guard let storedTypes = userDefaults.array(forKey: allServiceTypesKey) as? [String] else {
            userDefaults.set(registeredTypes, forKey: allServiceTypesKey)
            return registeredTypes
        }

        var serviceTypes = storedTypes.filter { registeredTypes.contains($0) }
        let missingTypes = registeredTypes.filter { !serviceTypes.contains($0) }
        for typeId in missingTypes {
            // A service added in an update takes its registration position in the list.
            let position = registeredTypes.firstIndex(of: typeId) ?? serviceTypes.count
            serviceTypes.insert(typeId, at: min(position, serviceTypes.count))
            let type = ServiceType(rawValue: typeId)
            if serviceInfo(withType: type, windowType: windowType) == nil {
                setServiceInfo(
                    QueryServiceConfiguration(
                        type: type,
                        enabled: enabledWhenAddedServiceTypeIDs.contains(typeId),
                        windowType: windowType
                    ),
                    windowType: windowType
                )
            }
        }

        if serviceTypes != storedTypes {
            userDefaults.set(serviceTypes, forKey: allServiceTypesKey)
        }
        return serviceTypes
    }

    /// Persists ordered service type identifiers for the given window.
    /// - Parameters:
    ///   - allServiceTypes: Ordered service type identifiers.
    ///   - windowType: Target window type.
    @objc(setAllServiceTypes:windowType:)
    func setAllServiceTypes(_ allServiceTypes: [String], windowType: EZWindowType) {
        userDefaults.set(allServiceTypes, forKey: Self.serviceTypesKey(of: windowType))
    }

    /// Returns configured services for the given window with persisted flags applied.
    /// - Parameter windowType: Target window type.
    /// - Returns: Service instances with persisted state applied.
    @objc(allServices:)
    func allServices(_ windowType: EZWindowType) -> [QueryService] {
        let services = QueryServiceFactory.shared.services(fromTypes: allServiceTypes(windowType))
        services.forEach { updateServiceInfo($0, windowType: windowType) }
        return services
    }

    @objc(enabledServices:)
    func enabledServices(_ windowType: EZWindowType) -> [QueryService] {
        let typeIds = enabledServiceTypeIDs(windowType)
        var result: [QueryService] = []

        for typeId in typeIds {
            guard let service = QueryServiceFactory.shared.service(withTypeId: typeId) else {
                continue
            }
            updateServiceInfo(service, windowType: windowType)
            result.append(service)
        }
        return result
    }

    func enabledServiceTypeIDs(_ windowType: EZWindowType) -> [String] {
        allServiceTypes(windowType).filter { typeId in
            serviceInfo(withType: ServiceType(rawValue: typeId), windowType: windowType)?.enabled == true
        }
    }

    func setServiceEnabled(_ enabled: Bool, serviceTypeId: String, windowType: EZWindowType) {
        let type = ServiceType(rawValue: serviceTypeId)
        let info = serviceInfo(withType: type, windowType: windowType) ??
            QueryServiceConfiguration(
                type: type,
                enabled: enabled,
                enabledQuery: queryCount == 0,
                windowType: windowType
            )
        info.enabled = enabled
        setServiceInfo(info, windowType: windowType)
    }

    /// Returns a service instance with persisted flags applied.
    /// - Parameters:
    ///   - serviceTypeId: Service type identifier.
    ///   - windowType: Target window type.
    /// - Returns: Configured service instance, or `nil` for unrecognized types.
    @objc(service:windowType:)
    func service(_ serviceTypeId: String, windowType: EZWindowType) -> QueryService? {
        guard let service = QueryServiceFactory.shared.service(withTypeId: serviceTypeId) else {
            assertionFailure("Unsupported service type: \(serviceTypeId)")
            logError("Unsupported service type: \(serviceTypeId)")
            return nil
        }
        updateServiceInfo(service, windowType: windowType)
        return service
    }

    /// Fetches persisted service info for a service type.
    /// - Parameters:
    ///   - type: Service type identifier.
    ///   - windowType: Target window type.
    /// - Returns: Persisted service info when available.
    @objc(serviceInfoWithType:windowType:)
    func serviceInfo(withType type: ServiceType, windowType: EZWindowType) -> QueryServiceConfiguration? {
        guard let data = userDefaults.data(forKey: Self.serviceInfoKey(type: type, windowType: windowType)) else {
            return nil
        }

        if let info = try? decoder.decode(QueryServiceConfiguration.self, from: data) {
            return normalized(info, type: type, windowType: windowType)
        }

        return decodeLegacyServiceInfo(from: data, type: type, windowType: windowType)
    }

    /// Persists a service info record.
    /// - Parameters:
    ///   - serviceInfo: Service info to persist.
    ///   - windowType: Target window type.
    @objc(setServiceInfo:windowType:)
    func setServiceInfo(_ serviceInfo: QueryServiceConfiguration, windowType: EZWindowType) {
        let normalizedInfo = normalized(serviceInfo, type: serviceInfo.type, windowType: windowType)
        guard let data = try? encoder.encode(normalizedInfo) else {
            return
        }
        userDefaults.set(data, forKey: Self.serviceInfoKey(type: normalizedInfo.type, windowType: windowType))
    }

    /// Persists a service's current state.
    /// - Parameters:
    ///   - service: Service whose state should be saved.
    ///   - windowType: Target window type.
    @objc(setService:windowType:)
    func setService(_ service: QueryService, windowType: EZWindowType) {
        let serviceInfo = QueryServiceConfiguration.serviceInfo(with: service)
        setServiceInfo(serviceInfo, windowType: windowType)
    }

    /// Updates query enablement for a service.
    /// - Parameters:
    ///   - enabledQuery: Whether the service is allowed to query.
    ///   - serviceType: Service type identifier.
    ///   - windowType: Target window type.
    @objc(setEnabledQuery:serviceType:windowType:)
    func setEnabledQuery(_ enabledQuery: Bool, serviceType: ServiceType, windowType: EZWindowType) {
        let info = serviceInfo(withType: serviceType, windowType: windowType) ??
            QueryServiceConfiguration(
                type: serviceType,
                enabled: true,
                enabledQuery: enabledQuery,
                windowType: windowType
            )

        info.enabledQuery = enabledQuery
        setServiceInfo(info, windowType: windowType)
    }

    /// Increases total query counts using the provided query text length.
    /// - Parameter queryText: Text used for the query.
    @objc(increaseQueryCount:)
    func increaseQueryCount(_ queryText: String) {
        let currentCount = queryCount
        let currentLevel = queryLevel(for: currentCount)
        let newCount = currentCount + 1
        let newLevel = queryLevel(for: newCount)

        if currentCount == 0 || newLevel != currentLevel {
            let levelTitle = queryLevelTitle(newLevel, chineseFlag: true)
            logInfo("new level: \(levelTitle)")

            let dict: [String: String] = [
                "count": "\(newCount)",
                "level": "\(newLevel)",
                "title": levelTitle,
            ]
            AnalyticsService.logEvent(withName: "query_count", parameters: dict)
        }

        queryCount = newCount
        queryCharacterCount += queryText.count
    }

    /// Updates per-service query statistics.
    /// - Parameter service: Service being queried.
    @objc(increaseQueryService:)
    func increaseQueryService(_ service: QueryService) {
        let serviceType = service.serviceType()
        let record = record(with: serviceType)
        let queryLength = service.queryModel.queryText.count
        record.queryCount += 1
        record.queryCharacterCount += queryLength
        setQueryServiceRecord(record, serviceType: serviceType)

        AnalyticsService.logQueryService(service)
    }

    /// Checks whether a service has free quota left for the current user.
    /// - Parameter service: Service being queried.
    /// - Returns: `true` when the free quota is not exceeded.
    @objc(hasFreeQuotaLeft:)
    func hasFreeQuotaLeft(_ service: QueryService) -> Bool {
        let record = record(with: service.serviceType())
        let totalFreeCharacters = Double(service.totalFreeQueryCharacterCount()) * 0.9 /
            Double(Constants.totalUserCount)
        return Double(record.queryCharacterCount) < totalFreeCharacters
    }

    /// Whether the user is considered new.

    func isNewUser() -> Bool {
        queryCount < 100
    }

    // MARK: Private

    private static var sharedInstance: LocalStorage?

    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Services enabled in a window the first time it is set up.
    private let defaultEnabledServiceTypeIDs: [String] = [
        ServiceType.builtinDictionary.rawValue,
        ServiceType.reading.rawValue,
        ServiceType.mDict.rawValue,
    ]

    /// Services enabled when an update adds them to an existing window list; others are
    /// added disabled.
    private let enabledWhenAddedServiceTypeIDs: [String] = [
        ServiceType.builtinDictionary.rawValue,
    ]

    /// Raw dictionary backing service query statistics.
    private var queryServiceRecordDict: [String: [String: Any]] {
        get {
            userDefaults.dictionary(forKey: Constants.queryServiceRecordKey) as? [String: [String: Any]] ?? [:]
        }
        set {
            userDefaults.set(newValue, forKey: Constants.queryServiceRecordKey)
        }
    }

    /// Ensures all known services have stored defaults for each window type.
    private func setup() {
        let allWindowTypes: [EZWindowType] = [.mini, .fixed, .main]

        for windowType in allWindowTypes {
            for serviceTypeId in allServiceTypes(windowType) {
                let type = ServiceType(rawValue: serviceTypeId)
                guard serviceInfo(withType: type, windowType: windowType) == nil else { continue }

                let serviceInfo = QueryServiceConfiguration(
                    type: type,
                    enabled: defaultEnabledServiceTypeIDs.contains(serviceTypeId),
                    enabledQuery: queryCount == 0,
                    windowType: windowType
                )
                setServiceInfo(serviceInfo, windowType: windowType)
            }
        }
    }

    /// Applies persisted flags to a live service instance.
    /// - Parameters:
    ///   - service: Service to update.
    ///   - windowType: Window the service belongs to.
    private func updateServiceInfo(_ service: QueryService, windowType: EZWindowType) {
        let info = serviceInfo(withType: service.serviceType(), windowType: windowType)
        service.enabled = info?.enabled ?? true
        service.enabledQuery = info?.enabledQuery ?? true
        service.windowType = windowType
    }

    /// Reads or creates a per-service query usage record.
    /// - Parameter serviceType: Service type to query.
    /// - Returns: Usage record with counts.
    private func record(with serviceType: ServiceType) -> QueryServiceRecord {
        let dict = queryServiceRecordDict
        if let recordDict = dict[serviceType.rawValue],
           let queryCount = (recordDict["queryCount"] as? NSNumber)?.intValue ?? recordDict["queryCount"] as? Int,
           let queryCharacterCount = (recordDict["queryCharacterCount"] as? NSNumber)?
           .intValue ?? recordDict["queryCharacterCount"] as? Int {
            return QueryServiceRecord(
                serviceType: serviceType,
                queryCount: queryCount,
                queryCharacterCount: queryCharacterCount
            )
        }

        let record = QueryServiceRecord(serviceType: serviceType, queryCount: 0, queryCharacterCount: 0)
        setQueryServiceRecord(record, serviceType: serviceType)
        return record
    }

    /// Persists a per-service query usage record.
    /// - Parameters:
    ///   - record: Usage record to store.
    ///   - serviceType: Associated service type.
    private func setQueryServiceRecord(_ record: QueryServiceRecord, serviceType: ServiceType) {
        var dict = queryServiceRecordDict
        dict[serviceType.rawValue] = [
            "serviceType": record.serviceType.rawValue,
            "queryCount": record.queryCount,
            "queryCharacterCount": record.queryCharacterCount,
        ]
        queryServiceRecordDict = dict
    }

    /// Calculates a query level bucket for a count.
    /// - Parameter count: Total query count.
    /// - Returns: Level index.
    private func queryLevel(for count: Int) -> Int {
        switch count {
        case ..<10: return 1
        case ..<100: return 2
        case ..<500: return 3
        case ..<2000: return 4
        case ..<5000: return 5
        case ..<10000: return 6
        case ..<20000: return 7
        case ..<50000: return 8
        case ..<100000: return 9
        default: return 10
        }
    }

    /// Returns a localized level title.
    /// - Parameters:
    ///   - level: Level index.
    ///   - chineseFlag: Whether Chinese labels should be used.
    /// - Returns: Level title.
    private func queryLevelTitle(_ level: Int, chineseFlag: Bool) -> String {
        let titles = ["黑铁", "青铜", "白银", "黄金", "铂金", "钻石", "大师", "宗师", "王者", "传奇"]
        let enTitles = [
            "Iron",
            "Bronze",
            "Silver",
            "Gold",
            "Platinum",
            "Diamond",
            "Master",
            "Grandmaster",
            "King",
            "Legend",
        ]

        let clampedLevel = max(1, min(level, titles.count))
        return chineseFlag ? titles[clampedLevel - 1] : enTitles[clampedLevel - 1]
    }

    /// Attempts to decode legacy JSON payloads saved by MJExtension.
    /// - Parameters:
    ///   - data: Raw JSON data.
    ///   - type: Service type the data was stored for.
    ///   - windowType: Window scope.
    /// - Returns: Normalized service info when decoding succeeds.
    private func decodeLegacyServiceInfo(
        from data: Data,
        type: ServiceType,
        windowType: EZWindowType
    )
        -> QueryServiceConfiguration? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let info = QueryServiceConfiguration(
            type: type,
            enabled: jsonObject["enabled"] as? Bool ?? true,
            enabledQuery: jsonObject["enabledQuery"] as? Bool ?? true,
            windowType: windowType
        )
        return normalized(info, type: type, windowType: windowType)
    }

    /// Returns a copy of `info` stored under `type` and `windowType`.
    private func normalized(
        _ info: QueryServiceConfiguration,
        type: ServiceType,
        windowType: EZWindowType
    )
        -> QueryServiceConfiguration {
        QueryServiceConfiguration(
            type: type,
            enabled: info.enabled,
            enabledQuery: info.enabledQuery,
            windowType: windowType
        )
    }
}

// MARK: - Storage Keys

extension LocalStorage {
    /// UserDefaults key of a window's ordered service list.
    static func serviceTypesKey(of windowType: EZWindowType) -> String {
        "\(Constants.allServiceTypesKey)-\(windowType.rawValue)"
    }

    /// UserDefaults key of a service's enabled state in a window.
    static func serviceInfoKey(type: ServiceType, windowType: EZWindowType) -> String {
        "\(Constants.serviceInfoStorageKey)-\(type.rawValue)-\(windowType.rawValue)"
    }

    /// Key that older builds used for one instance of a service that could be added several times.
    /// Only read by `ServiceListMigration`.
    static func legacyServiceInfoKey(type: ServiceType, instanceID: String, windowType: EZWindowType) -> String {
        "\(Constants.serviceInfoStorageKey)-\(type.rawValue)-\(instanceID)-\(windowType.rawValue)"
    }
}

// MARK: - Constants

private enum Constants {
    static let serviceInfoStorageKey = "kServiceInfoStorageKey"
    static let allServiceTypesKey = "kAllServiceTypesKey"
    static let queryCountKey = "kQueryCountKey"
    static let queryCharacterCountKey = "kQueryCharacterCountKey"
    static let appModelTriggerListKey = "kAppModelTriggerListKey"
    static let queryServiceRecordKey = "kQueryServiceRecordKey"
    static let totalUserCount = 1000
}

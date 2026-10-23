//
//  QueryServiceFactory.swift
//  Easydict
//
//  Created by tisfeng on 2025/12/16.
//  Copyright © 2025 izual. All rights reserved.
//

import Defaults
import Foundation

// MARK: - QueryServiceMetadata

struct QueryServiceMetadata {
    let serviceType: ServiceType
    let title: String
    let isStream: Bool
}

// MARK: - ServiceRegistration

private struct ServiceRegistration {
    // MARK: Lifecycle

    init(
        _ serviceType: ServiceType,
        _ serviceClass: QueryService.Type,
        _ titleKey: String
    ) {
        self.serviceType = serviceType
        self.serviceClass = serviceClass
        self.titleKey = titleKey
    }

    // MARK: Internal

    let serviceType: ServiceType
    let serviceClass: QueryService.Type
    let titleKey: String
}

// MARK: - QueryServiceFactory

/// A registry that maps `ServiceType` identifiers to their corresponding `QueryService` subclasses.
///
/// This class mirrors the legacy Objective-C `EZServiceTypes` API and stays accessible from both Objective-C and Swift.
@objcMembers
final class QueryServiceFactory: NSObject {
    // MARK: Internal

    /// Shared singleton instance.
    static let shared = QueryServiceFactory()

    /// Every query service, in the default order of a window's service list.
    var allServiceTypes: [ServiceType] {
        serviceRegistrations.map(\.serviceType)
    }

    var allServiceTypeIDs: [String] {
        allServiceTypes.map(\.rawValue)
    }

    func service(withTypeId typeId: String) -> QueryService? {
        serviceRegistration(withTypeId: typeId)?.serviceClass.init()
    }

    func services(fromTypes types: [String]) -> [QueryService] {
        types.compactMap { service(withTypeId: $0) }
    }

    func isStreamService(typeIdIfHave typeId: String) -> Bool {
        guard let serviceClass = serviceRegistration(withTypeId: typeId)?.serviceClass else {
            return false
        }
        return serviceClass is StreamService.Type
    }

    func metadata(withTypeId typeId: String) -> QueryServiceMetadata? {
        guard let registration = serviceRegistration(withTypeId: typeId) else { return nil }

        return QueryServiceMetadata(
            serviceType: registration.serviceType,
            title: title(for: registration),
            isStream: registration.serviceClass is StreamService.Type
        )
    }

    // MARK: Private

    /// Slim build: a fixed set of local services. Every window lists all of them;
    /// the user can only enable, disable and reorder them.
    private let serviceRegistrations: [ServiceRegistration] = [
        .init(.reading, ReadingService.self, "service.reading.name"),
        .init(.mDict, MDictService.self, "service.mdict.name"),
        .init(.customOpenAI, CustomOpenAIService.self, "custom_openai"),
    ]

    private func serviceRegistration(withTypeId typeId: String) -> ServiceRegistration? {
        serviceRegistrations.first { $0.serviceType.rawValue == typeId }
    }

    private func title(for registration: ServiceRegistration) -> String {
        if registration.serviceType == .customOpenAI {
            let nameKey = serivceConfigurationKey(
                .name,
                serviceType: registration.serviceType,
                defaultValue: ""
            )
            let customName = Defaults[nameKey]
            if !customName.isEmpty {
                return customName
            }
        }
        return NSLocalizedString(registration.titleKey, comment: "")
    }
}

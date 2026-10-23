//
//  ServiceTests.swift
//  EasydictTests
//
//  Created by tisfeng on 2025/12/20.
//  Copyright © 2025 izual. All rights reserved.
//

import Testing

@testable import Easydict

// MARK: - ServiceTests

/// Integration tests that verify each registered service can translate a sample input.
@Suite("Service Translation Validation", .tags(.integration))
struct ServiceTests {
    // MARK: Internal

    /// Validates that every registered service returns a successful translation result.
    @Test("Validate All Services Translation", .tags(.integration))
    func testAllServicesValidateTranslation() async throws {
        let factory = QueryServiceFactory.shared
        let serviceTypes = factory.allServiceTypes

        #expect(!serviceTypes.isEmpty, "QueryServiceFactory returned no registered services.")

        for serviceType in serviceTypes {
            try await validate(serviceType: serviceType, factory: factory)
        }
    }

    // MARK: Private

    /// Validates a single service type and records a failure if translation fails.
    private func validate(serviceType: ServiceType, factory: QueryServiceFactory) async throws {
        let service = try #require(factory.service(withTypeId: serviceType.rawValue))

        let result = await service.validate()
        #expect(
            result.error == nil,
            "Service [\(serviceType.rawValue)] failed validation: \(result.error?.localizedDescription ?? "unknown error")"
        )
    }
}

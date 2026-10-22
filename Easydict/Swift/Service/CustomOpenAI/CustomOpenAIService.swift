//
//  CustomOpenAIService.swift
//  Easydict
//
//  Created by phlpsong on 2024/2/16.
//  Copyright © 2024 izual. All rights reserved.
//

import Defaults
import Foundation
import OpenAI

// MARK: - CustomOpenAIService

@objc(EZCustomOpenAIService)
class CustomOpenAIService: BaseOpenAIService {
    // MARK: Public

    public override func name() -> String {
        let serviceName = Defaults[super.nameKey]
        return serviceName.isEmpty ? NSLocalizedString("custom_openai", comment: "") : serviceName
    }

    public override func serviceType() -> ServiceType {
        .customOpenAI
    }

    // MARK: Internal

    override var supportsStreamingToggle: Bool { true }

    /// The switch works when the custom endpoint is a local Ollama server; other servers
    /// cannot report thinking support, so their switch stays disabled.
    override var supportsThinkingToggle: Bool {
        true
    }

    override var cachedThinkingCapability: ThinkingCapability? {
        OllamaThinkingProbe.cachedCapability(endpoint: endpoint, model: model)
    }

    @nonobjc
    override var reasoningEffort: ChatQuery.ReasoningEffort? {
        thinkingReasoningEffort
    }

    override func thinkingCapability(refresh: Bool) async -> ThinkingCapability {
        await OllamaThinkingProbe.capability(endpoint: endpoint, model: model, localOnly: true, refresh: refresh)
    }

    override func serviceTypeWithUniqueIdentifier() -> String {
        guard !uuid.isEmpty else {
            return ServiceType.customOpenAI.rawValue
        }
        return "\(ServiceType.customOpenAI.rawValue)#\(uuid)"
    }

    override func isDuplicatable() -> Bool {
        true
    }

    override func isDeletable(_ type: EZWindowType) -> Bool {
        !uuid.isEmpty
    }

    override func configurationListItems() -> Any {
        StreamConfigurationView(
            service: self,
            showCustomNameSection: true,
            showStreamingToggle: true
        )
    }
}

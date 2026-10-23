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

    /// Slim build: local servers usually need no key, so the key is optional and is only
    /// sent when filled in; a server that needs one answers with its own auth error.
    public override func apiKeyRequirement() -> ServiceAPIKeyRequirement {
        .none
    }

    // MARK: Internal

    override var supportsStreamingToggle: Bool { true }

    /// The switch works when the local server answers Ollama's `/api/show`; other servers
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

    override func configurationListItems() -> Any {
        StreamConfigurationView(
            service: self,
            showCustomNameSection: true,
            showStreamingToggle: true
        )
    }
}

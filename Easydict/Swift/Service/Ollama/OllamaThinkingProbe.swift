//
//  OllamaThinkingProbe.swift
//  Easydict
//
//  Slim build: detects through Ollama's `/api/show` whether a model can switch
//  thinking on and off, so the thinking switch is only offered when it works.
//

import Alamofire
import Foundation
import os

// MARK: - ThinkingCapability

enum ThinkingCapability: Sendable, Equatable {
    /// The model reports both `false` and `true` as thinking values.
    case toggleable
    /// The model cannot think, or only offers levels that cannot be turned off.
    case unsupported
    /// The endpoint did not answer like Ollama, so nothing can be concluded.
    case unknown
}

// MARK: - OllamaThinkingProbe

enum OllamaThinkingProbe {
    // MARK: Internal

    /// The cached result for `endpoint` and `model`, if one was detected before.
    static func cachedCapability(endpoint: String, model: String) -> ThinkingCapability? {
        guard let key = cacheKey(endpoint: endpoint, model: model) else { return nil }
        return cache.withLock { $0[key] }
    }

    /// Asks the Ollama server behind `endpoint` about `model`.
    /// - Parameters:
    ///   - localOnly: Only probe loopback and private-network hosts. Used for custom
    ///     OpenAI-compatible endpoints so cloud providers never receive the extra request.
    ///   - refresh: Ignore the cached result.
    static func capability(
        endpoint: String,
        model: String,
        localOnly: Bool,
        refresh: Bool
    ) async
        -> ThinkingCapability {
        guard let key = cacheKey(endpoint: endpoint, model: model),
              let rootURL = URL(string: endpoint)?.rootURL,
              !localOnly || isLocalHost(rootURL.host)
        else { return .unknown }

        if !refresh, let cached = cache.withLock({ $0[key] }) {
            return cached
        }

        let response = await AF.request(
            rootURL.appendingPathComponent("api/show"),
            method: .post,
            parameters: ["model": model],
            encoder: JSONParameterEncoder.default,
            requestModifier: { $0.timeoutInterval = Constants.timeout }
        )
        .validate(statusCode: 200 ..< 300)
        .serializingDecodable(ShowResponse.self)
        .response

        guard case let .success(show) = response.result else {
            return .unknown
        }

        let capability = show.thinkingCapability
        if capability != .unknown {
            cache.withLock { $0[key] = capability }
        }
        logInfo("Thinking capability of \(model): \(capability)")
        return capability
    }

    // MARK: Private

    private enum Constants {
        static let timeout: TimeInterval = 3
    }

    /// The parts of Ollama's `/api/show` response that describe thinking support.
    private struct ShowResponse: Decodable {
        struct Thinking: Decodable {
            let values: [ThinkingValue]
        }

        /// A thinking value is either a switch (`false`/`true`) or a level name.
        enum ThinkingValue: Decodable, Equatable {
            case bool(Bool)
            case level(String)

            // MARK: Lifecycle

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let value = try? container.decode(Bool.self) {
                    self = .bool(value)
                } else {
                    self = try .level(container.decode(String.self))
                }
            }
        }

        let capabilities: [String]?
        let thinking: Thinking?

        var thinkingCapability: ThinkingCapability {
            guard let capabilities else { return .unknown }
            guard capabilities.contains("thinking") else { return .unsupported }
            guard let values = thinking?.values else { return .unknown }
            return values.contains(.bool(false)) && values.contains(.bool(true)) ? .toggleable : .unsupported
        }
    }

    private static let cache = OSAllocatedUnfairLock<[String: ThinkingCapability]>(initialState: [:])

    private static func cacheKey(endpoint: String, model: String) -> String? {
        let model = model.trimmingCharacters(in: .whitespaces)
        guard !model.isEmpty, let root = URL(string: endpoint)?.rootURL?.absoluteString else { return nil }
        return "\(root)|\(model)"
    }

    private static func isLocalHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]")) else {
            return false
        }
        if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local") || host == "::1" {
            return true
        }
        if host.hasPrefix("fc") || host.hasPrefix("fd") || host.hasPrefix("fe80:") {
            return host.contains(":")
        }

        let octets = host.split(separator: ".").compactMap { UInt8($0) }
        guard octets.count == 4 else { return false }
        switch (octets[0], octets[1]) {
        case (10, _), (127, _), (169, 254), (192, 168):
            return true
        case (172, 16 ... 31):
            return true
        default:
            return false
        }
    }
}

//
//  OpenAICompatibleTTSClient.swift
//  Easydict
//
//  Slim build: requests speech from a server implementing OpenAI's `POST /v1/audio/speech`
//  (Kokoro-FastAPI, mlx-audio, LocalAI, OpenAI itself, ...).
//

import Alamofire
import Defaults
import Foundation

// MARK: - OpenAICompatibleTTSClient

struct OpenAICompatibleTTSClient {
    // MARK: Internal

    /// Client built from the current settings.
    static var configured: OpenAICompatibleTTSClient {
        .init(endpoint: Defaults[.ttsEndpoint], apiKey: Defaults[.ttsAPIKey], model: Defaults[.ttsModel])
    }

    let endpoint: String
    let apiKey: String
    let model: String

    /// Accepts the full speech URL or just a base such as `http://localhost:8880/v1`.
    static func speechURL(from endpoint: String) -> URL? {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              components.host?.isEmpty == false
        else { return nil }

        var path = components.path
        while path.hasSuffix("/") {
            path.removeLast()
        }
        if path.isEmpty {
            path = "/v1/audio/speech"
        } else if !path.hasSuffix("/audio/speech") {
            path += "/audio/speech"
        }
        components.path = path
        return components.url
    }

    /// Identifies the audio a request produces, for caching.
    func cacheKey(text: String, voice: String) -> String {
        [endpoint, model, voice, text].joined(separator: "\u{1F}")
    }

    /// Returns encoded audio (MP3 unless the server ignores `response_format`).
    func synthesize(_ text: String, voice: String) async throws -> Data {
        guard let url = Self.speechURL(from: endpoint) else {
            throw SpeechSynthesisError.invalidEndpoint
        }

        var headers = HTTPHeaders()
        let token = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            headers.add(.authorization(bearerToken: token))
        }

        let request = SpeechRequest(
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            input: text,
            voice: voice.trimmingCharacters(in: .whitespacesAndNewlines),
            responseFormat: "mp3"
        )
        let response = await AF.request(
            url,
            method: .post,
            parameters: request,
            encoder: JSONParameterEncoder.default,
            headers: headers,
            requestModifier: { $0.timeoutInterval = Self.timeout }
        )
        .serializingData(automaticallyCancelling: true, emptyResponseCodes: [])
        .response

        guard let statusCode = response.response?.statusCode else {
            throw response.error ?? SpeechSynthesisError.emptyAudio
        }
        let data = response.data ?? Data()
        guard (200 ..< 300).contains(statusCode) else {
            let body = String(bytes: data, encoding: .utf8).map { String($0.prefix(300)) } ?? ""
            throw SpeechSynthesisError.httpStatus(statusCode, body)
        }
        guard !data.isEmpty else {
            throw SpeechSynthesisError.emptyAudio
        }
        return data
    }

    // MARK: Private

    private struct SpeechRequest: Encodable {
        enum CodingKeys: String, CodingKey {
            case model
            case input
            case voice
            case responseFormat = "response_format"
        }

        let model: String
        let input: String
        let voice: String
        let responseFormat: String
    }

    /// Generous because a local server may load its model on the first request.
    private static let timeout: TimeInterval = 60
}

// MARK: - SpeechSynthesisError

enum SpeechSynthesisError: LocalizedError {
    case invalidEndpoint
    case httpStatus(Int, String)
    case emptyAudio
    case unplayableAudio

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            String(localized: "speech.error.invalid_endpoint")
        case let .httpStatus(statusCode, body):
            String(localized: "speech.error.http_status \(statusCode) \(body)")
        case .emptyAudio:
            String(localized: "speech.error.empty_audio")
        case .unplayableAudio:
            String(localized: "speech.error.unplayable_audio")
        }
    }
}

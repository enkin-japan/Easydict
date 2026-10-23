//
//  ActionManager.swift
//  Easydict
//
//  Created by tisfeng on 2025/8/29.
//  Copyright © 2025 izual. All rights reserved.
//

import AppKit
import Defaults
import Foundation
import SelectedTextKit

// MARK: - ActionManager

/// Singleton class responsible for handling various application actions
@objc(EZActionManager)
class ActionManager: NSObject {
    // MARK: Internal

    // MARK: - Singleton

    @objc static let shared = ActionManager()

    // MARK: - Text Field Detection and Access

    // MARK: - Public Methods

    /// Translate selected text and replace it with the translation result
    func translateAndReplace() async {
        logInfo("Translate and Replace")
        await executeTextReplacementAction(.translate)
    }

    /// Translates `text` with the first enabled AI service and returns the full result.
    /// Used by the macOS Services menu ("Translate and Replace"), which needs the text synchronously.
    func translatedText(for text: String) async throws -> String {
        guard let request = await prepareTranslationRequest(queryText: text, type: .translate) else {
            throw QueryError(type: .api, message: "No enabled Custom OpenAI service")
        }

        var result = ""
        for try await chunk in request.contentStream() {
            result += chunk
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Private

    /// Type of text processing action
    private enum ProcessingType {
        case translate
    }

    /// Text to translate, its detected languages and the service that translates it.
    private struct TranslationRequest {
        let text: String
        let from: Language
        let to: Language
        let service: StreamService

        func contentStream() -> AsyncThrowingStream<String, Error> {
            // Replacing text always wants a plain translation, never a dictionary entry.
            service.queryType = .translation
            return service.contentStreamTranslate(text, from: from, to: to)
        }
    }

    private let systemUtility = SystemUtility.shared

    /// First enabled `StreamService` across the query windows (fixed → mini → main).
    private static func firstEnabledStreamService() -> StreamService? {
        let windowTypes: [EZWindowType] = [.fixed, .mini, .main]
        for windowType in windowTypes {
            let services = LocalStorage.shared().enabledServices(windowType)
            if let service = services.first(where: { $0 is StreamService }) as? StreamService {
                return service
            }
        }
        return nil
    }

    // MARK: - Core Action Methods

    /// Common method to execute text replacement actions
    private func executeTextReplacementAction(_ type: ProcessingType) async {
        let enableSelectAll = Defaults[.autoSelectAllTextFieldText]
        let elementInfo = await systemUtility.focusedElementInfo(enableSelectAll: enableSelectAll)

        // Prepare translation request
        var queryText = elementInfo.focusedText
        if queryText?.isEmpty ?? true {
            queryText = await systemUtility.getSelectedText()
        }

        guard let queryText, !queryText.isEmpty else {
            logInfo("No text selected or focused for \(type), skipping action")
            return
        }

        // Prepare translation request
        guard let request = await prepareTranslationRequest(queryText: queryText, type: type) else {
            return
        }

        // Execute the streaming service
        await performStreamingService(request: request, elementInfo: elementInfo)
    }

    // MARK: - Helper Methods

    /// Prepare translation request from text field information
    /// - Parameters:
    ///   - elementInfo: Information about the current focused element
    ///   - type: The type of processing (translate or polish)
    /// - Returns: A configured TranslationRequest or nil if preparation fails
    private func prepareTranslationRequest(
        queryText: String,
        type: ProcessingType
    ) async
        -> TranslationRequest? {
        // Detect language and target
        let queryModel = try? await DetectManager().detectText(queryText)
        guard let detectedLanguage = queryModel?.detectedLanguage,
              let targetLanguage = queryModel?.queryTargetLanguage
        else {
            logError("Failed to detect target language, skipping \(type) and replace")
            return nil
        }

        // Slim build: use the Custom OpenAI service if it is enabled in any window.
        guard let service = Self.firstEnabledStreamService() else {
            logError("No enabled Custom OpenAI service for \(type), skipping")
            return nil
        }

        return TranslationRequest(text: queryText, from: detectedLanguage, to: targetLanguage, service: service)
    }

    // MARK: - Streaming Service Methods

    /// Perform translation or polishing using a streaming service
    private func performStreamingService(
        request: TranslationRequest,
        elementInfo: FocusedElementInfo
    ) async {
        logInfo("Using model: \(request.service.model)")

        do {
            try Task.checkCancellation()
            let contentStream = request.contentStream()
            try Task.checkCancellation()
            await replaceTextWithStream(contentStream, elementInfo: elementInfo)
        } catch {
            if Task.isCancelled {
                logInfo("Streaming task cancelled")
            } else {
                logError("stream failed: \(error.localizedDescription)")
            }
        }
    }

    /// Replace text with streaming data
    @MainActor
    private func replaceTextWithStream(
        _ contentStream: AsyncThrowingStream<String, Error>,
        elementInfo: FocusedElementInfo
    ) async {
        logInfo("Replacing text with streaming content")

        // For avoding polluting user pasteboard content, we need to save and restore it when AX is not supported.
        let pasteboard = NSPasteboard.general
        var snapshotItems: [NSPasteboardItem]?

        let isSupportedAX = elementInfo.isSupportedAXElement
        if !isSupportedAX {
            snapshotItems = pasteboard.backupItems()
        }

        do {
            let textStrategy = systemUtility.textStrategies(for: elementInfo)

            /**
             - Note:
             For GitHub web text area, if select all and insert empty string,
             it will clear the text area and lose focus.
             So we do not insert empty string.
             */

            var reuslt = ""
            for try await content in contentStream where !content.isEmpty {
                //                logInfo("Received streaming content chunk: \(content.prettyJSONString)")

                reuslt += content
                await systemUtility.insertText(content, using: textStrategy)
            }
            logInfo("Final replacement result: \(reuslt.prettyJSONString)")
        } catch {
            logError("Streaming replacement failed: \(error)")
        }

        if let snapshotItems, !isSupportedAX {
            pasteboard.restoreItems(snapshotItems)
        }
    }
}

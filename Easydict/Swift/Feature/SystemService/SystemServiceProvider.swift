//
//  SystemServiceProvider.swift
//  Easydict
//
//  Slim build: macOS Services menu entries (right click → Services, or a global
//  shortcut set in System Settings › Keyboard › Keyboard Shortcuts › Services).
//
//  The system hands the selected text to the app through the Services pasteboard,
//  so these entries need no Accessibility, Automation or Screen Recording permission
//  and work in apps whose own context menu has no "Translate" item.
//

import AppKit

// MARK: - SystemServiceProvider

/// Provider registered as `NSApp.servicesProvider`.
/// Selector names must match the `NSMessage` values declared under `NSServices` in Info.plist.
@objc(EZSystemServiceProvider)
final class SystemServiceProvider: NSObject {
    // MARK: Internal

    @objc static let shared = SystemServiceProvider()

    /// Registers the provider. Call once at launch.
    @objc
    func registerProvider() {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    /// "Look Up in Easydict": opens the query window with the selected text.
    @objc(lookUpInEasydict:userData:error:)
    func lookUpInEasydict(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let text = Self.text(from: pasteboard) else {
            error.pointee = "No text was passed to Easydict." as NSString
            return
        }

        let windowType = MyConfiguration.shared.shortcutSelectTranslateWindowType
        EZWindowManager.shared().showFloating(
            windowType,
            queryText: text,
            autoQuery: true,
            actionType: .invokeQuery
        )
    }

    /// "Translate and Replace with Easydict": replaces the selection with its translation.
    ///
    /// Services are synchronous, so this spins the main run loop until the AI service
    /// finishes (the main queue keeps being serviced, so main-actor work still runs).
    @objc(translateAndReplaceInEasydict:userData:error:)
    func translateAndReplaceInEasydict(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let text = Self.text(from: pasteboard) else {
            error.pointee = "No text was passed to Easydict." as NSString
            return
        }

        let box = OutcomeBox()
        Task {
            do {
                box.value = .success(try await ActionManager.shared.translatedText(for: text))
            } catch {
                box.value = .failure(error)
            }
        }

        let deadline = Date().addingTimeInterval(Constants.replaceTimeout)
        while box.value == nil, Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }

        switch box.value {
        case let .success(translated) where !translated.isEmpty:
            pasteboard.clearContents()
            pasteboard.setString(translated, forType: .string)
        case let .failure(failure):
            logError("Services translate and replace failed: \(failure)")
            error.pointee = failure.localizedDescription as NSString
        default:
            error.pointee = "Easydict translation timed out or returned nothing." as NSString
        }
    }

    // MARK: Private

    /// Holds the async result while the main run loop is spun.
    private final class OutcomeBox: @unchecked Sendable {
        var value: Result<String, Error>?
    }

    private enum Constants {
        /// Keep below `NSTimeout` in Info.plist (60 s).
        static let replaceTimeout: TimeInterval = 55
    }

    private static func text(from pasteboard: NSPasteboard) -> String? {
        guard let text = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        else {
            return nil
        }
        return text
    }
}

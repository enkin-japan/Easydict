//
//  MyConfiguration.swift
//  Easydict
//
//  Created by ljk on 2024/1/2.
//  Copyright © 2024 izual. All rights reserved.
//

import AppKit
import Combine
import Defaults
import Foundation

// MARK: - MyConfiguration

/// Singleton class to manage application configuration settings.
/// This class uses the `Defaults` library to persist settings and provides
/// reactive updates using Combine.
@objcMembers
class MyConfiguration: NSObject {
    // MARK: Lifecycle

    override private init() {
        super.init()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            observeKeys()
        }
    }

    // MARK: Internal

    private(set) static var shared = MyConfiguration()

    @DefaultsWrapper(.firstLanguage) var firstLanguage: Language
    @DefaultsWrapper(.secondLanguage) var secondLanguage: Language
    @DefaultsWrapper(.queryFromLanguage) var fromLanguage: Language
    @DefaultsWrapper(.queryToLanguage) var toLanguage: Language

    @DefaultsWrapper(.autoShowQueryIcon) var autoSelectText: Bool
    @DefaultsWrapper(.autoShowQueryIconExcludedLanguage) var autoShowQueryIconExcludedLanguage: Language
    @DefaultsWrapper(.autoShowQueryIconMinTextLength) var autoShowQueryIconMinTextLength: Int
    @DefaultsWrapper(.enableForceGetSelectedText) var enableForceGetSelectedText: Bool
    @DefaultsWrapper(.clickQuery) var clickQuery: Bool

    @DefaultsWrapper(.mouseSelectTranslateWindowType) var mouseSelectTranslateWindowType:
        EZWindowType
    @DefaultsWrapper(.shortcutSelectTranslateWindowType) var shortcutSelectTranslateWindowType:
        EZWindowType
    @DefaultsWrapper(.fixedWindowPosition) var fixedWindowPosition: EZShowWindowPosition
    @DefaultsWrapper(.miniWindowPosition) var miniWindowPosition: EZShowWindowPosition
    @DefaultsWrapper(.pinWindowWhenDisplayed) var pinWindowWhenDisplayed
    @DefaultsWrapper(.keepFixedWindowVisible) var keepFixedWindowVisible: Bool
    @DefaultsWrapper(.hideMainWindow) var hideMainWindow: Bool

    @DefaultsWrapper(.clearQueryWhenInputTranslate) var clearInput: Bool
    @DefaultsWrapper(.keepPrevResultWhenSelectTranslateTextIsEmpty) var keepPrevResultWhenEmpty:
        Bool
    @DefaultsWrapper(.selectQueryTextWhenWindowActivate) var selectQueryTextWhenWindowActivate: Bool
    @DefaultsWrapper(.automaticallyRemoveCodeCommentSymbols) var automaticallyRemoveCodeCommentSymbols: Bool
    @DefaultsWrapper(.automaticWordSegmentation) var automaticWordSegmentation: Bool
    @DefaultsWrapper(.replaceNewlineWithSpace) var replaceNewlineWithSpace: Bool
    @DefaultsWrapper(.enableRemoveBooksExcerptInfo) var enableRemoveBooksExcerptInfo: Bool

    @DefaultsWrapper(.autoQuerySelectedText) var autoQuerySelectedText: Bool
    @DefaultsWrapper(.autoQueryPastedText) var autoQueryPastedText: Bool
    @DefaultsWrapper(.autoQueryWhenTextChanged) var autoQueryWhenTextChanged: Bool
    @DefaultsWrapper(.autoCopySelectedText) var autoCopySelectedText: Bool
    @DefaultsWrapper(.autoCopyFirstTranslatedText) var autoCopyFirstTranslatedText: Bool

    @DefaultsWrapper(.showGoogleQuickLink) var showGoogleQuickLink: Bool
    @DefaultsWrapper(.showEudicQuickLink) var showEudicQuickLink: Bool
    @DefaultsWrapper(.showQuickActionButton) var showQuickActionButton: Bool

    @DefaultsWrapper(.appearanceType) var appearance: AppearanceType
    @DefaultsWrapper(.hideMenuBarIcon) var hideMenuBarIcon: Bool
    @DefaultsWrapper(.fontSizeOptionIndex) var fontSizeIndex: UInt
    @DefaultsWrapper(.enableMarkdownRendering) var enableMarkdownRendering: Bool

    // Advanced Tab
    @DefaultsWrapper(.enableCompatibilityReplace) var enableCompatibilityReplace: Bool
    @DefaultsWrapper(.forceGetSelectedTextType) var forceGetSelectedTextType:
        ForceGetSelectedTextType

    @DefaultsWrapper(.formerFixedScreenVisibleFrame) var formerFixedScreenVisibleFrame: CGRect
    @DefaultsWrapper(.formerMiniScreenVisibleFrame) var formerMiniScreenVisibleFrame: CGRect
    @DefaultsWrapper(.enableAnkiConnect) var enableAnkiConnect: Bool

    // Max window height percentage, e.g., 80 means 80% of the screen height
    @DefaultsWrapper(.maxWindowHeightPercentage) var maxWindowHeightPercentage: Int

    @DefaultsWrapper(.allowCrashLog) var allowCrashLog: Bool
    @DefaultsWrapper(.allowAnalytics) var allowAnalytics: Bool

    @ShortcutWrapper(.pinShortcut) var pinShortcutString: String
    @ShortcutWrapper(.googleShortcut) var googleShortcutString: String
    @ShortcutWrapper(.eudicShortcut) var eudicDictShortcutString: String

    let updater = GlobalContext.shared.updaterController.updater
    let fontSizes: [CGFloat] = [1, 1.1, 1.2, 1.3, 1.4]
    var disabledAutoSelect: Bool = false
    var isRecordingSelectTextShortcutKey: Bool = false
    var cancellables: Set<AnyCancellable> = []

    /// Slim build: AppleScript is never used.
    var preferAppleScriptAPI: Bool { false }

    var fontSizeRatio: CGFloat {
        let safeIndex = max(0, min(Int(fontSizeIndex), fontSizes.count - 1))
        return fontSizes[safeIndex]
    }

    static func destroySharedInstance() {
        shared = MyConfiguration()
    }

    // MARK: Private

    // swiftlint:disable:next function_body_length
    private func observeKeys() {
        Defaults.publisher(.firstLanguage, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetFirstLanguage()
            }
            .store(in: &cancellables)

        Defaults.publisher(.secondLanguage, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetSecondLanguage()
            }
            .store(in: &cancellables)

        Defaults.publisher(.autoShowQueryIcon, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetAutoSelectText()
            }
            .store(in: &cancellables)

        Defaults.publisher(.autoShowQueryIconExcludedLanguage, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetAutoShowQueryIconExcludedLanguage()
            }
            .store(in: &cancellables)

        Defaults.publisher(.autoShowQueryIconMinTextLength, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetAutoShowQueryIconMinTextLength()
            }
            .store(in: &cancellables)

        Defaults.publisher(.enableForceGetSelectedText, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetForceAutoGetSelectedText()
            }
            .store(in: &cancellables)

        Defaults.publisher(.clickQuery, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetClickQuery()
            }
            .store(in: &cancellables)

        Defaults.publisher(.hideMainWindow, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetHideMainWindow()
            }
            .store(in: &cancellables)

        Defaults.publisher(.autoQuerySelectedText, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetAutoQuerySelectedText()
            }
            .store(in: &cancellables)

        Defaults.publisher(.autoQueryPastedText, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetAutoQueryPastedText()
            }
            .store(in: &cancellables)

        Defaults.publisher(.autoCopySelectedText, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetAutoCopySelectedText()
            }
            .store(in: &cancellables)

        Defaults.publisher(.autoCopyFirstTranslatedText, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetAutoCopyFirstTranslatedText()
            }
            .store(in: &cancellables)

        Defaults.publisher(.showGoogleQuickLink, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetShowGoogleQuickLink()
            }
            .store(in: &cancellables)

        Defaults.publisher(.showEudicQuickLink, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetShowEudicQuickLink()
            }
            .store(in: &cancellables)

        Defaults.publisher(.showQuickActionButton, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetShowSettingQuickLink()
            }
            .store(in: &cancellables)

        Defaults.publisher(.hideMenuBarIcon, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetHideMenuBarIcon()
            }
            .store(in: &cancellables)

        Defaults.publisher(.fixedWindowPosition, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetFixedWindowPosition()
            }
            .store(in: &cancellables)

        Defaults.publisher(.keepFixedWindowVisible, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetKeepFixedWindowVisible()
            }
            .store(in: &cancellables)

        Defaults.publisher(.mouseSelectTranslateWindowType, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetMouseSelectTranslateWindowType()
            }
            .store(in: &cancellables)

        Defaults.publisher(.shortcutSelectTranslateWindowType, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetShortcutSelectTranslateWindowType()
            }
            .store(in: &cancellables)

        Defaults.publisher(.allowCrashLog, options: [.initial])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetAllowCrashLog()
            }
            .store(in: &cancellables)

        Defaults.publisher(.allowAnalytics, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetAllowAnalytics()
            }
            .store(in: &cancellables)

        Defaults.publisher(.clearQueryWhenInputTranslate, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetClearInput()
            }
            .store(in: &cancellables)

        Defaults.publisher(.fontSizeOptionIndex, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didSetFontSizeIndex()
            }
            .store(in: &cancellables)

        Defaults.publisher(.appearanceType, options: [])
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                let newValue = change.newValue
                self?.didSetAppearance(newValue)
            }
            .store(in: &cancellables)

        Defaults.publisher(
            keys: [
                .pinShortcut,
                .googleShortcut,
                .eudicShortcut,
            ],
            options: []
        )
        .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
        .receive(on: DispatchQueue.main)
        .sink { _ in
            EZWindowManager.shared().updateWindowsTitlebarButtonsToolTip()
        }
        .store(in: &cancellables)
    }
}

// MARK: setter

extension MyConfiguration {
    fileprivate func didSetFirstLanguage() {
        logSettings(["first_language": firstLanguage])
    }

    fileprivate func didSetSecondLanguage() {
        logSettings(["second_language": secondLanguage])
    }

    fileprivate func didSetAutoSelectText() {
        EventMonitor.shared.addBothMonitor(autoSelectText)
        logSettings(["auto_select_sext": autoSelectText])
    }

    fileprivate func didSetAutoShowQueryIconExcludedLanguage() {
        logSettings(["auto_show_query_icon_excluded_language": autoShowQueryIconExcludedLanguage])
    }

    fileprivate func didSetAutoShowQueryIconMinTextLength() {
        logSettings(["auto_show_query_icon_min_text_length": autoShowQueryIconMinTextLength])
    }

    fileprivate func didSetForceAutoGetSelectedText() {
        logSettings(["force_get_selected_text": enableForceGetSelectedText])
    }

    fileprivate func didSetClickQuery() {
        EZWindowManager.shared().updatePopButtonQueryAction()

        logSettings(["click_query": clickQuery])
    }

    fileprivate func didSetHideMainWindow() {
        let windowManger = EZWindowManager.shared()
        windowManger.updatePopButtonQueryAction()
        if hideMainWindow {
            windowManger.destroyMainWindow()
        }

        logSettings(["hide_main_window": hideMainWindow])
    }

    fileprivate func didSetAutoQuerySelectedText() {
        logSettings(["auto_query_selected_text": autoQuerySelectedText])
    }

    fileprivate func didSetAutoQueryPastedText() {
        logSettings(["auto_query_pasted_text": autoQueryPastedText])
    }

    fileprivate func didSetAutoCopySelectedText() {
        logSettings(["auto_copy_selected_text": autoCopySelectedText])
    }

    fileprivate func didSetAutoCopyFirstTranslatedText() {
        logSettings(["auto_copy_first_translated_text": autoCopyFirstTranslatedText])
    }

    fileprivate func didSetShowGoogleQuickLink() {
        postUpdateQuickLinkButtonNotification()
        logSettings(["show_google_link": showGoogleQuickLink])
    }

    fileprivate func didSetShowEudicQuickLink() {
        postUpdateQuickLinkButtonNotification()
        logSettings(["show_eudic_link": showEudicQuickLink])
    }

    func didSetShowSettingQuickLink() {
        postUpdateQuickLinkButtonNotification()

        logSettings(["showSettingQuickLink": showQuickActionButton])
    }

    fileprivate func didSetHideMenuBarIcon() {
        logSettings(["hide_menu_bar_icon": hideMenuBarIcon])
    }

    fileprivate func didSetFixedWindowPosition() {
        logSettings(["show_fixed_window_position": fixedWindowPosition])
    }

    fileprivate func didSetKeepFixedWindowVisible() {
        logSettings(["keep_fixed_window_visible": keepFixedWindowVisible])

        // Apply to a fixed window that is already showing; the window is not created just for this.
        let fixedWindow = NSApp.windows.first { $0 is EZFixedQueryWindow && $0.isVisible }
        if let fixedWindow = fixedWindow as? EZBaseQueryWindow {
            fixedWindow.isPin = keepFixedWindowVisible || pinWindowWhenDisplayed
        }
    }

    fileprivate func didSetMouseSelectTranslateWindowType() {
        logSettings(["show_mouse_window_type": mouseSelectTranslateWindowType])
    }

    fileprivate func didSetShortcutSelectTranslateWindowType() {
        logSettings(["show_shortcut_window_type": shortcutSelectTranslateWindowType])
    }

    fileprivate func didSetAllowCrashLog() {
        AnalyticsService.setCrashEnabled(allowCrashLog)
        logSettings(["allow_crash_log": allowCrashLog])
    }

    fileprivate func didSetAllowAnalytics() {
        logSettings(["allow_analytics": allowAnalytics])
    }

    fileprivate func didSetClearInput() {
        logSettings(["clear_input": clearInput])
    }

    fileprivate func didSetFontSizeIndex() {
        NotificationCenter.default.post(name: .didChangeFontSize, object: nil)
    }

    fileprivate func didSetAppearance(_ appearance: AppearanceType) {
        DarkModeManager.shared.updateDarkMode(appearance)
    }
}

extension MyConfiguration {
    fileprivate func postUpdateQuickLinkButtonNotification() {
        let notification = Notification(name: Notification.Name.linkButtonUpdated, object: nil)
        NotificationCenter.default.post(notification)
    }

    fileprivate func logSettings(_ parameters: [String: Any]) {
        AnalyticsService.logEvent(withName: "settings", parameters: parameters)
    }
}

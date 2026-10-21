//
//  AdvancedTab.swift
//  Easydict
//
//  Created by tisfeng on 2024/1/23.
//  Copyright © 2024 izual. All rights reserved.
//

import Defaults
import SFSafeSymbols
import SwiftUI

// MARK: - AdvancedTab

struct AdvancedTab: View {
    // MARK: Internal

    // Query text processing
    @Default(.replaceNewlineWithSpace) var replaceNewlineWithSpace: Bool
    @Default(.automaticallyRemoveCodeCommentSymbols) var automaticallyRemoveCodeCommentSymbols: Bool
    @Default(.automaticWordSegmentation) var automaticWordSegmentation: Bool

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $enableBetaFeature) {
                    AdvancedTabItemView(
                        color: .blue,
                        icon: .hammerFill,
                        labelText: "setting.advance.enable_beta_feature"
                    )
                }
            }

            // Items image color order: blue, green, orange, purple, red, mint, yellow, cyan, indigo

            // General settings section
            Section {
                // Slim build: TTS is fixed to the offline system voice.
                LabeledContent {
                    TextField(
                        text: $minClassicalChineseTextDetectLength,
                        prompt: Text(verbatim: "\(AppConstants.minClassicalChineseLength)")
                    ) {
                        EmptyView()
                    }
                    .frame(width: 100)
                    .fixedSize(horizontal: true, vertical: false)
                    .onChange(of: minClassicalChineseTextDetectLength) { newValue in
                        minClassicalChineseTextDetectLength = newValue.filter { $0.isNumber }
                        logInfo(
                            "Min classical Chinese text detect length: \(minClassicalChineseTextDetectLength)"
                        )
                    }
                } label: {
                    AdvancedTabItemView(
                        color: .purple,
                        icon: .book,
                        labelText: "setting.advance.min_classical_chinese_text_detect_length"
                    )
                }
            } header: {
                Text("setting.advance.header.general_settings")
            }

            // Mouse query icon
            Section {
                let minLengthBinding = Binding<Double>(
                    get: {
                        Double(min(50, max(0, autoShowQueryIconMinTextLength)))
                    },
                    set: { newValue in
                        autoShowQueryIconMinTextLength = min(50, max(0, Int(newValue)))
                    }
                )

                Toggle(isOn: $autoShowQueryIcon) {
                    AdvancedTabItemView(
                        color: .blue,
                        icon: .cursorarrowRays,
                        labelText: "setting.advance.auto_show_query_icon"
                    )
                }

                Group {
                    LabeledContent {
                        Picker(selection: $autoShowQueryIconExcludedLanguage) {
                            ForEach(Language.allAvailableOptions, id: \.rawValue) { option in
                                Text(verbatim: "\(option.flagEmoji) \(option.localizedName)")
                                    .tag(option)
                            }
                        } label: {
                            EmptyView()
                        }
                        .labelsHidden()
                    } label: {
                        Text("setting.advance.auto_show_query_icon.condition.language")
                    }

                    LabeledContent {
                        HStack(spacing: 8) {
                            Slider(value: minLengthBinding, in: 0 ... 50, step: 10)
                            Text("\(autoShowQueryIconMinTextLength)")
                                .frame(width: 32, alignment: .trailing)
                                .monospacedDigit()
                        }
                    } label: {
                        Text("setting.advance.auto_show_query_icon.condition.min_length")
                    }

                    Text("setting.advance.auto_show_query_icon.condition.desc")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 28)
                .disabled(!autoShowQueryIcon)
                .opacity(autoShowQueryIcon ? 1 : 0.6)

                Toggle(isOn: $clickQuery) {
                    AdvancedTabItemView(
                        color: .green,
                        icon: .cursorarrowClick,
                        labelText: "setting.advance.click_icon_query_info"
                    )
                }
            } header: {
                Text("setting.advance.mouse_select_query.header")
            }

            // Force get selected text and replace text
            Section {
                Toggle(isOn: $enableForceGetSelectedText) {
                    AdvancedTabItemView(
                        color: .blue,
                        icon: .characterCursorIbeam,
                        labelText: "setting.advance.enable_force_get_selected_text",
                        subtitleText: "setting.advance.enable_force_get_selected_text_desc"
                    )
                }

                Picker(
                    selection: $forceGetSelectedTextType,
                    label: AdvancedTabItemView(
                        color: .green,
                        icon: .highlighter,
                        labelText: "setting.advance.force_get_selected_text_type"
                    )
                ) {
                    ForEach(ForceGetSelectedTextType.allCases, id: \.rawValue) { option in
                        Text(option.localizedStringResource)
                            .tag(option)
                    }
                }

                Toggle(isOn: $enableCompatibilityReplace) {
                    AdvancedTabItemView(
                        color: .purple,
                        icon: .arrowForwardSquare,
                        labelText: "setting.advance.enable_compatibility_replace",
                        subtitleText: "setting.advance.enable_compatibility_replace_desc"
                    )
                }
                Toggle(isOn: $autoSelectAllTextFieldText) {
                    AdvancedTabItemView(
                        color: .red,
                        icon: .checkmarkSquare,
                        labelText: "setting.advance.auto_select_all_text_field_text",
                        subtitleText: "setting.advance.auto_select_all_text_field_text_desc"
                    )
                }
                Toggle(isOn: $enableRemoveBooksExcerptInfo) {
                    AdvancedTabItemView(
                        color: .mint,
                        icon: .book,
                        labelText: "setting.advance.enable_remove_books_excerpt_info"
                    )
                }
            } header: {
                Text("setting.advance.header.text_selection_and_replacement")
            }

            // Query text processing
            Section {
                Toggle(isOn: $replaceNewlineWithSpace) {
                    AdvancedTabItemView(
                        color: .blue,
                        icon: .arrowForwardSquare,
                        labelText: "setting.advance.automatically_replace_newline_with_space"
                    )
                }
                Toggle(isOn: $automaticallyRemoveCodeCommentSymbols) {
                    AdvancedTabItemView(
                        color: .green,
                        icon: .chevronLeftForwardslashChevronRight,
                        labelText: "setting.advance.automatically_remove_code_comment_symbols"
                    )
                }
                Toggle(isOn: $automaticWordSegmentation) {
                    AdvancedTabItemView(
                        color: .orange,
                        icon: .textWordSpacing,
                        labelText: "setting.advance.automatically_split_words"
                    )
                }
            } header: {
                Text("setting.advance.header.query_text_processing")
            } footer: {
                HStack {
                    Text("setting.advance.footer.query_text_processing_desc")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.leading, 10)

                    Spacer()
                }
            }

            // OCR settings section
            Section {
                Toggle(isOn: $enableOCRTextNormalization) {
                    AdvancedTabItemView(
                        color: .green,
                        icon: .docViewfinder,
                        labelText: "setting.advance.enable_ocr_text_normalization",
                        subtitleText: "setting.advance.enable_ocr_text_normalization_desc"
                    )
                }

                Toggle(isOn: $showOCRMenuItems) {
                    AdvancedTabItemView(
                        color: .orange,
                        icon: .textAndCommandMacwindow,
                        labelText: "setting.advance.show_ocr_menu_items",
                        subtitleText: "setting.advance.show_ocr_menu_items_desc"
                    )
                }

            } header: {
                Text("setting.advance.header.ocr_settings")
            }

            // Windows management
            Section {
                Picker(
                    selection: $mouseSelectTranslateWindowType,
                    label: AdvancedTabItemView(
                        color: .blue,
                        icon: .cursorarrowRays,
                        labelText: "setting.advance.window.mouse_select_translate_window_type"
                    )
                ) {
                    ForEach(EZWindowType.availableOptions, id: \.rawValue) { option in
                        Text(option.localizedStringResource)
                            .tag(option)
                    }
                }

                Picker(
                    selection: $shortcutSelectTranslateWindowType,
                    label: AdvancedTabItemView(
                        color: .green,
                        icon: .keyboardFill,
                        labelText: "setting.advance.window.shortcut_select_translate_window_type"
                    )
                ) {
                    ForEach(EZWindowType.availableOptions, id: \.rawValue) { option in
                        Text(option.localizedStringResource)
                            .tag(option)
                    }
                }

                Picker(
                    selection: $fixedWindowPosition,
                    label: AdvancedTabItemView(
                        color: .orange,
                        icon: .textAndCommandMacwindow,
                        labelText: "setting.advance.window.fixed_window_position"
                    )
                ) {
                    ForEach(EZShowWindowPosition.allCases, id: \.rawValue) { option in
                        Text(option.localizedStringResource)
                            .tag(option)
                    }
                }

                Picker(
                    selection: $miniWindowPosition,
                    label: AdvancedTabItemView(
                        color: .purple,
                        icon: .macwindow,
                        labelText: "setting.advance.window.mini_window_position"
                    )
                ) {
                    ForEach(EZShowWindowPosition.allCases, id: \.rawValue) { option in
                        Text(option.localizedStringResource)
                            .tag(option)
                    }
                }

                Toggle(isOn: $pinWindowWhenDisplayed) {
                    AdvancedTabItemView(
                        color: .red,
                        icon: .pinFill,
                        labelText: "setting.advance.pin_window_when_showing"
                    )
                }

                Toggle(isOn: $hideMainWindow) {
                    AdvancedTabItemView(
                        color: .mint,
                        icon: .eyeSlashFill,
                        labelText: "setting.advance.hide_main_window"
                    )
                }

                Picker(
                    selection: $maxWindowHeightPercentageValue,
                    label: AdvancedTabItemView(
                        color: .yellow,
                        icon: .arrowUpAndDown,
                        labelText: "setting.advance.window.max_height_percentage"
                    )
                ) {
                    ForEach(MaxWindowHeightPercentageOption.allCases) { option in
                        Text(option.title)
                            .tag(option)
                    }
                    .onChange(of: maxWindowHeightPercentageValue) { _ in
                        // Post notification when max window height percentage changes
                        NotificationCenter.default.post(
                            name: .maxWindowHeightSettingsChanged, object: nil
                        )
                    }
                }

            } header: {
                Text("setting.advance.window_management.header")
            }

            AdvancedTabAnkiSection()
            // Vocabulary notebook
            Section {
                Toggle(isOn: $enableVocabularyNotebook) {
                    AdvancedTabItemView(
                        color: .brown,
                        icon: .bookClosed,
                        labelText: "setting.advance.vocabulary_notebook",
                        subtitleText: "setting.advance.vocabulary_notebook_desc"
                    )
                }

                LabeledContent {
                    HStack(spacing: 8) {
                        Text(displayedVocabularyNotebookDirectory)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Button {
                            chooseVocabularyNotebookDirectory()
                        } label: {
                            Text("setting.advance.vocabulary_notebook_choose_directory")
                        }
                    }
                } label: {
                    AdvancedTabItemView(
                        color: .brown,
                        icon: .folderFill,
                        labelText: "setting.advance.vocabulary_notebook_directory"
                    )
                }
                .disabled(!enableVocabularyNotebook)
            } header: {
                Text("setting.advance.header.vocabulary_notebook")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Private

    @Default(.enableBetaFeature) private var enableBetaFeature

    @Default(.enableCompatibilityReplace) private var enableCompatibilityReplace
    @Default(.minClassicalChineseTextDetectLength) private var minClassicalChineseTextDetectLength
    @Default(.enableOCRTextNormalization) private var enableOCRTextNormalization
    @Default(.showOCRMenuItems) private var showOCRMenuItems
    @Default(.autoSelectAllTextFieldText) private var autoSelectAllTextFieldText

    // Force get selected text
    @Default(.enableForceGetSelectedText) private var enableForceGetSelectedText
    @Default(.forceGetSelectedTextType) private var forceGetSelectedTextType

    // mouse select from Books.app
    @Default(.enableRemoveBooksExcerptInfo) private var enableRemoveBooksExcerptInfo

    // Mouse select query
    @Default(.autoShowQueryIcon) private var autoShowQueryIcon
    @Default(.autoShowQueryIconExcludedLanguage) private var autoShowQueryIconExcludedLanguage
    @Default(.autoShowQueryIconMinTextLength) private var autoShowQueryIconMinTextLength
    @Default(.clickQuery) private var clickQuery

    // Windows management
    @Default(.fixedWindowPosition) private var fixedWindowPosition
    @Default(.miniWindowPosition) private var miniWindowPosition
    @Default(.mouseSelectTranslateWindowType) private var mouseSelectTranslateWindowType
    @Default(.shortcutSelectTranslateWindowType) private var shortcutSelectTranslateWindowType
    @Default(.pinWindowWhenDisplayed) private var pinWindowWhenDisplayed
    @Default(.hideMainWindow) private var hideMainWindow

    @Default(.enableVocabularyNotebook) private var enableVocabularyNotebook
    @Default(.vocabularyNotebookDirectory) private var vocabularyNotebookDirectory

    @Default(.maxWindowHeightPercentage) private var maxWindowHeightPercentageValue

    /// The directory path shown in the picker row, or a placeholder when unset.
    private var displayedVocabularyNotebookDirectory: String {
        vocabularyNotebookDirectory.isEmpty
            ? String(localized: "setting.advance.vocabulary_notebook_directory_placeholder")
            : vocabularyNotebookDirectory
    }

    /// Presents an `NSOpenPanel` for choosing the vocabulary notebook directory.
    private func chooseVocabularyNotebookDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "setting.advance.vocabulary_notebook_choose_directory")

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let directory = url.path
        guard FileManager.default.isWritableFile(atPath: directory) else {
            let alert = NSAlert()
            alert.messageText = String(
                localized: "setting.advance.vocabulary_notebook_directory_not_writable"
            )
            alert.addButton(withTitle: String(localized: "ok"))
            alert.runModal()
            return
        }

        vocabularyNotebookDirectory = directory
    }
}

#Preview {
    AdvancedTab()
}

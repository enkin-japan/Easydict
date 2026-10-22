//
//  ThinkingToggleCell.swift
//  Easydict
//
//  Slim build: thinking switch that is only operable for models detected as able to
//  turn thinking on and off.
//

import Defaults
import SwiftUI

// MARK: - ThinkingToggleCell

struct ThinkingToggleCell: View {
    // MARK: Lifecycle

    init(service: StreamService) {
        self.service = service
        self._isEnabled = .init(service.enableThinkingKey)
        self._model = .init(service.modelKey)
        self._endpoint = .init(service.endpointKey)
    }

    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("service.configuration.thinking.title", isOn: switchBinding)
                .disabled(capability != .toggleable)

            Text(footnote)
                .font(.footnote)
                .foregroundStyle(.gray)
        }
        .task(id: "\(endpoint)|\(model)") {
            capability = nil
            capability = await service.thinkingCapability(refresh: true)
        }
    }

    // MARK: Private

    /// nil while detection is in progress.
    @State private var capability: ThinkingCapability?

    private let service: StreamService

    @Default private var isEnabled: Bool
    @Default private var model: String
    @Default private var endpoint: String

    /// Shows the stored choice only when it takes effect; a disabled switch reads as off.
    private var switchBinding: Binding<Bool> {
        Binding(
            get: { capability == .toggleable && isEnabled },
            set: { isEnabled = $0 }
        )
    }

    private var footnote: LocalizedStringKey {
        switch capability {
        case .none:
            "service.configuration.thinking.footnote.checking"
        case .toggleable:
            "service.configuration.thinking.footnote.toggleable"
        case .unsupported:
            "service.configuration.thinking.footnote.unsupported"
        case .unknown:
            "service.configuration.thinking.footnote.unknown"
        }
    }
}

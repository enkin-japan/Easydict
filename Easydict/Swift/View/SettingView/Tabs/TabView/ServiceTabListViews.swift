//
//  ServiceTabListViews.swift
//  Easydict
//
//  Created by MoonMao on 2026/5/27.
//  Copyright © 2026 izual. All rights reserved.
//

import SwiftUI

// MARK: - ServiceItems

struct ServiceItems: View {
    // MARK: Internal

    var body: some View {
        ForEach(viewModel.serviceItems) { item in
            ServiceItemView(item: item)
                .tag(ServiceTabSelection.service(item.id))
        }
        .onMove { source, destination in
            viewModel.moveServices(fromOffsets: source, toOffset: destination)
        }
    }

    // MARK: Private

    @EnvironmentObject private var viewModel: ServiceTabViewModel
}

// MARK: - ServiceItemView

private struct ServiceItemView: View {
    // MARK: Internal

    let item: ServiceListItem

    var body: some View {
        HStack(spacing: 4) {
            HStack {
                ServiceIcon(type: item.type, iconSize: 18, containerSize: 22)
                Text(verbatim: item.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            // Magnet can trigger a SwiftUI List(selection:) edge case where the
            // first click on an unselected row selects the row before Toggle sees it.
            // The Button handles clicks while Toggle only renders the switch.
            Button {
                toggleEnabled()
            } label: {
                Toggle(item.name, isOn: .constant(item.enabled))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .allowsHitTesting(false)
            }
            .buttonStyle(.borderless)
            .frame(width: 40, alignment: .center)
        }
        .listRowSeparator(.hidden)
        .listRowInsets(.init())
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: Private

    @EnvironmentObject private var viewModel: ServiceTabViewModel

    private func toggleEnabled() {
        viewModel.setServiceEnabled(!item.enabled, for: item)
    }
}

// MARK: - ServiceIcon

private struct ServiceIcon: View {
    let type: ServiceType
    let iconSize: CGFloat
    let containerSize: CGFloat

    var body: some View {
        Image(type.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: iconSize, height: iconSize)
            .frame(width: containerSize, height: containerSize)
    }
}

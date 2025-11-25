//
//  ShareSheetView.swift
//  StashShare
//
//  UI mirrored from the main app's ShareView for visual parity.
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct ShareSheetView: View {
    @StateObject private var viewModel: ShareSheetViewModel
    
    private struct InputBarHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }
    
    init(attachments: [ShareAttachmentItem], onFinished: (() -> Void)?) {
        _viewModel = StateObject(wrappedValue: ShareSheetViewModel(attachments: attachments, onFinished: onFinished))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch viewModel.selectedTab {
                case .contacts:
                    if !viewModel.contactsFavorites.isEmpty {
                        ForEach(viewModel.contactsFavorites) { client in
                            ShareRowExt(
                                client: client,
                                mode: .contacts,
                                isSelected: viewModel.selectedIds.contains(client.id),
                                onToggleSelect: { viewModel.send(.toggleSelect(client.id)) }
                            )
                        }
                    }
                    ForEach(viewModel.contactsCompanyKeys, id: \.self) { key in
                        Text(key).font(.body1).foregroundColor(Color("GrayLabel"))
                            .padding(.top, 8)
                        ForEach(viewModel.contactsGrouped[key] ?? []) { client in
                            ShareRowExt(
                                client: client,
                                mode: .contacts,
                                isSelected: viewModel.selectedIds.contains(client.id),
                                onToggleSelect: { viewModel.send(.toggleSelect(client.id)) }
                            )
                        }
                    }
                case .recents:
                    ForEach(viewModel.recentsPinned) { client in
                        ShareRowExt(
                            client: client,
                            mode: .recents,
                            isSelected: viewModel.selectedIds.contains(client.id),
                            onToggleSelect: { viewModel.send(.toggleSelect(client.id)) }
                        )
                    }
                    ForEach(viewModel.recentsUnpinned) { client in
                        ShareRowExt(
                            client: client,
                            mode: .recents,
                            isSelected: viewModel.selectedIds.contains(client.id),
                            onToggleSelect: { viewModel.send(.toggleSelect(client.id)) }
                        )
                    }
                }
            }
        }
        .background(ShareTheme.background)
        .padding(.horizontal, 16)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        // Tap-to-dismiss keyboard removed for app extension compatibility
        .overlay(alignment: .bottom) {
            VStack(spacing: 6) {
                let visualItems: [ShareAttachmentItem] = viewModel.attachments.filter { item in
                    switch item.kind { case .image, .video: return true; default: return false }
                }
                if !visualItems.isEmpty {
                    AttachBarExt(
                        items: visualItems,
                        onRemove: { viewModel.send(.removeAttachment($0)) }
                    )
                }
            }
            .padding(.bottom, viewModel.inputBarHeight + 8)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                ShareTopBarExt(
                    title: "공유 노트 선택",
                    selectedCount: viewModel.selectedIds.count,
                    onClose: { viewModel.send(.close) },
                    onSearch: { viewModel.send(.search) }
                )
                .padding(.top, 16)
                .background(ShareTheme.background)
                
                if viewModel.isSearching {
                    ShareSearchBarExt(
                        text: $viewModel.searchText,
                        onClose: { viewModel.send(.search) }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .background(ShareTheme.background)
                }
                
                Group {
                    if !viewModel.selectedIds.isEmpty {
                        SelectedClientsBarExt(
                            clients: viewModel.selectedClientsSorted,
                            onToggleSelect: { viewModel.send(.toggleSelect($0)) }
                        )
                        .padding(.vertical, 8)
                        .background(ShareTheme.background)
                        .padding(.horizontal, 16)
                    } else {
                        ShareTabPickerExt(
                            selectedTab: viewModel.selectedTab,
                            onSelect: { tab in
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    viewModel.send(.setTab(tab))
                                }
                            }
                        )
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ShareInputBarExt(
                text: $viewModel.inputText,
                isEnabled: !viewModel.selectedIds.isEmpty,
                onSend: { viewModel.send(.send) }
            )
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: InputBarHeightKey.self, value: proxy.size.height)
                }
            )
        }
        .onPreferenceChange(InputBarHeightKey.self) { viewModel.send(.setInputBarHeight($0)) }
        .onAppear { viewModel.send(.onAppear) }
    }
    
}
 

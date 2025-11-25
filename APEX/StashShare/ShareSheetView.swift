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
                        Text(key).font(.body1).foregroundColor(.primary)
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
                    title: "노트에 공유",
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
                        selectedClientsBar
                            .padding(.vertical, 8)
                            .background(ShareTheme.background)
                            .padding(.horizontal, 16)
                    } else {
                        tabPicker
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
    
    private var selectedClientsBar: some View {
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.selectedClientsSorted) { client in
                    chip(for: client)
                }
            }
        }
    }
    
    private func chip(for client: PClient) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                let initials = Profile.makeInitials(name: client.name, surname: client.surname)
                let image = client.profileImageData.flatMap { UIImage(data: $0) }
                Profile(
                    image: image,
                    initials: initials,
                    size: .extraSmall,
                    fontSize: 30.72,
                    backgroundColor: ShareTheme.primaryContainer,
                    textColor: .white,
                    fontWeight: .semibold
                )
                Button { viewModel.send(.toggleSelect(client.id)) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)
            }
            
            Text("\(client.name) \(client.surname)")
                .font(.caption2)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 4)
    }
    
    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(ShareSheetViewModel.Tab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.send(.setTab(tab))
                    }
                } label: {
                    VStack(spacing: 0) {
                        Text(tab.rawValue)
                            .font(viewModel.selectedTab == tab ? .body1 : .body2)
                            .foregroundColor(viewModel.selectedTab == tab ? ShareTheme.primary : .gray)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                        Rectangle()
                            .fill(viewModel.selectedTab == tab ? ShareTheme.primary : .clear)
                            .frame(height: 4)
                            .animation(.easeInOut(duration: 0.25), value: viewModel.selectedTab)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .background(
            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(ShareTheme.primaryContainer)
                    .frame(height: 2)
            }
        )
        .animation(.easeInOut(duration: 0.25), value: viewModel.selectedTab)
        .frame(height: 40)
    }
    
}
 
struct ShareTopBarExt: View {
    let title: String
    let selectedCount: Int
    let onClose: () -> Void
    let onSearch: () -> Void
    
    init(
        title: String,
        selectedCount: Int,
        onClose: @escaping () -> Void,
        onSearch: @escaping () -> Void
    ) {
        self.title = title
        self.selectedCount = selectedCount
        self.onClose = onClose
        self.onSearch = onSearch
    }
    
    private var background: Color = Color("Background")
    private var foreground: Color = .black
    private var height: CGFloat = 52
    
    var body: some View {
        ZStack(alignment: .center) {
            HStack(spacing: 0) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    .foregroundColor(foreground)
                        .frame(width: 44, height: 44)
                        .glassEffect()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("닫기"))
                
                Spacer(minLength: 0)
                
                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                    .foregroundColor(foreground)
                        .frame(width: 44, height: 44)
                        .glassEffect()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("검색"))
            }
            .frame(height: height)
            .padding(.horizontal, 12)
            
            VStack(spacing: 0) {
                Text(title)
                    .lineLimit(1)
                    .font(.title5)
                    .foregroundColor(foreground)
                if selectedCount > 0 {
                    Text("\(selectedCount)명")
                        .lineLimit(1)
                        .font(.caption2)
                        .foregroundColor(ShareTheme.primary)
                }
            }
            .frame(height: height)
            .padding(.horizontal, 12)
            .allowsHitTesting(false)
        }
        .padding(.vertical, 8)
        .background(ShareTheme.background)
    }
}
 
struct AttachBarExt: View {
    let items: [ShareAttachmentItem]
    var onRemove: (ShareAttachmentItem) -> Void
    
    private enum Metrics {
        static let itemSize: CGFloat = 72
        static let corner: CGFloat = 3.95
        static let spacing: CGFloat = 8
        static let xSize: CGFloat = 16
        static let xTapSize: CGFloat = 28
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Metrics.spacing) {
                ForEach(items.filter { item in
                    switch item.kind {
                    case .image, .video:
                        return true
                    default:
                        return false
                    }
                }) { item in
                    itemView(item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private func itemView(_ item: ShareAttachmentItem) -> some View {
        ZStack(alignment: .topTrailing) {
            content(for: item)
                .frame(width: Metrics.itemSize, height: Metrics.itemSize)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
            
            Button {
                onRemove(item)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: Metrics.xSize, weight: .medium))
                    .foregroundColor(.gray)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: Metrics.xTapSize, height: Metrics.xTapSize, alignment: .topTrailing)
        }
        .background(Color("BackgroundSecondary"))
        .clipShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
    }
    
    @ViewBuilder
    private func content(for item: ShareAttachmentItem) -> some View {
        switch item.kind {
        case .image(let uiImage):
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        case .video(_, let thumbnail):
            ZStack {
                if let thumb = thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(Color("BackgroundSecondary"))
                }
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))
                    .shadow(radius: 2)
            }
        default:
            Color.clear
        }
    }
}
 
struct ShareInputBarExt: View {
    @Binding var text: String
    var isEnabled: Bool
    var placeholder: String = "(선택) 메모 입력"
    var onSend: () -> Void
    
    init(
        text: Binding<String>,
        isEnabled: Bool,
        placeholder: String = "(선택) 메모 입력",
        onSend: @escaping () -> Void
    ) {
        self._text = text
        self.isEnabled = isEnabled
        self.placeholder = placeholder
        self.onSend = onSend
    }
    @State private var isEditing: Bool = false
    @FocusState private var isFocused: Bool
    
    private enum Metrics {
        static let barHeight: CGFloat = 56
        static let horizontalPadding: CGFloat = 12
        static let fieldHeight: CGFloat = 40
        static let fieldRadius: CGFloat = 32
        static let sendSize: CGFloat = 48
        static let sendIcon: CGFloat = 20
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if isEditing {
                Button(
                    action: {
                        isFocused = false
                        isEditing = false
                    },
                    label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(width: 44, height: 44)
                    }
                )
                .buttonStyle(.plain)
                .accessibilityLabel(Text("지우기"))
                .glassEffect()
            }
            
            TextField(
                placeholder,
                text: $text,
                onEditingChanged: { editing in
                    isEditing = editing
                },
                onCommit: {
                    if computedIsEnabled { onSend() }
                }
            )
            .font(.body5)
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .frame(height: Metrics.fieldHeight)
            .focused($isFocused)
            .glassEffect(
                in: UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: Metrics.fieldRadius,
                    topTrailingRadius: Metrics.fieldRadius
                )
            )
            .submitLabel(.send)
            
            Button(
                action: {
                    if computedIsEnabled { onSend() }
                },
                label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: Metrics.sendIcon, weight: .medium))
                        .foregroundStyle(.white)
                }
            )
            .buttonStyle(.plain)
            .frame(width: Metrics.sendSize, height: Metrics.sendSize)
            .background(computedIsEnabled ? ShareTheme.primary : ShareTheme.backgroundSecondary)
            .clipShape(Circle())
            .disabled(!computedIsEnabled)
            .accessibilityLabel(Text("전송"))
            .glassEffect()
        }
        .padding(.horizontal, Metrics.horizontalPadding)
        .frame(height: Metrics.barHeight)
    }
    
    private var computedIsEnabled: Bool { isEnabled }
}

// MARK: - Search Bar (for ShareSheetView)
struct ShareSearchBarExt: View {
    @Binding var text: String
    var onClose: () -> Void
    @FocusState private var isFocused: Bool
    
    init(text: Binding<String>, onClose: @escaping () -> Void) {
        self._text = text
        self.onClose = onClose
    }
    
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                TextField("검색", text: $text)
                    .font(.body5)
                    .foregroundColor(.primary)
                    .focused($isFocused)
                    .submitLabel(.search)
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(ShareTheme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            Button("취소") {
                onClose()
            }
            .font(.callout)
            .foregroundColor(ShareTheme.primary)
            .buttonStyle(.plain)
        }
        .onAppear { isFocused = true }
    }
}

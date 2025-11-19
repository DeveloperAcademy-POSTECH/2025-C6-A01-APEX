//
//  ShareView.swift
//  APEX
//
//  Created by 조운경 on 10/28/25.
//

import SwiftUI
import AVFoundation

struct ShareView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = ClientsStore.shared
    @StateObject private var viewModel: ShareViewModel

    init(
        initialAttachments: [ShareAttachmentItem] = [],
        excludedClientIds: [UUID] = []
    ) {
        _viewModel = StateObject(wrappedValue: ShareViewModel(
            initialAttachments: initialAttachments,
            excludedClientIds: excludedClientIds
        ))
    }

    @State private var inputBarHeight: CGFloat = 0
    @State private var attachBarHeight: CGFloat = 0

    private struct InputBarHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }
    private struct AttachBarHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch viewModel.selectedTab {
                case .connects:
                    // Favorites first
                    if !viewModel.connectsFavorites.isEmpty {
                        ForEach(viewModel.connectsFavorites) { client in
                            ShareRow(
                                client: client,
                                mode: .contacts,
                                isSelected: viewModel.selectedIds.contains(client.id),
                                onToggleSelect: { viewModel.send(.toggleSelect(client.id)) }
                            )
                            .listRowSeparator(.hidden)
                        }
                    }

                    // All grouped by company
                    ForEach(viewModel.connectsCompanyKeys, id: \.self) { key in
                        Text(key).font(.body1).foregroundColor(.primary)
                            .padding(.top, 8)
                        ForEach(viewModel.connectsGrouped[key] ?? []) { client in
                            ShareRow(
                                client: client,
                                mode: .contacts,
                                isSelected: viewModel.selectedIds.contains(client.id),
                                onToggleSelect: { viewModel.send(.toggleSelect(client.id)) }
                            )
                            .listRowSeparator(.hidden)
                        }
                    }

                case .recents:
                    ForEach(viewModel.recentsPinned) { client in
                        ShareRow(
                            client: client,
                            mode: .recents,
                            isSelected: viewModel.selectedIds.contains(client.id),
                            onToggleSelect: { viewModel.send(.toggleSelect(client.id)) }
                        )
                        .listRowSeparator(.hidden)
                    }
                    ForEach(viewModel.recentsUnpinned) { client in
                        ShareRow(
                            client: client,
                            mode: .recents,
                            isSelected: viewModel.selectedIds.contains(client.id),
                            onToggleSelect: { viewModel.send(.toggleSelect(client.id)) }
                        )
                        .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .background(Color("Background"))
        .padding(.horizontal, 16)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.apexDismissKeyboard()
            }
        )
        .overlay(alignment: .bottom) {
            VStack(spacing: 6) {
                // Image/Video attachments bar (only when there is visual media)
                let visualItems: [ShareAttachmentItem] = viewModel.attachments.filter { item in
                    switch item.kind { case .image, .video: return true; default: return false }
                }
                if !visualItems.isEmpty {
                    AttachBar(
                        items: visualItems,
                        onRemove: { viewModel.send(.removeAttachment($0)) }
                    )
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: AttachBarHeightKey.self, value: proxy.size.height)
                        }
                    )
                }
            }
            .padding(.bottom, inputBarHeight + 8)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                APEXShareTopBar(
                    title: "노트에 공유",
                    selectedCount: viewModel.selectedIds.count,
                    onClose: { dismiss() },
                    onSearch: { viewModel.send(.search) }
                )
                .padding(.top, 16)
                .background(Color("Background"))

                Group {
                    if !viewModel.selectedIds.isEmpty {
                        selectedClientsBar
                            .padding(.vertical, 8)
                            .background(Color("Background"))
                            .padding(.horizontal, 16)
                    } else {
                        tabPicker
                    }
                }
            }
        }
        .safeAreaBar(edge: .bottom) {
            let seededText = viewModel.attachments.compactMap { item -> String? in
                if case let .text(text) = item.kind { return text } else { return nil }
            }.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let hasEffectiveText = !(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && seededText.isEmpty)
            let hasEffectiveFiles = viewModel.attachments.contains { if case .file = $0.kind { return true } else { return false } }
            let hasEffectiveAudio = viewModel.attachments.contains { if case .audio = $0.kind { return true } else { return false } }
            let hasMedia = viewModel.attachments.contains { item in
                switch item.kind { case .image, .video: return true; default: return false }
            }
            ShareInputBar(
                text: $viewModel.inputText,
                isEnabled: !viewModel.selectedIds.isEmpty,
                onSend: { viewModel.send(.send) }
            )
        }
        .onPreferenceChange(InputBarHeightKey.self) { inputBarHeight = $0 }
        .onPreferenceChange(AttachBarHeightKey.self) { attachBarHeight = $0 }
        .onAppear { viewModel.send(.onAppear) }
        .onChange(of: viewModel.shouldDismiss) { shouldDismiss in
            if shouldDismiss {
                dismiss()
                viewModel.shouldDismiss = false
            }
        }
    }

    // MARK: - Payload Summary (Text / Files / Audio)

    private var hasNonVisualPayloads: Bool {
        let trimmedTyped = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let seededText = viewModel.attachments.compactMap { item -> String? in
            if case let .text(text) = item.kind { return text } else { return nil }
        }.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let filesCount = viewModel.attachments.reduce(0) { acc, item in
            if case .file = item.kind { return acc + 1 } else { return acc }
        }
        let audioCount = viewModel.attachments.reduce(0) { acc, item in
            if case .audio = item.kind { return acc + 1 } else { return acc }
        }
        return !trimmedTyped.isEmpty || !seededText.isEmpty || filesCount > 0 || audioCount > 0
    }

    private var payloadSummaryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                let typed = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                let seededText = viewModel.attachments.compactMap { item -> String? in
                    if case let .text(text) = item.kind { return text } else { return nil }
                }.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let effectiveText = typed.isEmpty ? seededText : typed
                if !effectiveText.isEmpty {
                    chip(icon: "textformat", label: "텍스트") {
                        if !typed.isEmpty {
                            viewModel.inputText = ""
                        } else {
                            viewModel.attachments.removeAll { item in if case .text = item.kind { return true } else { return false } }
                        }
                    }
                }

                let filesCount = viewModel.attachments.reduce(0) { acc, item in
                    if case .file = item.kind { return acc + 1 } else { return acc }
                }
                if filesCount > 0 {
                    chip(icon: "doc.fill", label: "파일 \(filesCount)개") {
                        viewModel.attachments.removeAll { item in if case .file = item.kind { return true } else { return false } }
                    }
                }

                let audioCount = viewModel.attachments.reduce(0) { acc, item in
                    if case .audio = item.kind { return acc + 1 } else { return acc }
                }
                if audioCount > 0 {
                    chip(icon: "waveform", label: "음성 \(audioCount)개") {
                        viewModel.attachments.removeAll { item in if case .audio = item.kind { return true } else { return false } }
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func chip(icon: String, label: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(.caption2)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color("BackgroundSecondary"))
        .clipShape(Capsule())
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(ShareViewModel.Tab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.95)) {
                        viewModel.send(.setTab(tab))
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(viewModel.selectedTab == tab ? Color("Primary") : Color("BackgroundHover"))
                        Rectangle()
                            .fill(viewModel.selectedTab == tab ? Color("Primary") : Color("BackgroundHover"))
                            .frame(height: viewModel.selectedTab == tab ? 4 : 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.white)
        .frame(height: 40)
    }

    // MARK: - Connects (favorites + grouped by company)

    // MARK: - Selected Clients Bar

    private var selectedClientsBar: some View {
        let selected: [Client] = store.clients
            .filter { viewModel.selectedIds.contains($0.id) }
            .sorted(by: { lhs, rhs in
                let lhsName = "\(lhs.name) \(lhs.surname)"
                let rhsName = "\(rhs.name) \(rhs.surname)"
                return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
            })

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(selected) { client in
                    chip(for: client)
                }
            }
        }
    }

    private func chip(for client: Client) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                let initials = Profile.makeInitials(name: client.name, surname: client.surname)
                Profile(
                    image: client.profile,
                    initials: initials,
                    size: .extraSmall,
                    fontSize: 30.72,
                    backgroundColor: Color("PrimaryContainer"),
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

            Text("\(client.name)\n\(client.surname)")
                .font(.caption2)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 4)
    }

    private func initialLetter(for name: String, surname: String) -> String {
        let givenName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let familyName = surname.trimmingCharacters(in: .whitespacesAndNewlines)
        if givenName.isEmpty && familyName.isEmpty { return "" }
        if containsHangul(givenName) || containsHangul(familyName) {
            let source = familyName.isEmpty ? givenName : familyName
            return String(source.prefix(1))
        } else {
            let first = givenName.isEmpty ? "" : String(givenName.prefix(1)).uppercased()
            let last = familyName.isEmpty ? "" : String(familyName.prefix(1)).uppercased()
            let combined = first + last
            return combined.isEmpty ? "" : String(combined.prefix(1))
        }
    }

    private func containsHangul(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            let scalarValue = scalar.value
            let isHangulSyllables = (0xAC00...0xD7A3).contains(scalarValue)
            let isHangulJamo = (0x1100...0x11FF).contains(scalarValue)
            let isHangulCompatibility = (0x3130...0x318F).contains(scalarValue)
            if isHangulSyllables || isHangulJamo || isHangulCompatibility {
                return true
            }
        }
        return false
    }
}

#Preview {
    let img = UIImage(systemName: "photo")!
    let thumb = UIImage(systemName: "film")!
    let sample: [ShareAttachmentItem] = [
        ShareAttachmentItem(id: UUID(), kind: .image(img)),
        ShareAttachmentItem(id: UUID(), kind: .video(nil, thumbnail: thumb))
    ]
    return ShareView(initialAttachments: sample)
        .background(Color("Background"))
}
#Preview("Text seed") {
    let seed: [ShareAttachmentItem] = [
        ShareAttachmentItem(id: UUID(), kind: .text("초기 텍스트 시드 테스트입니다.\n두 줄로 테스트합니다."))
    ]
    ShareView(initialAttachments: seed, excludedClientIds: [])
    .background(Color("Background"))
}


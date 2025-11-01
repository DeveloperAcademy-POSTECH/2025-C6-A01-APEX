//
//  ShareView.swift
//  APEX
//
//  Created by 조운경 on 10/28/25.
//

import SwiftUI

struct ShareView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case connects = "Connects"
        case recents = "Recents"
        var id: String { rawValue }
    }

    @State private var selectedTab: Tab = .connects
    @State private var selectedIds: Set<UUID> = []
    @State private var inputText: String = ""
    @State private var attachments: [ShareAttachmentItem]
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var store = ClientsStore.shared

    init(initialAttachments: [ShareAttachmentItem] = []) {
        _attachments = State(initialValue: initialAttachments)
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
                switch selectedTab {
                case .connects:
                    // Favorites first
                    if !connectsFavorites.isEmpty {
                        ForEach(connectsFavorites) { client in
                            ShareRow(
                                client: client,
                                mode: .contacts,
                                isSelected: selectedIds.contains(client.id),
                                onToggleSelect: { toggleSelect(client.id) }
                            )
                            .listRowSeparator(.hidden)
                        }
                    }

                    // All grouped by company
                    ForEach(connectsCompanyKeys, id: \.self) { key in
                        Text(key).font(.body1).foregroundColor(.primary)
                            .padding(.top, 8)
                        ForEach(connectsGrouped[key] ?? []) { client in
                            ShareRow(
                                client: client,
                                mode: .contacts,
                                isSelected: selectedIds.contains(client.id),
                                onToggleSelect: { toggleSelect(client.id) }
                            )
                            .listRowSeparator(.hidden)
                        }
                    }

                case .recents:
                    ForEach(recentsPinned) { client in
                        ShareRow(
                            client: client,
                            mode: .recents,
                            isSelected: selectedIds.contains(client.id),
                            onToggleSelect: { toggleSelect(client.id) }
                        )
                        .listRowSeparator(.hidden)
                    }
                    ForEach(recentsUnpinned) { client in
                        ShareRow(
                            client: client,
                            mode: .recents,
                            isSelected: selectedIds.contains(client.id),
                            onToggleSelect: { toggleSelect(client.id) }
                        )
                        .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .background(Color("Background"))
        .padding(.horizontal, 16)
        .ignoresSafeArea(.container, edges: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .overlay(alignment: .bottom) {
            if !attachments.isEmpty {
                AttachBar(
                    items: attachments,
                    onRemove: { removeAttachment($0) }
                )
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: AttachBarHeightKey.self, value: proxy.size.height)
                    }
                )
                .padding(.bottom, inputBarHeight + 8)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                APEXShareTopBar(
                    title: "노트에 공유",
                    selectedCount: selectedIds.count,
                    onClose: { dismiss() },
                    onSearch: { performSearch() }
                )
                .padding(.top, 12)
                .background(Color("Background"))

                Group {
                    if !selectedIds.isEmpty {
                        selectedClientsBar
                            .padding(.vertical, 8)
                            .background(Color("Background"))
                    } else {
                        Picker("", selection: $selectedTab) {
                            ForEach(Tab.allCases) { tab in Text(tab.rawValue).tag(tab) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .safeAreaBar(edge: .bottom) {
            ShareInputBar(
                text: $inputText,
                isEnabled: !selectedIds.isEmpty || !attachments.isEmpty,
                onSend: { handleSend() }
            )
        }
        .onPreferenceChange(InputBarHeightKey.self) { inputBarHeight = $0 }
        .onPreferenceChange(AttachBarHeightKey.self) { attachBarHeight = $0 }
    }

    // MARK: - Connects (favorites + grouped by company)

    private var connectsFavorites: [Client] {
        store.clients.filter { $0.favorite }.sorted(by: sortByName)
    }

    private var connectsGrouped: [String: [Client]] {
        let grouped = Dictionary(grouping: store.clients) { client -> String in
            let trimmed = client.company.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Ungrouped" : trimmed
        }
        // sort each group by name
        var sortedGroups: [String: [Client]] = [:]
        for (key, value) in grouped { sortedGroups[key] = value.sorted(by: sortByName) }
        return sortedGroups
    }

    private var connectsCompanyKeys: [String] {
        connectsGrouped.keys.sorted { lhs, rhs in
            if lhs == "Ungrouped" { return false }
            if rhs == "Ungrouped" { return true }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    // MARK: - Recents (pinned first, then latest note desc)

    private var recentsSorted: [Client] {
        store.clients
            .sorted { lhs, rhs in
                let lDate = latestNoteDate(of: lhs) ?? .distantPast
                let rDate = latestNoteDate(of: rhs) ?? .distantPast
                if lDate != rDate { return lDate > rDate }
                return sortByName(lhs, rhs)
            }
    }

    private var recentsPinned: [Client] { recentsSorted.filter { $0.pin } }
    private var recentsUnpinned: [Client] { recentsSorted.filter { !$0.pin } }

    private func latestNoteDate(of client: Client) -> Date? {
        client.notes.max(by: { $0.uploadedAt < $1.uploadedAt })?.uploadedAt
    }

    private func sortByName(_ lhs: Client, _ rhs: Client) -> Bool {
        let lhsName = "\(lhs.name) \(lhs.surname)"
        let rhsName = "\(rhs.name) \(rhs.surname)"
        return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
    }

    // MARK: - Selection

    private func toggleSelect(_ id: UUID) {
        if selectedIds.contains(id) { selectedIds.remove(id) } else { selectedIds.insert(id) }
    }

    private func performSearch() {

    }

    private func handleSend() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundle = makeAttachmentBundle()
        if selectedIds.isEmpty && (bundle == nil && trimmed.isEmpty) { return }

        let note = Note(
            uploadedAt: Date(),
            text: trimmed.isEmpty ? nil : trimmed,
            bundle: bundle
        )

        for id in selectedIds {
            if let idx = store.clients.firstIndex(where: { $0.id == id }) {
                var client = store.clients[idx]
                client.notes.insert(note, at: 0)
                store.update(client)
            }
        }

        inputText = ""
        attachments.removeAll()
        selectedIds.removeAll()
        dismiss()
    }

    private func makeAttachmentBundle() -> AttachmentBundle? {
        if attachments.isEmpty { return nil }
        var images: [ImageAttachment] = []
        var videos: [VideoAttachment] = []
        for (order, item) in attachments.enumerated() {
            switch item.kind {
            case .image(let uiImage):
                if let data = uiImage.jpegData(compressionQuality: 0.9) {
                    images.append(ImageAttachment(data: data, progress: nil, orderIndex: order))
                }
            case .video(let url, _):
                if let url {
                    videos.append(VideoAttachment(url: url, progress: nil, orderIndex: order))
                }
            }
        }
        if images.isEmpty && videos.isEmpty { return nil }
        return .media(images: images, videos: videos)
    }

    private func removeAttachment(_ item: ShareAttachmentItem) {
        attachments.removeAll { $0.id == item.id }
    }
    // MARK: - Selected Clients Bar

    private var selectedClientsBar: some View {
        let selected: [Client] = store.clients
            .filter { selectedIds.contains($0.id) }
            .sorted(by: sortByName)

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
                    size: .small,
                    fontSize: 30.72,
                    backgroundColor: Color("PrimaryContainer"),
                    textColor: .white,
                    fontWeight: .semibold
                )
                Button { toggleSelect(client.id) } label: {
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

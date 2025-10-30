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

    private let clients: [Client] = sampleClients

    init(initialAttachments: [ShareAttachmentItem] = []) {
        _attachments = State(initialValue: initialAttachments)
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
        .padding(.horizontal, 16)
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                APEXShareTopBar(
                    title: "노트에 공유",
                    selectedCount: selectedIds.count,
                    onClose: { dismiss() },
                    onSearch: { performSearch() }
                )

                Group {
                    if !selectedIds.isEmpty {
                        selectedClientsBar
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color("Background"))
                    } else {
                        Picker("", selection: $selectedTab) {
                            ForEach(Tab.allCases) { tab in Text(tab.rawValue).tag(tab) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if !attachments.isEmpty {
                    AttachBar(
                        items: attachments,
                        onRemove: { removeAttachment($0) }
                    )
                }

                ShareInputBar(
                    text: $inputText,
                    isEnabled: !selectedIds.isEmpty || !attachments.isEmpty,
                    onSend: { handleSend() }
                )
            }
        }
        .scrollEdgeEffectStyle(.hard, for: .all)
        .onAppear {
            if attachments.isEmpty {
                seedTempAttachments()
            }
        }
    }

    // MARK: - Connects (favorites + grouped by company)

    private var connectsFavorites: [Client] {
        clients.filter { $0.favorite }.sorted(by: sortByName)
    }

    private var connectsGrouped: [String: [Client]] {
        let grouped = Dictionary(grouping: clients) { client -> String in
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
        clients
            .filter { !$0.notes.isEmpty }
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
        // 임시: 테스트 이미지 추가 트리거
        seedTempAttachments()
    }

    private func handleSend() {
        // Clear input for now; integrate with actual share action if needed
        inputText = ""
    }

    private func removeAttachment(_ item: ShareAttachmentItem) {
        attachments.removeAll { $0.id == item.id }
    }

    private func seedTempAttachments() {
        let names = ["ProfileS", "CardS"]
        for name in names {
            if let img = UIImage(named: name) {
                attachments.append(ShareAttachmentItem(id: UUID(), kind: .image(img)))
            }
        }
    }

    // MARK: - Selected Clients Bar

    private var selectedClientsBar: some View {
        let selected: [Client] = clients
            .filter { selectedIds.contains($0.id) }
            .sorted(by: sortByName)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selected) { client in
                    chip(for: client)
                }
            }
        }
    }

    private func chip(for client: Client) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Profile(
                    image: client.profile,
                    initials: initialLetter(for: client.name, surname: client.surname),
                    size: .small,
                    fontSize: 30.72
                )

                Button { toggleSelect(client.id) } label: {
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
    ShareView()
        .background(Color("Background"))
}

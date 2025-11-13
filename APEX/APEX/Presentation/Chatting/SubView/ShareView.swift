//
//  ShareView.swift
//  APEX
//
//  Created by 조운경 on 10/28/25.
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

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
    // Seeds captured from initializer and re-applied on appear
    private let initialAttachmentsSeed: [ShareAttachmentItem]
    private let excludedIds: Set<UUID>
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var store = ClientsStore.shared

    init(
        initialAttachments: [ShareAttachmentItem] = [],
        excludedClientIds: [UUID] = []
    ) {
        _attachments = State(initialValue: initialAttachments)
        self.excludedIds = Set(excludedClientIds)
        _inputText = State(initialValue: "")
        self.initialAttachmentsSeed = initialAttachments
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
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.apexDismissKeyboard()
            }
        )
        .overlay(alignment: .bottom) {
            VStack(spacing: 6) {
                // Image/Video attachments bar (only when there is visual media)
                let visualItems: [ShareAttachmentItem] = attachments.filter { item in
                    switch item.kind { case .image, .video: return true; default: return false }
                }
                if !visualItems.isEmpty {
                    AttachBar(
                        items: visualItems,
                        onRemove: { removeAttachment($0) }
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
                    selectedCount: selectedIds.count,
                    onClose: { dismiss() },
                    onSearch: { performSearch() }
                )
                .padding(.top, 16)
                .background(Color("Background"))

                Group {
                    if !selectedIds.isEmpty {
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
            let seededText = attachments.compactMap { item -> String? in
                if case let .text(text) = item.kind { return text } else { return nil }
            }.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let hasEffectiveText = !(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && seededText.isEmpty)
            let hasEffectiveFiles = attachments.contains { if case .file = $0.kind { return true } else { return false } }
            let hasEffectiveAudio = attachments.contains { if case .audio = $0.kind { return true } else { return false } }
            let hasMedia = attachments.contains { item in
                switch item.kind { case .image, .video: return true; default: return false }
            }
            ShareInputBar(
                text: $inputText,
                isEnabled: !selectedIds.isEmpty,
                onSend: { handleSend() }
            )
        }
        .onPreferenceChange(InputBarHeightKey.self) { inputBarHeight = $0 }
        .onPreferenceChange(AttachBarHeightKey.self) { attachBarHeight = $0 }
        // Re-seed state each time the sheet appears, so prefilled data works repeatedly
        .onAppear {
            inputText = ""
            attachments = initialAttachmentsSeed
        }
    }

    // MARK: - Payload Summary (Text / Files / Audio)

    private var hasNonVisualPayloads: Bool {
        let trimmedTyped = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let seededText = attachments.compactMap { item -> String? in
            if case let .text(text) = item.kind { return text } else { return nil }
        }.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let filesCount = attachments.reduce(0) { acc, item in
            if case .file = item.kind { return acc + 1 } else { return acc }
        }
        let audioCount = attachments.reduce(0) { acc, item in
            if case .audio = item.kind { return acc + 1 } else { return acc }
        }
        return !trimmedTyped.isEmpty || !seededText.isEmpty || filesCount > 0 || audioCount > 0
    }

    private var payloadSummaryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                let typed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                let seededText = attachments.compactMap { item -> String? in
                    if case let .text(text) = item.kind { return text } else { return nil }
                }.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let effectiveText = typed.isEmpty ? seededText : typed
                if !effectiveText.isEmpty {
                    chip(icon: "textformat", label: "텍스트") {
                        if !typed.isEmpty {
                            inputText = ""
                        } else {
                            attachments.removeAll { item in if case .text = item.kind { return true } else { return false } }
                        }
                    }
                }

                let filesCount = attachments.reduce(0) { acc, item in
                    if case .file = item.kind { return acc + 1 } else { return acc }
                }
                if filesCount > 0 {
                    chip(icon: "doc.fill", label: "파일 \(filesCount)개") {
                        attachments.removeAll { item in if case .file = item.kind { return true } else { return false } }
                    }
                }

                let audioCount = attachments.reduce(0) { acc, item in
                    if case .audio = item.kind { return acc + 1 } else { return acc }
                }
                if audioCount > 0 {
                    chip(icon: "waveform", label: "음성 \(audioCount)개") {
                        attachments.removeAll { item in if case .audio = item.kind { return true } else { return false } }
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
            ForEach(Tab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.95)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedTab == tab ? Color("Primary") : Color("BackgroundHover"))
                        Rectangle()
                            .fill(selectedTab == tab ? Color("Primary") : Color("BackgroundHover"))
                            .frame(height: selectedTab == tab ? 4 : 2)
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

    private var connectsFavorites: [Client] {
        store.clients.filter { !excludedIds.contains($0.id) && $0.favorite }.sorted(by: sortByName)
    }

    private var connectsGrouped: [String: [Client]] {
        let filtered = store.clients.filter { !excludedIds.contains($0.id) }
        let grouped = Dictionary(grouping: filtered) { client -> String in
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
            .filter { !excludedIds.contains($0.id) }
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
        // Compute typed vs seeded text separately
        let typed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let seeded = attachments.compactMap { item -> String? in
            if case let .text(text) = item.kind { return text } else { return nil }
        }.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Build bundle (media/files/audio) — text handled as separate notes
        let bundle = makeAttachmentBundle()

        // Require at least one recipient and at least one payload
        if selectedIds.isEmpty { return }
        if bundle == nil && seeded.isEmpty && typed.isEmpty { return }

        // Build notes in desired visual order (top to bottom)
        var notesToSend: [Note] = []
        if let bundle {
            notesToSend.append(Note(uploadedAt: Date(), text: nil, bundle: bundle))
        }
        if !seeded.isEmpty {
            notesToSend.append(Note(uploadedAt: Date(), text: seeded, bundle: nil))
        }
        if !typed.isEmpty {
            notesToSend.append(Note(uploadedAt: Date(), text: typed, bundle: nil))
        }

        // Insert at index 0 (newest first) but maintain above order by inserting in reverse
        for id in selectedIds {
            if let idx = store.clients.firstIndex(where: { $0.id == id }) {
                var client = store.clients[idx]
                for note in notesToSend {
                    client.notes.append(note)
                }
                store.update(client)
            }
            // Also update ChatStore so already-open chats reflect the new notes immediately
            let existing = ChatStore.shared.notes(for: id)
            var updated = existing
            for note in notesToSend {
                updated.append(note)
            }
            ChatStore.shared.setNotes(updated, for: id)
        }

        inputText = ""
        attachments.removeAll()
        selectedIds.removeAll()
        dismiss()
    }

    private func makeAttachmentBundle() -> AttachmentBundle? {
        // Build images, videos, generic files, and audio in a single pass
        var images: [ImageAttachment] = []
        var videos: [VideoAttachment] = []
        var genericFiles: [URL] = []
        var audios: [URL] = []

        for (order, item) in attachments.enumerated() {
            switch item.kind {
            case .image(let uiImage):
                if let data = uiImage.jpegData(compressionQuality: 0.9) {
                    images.append(ImageAttachment(data: data, progress: nil, orderIndex: order))
                }
            case .video(let url, _):
                if let url {
                    let copied = ensureSharedCopy(of: url, directoryName: "SharedVideos", defaultExtension: "mov")
                    videos.append(VideoAttachment(url: copied, progress: nil, orderIndex: order))
                }
            case .file(let url):
                // Detect if file is image or video and map to media; otherwise keep as file
                let type = UTType(filenameExtension: url.pathExtension)
                if let t = type, t.conforms(to: .image), let data = try? Data(contentsOf: url) {
                    images.append(ImageAttachment(data: data, progress: nil, orderIndex: order))
                } else if let t = type, t.conforms(to: .movie) || (type?.conforms(to: .audiovisualContent) ?? false) {
                    let copied = ensureSharedCopy(of: url, directoryName: "SharedVideos", defaultExtension: url.pathExtension.isEmpty ? "mov" : url.pathExtension)
                    videos.append(VideoAttachment(url: copied, progress: nil, orderIndex: order))
                } else {
                    genericFiles.append(url)
                }
            case .audio(let url):
                audios.append(url)
            case .text:
                break
            }
        }

        if !images.isEmpty || !videos.isEmpty {
            return .media(images: images, videos: videos)
        }
        if !genericFiles.isEmpty {
            let files = genericFiles.map { url in
                let copied = ensureSharedCopy(of: url, directoryName: "SharedFiles", defaultExtension: "dat")
                return FileAttachment(url: copied, contentType: UTType(filenameExtension: copied.pathExtension), progress: nil)
            }
            return .files(files)
        }
        if !audios.isEmpty {
            let sharedURLs: [URL] = audios.map { ensureSharedAudioCopy(of: $0) }
            let audioAttachments: [AudioAttachment] = sharedURLs.map { url in
                AudioAttachment(url: url, duration: assetDuration(for: url))
            }
            return .audio(audioAttachments)
        }
        return nil
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

// MARK: - Audio utilities (copy to app storage + duration)
private func ensureSharedAudioCopy(of sourceURL: URL) -> URL {
    let fileManager = FileManager.default
    // Target directory under Documents/SharedAudios
    let baseDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? sourceURL.deletingLastPathComponent()
    let sharedDir = baseDir.appendingPathComponent("SharedAudios", isDirectory: true)
    if !fileManager.fileExists(atPath: sharedDir.path) {
        try? fileManager.createDirectory(at: sharedDir, withIntermediateDirectories: true)
    }
    let name = sourceURL.deletingPathExtension().lastPathComponent
    let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
    var dest = sharedDir.appendingPathComponent(name).appendingPathExtension(ext)
    var counter = 2
    while fileManager.fileExists(atPath: dest.path) {
        dest = sharedDir.appendingPathComponent("\(name) \(counter)").appendingPathExtension(ext)
        counter += 1
    }
    if sourceURL == dest { return dest }
    if fileManager.fileExists(atPath: dest.path) == false {
        try? fileManager.copyItem(at: sourceURL, to: dest)
    }
    return dest
}

private func ensureSharedCopy(of sourceURL: URL, directoryName: String, defaultExtension: String) -> URL {
    let fileManager = FileManager.default
    let baseDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? sourceURL.deletingLastPathComponent()
    let sharedDir = baseDir.appendingPathComponent(directoryName, isDirectory: true)
    if !fileManager.fileExists(atPath: sharedDir.path) {
        try? fileManager.createDirectory(at: sharedDir, withIntermediateDirectories: true)
    }
    let name = sourceURL.deletingPathExtension().lastPathComponent
    let ext = sourceURL.pathExtension.isEmpty ? defaultExtension : sourceURL.pathExtension
    var dest = sharedDir.appendingPathComponent(name).appendingPathExtension(ext)
    var counter = 2
    while fileManager.fileExists(atPath: dest.path) {
        dest = sharedDir.appendingPathComponent("\(name) \(counter)").appendingPathExtension(ext)
        counter += 1
    }
    if sourceURL != dest, !fileManager.fileExists(atPath: dest.path) {
        try? fileManager.copyItem(at: sourceURL, to: dest)
    }
    return dest
}

private func assetDuration(for url: URL) -> TimeInterval? {
    let asset = AVAsset(url: url)
    let seconds = asset.duration.seconds
    return seconds.isFinite && seconds > 0 ? seconds : nil
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


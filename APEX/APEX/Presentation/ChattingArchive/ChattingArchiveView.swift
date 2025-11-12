//
//  ChattingDetailView.swift
//  APEX
//
//  Created by 조운경 on 10/30/25.
//

import SwiftUI
import UIKit
import AVFoundation
import LinkPresentation
import UniformTypeIdentifiers
import Combine

// Flattened media item for preview rendering
struct FlattenedMediaItem: Identifiable, Equatable {
    // Stable id composed from note id + type + local index to reduce view churn
    let id: String
    let isVideo: Bool
    let imageData: Data?
    let videoURL: URL?
    let uploadedAt: Date
    let localOrder: Int
}

// swiftlint:disable type_body_length
struct ChattingArchiveView: View {
    // In real usage, pass the actual conversation/client data
    var client: Client? = sampleClients.first
    // Callback to allow parent to control navigation after destructive actions (e.g., pop parent too)
    var onDeletedContact: (() -> Void)? = nil
    @EnvironmentObject private var router: NavigationRouter

    @State private var isMuted: Bool = false
    @State private var isFavorite: Bool = false
    @State private var mediaItems: [FlattenedMediaItem] = []
    // Additional flattened previews
    @State private var fileItems: [FlattenedFileItem] = []
    @State private var audioItems: [FlattenedAudioItem] = []
    @State private var linkItems: [FlattenedLinkItem] = []
    @Environment(\.dismiss) private var dismiss
    // Archive navigation handled by NavigationRouter
    // Record viewer
    private struct DetailRecordPayload: Identifiable { let id = UUID(); let url: URL }
    @State private var recordPayload: DetailRecordPayload?
    // Bottom actions
    @State private var showDeleteMediaAlert: Bool = false
    @State private var showDeleteContactOverlay: Bool = false
    @State private var isDeleteConfirmChecked: Bool = false
    @State private var totalMediaBytes: Int64 = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection

                sharedMediaSection
                
                sharedFilesSection

                sharedLinksSection

                sharedAudioSection
                
                bottomActionsBar
            }
            .padding(.leading, 16)
            .padding(.vertical, 12)
        }
        .background(Color("Background"))
        .scrollEdgeEffectStyle(.soft, for: .top)
        .safeAreaBar(edge: .top) { topBar }
        .overlay(alignment: .center) { contactDeleteOverlay }
        .onAppear {
            isFavorite = client?.favorite ?? false
            reloadMediaPreview()
        }
        .onChange(of: isFavorite) { newValue in
            persistFavorite(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .apexChatNotesUpdated)) { notif in
            guard let changedId = notif.userInfo?["clientId"] as? UUID,
                  let currentId = client?.id,
                  changedId == currentId else { return }
            reloadMediaPreview()
        }
        // Reflect audio rename/delete from RecordView across this detail
        .onReceive(NotificationCenter.default.publisher(for: .apexAudioRenamed)) { notif in
            guard let oldURL = notif.userInfo?["oldURL"] as? URL,
                  let newURL = notif.userInfo?["newURL"] as? URL,
                  let clientId = client?.id else { return }
            var notes = ChatStore.shared.notes(for: clientId)
            var changed = false
            for idx in notes.indices {
                if case var .audio(audios) = notes[idx].bundle {
                    var updated = false
                    for audioIndex in audios.indices where audios[audioIndex].url == oldURL {
                        audios[audioIndex] = AudioAttachment(url: newURL, duration: audios[audioIndex].duration)
                        updated = true
                    }
                    if updated {
                        notes[idx].bundle = .audio(audios)
                        changed = true
                    }
                }
            }
            if changed { ChatStore.shared.setNotes(notes, for: clientId) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .apexAudioDeleted)) { notif in
            guard let url = notif.userInfo?["url"] as? URL,
                  let clientId = client?.id else { return }
            var notes = ChatStore.shared.notes(for: clientId)
            var changed = false
            for idx in notes.indices {
                if case var .audio(audios) = notes[idx].bundle {
                    let before = audios.count
                    audios.removeAll { $0.url == url }
                    if audios.count != before {
                        notes[idx].bundle = audios.isEmpty ? nil : .audio(audios)
                        changed = true
                    }
                }
            }
            if changed {
                // Remove notes that became completely empty (no text and no bundle)
                notes.removeAll { $0.text == nil && $0.bundle == nil }
                ChatStore.shared.setNotes(notes, for: clientId)
            }
        }
        .fullScreenCover(item: $recordPayload) { payload in
            RecordView(audioURL: payload.url)
        }
        // Hidden NavigationLink for archive push removed; Router handles navigation
    }

    // MARK: - Sections

    private var headerSection: some View {
        let initials = Profile.makeInitials(name: client?.name ?? "", surname: client?.surname ?? "")
        let fullName = ((client?.name ?? "") + " " + (client?.surname ?? "")).trimmingCharacters(in: .whitespaces)
        return ChatDetailHeader(
            image: client?.profile,
            initials: initials,
            name: fullName,
            company: client?.company,
            position: client?.position,
            phone: client?.phoneNumber,
            favorite: client?.favorite ?? false
        )
    }

    private var sharedMediaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "사진/동영상", iconName: "photo", iconColor: Color("Primary"), action: {
                if let id = client?.id {
                    router.push(.archiveSection(id, .media))
                }
            })
            let allItems = mediaItems
            if !allItems.isEmpty {
                let shouldShowSeeAll = allItems.count >= 9
                let previewItems = shouldShowSeeAll ? Array(allItems.prefix(8)) : allItems
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(Array(previewItems.enumerated()), id: \.element.id) { idx, item in
                            APEXMediaTile(
                                source: {
                                    if item.isVideo, let url = item.videoURL {
                                        return .video(url)
                                    } else {
                                        return .image(item.imageData ?? Data())
                                    }
                                }(),
                                showVideoIcon: true,
                                variant: .grid,
                                showsDuration: false
                            )
                            .frame(width: 121.67, height: 121.67)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(alignment: .bottomLeading) {
                                if item.isVideo, let url = item.videoURL {
                                    Text(format(durationOf: url))
                                        .font(.caption1)
                                        .foregroundStyle(.white)
                                        .padding(12)
                                }
                            }
                            .clipped()
                            .apexOpensMediaViewer(
                                items: previewItems.map { mediaItem in
                                    if mediaItem.isVideo, let url = mediaItem.videoURL {
                                        return .video(url)
                                    } else {
                                        return .image(mediaItem.imageData ?? Data())
                                    }
                                },
                                index: idx,
                                title: client.map { "\($0.name) \($0.surname)"} ?? "Shared Media",
                                uploadedAt: nil,
                                excludedClientIds: client.map { [$0.id] } ?? [],
                                onDelete: { removedIndex, _ in
                                    guard previewItems.indices.contains(removedIndex),
                                          let clientId = client?.id else { return }
                                    let target = previewItems[removedIndex]
                                    deleteFlattenedMedia(item: target, clientId: clientId)
                                    reloadMediaPreview()
                                }
                            )
                        }
                        if shouldShowSeeAll, let id = client?.id {
                            SeeAllTile(size: 121.67, title: "전체보기")
                                .onTapGesture { router.push(.archiveSection(id, .media)) }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private var sharedLinksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "링크", iconName: "link", iconColor: Color(hex: "BC0D59"), action: {
                if let id = client?.id {
                    router.push(.archiveSection(id, .links))
                }
            })
            ScrollView(.horizontal, showsIndicators: false) {
                let allItems = linkItems
                let shouldShowSeeAll = allItems.count >= 9
                let previewItems = shouldShowSeeAll ? Array(allItems.prefix(8)) : allItems
                HStack(spacing: 2) {
                    ForEach(previewItems, id: \.id) { item in
                        APEXLinkTile(url: item.url, width: 121.67)
                    }
                    if shouldShowSeeAll, let id = client?.id {
                        SeeAllTile(size: 121.67, title: "전체보기")
                            .onTapGesture { router.push(.archiveSection(id, .links)) }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var sharedFilesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "파일", iconName: "document", iconColor: Color(hex: "00B22D"), action: {
                if let id = client?.id {
                    router.push(.archiveSection(id, .files))
                }
            })
            ScrollView(.horizontal, showsIndicators: false) {
                let allItems = fileItems
                let shouldShowSeeAll = allItems.count >= 9
                let previewItems = shouldShowSeeAll ? Array(allItems.prefix(8)) : allItems
                HStack(spacing: 2) {
                    ForEach(previewItems, id: \.id) { item in
                        APEXFileTile(
                            url: item.url,
                            contentType: item.contentType,
                            highlightQuery: nil,
                            size: 121.67,
                            onTap: {
                                if FileManager.default.fileExists(atPath: item.url.path) {
                                    UIApplication.shared.open(item.url, options: [:], completionHandler: nil)
                                }
                            }
                        )
                    }
                    if shouldShowSeeAll, let id = client?.id {
                        SeeAllTile(size: 121.67, title: "전체보기")
                            .onTapGesture { router.push(.archiveSection(id, .files)) }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var sharedAudioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "음성메모", iconName: "waveform", iconColor: Color(hex: "E28822"), action: {
                if let id = client?.id {
                    router.push(.archiveSection(id, .audio))
                }
            })
            ScrollView(.horizontal, showsIndicators: false) {
                let allItems = audioItems
                let shouldShowSeeAll = allItems.count >= 9
                let previewItems = shouldShowSeeAll ? Array(allItems.prefix(8)) : allItems
                HStack(spacing: 2) {
                    ForEach(previewItems, id: \.id) { item in
                        ZStack {
                            AudioSquareTile(
                                url: item.url,
                                duration: item.duration,
                                preferredLength: 121.67,
                                titleOverride: nil,
                                highlightQuery: nil
                            )
                            .allowsHitTesting(false)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { recordPayload = DetailRecordPayload(url: item.url) }
                    }
                    if shouldShowSeeAll, let id = client?.id {
                        SeeAllTile(size: 121.67, title: "전체보기")
                            .onTapGesture { router.push(.archiveSection(id, .audio)) }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
    // MARK: - Helpers

    private var topBar: some View {
        ZStack(alignment: .center) {
            HStack(spacing: 0) {
                Button(action: { router.pop() }) {
                    Image(systemName: "chevron.left")
                        .font(.title4)
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect()

                Spacer(minLength: 0)

                Button(action: { isFavorite.toggle() }) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.title4)
                        .foregroundColor(Color("Primary"))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect()
            }
            .frame(height: 52)
            .padding(.horizontal, 12)
        }
    }

    private var bottomActionsBar: some View {
        VStack(spacing: 10) {
            VStack(spacing: 8) {
                Button(role: .destructive) {
                    showDeleteMediaAlert = true
                } label: {
                    Text("미디어 데이터 모두 삭제하기 (\(formatBytes(totalMediaBytes)))")
                        .font(.body5)
                        .foregroundColor(Color("BlackLabel"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.plain)
                .background(Color("BackgroundSecondary"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .disabled(totalMediaBytes == 0)
                .opacity(totalMediaBytes == 0 ? 0.5 : 1)

                Button(role: .destructive) {
                    showDeleteContactOverlay = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("연락처 삭제하기")
                    }
                    .font(.body5)
                    .foregroundColor(Color("Error"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                }
                .buttonStyle(.plain)
                .background(Color("ErrorContainer"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 8)
        }
        // Confirmations
        .alert("모든 미디어 데이터를 삭제할까요?", isPresented: $showDeleteMediaAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) { deleteAllMediaDataForCurrentClient() }
        } message: {
            Text("사진/영상, 파일, 음성메모 데이터를 모두 삭제합니다. 이 작업은 되돌릴 수 없습니다.")
        }
        .background(Color("Background").ignoresSafeArea())
    }

    private func sectionHeader(title: String, iconName: String, iconColor: Color, action: @escaping (() -> Void)) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
                
                Text(title)
                    .font(.body2)
                    .foregroundStyle(Color("BlackLabel"))
                
                Spacer()
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(SectionHeaderPressedStyle())
    }

    // NotesView deleteOverlay 재활용 스타일의 오버레이
    private var contactDeleteOverlay: some View {
        Group {
            if showDeleteContactOverlay {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea(.all)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showDeleteContactOverlay = false
                            isDeleteConfirmChecked = false
                        }
                    ContactDeleteConfirmCard(
                        isChecked: $isDeleteConfirmChecked,
                        onCancel: {
                            showDeleteContactOverlay = false
                            isDeleteConfirmChecked = false
                        },
                        onDelete: {
                            guard isDeleteConfirmChecked else { return }
                            deleteCurrentContact()
                            showDeleteContactOverlay = false
                        }
                    )
                    .padding(.horizontal, 42)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.opacity)
            }
        }
    }

    private struct ChatDetailHeader: View {
        let image: UIImage?
        let initials: String
        let name: String
        let company: String?
        let position: String?
        let phone: String?
        let favorite: Bool

        var body: some View {
            VStack(alignment: .center, spacing: 8) {
                Profile(
                    image: image,
                    initials: initials,
                    size: .large,
                    fontSize: 64,
                    backgroundColor: Color("PrimaryContainer"),
                    textColor: .white,
                    fontWeight: .semibold
                )

                Text(name)
                    .font(.title5)
                    .foregroundColor(Color("BlackLabel"))
                    .multilineTextAlignment(.center)

                Group {
                    if let company, let position, !company.isEmpty, !position.isEmpty {
                        Text("\(company) · \(position)")
                    } else if let company, !company.isEmpty {
                        Text(company)
                    } else if let position, !position.isEmpty {
                        Text(position)
                    }
                }
                .font(.body5)
                .foregroundColor(Color("GrayLabel"))
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private struct ActionButton: View {
        let title: String
        let systemImage: String
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color("Primary"))
                    Text(title)
                        .font(.caption2)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color("BackgroundSecondary"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
// swiftlint:enable type_body_length

// MARK: - ButtonStyles
private struct SectionHeaderPressedStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color("BackgroundSecondary") : Color.clear)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - DeleteConfirmCard (NotesView 스타일 재활용)
private struct ContactDeleteConfirmCard: View {
    @Binding var isChecked: Bool
    var onCancel: () -> Void
    var onDelete: () -> Void

    private enum Metrics {
        static let corner: CGFloat = 30
        static let padding: CGFloat = 14
        static let paddingH: CGFloat = 8
        static let titleTop: CGFloat = 10
        static let titleToBody: CGFloat = 10
        static let bodyToCheck: CGFloat = 10
        static let buttonsTop: CGFloat = 8
    }

    private let deleteActiveBackground = Color("ErrorContainer")
    private let checkboxStroke = Color("BackgroundSecondary")

    var body: some View {
        VStack(spacing: 10) {
            titleSection
            bodySection
            confirmCheckSection
            buttonsSection
        }
        .padding(Metrics.padding)
        .glassEffect(in: RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
        .allowsHitTesting(true)
    }

    // MARK: Sections
    private var titleSection: some View {
        Text("해당 연락처 노트를\n영구적으로 삭제하겠습니까?")
            .font(.body1)
            .foregroundStyle(Color("BlackLabel"))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Metrics.paddingH)
    }

    private var bodySection: some View {
        Text("연락처 내 모든 노트와 파일이 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.")
            .font(.body3)
            .foregroundColor(.black)
            .multilineTextAlignment(.center)
            .padding(.bottom, Metrics.bodyToCheck)
            .padding(.horizontal, Metrics.paddingH)
    }

    private var confirmCheckSection: some View {
        Button(action: { isChecked.toggle() }) {
            HStack(spacing: 16) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isChecked ? Color("Primary") : .gray)
                    .frame(width: 24, height: 24)
                Text("위 내용 모두 확인했습니다.")
                    .font(.body2)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 24)
        .padding(.horizontal, Metrics.paddingH)
    }

    private var buttonsSection: some View {
        HStack(spacing: 16) {
            Button(action: { onCancel() }) {
                Text("취소")
                    .font(.body3)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .background(Color("BackgroundSecondary"))
            .clipShape(Capsule())

            Button(role: .destructive, action: { onDelete() }) {
                Text("삭제")
                    .font(.body3)
                    .foregroundStyle(isChecked ? Color("Error") : Color("GrayLabel"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .background(isChecked ? deleteActiveBackground : Color("BackgroundSecondary"))
            .clipShape(Capsule())
            .disabled(!isChecked)
        }
    }
}
// MARK: - Private helpers

extension ChattingArchiveView {
    struct SeeAllTile: View {
        let size: CGFloat
        let title: String
        
        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color("BackgroundSecondary"))
                VStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color("Primary"))
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(Color("Primary"))
                }
            }
            .frame(width: size, height: size)
        }
    }
    func reloadMediaPreview() {
        guard let clientId = client?.id else {
            mediaItems = []; fileItems = []; audioItems = []; linkItems = []
            totalMediaBytes = 0
            return
        }
        var notes = ChatStore.shared.notes(for: clientId)
        if notes.isEmpty {
            // Fallback to client's persisted notes if ChatStore hasn't been seeded yet
            notes = client?.notes ?? []
        }
        mediaItems = computeMediaItems(from: notes)
        fileItems = computeFileItems(from: notes)
        audioItems = computeAudioItems(from: notes)
        linkItems = computeLinkItems(from: notes)
        totalMediaBytes = computeTotalMediaBytes(from: notes)
    }

    func computeMediaItems(from notes: [Note]) -> [FlattenedMediaItem] {
        var result: [FlattenedMediaItem] = []
        for note in notes {
            guard case let .media(images, videos)? = note.bundle else { continue }
            struct LocalEntry { let isImage: Bool; let index: Int; let order: Int }
            var merged: [LocalEntry] = []
            for imageIndex in images.indices {
                let order = images[imageIndex].orderIndex ?? imageIndex
                merged.append(LocalEntry(isImage: true, index: imageIndex, order: order))
            }
            for videoIndex in videos.indices {
                let order = videos[videoIndex].orderIndex ?? (images.count + videoIndex)
                merged.append(LocalEntry(isImage: false, index: videoIndex, order: order))
            }
            merged.sort { $0.order < $1.order }
            for entry in merged {
                if entry.isImage {
                    let data = images[entry.index].data
                    let id = "\(note.id.uuidString)-i-\(entry.index)"
                    result.append(.init(id: id, isVideo: false, imageData: data, videoURL: nil, uploadedAt: note.uploadedAt, localOrder: entry.order))
                } else {
                    let url = videos[entry.index].url
                    let id = "\(note.id.uuidString)-v-\(entry.index)"
                    result.append(.init(id: id, isVideo: true, imageData: nil, videoURL: url, uploadedAt: note.uploadedAt, localOrder: entry.order))
                }
            }
        }
        return result.sorted {
            if $0.uploadedAt != $1.uploadedAt { return $0.uploadedAt > $1.uploadedAt }
            // Within the same note bundle, later (higher) local index/order is more recent
            if $0.id.prefix(36) == $1.id.prefix(36) { return $0.localOrder > $1.localOrder }
            return $0.id > $1.id
        }
    }

    func computeFileItems(from notes: [Note]) -> [FlattenedFileItem] {
        var result: [FlattenedFileItem] = []
        for note in notes {
            if case let .files(fileSet)? = note.bundle {
                for (index, fileAttachment) in fileSet.enumerated() {
                    result.append(.init(id: "\(note.id.uuidString)-f-\(index)", url: fileAttachment.url, contentType: fileAttachment.contentType, uploadedAt: note.uploadedAt, localIndex: index))
                }
            }
        }
        return result.sorted {
            if $0.uploadedAt != $1.uploadedAt { return $0.uploadedAt > $1.uploadedAt }
            if $0.id.prefix(36) == $1.id.prefix(36) { return $0.localIndex < $1.localIndex }
            return $0.id > $1.id
        }
    }

    func computeAudioItems(from notes: [Note]) -> [FlattenedAudioItem] {
        var result: [FlattenedAudioItem] = []
        for note in notes {
            if case let .audio(audioSet)? = note.bundle {
                for (index, audioAttachment) in audioSet.enumerated() {
                    result.append(.init(id: "\(note.id.uuidString)-a-\(index)", url: audioAttachment.url, duration: audioAttachment.duration, uploadedAt: note.uploadedAt, localIndex: index))
                }
            }
        }
        return result.sorted {
            if $0.uploadedAt != $1.uploadedAt { return $0.uploadedAt > $1.uploadedAt }
            if $0.id.prefix(36) == $1.id.prefix(36) { return $0.localIndex < $1.localIndex }
            return $0.id > $1.id
        }
    }

    func computeLinkItems(from notes: [Note]) -> [FlattenedLinkItem] {
        var all: [FlattenedLinkItem] = []
        for note in notes {
            guard let text = note.text else { continue }
            let found = urls(in: text, limit: Int.max)
            for foundURL in found {
                all.append(.init(id: "\(note.id.uuidString)-l-\(foundURL.absoluteString)", url: foundURL, uploadedAt: note.uploadedAt))
            }
        }
        let sorted = all.sorted { $0.uploadedAt == $1.uploadedAt ? $0.id > $1.id : $0.uploadedAt > $1.uploadedAt }
        var seen = Set<String>()
        var dedup: [FlattenedLinkItem] = []
        for item in sorted where seen.insert(item.url.absoluteString).inserted {
            dedup.append(item)
        }
        return dedup
    }

    func computeTotalMediaBytes(from notes: [Note]) -> Int64 {
        var total: Int64 = 0
        for note in notes {
            guard let bundle = note.bundle else { continue }
            switch bundle {
            case .media(let images, let videos):
                for imageAttachment in images { total += Int64(imageAttachment.data.count) }
                for videoAttachment in videos { total += fileSize(at: videoAttachment.url) }
            case .files(let files):
                for fileAttachment in files { total += fileSize(at: fileAttachment.url) }
            case .audio(let audios):
                for audioAttachment in audios { total += fileSize(at: audioAttachment.url) }
            }
        }
        return max(0, total)
    }

    func fileSize(at url: URL) -> Int64 {
        // Prefer resource values
        if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
            return Int64(size)
        }
        // Fallback to attributes
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? NSNumber {
            return size.int64Value
        }
        return 0
    }

    func formatBytes(_ bytes: Int64) -> String {
        let kb: Double = 1024
        let mb = kb * 1024
        let gb = mb * 1024
        let value = Double(bytes)
        if value >= gb {
            return String(format: "%.2f GB", value / gb)
        } else if value >= mb {
            return String(format: "%.1f MB", value / mb)
        } else if value >= kb {
            return String(format: "%.0f KB", value / kb)
        } else {
            return "\(bytes) B"
        }
    }

    func deleteAllMediaDataForCurrentClient() {
        guard let clientId = client?.id else { return }
        var notes = ChatStore.shared.notes(for: clientId)
        var changed = false
        for idx in notes.indices {
            guard let bundle = notes[idx].bundle else { continue }
            switch bundle {
            case .media(let images, let videos):
                // Nothing on disk for images; remove video files if reachable
                for videoAttachment in videos { deleteFileIfExists(at: videoAttachment.url) }
                notes[idx].bundle = nil
                changed = true
            case .files(let files):
                for fileAttachment in files { deleteFileIfExists(at: fileAttachment.url) }
                notes[idx].bundle = nil
                changed = true
            case .audio(let audios):
                for audioAttachment in audios { deleteFileIfExists(at: audioAttachment.url) }
                notes[idx].bundle = nil
                changed = true
            }
        }
        if changed {
            // Drop notes that now have no text and no bundle
            notes.removeAll { $0.text == nil && $0.bundle == nil }
            ChatStore.shared.setNotes(notes, for: clientId)
            reloadMediaPreview()
        }
    }

    func deleteFileIfExists(at url: URL) {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            try? fm.removeItem(at: url)
        }
    }

    func deleteCurrentContact() {
        guard let id = client?.id else { return }
        // Remove from clients store
        ClientsStore.shared.remove(id)
        // Clear chat notes
        ChatStore.shared.setNotes([], for: id)
        // Let parent decide whether to pop further; this view does not pop itself here
        DispatchQueue.main.async { onDeletedContact?() }
    }
    
    private func persistFavorite(_ newValue: Bool) {
        guard let base = client else { return }
        let updated = Client(
            id: base.id,
            profile: base.profile,
            nameCardFront: base.nameCardFront,
            nameCardBack: base.nameCardBack,
            surname: base.surname,
            name: base.name,
            position: base.position,
            company: base.company,
            email: base.email,
            phoneNumber: base.phoneNumber,
            linkedinURL: base.linkedinURL,
            memo: base.memo,
            action: base.action,
            favorite: newValue,
            pin: base.pin,
            notes: base.notes
        )
        ClientsStore.shared.update(updated)
    }
}

// MARK: - Media cell (moved to common: APEXMediaTile)

 // MARK: - Full media viewer removed; handled by common APEXMediaViewerWrapper

// MARK: - Flattened non-media models

struct FlattenedFileItem: Identifiable, Equatable {
    let id: String
    let url: URL
    let contentType: UTType?
    let uploadedAt: Date
    let localIndex: Int
}

struct FlattenedAudioItem: Identifiable, Equatable {
    let id: String
    let url: URL
    let duration: TimeInterval?
    let uploadedAt: Date
    let localIndex: Int
}

struct FlattenedLinkItem: Identifiable, Equatable {
    let id: String
    let url: URL
    let uploadedAt: Date
}

// MARK: - File tile (row item styled like chat grid tile but used horizontally)

// Removed local FileTile + helpers; replaced with common APEXFileTile

// MARK: - Link preview
// Uses shared LinkPreviewCard from Presentation/Common/LinkPreviewSupport.swift

// MARK: - Link detection helpers (copied from chat view)

private func urls(in text: String, limit: Int = 3) -> [URL] {
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    let textAsNSString = text as NSString
    let fullRange = NSRange(location: 0, length: textAsNSString.length)
    let matches = detector?.matches(in: text, options: [], range: fullRange) ?? []
    var seen = Set<String>()
    var extractedURLs: [URL] = []
    for match in matches {
        guard let range = Range(match.range, in: text) else { continue }
        let substring = String(text[range])
        let baseURL = match.url ?? normalizedURL(from: substring)
        guard let unwrapped = baseURL else { continue }
        let finalURL = normalizeURL(unwrapped)
        if seen.insert(finalURL.absoluteString).inserted {
            extractedURLs.append(finalURL)
            if extractedURLs.count >= limit { break }
        }
    }
    return extractedURLs
}

private func normalizedURL(from raw: String) -> URL? {
    var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let lowercased = value.lowercased()
    if !(lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://")) {
        value = "https://" + value
    }
    return URL(string: value)
}

// normalizeURL is provided by LinkPreviewSupport.swift

// MARK: - Video duration helper
private func format(durationOf url: URL) -> String {
    let asset = AVAsset(url: url)
    let seconds = Int(CMTimeGetSeconds(asset.duration).rounded())
    let minutes = seconds / 60
    let remainingSeconds = seconds % 60
    return String(format: "%02d:%02d", minutes, remainingSeconds)
}

// MARK: - Media deletion helper
private func deleteFlattenedMedia(item: FlattenedMediaItem, clientId: UUID) {
    guard let parsed = parseFlattenedMediaId(item.id) else { return }
    var notes = ChatStore.shared.notes(for: clientId)
    guard let noteIndex = notes.firstIndex(where: { $0.id == parsed.noteId }) else { return }
    guard case var .media(images, videos) = notes[noteIndex].bundle else { return }
    if parsed.isImage {
        guard images.indices.contains(parsed.localIndex) else { return }
        images.remove(at: parsed.localIndex)
    } else {
        guard videos.indices.contains(parsed.localIndex) else { return }
        videos.remove(at: parsed.localIndex)
    }
    // Recompute contiguous order indices
    struct Combined { let isImage: Bool; let idx: Int; let order: Int }
    var merged: [Combined] = []
    for imageIndex in images.indices {
        let order = images[imageIndex].orderIndex ?? imageIndex
        merged.append(Combined(isImage: true, idx: imageIndex, order: order))
    }
    for videoIndex in videos.indices {
        let order = videos[videoIndex].orderIndex ?? (images.count + videoIndex)
        merged.append(Combined(isImage: false, idx: videoIndex, order: order))
    }
    merged.sort { $0.order < $1.order }
    for (newOrder, entry) in merged.enumerated() {
        if entry.isImage { images[entry.idx].orderIndex = newOrder } else { videos[entry.idx].orderIndex = newOrder }
    }
    if images.isEmpty && videos.isEmpty {
        if notes[noteIndex].text == nil {
            notes.remove(at: noteIndex)
        } else {
            notes[noteIndex].bundle = nil
        }
    } else {
        notes[noteIndex].bundle = .media(images: images, videos: videos)
    }
    ChatStore.shared.setNotes(notes, for: clientId)
}

private func parseFlattenedMediaId(_ id: String) -> (noteId: UUID, isImage: Bool, localIndex: Int)? {
    if let range = id.range(of: "-i-", options: .backwards) {
        let uuidPart = String(id[..<range.lowerBound])
        let indexPart = String(id[range.upperBound...])
        guard let noteId = UUID(uuidString: uuidPart), let localIndex = Int(indexPart) else { return nil }
        return (noteId, true, localIndex)
    } else if let range = id.range(of: "-v-", options: .backwards) {
        let uuidPart = String(id[..<range.lowerBound])
        let indexPart = String(id[range.upperBound...])
        guard let noteId = UUID(uuidString: uuidPart), let localIndex = Int(indexPart) else { return nil }
        return (noteId, false, localIndex)
    } else {
        return nil
    }
}

#Preview {
    ChattingArchiveView()
}

#Preview("전체보기 타일") {
    ChattingArchiveView.SeeAllTile(size: 121.67, title: "전체보기")
        .padding()
        .background(Color("Background"))
}

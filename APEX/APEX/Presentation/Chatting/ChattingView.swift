//
//  ChattingView.swift
//  APEX
//
//  Created by 조운경 on 10/8/25.
//

import SwiftUI
import AVFoundation
import LinkPresentation
import Combine
import UniformTypeIdentifiers
import UIKit

struct ChattingView: View {
    @Environment(\.dismiss) private var dismiss
    let chatTitle: String
    init(chatTitle: String = "채팅") { self.chatTitle = chatTitle }
    @State private var notes: [Note] = []
    // Custom bottom sheet state
    fileprivate enum BottomSheetMode { case hidden, collapsed, expanded }
    @State private var sheetMode: BottomSheetMode = .hidden
    @State private var stagedAttachments: [ShareAttachmentItem] = []
    @State private var bottomBarOffsetY: CGFloat = 0
    @State private var timestampRevealProgress: CGFloat = 0   // 0.0 ~ 1.0
    @State private var visibleDateForIndicator: Date?
    @State private var isShowingDateIndicator: Bool = false
    @State private var hideIndicatorWork: DispatchWorkItem?
    @State private var didReceiveInitialPositions: Bool = false
    @State private var indicatorOffsetY: CGFloat = 0
    @State private var canScroll: Bool = false
    @State private var isAtScrollEdge: Bool = false
    @State private var chipHeight: CGFloat = 0
    @State private var showScrollToBottom: Bool = false
    @State private var keyboardScrollWork: DispatchWorkItem?
    @State private var bottomInsetHeight: CGFloat = 0
    @State private var isEditorCurrentlyFocused: Bool = false
    @State private var showCopyToast: Bool = false
    private struct EditingPayload: Identifiable { let id = UUID(); let noteId: UUID; var text: String }
    @State private var editing: EditingPayload?
    private struct SelectCopyPayload: Identifiable { let id = UUID(); let text: String }
    @State private var selectCopy: SelectCopyPayload?
    @State private var showShareFromEdit: Bool = false

    private enum Metrics {
        static let timeWidth: CGFloat = 72
        static let timeGap: CGFloat = 12
    }
    private let bottomSentinelId: String = "chat-bottom-sentinel"
    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .trailing, spacing: 6) {
                    // Top sentinel to measure content's top Y
                    Color.clear
                        .frame(height: 1) // ensure geometry updates while scrolling
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: ScrollMetricsKey.self,
                                    value: ScrollMetrics(topY: geo.frame(in: .named("chatScroll")).minY, bottomY: nil, viewportHeight: nil)
                                )
                            }
                        )
                    ForEach(Array(notes.enumerated()), id: \.element.id) { idx, note in
                        if idx == 0 || !Calendar.current.isDate(note.uploadedAt, inSameDayAs: notes[idx - 1].uploadedAt) {
                            dateHeaderView(note.uploadedAt)
                        }
                        ZStack(alignment: .trailing) {
                            Text(note.uploadedAt.formattedChatTime)
                                .font(.caption2)
                                .foregroundStyle(Color.secondary)
                                .frame(width: Metrics.timeWidth, alignment: .trailing)
                                .lineLimit(1)
                                .opacity(Double(timestampRevealProgress))
                                .offset(x: (1 - timestampRevealProgress) * 8)

                            ChatMessageView(
                                note: note,
                                chatTitle: chatTitle,
                                buildViewerPayload: { anchor in
                                    buildGlobalViewerPayload(startingFrom: anchor)
                                },
                                onDelete: { anchor in
                                    deleteMedia(anchor: anchor)
                                },
                                onDeleteAudio: { noteId, url in
                                    deleteAudio(noteId: noteId, url: url)
                                },
                                onCopyText: { text in
                                    UIPasteboard.general.string = text
                                    withAnimation { showCopyToast = true }
                                },
                                onStartEdit: { noteId, currentText in
                                    editing = EditingPayload(noteId: noteId, text: currentText)
                                },
                                onDeleteNote: { noteId in
                                    if let idx = notes.firstIndex(where: { $0.id == noteId }) {
                                        notes.remove(at: idx)
                                    }
                                },
                                onStartSelectCopy: { text in
                                    selectCopy = SelectCopyPayload(text: text)
                                }
                            )
                            .offset(x: -timestampRevealProgress * (Metrics.timeWidth + Metrics.timeGap))
                        }
                        .id(note.id)
                    }
                    Color.clear
                        .id(bottomSentinelId)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: ScrollMetricsKey.self,
                                    value: ScrollMetrics(topY: nil, bottomY: geo.frame(in: .named("chatScroll")).maxY, viewportHeight: nil)
                                )
                            }
                        )
                }
            }
            .textSelection(.enabled)
            .padding(.bottom, bottomInsetHeight + max(0, -bottomBarOffsetY))
            .coordinateSpace(name: "chatScroll")
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.visible)
            .ignoresSafeArea(.keyboard) // Prevent double lift: we manually pad for the input bar
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollMetricsKey.self,
                        value: ScrollMetrics(topY: nil, bottomY: nil, viewportHeight: geo.size.height)
                    )
                }
            )
            .onTapGesture { dismissKeyboard() }
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(bottomSentinelId, anchor: .bottom)
                }
            }
            .onChange(of: notes.count) { _ in
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(bottomSentinelId, anchor: .bottom)
                    }
                    // 확실히 맨 아래로 이동했을 때 버튼 숨김 (metrics 업데이트 전 선반영)
                    self.showScrollToBottom = false
                }
            }
            .onChange(of: bottomBarOffsetY) { _ in
                // 사용자가 위로 올려본 상태면(auto-scroll off) 건드리지 않음
                guard !showScrollToBottom else { return }
                // 키보드/레이아웃 반영 직후에 센티널로 스크롤
                keyboardScrollWork?.cancel()
                let work = DispatchWorkItem {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(bottomSentinelId, anchor: .bottom)
                    }
                }
                keyboardScrollWork = work
                // 레이아웃 적용 직후 실행하여 위치 튐 방지
                DispatchQueue.main.async(execute: work)
            }
            .onChange(of: bottomInsetHeight) { _ in
                guard !showScrollToBottom else { return }
                keyboardScrollWork?.cancel()
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(bottomSentinelId, anchor: .bottom)
                    }
                    self.showScrollToBottom = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .apexInputFocused)) { _ in
                keyboardScrollWork?.cancel()
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(bottomSentinelId, anchor: .bottom)
                }
                self.isEditorCurrentlyFocused = true
                self.showScrollToBottom = false

                let work = DispatchWorkItem {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(bottomSentinelId, anchor: .bottom)
                    }
                }
                keyboardScrollWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: work)
            }
            .onReceive(NotificationCenter.default.publisher(for: .apexInputBlurred)) { _ in
                self.isEditorCurrentlyFocused = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .apexNavigateToNote)) { notif in
                if let noteId = notif.userInfo?["noteId"] as? UUID {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(noteId, anchor: .center)
                    }
                    self.showScrollToBottom = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .apexAudioRenamed)) { notif in
                guard let oldURL = notif.userInfo?["oldURL"] as? URL,
                      let newURL = notif.userInfo?["newURL"] as? URL else { return }
                // Update notes in place for audio bundles
                for idx in notes.indices {
                    if case var .audio(audios) = notes[idx].bundle {
                        var changed = false
                        for i in audios.indices {
                            if audios[i].url == oldURL {
                                audios[i] = AudioAttachment(url: newURL, duration: audios[i].duration)
                                changed = true
                            }
                        }
                        if changed {
                            notes[idx].bundle = .audio(audios)
                        }
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if showScrollToBottom, canScroll {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(bottomSentinelId, anchor: .bottom)
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color("Primary"))
                            .frame(width: 48, height: 48)
                            .glassEffect()
                    }
                    .padding(.trailing, 8)
                    .padding(.bottom, 8 + bottomInsetHeight + max(0, -bottomBarOffsetY))
                    .transition(.scale.combined(with: .opacity))
                }
            }
            }

            // Right-side floating date indicator
            if canScroll, isShowingDateIndicator, let date = visibleDateForIndicator {
                Text(date.formattedScrollIndicator)
                    .font(.caption2)
                    .foregroundStyle(Color.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(.ultraThinMaterial)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Capsule())
                    .shadow(radius: 2)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: ChipHeightKey.self, value: geo.size.height)
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 4)
                    .padding(.top, indicatorOffsetY)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .trailing) {
            Color.clear
                .frame(width: 44)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            let dx = value.translation.width
                            let dy = value.translation.height
                            guard abs(dx) > abs(dy) else { return }
                            if dx < 0 {
                                let progress = min(1, max(0, -dx / 80))
                                timestampRevealProgress = progress
                            } else {
                                timestampRevealProgress = 0
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                timestampRevealProgress = 0
                            }
                        }
                )
        }
        .onPreferenceChange(DateHeaderPositionsKey.self) { positions in
            if !didReceiveInitialPositions {
                didReceiveInitialPositions = true
                return
            }
            updateScrollDateIndicator(with: positions)
        }
        .onPreferenceChange(ScrollMetricsKey.self) { metrics in
            // Compute thumb-aligned vertical offset for the indicator
            guard let topY = metrics.topY, let bottomY = metrics.bottomY, let viewport = metrics.viewportHeight else { return }
            let contentHeight = bottomY - topY
            guard contentHeight > 0 else { return }
            let newCanScroll = (contentHeight - viewport) > 1
            if canScroll != newCanScroll { canScroll = newCanScroll }
            if !newCanScroll { isShowingDateIndicator = false }

            // Offset/progress within scrollable range
            let maxOffset = max(contentHeight - viewport, 1)
            let offset = min(max(-topY, 0), maxOffset)
            let progress = min(max(offset / maxOffset, 0), 1)

            // Detect rubber-band overscroll to clamp visually at edges
            let overscrollTop = topY > 0
            let overscrollBottom = bottomY < viewport
            let verticalPadding: CGFloat = 8
            let available = max(viewport - verticalPadding * 2, 0)
            let clampedProgress: CGFloat = overscrollTop ? 0 : (overscrollBottom ? 1 : progress)
            if chipHeight > 0 {
                let desiredTop = verticalPadding + available * clampedProgress - chipHeight / 2
                let minTop = verticalPadding
                let maxTop = verticalPadding + max(available - chipHeight, 0)
                indicatorOffsetY = min(max(desiredTop, minTop), maxTop)
            } else {
                indicatorOffsetY = verticalPadding + available * clampedProgress
            }

            // Show while scrolling; auto-hide after idle
            if visibleDateForIndicator != nil {
                isShowingDateIndicator = true
                hideIndicatorWork?.cancel()
                let work = DispatchWorkItem { self.isShowingDateIndicator = false }
                hideIndicatorWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
            }

            // Update visibility for scroll-to-bottom chevron based on content length and distance from bottom
            let minContentMultiple: CGFloat = 1.5    // Only if content height > 1.5x viewport
            let minDistanceToShow: CGFloat = 200     // Show when at least 200pt above bottom

            let contentIsLong = contentHeight > viewport * minContentMultiple
            let distanceFromBottom = maxOffset - offset   // Remaining scrollable distance to bottom (pt)
            let sufficientlyAboveBottom = distanceFromBottom > minDistanceToShow
            let atBottom = overscrollBottom || distanceFromBottom <= 4

            showScrollToBottom = (canScroll && contentIsLong && sufficientlyAboveBottom && !isEditorCurrentlyFocused) && !atBottom
        }
        .onPreferenceChange(ChipHeightKey.self) { h in
            if h > 0 { chipHeight = h }
        }
        .safeAreaInset(edge: .top) {
            APEXNavigationBar(
                .memo(
                    title: chatTitle,
                    onBack: { dismiss() },
                    onSearch: { },
                    onMenu: { }
                )
            )
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if !stagedAttachments.isEmpty {
                    AttachBar(items: stagedAttachments) { removed in
                        stagedAttachments.removeAll { $0.id == removed.id }
                    }
                }

                InputBar({ note in
                    handleIncoming(note: note)
                }, onSheetVisibilityChanged: { visible in
                    // Map InputBar left button toggle to our custom sheet modes
                    if visible {
                        sheetMode = .collapsed
                    } else {
                        sheetMode = (sheetMode == .expanded) ? .collapsed : .hidden
                    }
                }, stagedAttachments: $stagedAttachments, onBarOffsetChanged: { offset in
                    bottomBarOffsetY = offset
                })
            }
            .offset(y: bottomBarOffsetY)
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.2), value: bottomBarOffsetY)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: BottomInsetHeightKey.self, value: geo.size.height)
                }
            )
        }
        // Custom overlay sheet (replaces system .sheet for media picker)
        .overlay(alignment: .bottom) {
            if sheetMode != .hidden {
                ZStack(alignment: .bottom) {
                    if sheetMode == .expanded {
                        Color.black.opacity(0.18)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture { sheetMode = .collapsed }
                            .transition(.opacity)
                    }

                    BottomSheetHost(mode: $sheetMode, onHeightChanged: { height, mode in
                    // When partially up, lift the input bar together; when fully expanded, keep input bar at bottom
                    if mode == .collapsed {
                        bottomBarOffsetY = -(height + 8)
                    } else {
                        bottomBarOffsetY = 0
                    }
                    }) {
                        ChatMediaPickerSheet(
                            isPresented: .constant(true),
                            onTapFile: {
                                NotificationCenter.default.post(name: .apexOpenDocumentPicker, object: nil)
                                sheetMode = .hidden
                            },
                            onTapCamera: {
                                CameraManager.shared.prewarmIfPossible()
                                NotificationCenter.default.post(name: .apexOpenCamera, object: nil)
                                sheetMode = .hidden
                            },
                            onOpenSystemAlbum: {
                                NotificationCenter.default.post(name: .apexOpenPhotoPicker, object: nil)
                                sheetMode = .hidden
                            },
                            onDetentChanged: { _ in },
                            onHeightChanged: { _ in },
                            onConfirmUpload: {
                                NotificationCenter.default.post(name: .apexSendSelectedAttachments, object: nil)
                                sheetMode = .hidden
                            },
                            selectedAttachmentItems: $stagedAttachments
                        )
                        .padding(.bottom, 0)
                    }
                    .zIndex(1)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onPreferenceChange(BottomInsetHeightKey.self) { height in bottomInsetHeight = height }
        .apexToast(
            isPresented: $showCopyToast,
            image: Image(systemName: "doc.on.doc.fill"),
            text: "복사되었습니다.",
            buttonTitle: nil,
            duration: 1.6
        )
        .sheet(item: $editing) { payload in
            TextEditSheet(
                initialText: payload.text,
                onCancel: { editing = nil },
                onSave: { newText in
                    if let idx = notes.firstIndex(where: { $0.id == payload.noteId }) {
                        notes[idx].text = newText
                    }
                    editing = nil
                },
                onCopyAll: {
                    UIPasteboard.general.string = payload.text
                    withAnimation { showCopyToast = true }
                },
                onShare: {
                    editing = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showShareFromEdit = true }
                },
                onDelete: {
                    if let idx = notes.firstIndex(where: { $0.id == payload.noteId }) {
                        notes.remove(at: idx)
                    }
                    editing = nil
                },
                deleteSubject: "메모를"
            )
        }
        .sheet(item: $selectCopy) { payload in
            SelectCopySheet(
                text: payload.text,
                onClose: { selectCopy = nil },
                onCopyAll: {
                    UIPasteboard.general.string = payload.text
                    withAnimation { showCopyToast = true }
                }
            )
        }
        .sheet(isPresented: $showShareFromEdit) {
            ShareView(shouldSeedIfEmpty: false)
        }
    }
}

// MARK: - Send handling & simulated uploads

private extension ChattingView {
    func deleteAudio(noteId: UUID, url: URL) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId }) else { return }
        guard case var .audio(audios) = notes[idx].bundle else { return }
        audios.removeAll { $0.url == url }
        notes[idx].bundle = audios.isEmpty ? nil : .audio(audios)
    }
    func buildGlobalViewerPayload(startingFrom anchor: ChatMessageView.ChatAnchor) -> (items: [MediaSource], anchors: [ChatMessageView.ChatAnchor], index: Int) {
        var allItems: [MediaSource] = []
        var allAnchors: [ChatMessageView.ChatAnchor] = []
        for noteItem in notes {
            if case let .media(images, videos) = noteItem.bundle {
                struct Combined { let isImage: Bool; let index: Int; let order: Int }
                var merged: [Combined] = []
                for imageIndex in images.indices {
                    let order = images[imageIndex].orderIndex ?? imageIndex
                    merged.append(Combined(isImage: true, index: imageIndex, order: order))
                }
                for videoIndex in videos.indices {
                    let order = videos[videoIndex].orderIndex ?? (images.count + videoIndex)
                    merged.append(Combined(isImage: false, index: videoIndex, order: order))
                }
                merged.sort { $0.order < $1.order }
                for entry in merged {
                    if entry.isImage {
                        allItems.append(.image(images[entry.index].data))
                        allAnchors.append(.init(noteId: noteItem.id, isImage: true, localIndex: entry.index))
                    } else {
                        allItems.append(.video(videos[entry.index].url))
                        allAnchors.append(.init(noteId: noteItem.id, isImage: false, localIndex: entry.index))
                    }
                }
            }
        }
        let start = allAnchors.firstIndex(where: { $0.noteId == anchor.noteId && $0.isImage == anchor.isImage && $0.localIndex == anchor.localIndex }) ?? 0
        return (items: allItems, anchors: allAnchors, index: start)
    }

    func handleIncoming(note: Note) {
        var noteWithProgress = note
        if case let .media(images, videos) = note.bundle {
            // Preserve orderIndex; just reset progress for simulated upload
            let imagesWithProgress = images.map {
                ImageAttachment(
                    data: $0.data,
                    progress: 0,
                    orderIndex: $0.orderIndex
                )
            }
            let videosWithProgress = videos.map { VideoAttachment(url: $0.url, progress: 0, orderIndex: $0.orderIndex) }
            noteWithProgress.bundle = .media(images: imagesWithProgress, videos: videosWithProgress)
        }
        notes.append(noteWithProgress)
        if let idx = notes.indices.last { startUploadsForNote(at: idx) }
    }

    func startUploadsForNote(at index: Int) {
        guard notes.indices.contains(index) else { return }
        let noteId = notes[index].id
        if case let .media(images, videos) = notes[index].bundle {
            for imageIndex in images.indices { simulateImageUpload(noteId: noteId, imageIndex: imageIndex) }
            for videoIndex in videos.indices { simulateVideoUpload(noteId: noteId, videoIndex: videoIndex) }
        } else if case let .files(files) = notes[index].bundle {
            for fileIndex in files.indices { simulateFileUpload(noteId: noteId, fileIndex: fileIndex) }
        }
    }

    func simulateImageUpload(noteId: UUID, imageIndex: Int) {
        Task { @MainActor in
            let steps = 20
            for step in 0...steps {
                setImageProgress(noteId: noteId, imageIndex: imageIndex, value: Double(step) / Double(steps))
                try? await Task.sleep(nanoseconds: 80_000_000) // 0.08s
            }
            setImageProgress(noteId: noteId, imageIndex: imageIndex, value: nil)
        }
    }

    func simulateVideoUpload(noteId: UUID, videoIndex: Int) {
        Task { @MainActor in
            let steps = 30
            for step in 0...steps {
                setVideoProgress(noteId: noteId, videoIndex: videoIndex, value: Double(step) / Double(steps))
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
            setVideoProgress(noteId: noteId, videoIndex: videoIndex, value: nil)
        }
    }

    func simulateFileUpload(noteId: UUID, fileIndex: Int) {
        Task { @MainActor in
            let steps = 25
            for step in 0...steps {
                setFileProgress(noteId: noteId, fileIndex: fileIndex, value: Double(step) / Double(steps))
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
            setFileProgress(noteId: noteId, fileIndex: fileIndex, value: nil)
        }
    }

    func setImageProgress(noteId: UUID, imageIndex: Int, value: Double?) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId }) else { return }
        guard case var .media(images, videos) = notes[idx].bundle, images.indices.contains(imageIndex) else { return }
        images[imageIndex].progress = value
        notes[idx].bundle = .media(images: images, videos: videos)
    }

    func setVideoProgress(noteId: UUID, videoIndex: Int, value: Double?) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId }) else { return }
        guard case var .media(images, videos) = notes[idx].bundle, videos.indices.contains(videoIndex) else { return }
        videos[videoIndex].progress = value
        notes[idx].bundle = .media(images: images, videos: videos)
    }

    func setFileProgress(noteId: UUID, fileIndex: Int, value: Double?) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId }) else { return }
        guard case var .files(files) = notes[idx].bundle, files.indices.contains(fileIndex) else { return }
        files[fileIndex].progress = value
        notes[idx].bundle = .files(files)
    }
}

private struct ChatMessageView: View {
    let note: Note
    let chatTitle: String
    struct ChatAnchor { let noteId: UUID; let isImage: Bool; let localIndex: Int }
    let buildViewerPayload: (ChatAnchor) -> (items: [MediaSource], anchors: [ChatAnchor], index: Int)
    let onDelete: (ChatAnchor) -> Void
    let onDeleteAudio: (UUID, URL) -> Void
    let onCopyText: (String) -> Void
    let onStartEdit: (UUID, String) -> Void
    let onDeleteNote: (UUID) -> Void
    let onStartSelectCopy: (String) -> Void
    private struct ViewerPayload: Identifiable {
        let id = UUID()
        let items: [MediaSource]
        let anchors: [ChatAnchor]
        let index: Int
    }
    @State private var viewer: ViewerPayload?
    @State private var showShareSheet: Bool = false
    private struct RecordPayload: Identifiable { let id = UUID(); let url: URL }
    @State private var recordPayload: RecordPayload?
    // Removed selectedRange; SelectableText now manages selection internally
    @State private var showDeleteAlert: Bool = false
    @State private var deleteSubjectText: String = ""
    @State private var pendingDelete: (() -> Void)?


    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let text = note.text {
                VStack(alignment: .trailing, spacing: 8) {
                    // ChattingView.swift (텍스트 버블 부분만)
                    SelectableText(
                        text,
                        fontSize: 14,
                        textStyle: .body,
                        lineSpacing: 4,
                        maxLayoutWidth: min(UIScreen.main.bounds.width * 0.78, 420)
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    ForEach(urls(in: text), id: \.absoluteString) { url in
                        LinkPreviewCard(url: url)
                    }
                }
                .contentShape(Rectangle())
                .contextMenu {
                    Button { onStartEdit(note.id, text) } label: {
                        Label("수정", systemImage: "pencil")
                    }
                    Button { onStartSelectCopy(text) } label: {
                        Label("선택 복사", systemImage: "text.viewfinder")
                    }
                    Button { onCopyText(text) } label: {
                        Label("전체 복사", systemImage: "doc.on.doc")
                    }
                    Button { showShareSheet = true } label: {
                        Label("공유", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        deleteSubjectText = "메모를"
                        pendingDelete = { onDeleteNote(note.id) }
                        showDeleteAlert = true
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }

            if case let .media(images, videos) = note.bundle {
                if videos.count == 1, images.isEmpty {
                    SingleVideoCard(url: videos[0].url) {
                        openViewer(anchor: ChatAnchor(noteId: note.id, isImage: false, localIndex: 0))
                    }
                } else if images.count == 1, videos.isEmpty {
                    SingleImageCard(imageData: images[0].data) {
                        openViewer(anchor: ChatAnchor(noteId: note.id, isImage: true, localIndex: 0))
                    }
                } else {
                    MediaGrid(images: images, videos: videos) { isImage, localIndex in
                        openViewer(anchor: ChatAnchor(noteId: note.id, isImage: isImage, localIndex: localIndex))
                    }
                }
            } else if case let .files(files) = note.bundle {
                FilesGrid(files: files)
            }
            // Audio attachments: always render single tile with anchored menu
            else if case let .audio(audios) = note.bundle {
                if let first = audios.first {
                    AudioSquareTile(url: first.url, duration: first.duration)
                        .contextMenu {
                            Button { recordPayload = RecordPayload(url: first.url) } label: {
                                Label("더보기", systemImage: "ellipsis.circle")
                            }
                            Button { showShareSheet = true } label: {
                                Label("공유", systemImage: "square.and.arrow.up")
                            }
                            Button(role: .destructive) {
                                deleteSubjectText = "음성 녹음을"
                                pendingDelete = { onDeleteAudio(note.id, first.url) }
                                showDeleteAlert = true
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .alert("\(deleteSubjectText) 삭제하겠습니까?", isPresented: $showDeleteAlert) {
            Button("삭제", role: .destructive) { pendingDelete?() }
            Button("취소", role: .cancel) { }
        }
        .fullScreenCover(item: $viewer) { payload in
            MediaView(
                items: payload.items,
                selectedIndex: payload.index,
                title: chatTitle,
                uploadedAt: note.uploadedAt,
                onDelete: { removedIndex, _ in
                    guard payload.anchors.indices.contains(removedIndex) else { return }
                    onDelete(payload.anchors[removedIndex])
                },
                onTitleTap: { currentIndex in
                    guard payload.anchors.indices.contains(currentIndex) else { return }
                    let anchor = payload.anchors[currentIndex]
                    NotificationCenter.default.post(
                        name: .apexNavigateToNote,
                        object: nil,
                        userInfo: ["noteId": anchor.noteId]
                    )
                }
            )
        }
        .sheet(isPresented: $showShareSheet) {
            ShareView(shouldSeedIfEmpty: false)
        }
        .fullScreenCover(item: $recordPayload) { payload in
            RecordView(audioURL: payload.url)
        }
    }

    private func openViewer(anchor: ChatAnchor) {
        let payload = buildViewerPayload(anchor)
        viewer = ViewerPayload(items: payload.items, anchors: payload.anchors, index: payload.index)
    }
}

private extension ChattingView {
    @ViewBuilder
    func dateHeaderView(_ date: Date) -> some View {
        Text(date.formattedChatDayHeader)
            .font(.caption2)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: DateHeaderPositionsKey.self,
                        value: [date: geo.frame(in: .named("chatScroll")).minY]
                    )
                }
            )
    }

    func updateScrollDateIndicator(with positions: [Date: CGFloat]) {
        guard canScroll else {
            isShowingDateIndicator = false
            return
        }
        guard !positions.isEmpty else {
            visibleDateForIndicator = nil
            isShowingDateIndicator = false
            hideIndicatorWork?.cancel(); hideIndicatorWork = nil
            return
        }

        // Choose the nearest header to the top: prioritize smallest positive Y (>= 0),
        // fallback to the largest negative (just above the top).
        let positives = positions.filter { $0.value >= 0 }
        let candidate = positives.min(by: { $0.value < $1.value }) ?? positions.max(by: { $0.value < $1.value })
        let newDate = candidate?.key

        if newDate != visibleDateForIndicator {
            visibleDateForIndicator = newDate
        }

        // Show now and schedule hide after idle
        isShowingDateIndicator = (visibleDateForIndicator != nil)
        hideIndicatorWork?.cancel()
        let work = DispatchWorkItem { self.isShowingDateIndicator = false }
        hideIndicatorWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }
    func deleteMedia(anchor: ChatMessageView.ChatAnchor) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == anchor.noteId }) else { return }
        guard case var .media(images, videos) = notes[noteIndex].bundle else { return }

        if anchor.isImage {
            guard images.indices.contains(anchor.localIndex) else { return }
            images.remove(at: anchor.localIndex)
        } else {
            guard videos.indices.contains(anchor.localIndex) else { return }
            videos.remove(at: anchor.localIndex)
        }

        // Recompute contiguous orderIndex across all remaining media (images + videos)
        struct Combined { let isImage: Bool; let idx: Int; let order: Int }
        var merged: [Combined] = []
        for i in images.indices {
            let order = images[i].orderIndex ?? i
            merged.append(Combined(isImage: true, idx: i, order: order))
        }
        for v in videos.indices {
            let order = videos[v].orderIndex ?? (images.count + v)
            merged.append(Combined(isImage: false, idx: v, order: order))
        }
        merged.sort { $0.order < $1.order }
        for (newOrder, entry) in merged.enumerated() {
            if entry.isImage { images[entry.idx].orderIndex = newOrder } else { videos[entry.idx].orderIndex = newOrder }
        }

        notes[noteIndex].bundle = .media(images: images, videos: videos)
    }
}

private func clientName(from note: Note) -> String {
    // Placeholder until Note carries author/client info. Using a hardcoded title like the nav bar.
    return "Gyeong"
}

// Single video: center play button, duration below
private struct SingleVideoCard: View {
    let url: URL
    @State private var thumb: UIImage?
    @State private var duration: String = "00:00"
    var onTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Rectangle()
                    .foregroundStyle(Color.gray.opacity(0.15))
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay {
                        if let thumb {
                            Image(uiImage: thumb)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .overlay(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(spacing: 2) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color("Background"))
                        .shadow(radius: 4)

                    Text(duration)
                        .font(.caption1)
                        .foregroundStyle(Color("Background"))
                }
            }
            .frame(width: 240)
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }
        }
        .task {
            if thumb == nil { thumb = generateThumbnail(for: url) }
            duration = format(durationOf: url)
        }
    }
}

// Single image: fixed width 240, height fits content
private struct SingleImageCard: View {
    let imageData: Data
    var onTap: (() -> Void)?

    var body: some View {
        Group {
            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?() }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 240, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?() }
            }
        }
    }
}

// Grid for mixed media; videos show duration badge bottom-left
private struct MediaGrid: View {
    let images: [ImageAttachment]
    let videos: [VideoAttachment]
    var onOpen: (_ isImage: Bool, _ localIndex: Int) -> Void

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        struct CombinedItem { let isImage: Bool; let index: Int; let order: Int }
        let merged: [CombinedItem] = {
            var combined: [CombinedItem] = []
            for (imageIndex, img) in images.enumerated() {
                let order = img.orderIndex ?? imageIndex
                combined.append(CombinedItem(isImage: true, index: imageIndex, order: order))
            }
            for (videoIndex, vid) in videos.enumerated() {
                let order = vid.orderIndex ?? (images.count + videoIndex)
                combined.append(CombinedItem(isImage: false, index: videoIndex, order: order))
            }
            return combined.sorted { $0.order < $1.order }
        }()

        // Render LTR and right-align the last row using leading placeholders (3-column grid)
        let remainder = merged.count % 3
        let paddingCount = remainder == 0 ? 0 : (3 - remainder)
        let fullCount = merged.count - remainder
        let leadingPlaceholders = Array(repeating: Optional<Int>.none, count: paddingCount)
        let fullRows = Array(0..<fullCount).map { Optional($0) }
        let lastRow = (remainder > 0 ? Array(fullCount..<merged.count).map { Optional($0) } : [])
        let displayOrder: [Int?] = fullRows + leadingPlaceholders + lastRow

        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(displayOrder.indices, id: \.self) { slotIndex in
                if let mergedIndex = displayOrder[slotIndex] {
                    let item = merged[mergedIndex]
                    if item.isImage {
                        let img = images[item.index]
                        ZStack {
                            if let uiImage = UIImage(data: img.data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 116.33, height: 124)
                                    .clipped()
                                    .cornerRadius(10)
                            } else {
                                Rectangle().fill(Color.gray.opacity(0.15))
                                    .frame(width: 121, height: 124)
                            }
                            if let progress = img.progress {
                                ProgressOverlay(progress: progress)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(Rectangle())
                        .onTapGesture { onOpen(true, item.index) }
                    } else {
                        let video = videos[item.index]
                        ZStack {
                            VideoThumbTile(url: video.url)
                            if let progress = video.progress {
                                ProgressOverlay(progress: progress)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { onOpen(false, item.index) }
                    }
                } else {
                    // Invisible placeholder to push the last row to the right
                    Color.clear
                        .frame(height: 124)
                }
            }
        }
    }
}

private struct FilesGrid: View {
    let files: [FileAttachment]

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(files.indices, id: \.self) { idx in
                FileGridTile(file: files[idx])
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

private struct FileGridTile: View {
    let file: FileAttachment

    var body: some View {
        ZStack {
            Color("BackgroundSecondary")

            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: fileSystemSymbolName(for: file.contentType, url: file.url))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black)

                Spacer()

                Text(file.url.lastPathComponent)
                    .font(.caption2)
                    .lineLimit(4)
                    .truncationMode(.middle)
                    .foregroundStyle(.black)
                    .padding(.bottom, 4)

                if let sizeText = fileSizeText(for: file.url) {
                    Text(sizeText)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
            .padding(12)

            if let progress = file.progress {
                ProgressOverlay(progress: progress)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .cornerRadius(10)
        .environment(\.layoutDirection, .leftToRight)
        .contentShape(Rectangle())
        .allowsHitTesting(file.progress == nil)
        .onTapGesture {
            guard file.progress == nil else { return }
            openFileURL(file.url)
        }
    }

    private func fileSizeText(for url: URL) -> String? {
        if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) {
            return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }
        return nil
    }
}

private func fileSystemSymbolName(for type: UTType?, url: URL?) -> String {
    var resolvedType: UTType? = type
    if resolvedType == nil, let ext = url?.pathExtension, !ext.isEmpty {
        resolvedType = UTType(filenameExtension: ext)
    }
    guard let resolved = resolvedType else { return "document" }
    if resolved.conforms(to: .image) { return "photo" }
    if resolved.conforms(to: .movie) || resolved.conforms(to: .audiovisualContent) { return "video" }
    return "document"
}

private func openFileURL(_ url: URL) {
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
}

private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

extension Notification.Name {
    static let apexInputFocused = Notification.Name("apex.inputFocused")
    static let apexInputBlurred = Notification.Name("apex.inputBlurred")
    static let apexNavigateToNote = Notification.Name("apex.navigateToNote")
    static let apexAudioRenamed = Notification.Name("apex.audioRenamed")
    static let apexOpenDocumentPicker = Notification.Name("apex.openDocumentPicker")
    static let apexOpenCamera = Notification.Name("apex.openCamera")
    static let apexOpenPhotoPicker = Notification.Name("apex.openPhotoPicker")
    static let apexSendSelectedAttachments = Notification.Name("apex.sendSelectedAttachments")
}

private struct VideoThumbTile: View {
    let url: URL
    @State private var thumb: UIImage?
    @State private var duration: String = "00:00"

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .foregroundStyle(Color.gray.opacity(0.15))
                .frame(height: 124)
                .overlay {
                    if let thumb {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .overlay(Color.black.opacity(0.4))
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(duration)
                .font(.caption1)
                .foregroundStyle(.white)
                .padding(12)
        }
        .task {
            if thumb == nil { thumb = generateThumbnail(for: url) }
            duration = format(durationOf: url)
        }
    }
}

// MARK: - Video helpers

// Translucent overlay with circular progress and percentage
private struct ProgressOverlay: View {
    let progress: Double // 0...1
    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.circular)
                    .tint(.white)
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
        }
    }
}

private func format(durationOf url: URL) -> String {
    let asset = AVAsset(url: url)
    let seconds = Int(CMTimeGetSeconds(asset.duration).rounded())
    let minutes = seconds / 60
    let remainingSeconds = seconds % 60
    return String(format: "%02d:%02d", minutes, remainingSeconds)
}

private func generateThumbnail(for url: URL) -> UIImage? {
    let asset = AVAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 1200, height: 1200)
    do {
        let cgImage = try generator.copyCGImage(at: .init(seconds: 0.1, preferredTimescale: 600), actualTime: nil)
        return UIImage(cgImage: cgImage)
    } catch {
        return nil
    }
}

// MARK: - Link detection & preview

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
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = s.lowercased()
    if !(lower.hasPrefix("http://") || lower.hasPrefix("https://")) {
        s = "https://" + s
    }
    return URL(string: s)
}

private func normalizeURL(_ url: URL) -> URL {
    if let scheme = url.scheme, !scheme.isEmpty { return url }
    return URL(string: "https://" + url.absoluteString) ?? url
}

private func attributedMessage(_ text: String) -> AttributedString {
    let mas = NSMutableAttributedString(string: text)
    let full = NSRange(location: 0, length: (text as NSString).length)

    // 강제 줄바꿈 전략: 글자 단위 + 한글 우선
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byCharWrapping
    if #available(iOS 14.0, *) {
        paragraph.lineBreakStrategy = [.hangulWordPriority, .pushOut]
    }
    mas.addAttribute(.paragraphStyle, value: paragraph, range: full)

    if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
        detector.enumerateMatches(in: text, options: [], range: full) { match, _, _ in
            guard let match, let url = match.url else { return }
            mas.addAttribute(.link, value: url, range: match.range)
            mas.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
        }
    }
    return AttributedString(mas)
}

// Minimal text edit sheet for memo editing
private struct TextEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    let onCancel: () -> Void
    let onSave: (String) -> Void
    let onCopyAll: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void
    let deleteSubject: String
    @State private var showDeleteAlert: Bool = false

    init(
        initialText: String,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) -> Void,
        onCopyAll: @escaping () -> Void,
        onShare: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        deleteSubject: String
    ) {
        _text = State(initialValue: initialText)
        self.onCancel = onCancel
        self.onSave = onSave
        self.onCopyAll = onCopyAll
        self.onShare = onShare
        self.onDelete = onDelete
        self.deleteSubject = deleteSubject
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TextEditor(text: $text)
                    .font(.body6)
                    .padding(16)
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button (action: {
                        onCancel()
                        dismiss()
                    }, label: {
                        Image(systemName: "xmark")
                    })
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { onSave(text); dismiss() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .principal) {
                    Text("메모 수정")
                }
            }
            .background(Color("Background"))
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 48) {
                    Button { onCopyAll() } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .glassEffect()
                    }
                    .buttonStyle(.plain)

                    Button { onShare() } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .glassEffect()
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) { showDeleteAlert = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                            .glassEffect()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.clear)
            }
            .alert("\(deleteSubject) 삭제하겠습니까?", isPresented: $showDeleteAlert) {
                Button("삭제", role: .destructive) { onDelete(); dismiss() }
                Button("취소", role: .cancel) { }
            }
        }
    }
}

// Sheet showing selectable text for partial copy
private struct SelectCopySheet: View {
    @Environment(\.dismiss) private var dismiss
    let text: String
    let onClose: () -> Void
    let onCopyAll: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // 안내 문구 최소화, 기본 동작은 길게 눌러 복사
                    SelectableText(
                        text,
                        fontSize: 14,
                        textStyle: .body,
                        lineSpacing: 4,
                        maxLayoutWidth: UIScreen.main.bounds.width - 32
                    )
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { onClose(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("전체 복사") { onCopyAll(); dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text("선택 복사")
                }
            }
            .background(Color("Background"))
        }
    }
}

private final class LinkPreviewLoader: ObservableObject {
    @Published var metadata: LPLinkMetadata?
    private static let cache = NSCache<NSURL, LPLinkMetadata>()
    private let provider = LPMetadataProvider()
    private let url: URL

    init(url: URL) {
        self.url = url
        if let cached = Self.cache.object(forKey: url as NSURL) {
            self.metadata = cached
        } else {
            provider.startFetchingMetadata(for: url) { [weak self] meta, _ in
                DispatchQueue.main.async {
                    if let meta {
                        Self.cache.setObject(meta, forKey: self?.url as NSURL? ?? NSURL())
                    }
                    self?.metadata = meta
                }
            }
        }
    }
}

private struct LinkPreviewViewRepresentable: UIViewRepresentable {
    let metadata: LPLinkMetadata

    func makeUIView(context: Context) -> LPLinkView {
        let linkView = LPLinkView(metadata: metadata)
        linkView.translatesAutoresizingMaskIntoConstraints = false
        linkView.isUserInteractionEnabled = false // 탭이 상위 버튼으로 전달되도록
        return linkView
    }
    
    func updateUIView(_ uiView: LPLinkView, context: Context) {
        uiView.metadata = metadata
    }
}

// Helper: Load UIImage from NSItemProvider (for LPLinkMetadata image/icon)
private struct LPImageFromProvider: View {
    let provider: NSItemProvider?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .renderingMode(.original)
            } else {
                Color.gray.opacity(0.08)
            }
        }
        .task {
            guard image == nil, let provider else { return }
            _ = provider.loadObject(ofClass: UIImage.self) { obj, _ in
                if let img = obj as? UIImage {
                    DispatchQueue.main.async { self.image = img }
                }
            }
        }
    }
}

// Helper: Host text from metadata or fallback URL
private func hostText(from meta: LPLinkMetadata?, fallback: URL) -> String {
    let urlToShow = meta?.url ?? meta?.originalURL ?? fallback
    return urlToShow.host ?? urlToShow.absoluteString
}

// Helper: Subtitle text from URL path and query (fallback to absoluteString when empty)
private func subtitleText(from meta: LPLinkMetadata?, fallback: URL) -> String {
    let resolvedURL = meta?.url ?? meta?.originalURL ?? fallback
    var path = resolvedURL.path
    if path.hasPrefix("/") { path.removeFirst() }
    let query = resolvedURL.query.map { "?\($0)" } ?? ""
    let subtitle = path + query
    return subtitle.isEmpty ? resolvedURL.absoluteString : subtitle
}

// (reverted) removed openURL scheme correction helper

private struct LinkPreviewCard: View {
    let url: URL
    @StateObject private var loader: LinkPreviewLoader
    @Environment(\.openURL) private var openURL

    init(url: URL) {
        self.url = url
        _loader = StateObject(wrappedValue: LinkPreviewLoader(url: normalizeURL(url)))
    }

    var body: some View {
        Button {
            let target = normalizeURL(url)
            UIApplication.shared.open(target, options: [:], completionHandler: nil)
        } label: {
            VStack(spacing: 0) {
                // Top image area: fixed height 180, cropped fill
                Group {
                    if let meta = loader.metadata, meta.imageProvider != nil {
                        LPImageFromProvider(provider: meta.imageProvider)
                            .scaledToFill()
                    } else {
                        Color.gray.opacity(0.08)
                    }
                }
                .frame(width: 246, height: 180)
                .clipped()

                // Bottom info area: icon + host, title, subtitle
                VStack(alignment: .leading, spacing: 0) {
                    Image(systemName: "link")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.bottom, 2)

                    Text(loader.metadata?.title ?? url.host ?? url.absoluteString)
                        .font(.caption2)
                        .lineLimit(2)
                        .padding(.bottom, 4)

                    Text(subtitleText(from: loader.metadata, fallback: url))
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 246, height: 246, alignment: .top)
            .background(Color("BackgroundSecondary"))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// Square audio tile (single)
// (moved) AudioSquareTile, ScrollingWaveformFill, PlaybackSineShape to SubView/AudioTile.swift

// Square audio tile (grid item)
// (removed) AudioGridTile: no longer used; audio is always single tile

private func format(_ duration: TimeInterval?) -> String {
    guard let duration else { return "--:--" }
    let total = Int(duration.rounded())
    let minutes = total / 60
    let seconds = total % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

#if canImport(SwiftUI)
private struct DateHeaderPositionsKey: PreferenceKey {
    static var defaultValue: [Date: CGFloat] = [:]
    static func reduce(value: inout [Date: CGFloat], nextValue: () -> [Date: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct ScrollMetrics: Equatable {
    var topY: CGFloat?
    var bottomY: CGFloat?
    var viewportHeight: CGFloat?
}

private struct ScrollMetricsKey: PreferenceKey {
    static var defaultValue: ScrollMetrics = .init(topY: nil, bottomY: nil, viewportHeight: nil)
    static func reduce(value: inout ScrollMetrics, nextValue: () -> ScrollMetrics) {
        let next = nextValue()
        if let t = next.topY { value.topY = t }
        if let b = next.bottomY { value.bottomY = b }
        if let v = next.viewportHeight { value.viewportHeight = v }
    }
}

private struct ChipHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        value = max(value, next)
    }
}

private struct BottomInsetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// (reverted) ScrollBounceDisabler removed in favor of .scrollBounceBehavior(.basedOnSize)
#endif

// MARK: - Custom Bottom Sheet Host

private struct BottomSheetHost<Content: View>: View {
    @Binding var mode: ChattingView.BottomSheetMode
    var onHeightChanged: (CGFloat, ChattingView.BottomSheetMode) -> Void = { _, _ in }
    var cornerRadius: CGFloat = 16
    var content: () -> Content

    @GestureState private var dragY: CGFloat = 0

    private var bottomInset: CGFloat {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let win = scene.windows.first(where: { $0.isKeyWindow }) {
            return win.safeAreaInsets.bottom
        }
        return 0
    }
    private var screenH: CGFloat { UIScreen.main.bounds.height - bottomInset }

    private var collapsedHeight: CGFloat { screenH * 0.4 }
    private var expandedHeight: CGFloat { screenH * 0.85 }
    private var targetHeight: CGFloat {
        switch mode {
        case .hidden: return 0
        case .collapsed: return collapsedHeight
        case .expanded: return expandedHeight
        }
    }

    var body: some View {
        let threshold: CGFloat = 120
        let drag = DragGesture()
            .updating($dragY) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                switch mode {
                case .collapsed:
                    // Upward drag expands; downward drag to hide is disabled (only left button hides)
                    if value.translation.height < -threshold {
                        mode = .expanded
                    }
                case .expanded:
                    // Downward drag collapses
                    if value.translation.height > threshold {
                        mode = .collapsed
                    }
                case .hidden:
                    break
                }
            }

        // Interactive height while dragging
        let interactiveOffset: CGFloat = {
            switch mode {
            case .collapsed:
                // allow only upward drag (negative), increase height up to expanded
                let allowed = min(0, dragY)
                return -allowed
            case .expanded:
                // allow only downward drag (positive), decrease height down to collapsed
                let allowed = max(0, dragY)
                return -allowed
            case .hidden:
                return 0
            }
        }()
        let baseHeight = targetHeight
        let unclampedHeight = baseHeight + interactiveOffset
        let displayedHeight: CGFloat = {
            switch mode {
            case .collapsed:
                return min(max(unclampedHeight, collapsedHeight), expandedHeight)
            case .expanded:
                return min(max(unclampedHeight, collapsedHeight), expandedHeight)
            case .hidden:
                return 0
            }
        }()

        VStack(spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 8)

            content()
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(0, displayedHeight))
        .background(Color("Background"))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: -2)
        .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.86), value: mode)
        .gesture(drag)
        .onChange(of: mode) { _, newMode in
            let calculatedHeight: CGFloat
            switch newMode {
            case .hidden: calculatedHeight = 0
            case .collapsed: calculatedHeight = collapsedHeight
            case .expanded: calculatedHeight = expandedHeight
            }
            onHeightChanged(calculatedHeight, newMode)
        }
        .onAppear {
            let calculatedHeight: CGFloat
            switch mode {
            case .hidden: calculatedHeight = 0
            case .collapsed: calculatedHeight = collapsedHeight
            case .expanded: calculatedHeight = expandedHeight
            }
            onHeightChanged(calculatedHeight, mode)
        }
    }
}

#Preview {
    ChattingView()
}

#Preview("TextEditSheet") {
    TextEditSheet(
        initialText: "안녕하세요",
        onCancel: { },
        onSave: { _ in },
        onCopyAll: { },
        onShare: { },
        onDelete: { },
        deleteSubject: "메모를"
    )
}

// (reverted) LinkedText removed

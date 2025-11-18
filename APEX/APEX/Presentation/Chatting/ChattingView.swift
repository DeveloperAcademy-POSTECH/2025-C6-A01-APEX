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
    @EnvironmentObject private var router: NavigationRouter
    let clientId: UUID
    let chatTitle: String
    let initialNotes: [Note]
    init(clientId: UUID, chatTitle: String = "채팅", initialNotes: [Note] = []) {
        self.clientId = clientId
        self.chatTitle = chatTitle
        self.initialNotes = initialNotes
    }
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
    @FocusState private var isSearchFieldFocused: Bool
    // Search state
    @State private var isSearchActive: Bool = false
    @State private var searchText: String = ""
    @State private var matchedNoteIds: [UUID] = []
    @State private var currentMatchIndex: Int = 0
    // Suppress auto-scroll-to-bottom when navigating to a specific note
    @State private var suppressAutoScroll: Bool = false
    @State private var sheetModeBeforeSearch: BottomSheetMode? = nil
    // Date search
    @State private var showDatePicker: Bool = false
    @State private var datePickerSelection: Date = Date()
    @State private var highlightedDate: Date?
    @State private var dateHighlightOffsetY: CGFloat = 0
    private struct EditingPayload: Identifiable { let id = UUID(); let noteId: UUID; var text: String }
    @State private var editing: EditingPayload?
    // Selection delete confirmation
    @State private var showSelectionDeleteAlert: Bool = false
    // Delete selection mode
    @State private var isDeleteSelecting: Bool = false
    @State private var selectedNoteIds: Set<UUID> = []
    private struct ShareSeed: Identifiable {
        let id = UUID()
        var text: String?
        var files: [URL]
        var audios: [URL]
        var images: [UIImage] = []
        var videos: [URL] = []
    }
    @State private var shareSeed: ShareSeed?
    // Initial target scroll support
    @State private var didApplyInitialTargetScroll: Bool = false
    @State private var initialTargetNoteId: UUID?
    // Parent-scoped record viewer state
    private struct RecordPayload: Identifiable { let id = UUID(); let url: URL }
    @State private var recordPayload: RecordPayload?
    // Chat detail sheet
    @State private var showChatDetail: Bool = false

    private enum Metrics {
        static let timeWidth: CGFloat = 66
        static let timeGap: CGFloat = 12
        static let leftSelectWidth: CGFloat = 44
    }
    
    private func timeTextWidth(for date: Date) -> CGFloat {
        let text = date.formattedChatTime
        let font = UIFont.preferredFont(forTextStyle: .caption2)
        let size = (text as NSString).size(withAttributes: [.font: font])
        return ceil(size.width)
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
                            HStack(alignment: .center, spacing: 12) {
                                Group {
                                    if isDeleteSelecting {
                                        let isChecked = selectedNoteIds.contains(note.id)
                                        Button {
                                            var tx = Transaction()
                                            tx.disablesAnimations = true
                                            withTransaction(tx) {
                                                toggleSelection(for: note.id)
                                            }
                                        } label: {
                                            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 24, weight: .medium))
                                                .foregroundStyle(isChecked ? Color("Primary") : .gray)
                                                .frame(width: 24, height: 24, alignment: .center)
                                                .contentTransition(.identity)
                                                .animation(nil, value: selectedNoteIds)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        Color.clear
                                            .frame(width: 24, height: 24)
                                    }
                                }
                                .padding(.horizontal, 6.5)
                                .animation(nil, value: selectedNoteIds)
                                
                                HStack {
                                    Spacer(minLength: 0)
                                    
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
                                            currentClientId: clientId,
                                            highlightQuery: (
                                                isSearchActive &&
                                                !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                                                !matchedNoteIds.isEmpty &&
                                                matchedNoteIds.indices.contains(currentMatchIndex) &&
                                                matchedNoteIds[currentMatchIndex] == note.id
                                            ) ? searchText : nil,
                                            leadingReservedWidth: Metrics.leftSelectWidth,
                                            buildViewerPayload: { anchor in
                                                buildGlobalViewerPayload(startingFrom: anchor)
                                            },
                                            onOpenViewer: { anchor in
                                                openViewer(anchor: anchor)
                                            },
                                            onOpenShare: { selectedText in
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                                    shareSeed = ShareSeed(text: selectedText, files: [], audios: [], images: [], videos: [])
                                                }
                                            },
                                            onOpenShareFiles: { urls in
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                                    shareSeed = ShareSeed(text: nil, files: urls, audios: [], images: [], videos: [])
                                                }
                                            },
                                            onOpenShareAudio: { url in
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                                    shareSeed = ShareSeed(text: nil, files: [], audios: [url], images: [], videos: [])
                                                }
                                            },
                                            onDeleteFile: { noteId, fileIndex in
                                                deleteFile(noteId: noteId, fileIndex: fileIndex)
                                            },
                                            onOpenRecord: { url in
                                                NotificationCenter.default.post(name: .apexStopAllAudioPlayback, object: nil)
                                                recordPayload = RecordPayload(url: url)
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
                                            onStartMultiDelete: { noteId in
                                                startDeleteSelection(preselect: noteId)
                                            }
                                        )
                                        .offset(x: -timestampRevealProgress * (timeTextWidth(for: note.uploadedAt) + Metrics.timeGap))
                                        .allowsHitTesting(!isDeleteSelecting)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if isDeleteSelecting {
                                            var tx = Transaction()
                                            tx.disablesAnimations = true
                                            withTransaction(tx) {
                                                toggleSelection(for: note.id)
                                            }
                                        }
                                    }
                                }
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
                    .padding(.horizontal, 12)
                }
                .textSelection(.disabled)
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
                .onTapGesture {
                    UIApplication.apexDismissKeyboard()
                    if sheetMode == .collapsed {
                        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.2)) {
                            sheetMode = .hidden
                        }
                    }
                }
                .onAppear {
                    DispatchQueue.main.async {
                        // Capture pending initial target (if any) from router once
                        if initialTargetNoteId == nil, let pending = router.pendingScrollToNoteId {
                            initialTargetNoteId = pending
                            router.pendingScrollToNoteId = nil
                        }
                        if notes.isEmpty {
                            let persisted = ChatStore.shared.notes(for: clientId)
                            if persisted.isEmpty {
                                // Seed from initialNotes (e.g., persisted in ClientsStore) when ChatStore is empty
                                notes = initialNotes
                                ChatStore.shared.setNotes(initialNotes, for: clientId)
                            } else {
                                notes = persisted
                            }
                        }
                        // Apply initial non-animated target scroll if available
                        if let target = initialTargetNoteId, !didApplyInitialTargetScroll {
                            suppressAutoScroll = true
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                proxy.scrollTo(target, anchor: .center)
                            }
                            didApplyInitialTargetScroll = true
                        } else if !suppressAutoScroll {
                            proxy.scrollTo(bottomSentinelId, anchor: .bottom)
                        }
                        // If any incoming notes carry pending progress, kick off simulations
                        kickOffPendingUploadsIfNeeded()
                    }
                }
                .onChange(of: notes.count) { _ in
                    DispatchQueue.main.async {
                        guard !suppressAutoScroll else { return }
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(bottomSentinelId, anchor: .bottom) }
                        // 확실히 맨 아래로 이동했을 때 버튼 숨김 (metrics 업데이트 전 선반영)
                        self.showScrollToBottom = false
                    }
                }
                .onChange(of: bottomBarOffsetY) { _ in
                    // 사용자가 위로 올려본 상태면(auto-scroll off) 건드리지 않음
                    guard !showScrollToBottom else { return }
                    guard !suppressAutoScroll else { return }
                    // 키보드/레이아웃 반영 직후에 센티널로 스크롤
                    keyboardScrollWork?.cancel()
                    let work = DispatchWorkItem {
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(bottomSentinelId, anchor: .bottom) }
                    }
                    keyboardScrollWork = work
                    // 레이아웃 적용 직후 실행하여 위치 튐 방지
                    DispatchQueue.main.async(execute: work)
                }
                .onChange(of: bottomInsetHeight) { _ in
                    guard !showScrollToBottom else { return }
                    guard !suppressAutoScroll else { return }
                    keyboardScrollWork?.cancel()
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(bottomSentinelId, anchor: .bottom) }
                        self.showScrollToBottom = false
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .apexInputFocused)) { _ in
                    guard !suppressAutoScroll else { return }
                    keyboardScrollWork?.cancel()
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(bottomSentinelId, anchor: .bottom) }
                    self.isEditorCurrentlyFocused = true
                    self.showScrollToBottom = false

                    let work = DispatchWorkItem {
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(bottomSentinelId, anchor: .bottom) }
                    }
                    keyboardScrollWork = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: work)
                }
                .onReceive(NotificationCenter.default.publisher(for: .apexInputBlurred)) { _ in
                    self.isEditorCurrentlyFocused = false
                }
                .onReceive(NotificationCenter.default.publisher(for: .apexNavigateToNote)) { notif in
                    if let noteId = notif.userInfo?["noteId"] as? UUID {
                        suppressAutoScroll = true
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(noteId, anchor: .center)
                        }
                        self.showScrollToBottom = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            suppressAutoScroll = false
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .apexNavigateToDate)) { notif in
                    if let date = notif.userInfo?["date"] as? Date {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(dateHeaderId(date), anchor: .top)
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
                .onReceive(NotificationCenter.default.publisher(for: .apexAudioDeleted)) { notif in
                    guard let url = notif.userInfo?["url"] as? URL else { return }
                    var changedAny = false
                    for idx in notes.indices {
                        if case var .audio(audios) = notes[idx].bundle {
                            let before = audios.count
                            audios.removeAll { $0.url == url }
                            if audios.count != before {
                                notes[idx].bundle = audios.isEmpty ? nil : .audio(audios)
                                changedAny = true
                            }
                        }
                    }
                    if changedAny {
                        ChatStore.shared.setNotes(notes, for: clientId)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .apexChatNotesUpdated)) { notif in
                    // When any chat's notes change, refresh if this view's clientId matches
                    if let changedId = notif.userInfo?["clientId"] as? UUID, changedId == clientId {
                        let latest = ChatStore.shared.notes(for: clientId)
                        notes = latest
                        // Ensure any items with progress resume/complete simulation
                        kickOffPendingUploadsIfNeeded()
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
        
        .scrollEdgeEffectStyle(.soft, for: .all)
        .toolbar(.hidden, for: .navigationBar)
        // Full-screen left-swipe to reveal timestamps (non-intrusive)
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
        .onChange(of: isSearchActive) { _, active in
            if active {
                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.2)) {
                    if sheetMode != .hidden {
                        sheetModeBeforeSearch = sheetMode
                    }
                    sheetMode = .hidden
                    bottomBarOffsetY = 0
                }
                NotificationCenter.default.post(name: .apexMediaSheetVisibilityChanged, object: nil, userInfo: ["visible": false])
            }
            // Toggle focus on search field based on visibility
            DispatchQueue.main.async {
                isSearchFieldFocused = active
            }
            if !active {
                // Reset search state back to original
                searchText = ""
                matchedNoteIds.removeAll()
                currentMatchIndex = 0
                highlightedDate = nil
                dateHighlightOffsetY = 0
                showDatePicker = false
                if let previous = sheetModeBeforeSearch {
                    withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.2)) {
                        sheetMode = previous
                    }
                    sheetModeBeforeSearch = nil
                    NotificationCenter.default.post(name: .apexMediaSheetVisibilityChanged, object: nil, userInfo: ["visible": true])
                }
            }
        }
        .safeAreaBar(edge: .top) {
            if isSearchActive {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Button {
                        datePickerSelection = Date()
                        showDatePicker = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 44)
                    }
                    .glassEffect()
                }
                .frame(height: 52)
                .padding(.horizontal, 12)
                .background(Color("Background"))
            } else if isDeleteSelecting {
                APEXSheetTopBar(
                    title: "삭제",
                    rightTitle: "선택 해제",
                    isRightEnabled: !selectedNoteIds.isEmpty,
                    onRightTap: {
                        selectedNoteIds.removeAll()
                    },
                    onClose: {
                        cancelDeleteSelection()
                    },
                    rightIconSystemName: nil,
                    showsRightButton: true,
                    leftIconSystemName: "xmark"
                )
            } else {
                APEXNavigationBar(
                    .memo(
                        title: chatTitle,
                        onBack: { router.pop() },
                        onTitleTap: {
                            onTapTitleNavigate()
                        },
                        onSearch: { withAnimation { isSearchActive = true } },
                        onMenu: { router.push(.chatArchive(clientId)) }
                    )
                )
            }
        }
        .safeAreaBar(edge: .bottom) {
            if isDeleteSelecting {
                // Bottom action bar for selection delete
                Button {
                    showSelectionDeleteAlert = true
                } label: {
                    Text("\(selectedNoteIds.count) 삭제하기")
                        .font(.body2)
                        .foregroundColor(selectedNoteIds.isEmpty ? Color("BackgroundDisabled") : Color("Error"))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(selectedNoteIds.isEmpty ? Color("BackgroundSecondary") : Color("ErrorContainer"))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .disabled(selectedNoteIds.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !isDeleteSelecting {
                VStack(spacing: 8) {
                    if isSearchActive {
                        APEXSearchBar(
                            text: $searchText,
                            isFocused: _isSearchFieldFocused,
                            onPrev: { navigateToPrevMatch() },
                            onNext: { navigateToNextMatch() },
                            onClose: {
                                isSearchFieldFocused = false
                                withAnimation { isSearchActive = false }
                                searchText = ""
                                matchedNoteIds.removeAll()
                            },
                            onTextChange: { _ in
                                recomputeMatches()
                                scrollToCurrentMatch()
                            }
                        )
                    } else {
                        if !stagedAttachments.isEmpty {
                            AttachBar(items: stagedAttachments) { removed in
                                stagedAttachments.removeAll { $0.id == removed.id }
                            }
                        }

                        InputBar({ note in
                            handleIncoming(note: note)
                        }, onSheetVisibilityChanged: { visible in
                         // If in delete selection mode, force sheet hidden and ignore requests
                         if isDeleteSelecting {
                             withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.2)) {
                                 sheetMode = .hidden
                                 bottomBarOffsetY = 0
                             }
                             return
                         }
                         // Map InputBar left button toggle to our custom sheet modes
                         withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.2)) {
                             if visible {
                                 sheetMode = .collapsed
                             } else {
                                 sheetMode = (sheetMode == .expanded) ? .collapsed : .hidden
                             }
                         }
                        }, stagedAttachments: $stagedAttachments, onBarOffsetChanged: { offset in
                            bottomBarOffsetY = offset
                        })
                    }
                }
                .offset(y: bottomBarOffsetY)
                .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.2), value: bottomBarOffsetY)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: BottomInsetHeightKey.self, value: geo.size.height)
                    }
                )
            }
        }
        // Custom overlay sheet (replaces system .sheet for media picker)
        .overlay(alignment: .bottom) {
            if sheetMode != .hidden {
                ZStack(alignment: .bottom) {
                    if sheetMode == .expanded {
                        Color.black.opacity(0.18)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.2)) {
                                    sheetMode = .collapsed
                                }
                            }
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
                            selectedAttachmentItems: $stagedAttachments,
                            isFullyExpandedOverride: (sheetMode == .expanded),
                            onCloseTopBar: {
                                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.2)) {
                                    sheetMode = .hidden
                                }
                            }
                        )
                        .padding(.bottom, 0)
                    }
                    .zIndex(1)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onChange(of: sheetMode) { _, newMode in
            let visible = (newMode != .hidden)
            NotificationCenter.default.post(
                name: .apexMediaSheetVisibilityChanged,
                object: nil,
                userInfo: ["visible": visible]
            )
        }
        .onChange(of: isDeleteSelecting) { _, selecting in
            if selecting {
                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.2)) {
                    sheetMode = .hidden
                    bottomBarOffsetY = 0
                }
            }
        }
        .onPreferenceChange(BottomInsetHeightKey.self) { height in bottomInsetHeight = height }
        .alert("\(selectedNoteIds.count)개의 노트를 삭제하겠습니까?", isPresented: $showSelectionDeleteAlert) {
            Button("삭제", role: .destructive) {
                performDeleteSelected()
            }
            Button("취소", role: .cancel) { }
        }
        .sheet(item: $editing) { payload in
            TextEditSheet(
                initialText: payload.text,
                onCancel: { editing = nil },
                onSave: { newText in
                    if let idx = notes.firstIndex(where: { $0.id == payload.noteId }) {
                        notes[idx].text = newText
                    }
                    ChatStore.shared.setNotes(notes, for: clientId)
                    editing = nil
                },
                onCopyAll: {
                    UIPasteboard.general.string = payload.text
                    withAnimation { showCopyToast = true }
                },
                onShare: {
                    DispatchQueue.main.async {
                        editing = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            shareSeed = ShareSeed(text: payload.text, files: [], audios: [])
                        }
                    }
                },
                onDelete: {
                    if let idx = notes.firstIndex(where: { $0.id == payload.noteId }) {
                        notes.remove(at: idx)
                    }
                    ChatStore.shared.setNotes(notes, for: clientId)
                    editing = nil
                },
                deleteSubject: "메모를"
            )
        }
        .sheet(item: $shareSeed) { seed in
            let initialAttachments: [ShareAttachmentItem] = {
                var items: [ShareAttachmentItem] = []
                if let text = seed.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                    items.append(ShareAttachmentItem(id: UUID(), kind: .text(text)))
                }
                // Prefer to render file seeds as visual media when possible so AttachBar appears
                for url in seed.files {
                    let type = UTType(filenameExtension: url.pathExtension)
                    if let t = type, t.conforms(to: .image), let data = try? Data(contentsOf: url), let ui = UIImage(data: data) {
                        items.append(ShareAttachmentItem(id: UUID(), kind: .image(ui)))
                    } else if let t = type, (t.conforms(to: .movie) || t.conforms(to: .audiovisualContent)) {
                        let thumb = generateThumbnail(for: url)
                        items.append(ShareAttachmentItem(id: UUID(), kind: .video(url, thumbnail: thumb)))
                    } else {
                        items.append(ShareAttachmentItem(id: UUID(), kind: .file(url)))
                    }
                }
                // Also include any explicitly provided images/videos (if present)
                for ui in seed.images {
                    items.append(ShareAttachmentItem(id: UUID(), kind: .image(ui)))
                }
                for url in seed.videos {
                    let thumb = generateThumbnail(for: url)
                    items.append(ShareAttachmentItem(id: UUID(), kind: .video(url, thumbnail: thumb)))
                }
                for url in seed.audios {
                    items.append(ShareAttachmentItem(id: UUID(), kind: .audio(url)))
                }
                return items
            }()
            ShareView(
                initialAttachments: initialAttachments,
                excludedClientIds: [clientId]
            )
        }
        // Centralized media viewer now provided by APEXMediaViewerHost via environment presenter
        .fullScreenCover(item: $recordPayload) { payload in
            RecordView(audioURL: payload.url)
        }
        .sheet(isPresented: $showDatePicker) {
            let memoDays: Set<Date> = Set(notes.map { Calendar.current.startOfDay(for: $0.uploadedAt) })
            ChatDatePickerSheet(date: $datePickerSelection, hasMemoDays: memoDays, onClose: {
                showDatePicker = false
            }, onSelect: { selected in
                showDatePicker = false
                highlightedDate = selected
                triggerDateBounce()
                NotificationCenter.default.post(name: .apexNavigateToDate, object: nil, userInfo: ["date": selected])
            })
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
        }
        // Hidden NavigationLinks removed; Router handles navigation
    }
}

// MARK: - Send handling & simulated uploads

private extension ChattingView {
    func onTapTitleNavigate() {
        guard let client = ClientsStore.shared.clients.first(where: { $0.id == clientId }) else { return }
        let myId = ClientsStore.shared.clients.first?.id
        let isMe = (client.id == myId)
        if isMe {
            router.push(.myProfile)
        } else {
            router.push(.profileDetail(clientId))
        }
    }
    
    // MARK: - Delete selection helpers
    func startDeleteSelection(preselect noteId: UUID) {
        isDeleteSelecting = true
        selectedNoteIds = [noteId]
    }
    func toggleSelection(for noteId: UUID) {
        if selectedNoteIds.contains(noteId) {
            selectedNoteIds.remove(noteId)
        } else {
            selectedNoteIds.insert(noteId)
        }
    }
    func performDeleteSelected() {
        guard !selectedNoteIds.isEmpty else { return }
        notes.removeAll { selectedNoteIds.contains($0.id) }
        ChatStore.shared.setNotes(notes, for: clientId)
        cancelDeleteSelection()
    }
    func cancelDeleteSelection() {
        isDeleteSelecting = false
        selectedNoteIds.removeAll()
    }

    // convertToDummy moved to RootView wrapper; not needed here
    func deleteAudio(noteId: UUID, url: URL) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId }) else { return }
        guard case var .audio(audios) = notes[idx].bundle else { return }
        audios.removeAll { $0.url == url }
        // Remove the underlying file from disk to avoid stale temp files affecting future naming
        try? FileManager.default.removeItem(at: url)
        if audios.isEmpty {
            if notes[idx].text == nil {
                notes.remove(at: idx)
            } else {
                notes[idx].bundle = nil
            }
        } else {
            notes[idx].bundle = .audio(audios)
        }
        ChatStore.shared.setNotes(notes, for: clientId)
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
        } else if case let .files(files) = note.bundle {
            if files.count > 1 {
                let baseDate = note.uploadedAt
                if let text = note.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                    let textOnly = Note(uploadedAt: baseDate, text: text, bundle: nil)
                    notes.append(textOnly)
                }
                let startIdx = notes.count
                for f in files {
                    let single = Note(
                        uploadedAt: baseDate,
                        text: nil,
                        bundle: .files([
                            FileAttachment(url: f.url, contentType: f.contentType, progress: 0)
                        ])
                    )
                    notes.append(single)
                }
                ChatStore.shared.setNotes(notes, for: clientId)
                for idx in startIdx..<notes.count {
                    startUploadsForNote(at: idx)
                }
                return
            } else if files.count == 1, let f = files.first {
                noteWithProgress.bundle = .files([FileAttachment(url: f.url, contentType: f.contentType, progress: 0)])
            }
        }
        notes.append(noteWithProgress)
        ChatStore.shared.setNotes(notes, for: clientId)
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

    // MARK: - Search helpers
    func recomputeMatches() {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            matchedNoteIds.removeAll()
            currentMatchIndex = 0
            return
        }
        let lowercasedQuery = trimmedQuery.lowercased()
        var results: [UUID] = []
        for note in notes.reversed() {
            var matched = false
            if let textLowercased = note.text?.lowercased(), textLowercased.contains(lowercasedQuery) {
                matched = true
            }
            if !matched, case let .files(files) = note.bundle {
                if files.contains(where: { $0.url.lastPathComponent.lowercased().contains(lowercasedQuery) }) {
                    matched = true
                }
            }
            if !matched, case let .audio(audios) = note.bundle {
                if audios.contains(where: { $0.url.deletingPathExtension().lastPathComponent.lowercased().contains(lowercasedQuery) }) {
                    matched = true
                }
            }
            if matched { results.append(note.id) }
        }
        matchedNoteIds = results
        // Always start at the most recent match when query changes
        currentMatchIndex = results.isEmpty ? 0 : 0
    }

    func scrollToCurrentMatch() {
        guard !matchedNoteIds.isEmpty else { return }
        let id = matchedNoteIds[currentMatchIndex]
        NotificationCenter.default.post(name: .apexNavigateToNote, object: nil, userInfo: ["noteId": id])
    }

    func navigateToNextMatch() {
        guard !matchedNoteIds.isEmpty else { return }
        // Down arrow: move toward newer (list is newest-first), so decrement index
        currentMatchIndex = (currentMatchIndex - 1 + matchedNoteIds.count) % matchedNoteIds.count
        scrollToCurrentMatch()
    }

    func navigateToPrevMatch() {
        guard !matchedNoteIds.isEmpty else { return }
        // Up arrow: move toward older (list is newest-first), so increment index
        currentMatchIndex = (currentMatchIndex + 1) % matchedNoteIds.count
        scrollToCurrentMatch()
    }

    private func openViewer(anchor: ChatMessageView.ChatAnchor) {
        let payload = buildGlobalViewerPayload(startingFrom: anchor)
        let currentAnchor = payload.anchors.indices.contains(payload.index) ? payload.anchors[payload.index] : nil
        let initialUploadedAt = currentAnchor.flatMap { anchor in
            notes.first(where: { $0.id == anchor.noteId })?.uploadedAt
        }
        let viewerPayload = APEXOpenMediaViewerPayload(
            items: payload.items,
            index: payload.index,
            title: chatTitle,
            uploadedAt: initialUploadedAt,
            excludedClientIds: [clientId],
            onDelete: { removedIndex, _ in
                guard payload.anchors.indices.contains(removedIndex) else { return }
                let anchor = payload.anchors[removedIndex]
                deleteMedia(anchor: anchor)
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
        APEXMediaViewerStore.shared.put(viewerPayload)
        router.push(.mediaViewer(viewerPayload.id))
    }
}

private struct ChatMessageView: View {
    let note: Note
    let chatTitle: String
    let currentClientId: UUID
    let highlightQuery: String?
    let leadingReservedWidth: CGFloat
    struct ChatAnchor { let noteId: UUID; let isImage: Bool; let localIndex: Int }
    let buildViewerPayload: (ChatAnchor) -> (items: [MediaSource], anchors: [ChatAnchor], index: Int)
    let onOpenViewer: (ChatAnchor) -> Void
    let onOpenShare: (String) -> Void
    let onOpenShareFiles: ([URL]) -> Void
    let onOpenShareAudio: (URL) -> Void
    let onDeleteFile: (UUID, Int) -> Void
    let onOpenRecord: (URL) -> Void
    let onDelete: (ChatAnchor) -> Void
    let onDeleteAudio: (UUID, URL) -> Void
    let onCopyText: (String) -> Void
    let onStartEdit: (UUID, String) -> Void
    let onStartMultiDelete: (UUID) -> Void
    // Removed selectedRange; SelectableText now manages selection internally
    @State private var showDeleteAlert: Bool = false
    @State private var deleteSubjectText: String = ""
    @State private var pendingDelete: (() -> Void)?
    
    private enum Metrics {
        static let tileSize: CGFloat = 106
        static let spacing: CGFloat = 1
        static let cornerRadius: CGFloat = 15
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if case let .media(images, videos) = note.bundle {
                if videos.count == 1, images.isEmpty {
                    APEXMediaSingleCard(
                        source: .video(videos[0].url),
                        baseTileWidth: Metrics.tileSize,
                        columnsSpanned: 2,
                        spacing: Metrics.spacing,
                        cornerRadius: Metrics.cornerRadius
                    )
                    .onTapGesture {
                        onOpenViewer(ChatAnchor(noteId: note.id, isImage: false, localIndex: 0))
                    }
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button {
                            onOpenShareFiles([videos[0].url])
                        } label: {
                            Label("공유", systemImage: "square.and.arrow.up")
                        }
                        .tint(.primary)
                        Button(role: .destructive) {
                            onStartMultiDelete(note.id)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                } else if images.count == 1, videos.isEmpty {
                    APEXMediaSingleCard(
                        source: .image(images[0].data),
                        baseTileWidth: Metrics.tileSize,
                        columnsSpanned: 2,
                        spacing: Metrics.spacing,
                        cornerRadius: Metrics.cornerRadius
                    )
                    .onTapGesture {
                        onOpenViewer(ChatAnchor(noteId: note.id, isImage: true, localIndex: 0))
                    }
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button {
                            if let url = tempURLForImageData(images[0].data) {
                                onOpenShareFiles([url])
                            }
                        } label: {
                            Label("공유", systemImage: "square.and.arrow.up")
                        }
                        .tint(.primary)
                        Button(role: .destructive) {
                            onStartMultiDelete(note.id)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                } else {
                    MediaGrid(
                        images: images,
                        videos: videos,
                        onOpen: { isImage, localIndex in
                        onOpenViewer(ChatAnchor(noteId: note.id, isImage: isImage, localIndex: localIndex))
                        },
                        onShareImageAt: { _ in },
                        onShareVideoAt: { _ in },
                        onDeleteImageAt: { _ in },
                        onDeleteVideoAt: { _ in },
                        onShareAll: {
                            var urls: [URL] = []
                            for img in images {
                                if let url = tempURLForImageData(img.data) { urls.append(url) }
                            }
                            urls.append(contentsOf: videos.map { $0.url })
                            if !urls.isEmpty { onOpenShareFiles(urls) }
                        },
                        onDeleteMemo: {
                            onStartMultiDelete(note.id)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button {
                            var urls: [URL] = []
                            for img in images {
                                if let url = tempURLForImageData(img.data) { urls.append(url) }
                            }
                            urls.append(contentsOf: videos.map { $0.url })
                            if !urls.isEmpty { onOpenShareFiles(urls) }
                        } label: {
                            Label("공유", systemImage: "square.and.arrow.up")
                        }
                        .tint(.primary)
                        Button(role: .destructive) {
                            onStartMultiDelete(note.id)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            } else if case let .files(files) = note.bundle {
                if let first = files.first {
                    FileMemo(
                        url: first.url,
                        contentType: first.contentType,
                        highlightQuery: highlightQuery,
                        width: Metrics.tileSize * 2 + Metrics.spacing,
                        onTap: {
                            guard first.progress == nil else { return }
                            openFileURL(first.url)
                        }
                    )
                    .overlay {
                        if let progress = first.progress {
                            ProgressOverlay(progress: progress)
                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                    }
                    .allowsHitTesting(first.progress == nil)
                    .contextMenu {
                        Button { onOpenShareFiles([first.url]) } label: {
                            Label("공유", systemImage: "square.and.arrow.up")
                        }
                        .tint(.primary)
                        Button(role: .destructive) {
                            onStartMultiDelete(note.id)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
            // Audio attachments: always render single tile with anchored menu
            else if case let .audio(audios) = note.bundle {
                if let first = audios.first {
                    AudioSquareTile(url: first.url, duration: first.duration, preferredLength: nil, titleOverride: nil, highlightQuery: highlightQuery)
                        .contextMenu {
                            Button { onOpenRecord(first.url) } label: {
                                Label("더보기", systemImage: "ellipsis.circle")
                            }
                            .tint(.primary)
                            Button {
                                NotificationCenter.default.post(name: .apexStopAllAudioPlayback, object: nil)
                                onOpenShareAudio(first.url)
                            } label: {
                                Label("공유", systemImage: "square.and.arrow.up")
                            }
                            .tint(.primary)
                            Button(role: .destructive) {
                                onStartMultiDelete(note.id)
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                }
            }
            
            if let text = note.text {
                VStack(alignment: .trailing, spacing: 8) {
                    // ChattingView.swift (텍스트 버블 부분만)
                    SelectableText(
                        text,
                        fontSize: 14,
                        textStyle: .body,
                        lineSpacing: 4,
                        maxLayoutWidth: UIScreen.main.bounds.width - 24 - leadingReservedWidth,
                        highlightQuery: highlightQuery
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                    .background(Color("BackgroundSecondary"))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                    ForEach(urls(in: text), id: \.absoluteString) { url in
                        LinkPreviewCard(url: url)
                    }
                }
                .contentShape(Rectangle())
                .contextMenu {
                    Button { onCopyText(text) } label: {
                        Label("전체 복사", systemImage: "doc.on.doc")
                    }
                    .tint(.primary)
                    Button { onStartEdit(note.id, text) } label: {
                        Label("수정", systemImage: "pencil")
                    }
                    .tint(.primary)
                    Button { onOpenShare(text) } label: {
                        Label("공유", systemImage: "square.and.arrow.up")
                    }
                    .tint(.primary)
                    Button(role: .destructive) {
                        onStartMultiDelete(note.id)
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
        }
        .alert("\(deleteSubjectText) 삭제하겠습니까?", isPresented: $showDeleteAlert) {
            Button("삭제", role: .destructive) { pendingDelete?() }
            Button("취소", role: .cancel) { }
        }
        // removed per-cell share sheet and record cover; handled at parent level
    }
}

private extension ChatMessageView {
    func tempURLForImageData(_ data: Data) -> URL? {
        // Simple signature check for PNG header
        let isPNG: Bool = data.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let ext = isPNG ? "png" : "jpg"
        let filename = "apex-image-\(UUID().uuidString).\(ext)"
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

private extension ChattingView {
    @ViewBuilder
    func dateHeaderView(_ date: Date) -> some View {
        Text(date.formattedChatDayHeader)
            .font(.caption2)
            .foregroundColor(isSameCalendarDay(date, highlightedDate) ? Color("Primary") : .gray)
            .offset(y: isSameCalendarDay(date, highlightedDate) ? dateHighlightOffsetY : 0)
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
            .id(dateHeaderId(date))
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
    
    func dateHeaderId(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = (comps.month ?? 0)
        let d = (comps.day ?? 0)
        return String(format: "date-%04d%02d%02d", y, m, d)
    }

    func isSameCalendarDay(_ lhs: Date, _ rhs: Date?) -> Bool {
        guard let rhs else { return false }
        return Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }

    func triggerDateBounce() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) {
            dateHighlightOffsetY = -4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) {
                dateHighlightOffsetY = 3
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                dateHighlightOffsetY = -2
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.7)) {
                dateHighlightOffsetY = 0
            }
        }
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

        // If nothing remains in this media bundle, remove bundle or note entirely
        if images.isEmpty && videos.isEmpty {
            if notes[noteIndex].text == nil {
                notes.remove(at: noteIndex)
            } else {
                notes[noteIndex].bundle = nil
            }
            ChatStore.shared.setNotes(notes, for: clientId)
            return
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
        ChatStore.shared.setNotes(notes, for: clientId)
    }
    
    func deleteFile(noteId: UUID, fileIndex: Int) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteId }) else { return }
        guard case var .files(files) = notes[noteIndex].bundle else { return }
        guard files.indices.contains(fileIndex) else { return }
        files.remove(at: fileIndex)
        if files.isEmpty {
            if notes[noteIndex].text == nil {
                notes.remove(at: noteIndex)
            } else {
                notes[noteIndex].bundle = nil
            }
        } else {
            notes[noteIndex].bundle = .files(files)
        }
        ChatStore.shared.setNotes(notes, for: clientId)
    }

    // MARK: - Pending upload helpers
    func hasPendingProgress(at index: Int) -> Bool {
        guard notes.indices.contains(index) else { return false }
        switch notes[index].bundle {
        case .media(let images, let videos):
            return images.contains { $0.progress != nil } || videos.contains { $0.progress != nil }
        case .files(let files):
            return files.contains { $0.progress != nil }
        default:
            return false
        }
    }

    func kickOffPendingUploadsIfNeeded() {
        for idx in notes.indices where hasPendingProgress(at: idx) {
            startUploadsForNote(at: idx)
        }
    }
}

private func clientName(from note: Note) -> String {
    // Placeholder until Note carries author/client info. Using a hardcoded title like the nav bar.
    return "Gyeong"
}

// Removed: SingleVideoCard, SingleImageCard (use APEXMediaSingleCard instead)

// Grid for mixed media; videos show duration badge bottom-left
private struct MediaGrid: View {
    let images: [ImageAttachment]
    let videos: [VideoAttachment]
    var onOpen: (_ isImage: Bool, _ localIndex: Int) -> Void
    var onShareImageAt: (_ index: Int) -> Void
    var onShareVideoAt: (_ index: Int) -> Void
    var onDeleteImageAt: (_ index: Int) -> Void
    var onDeleteVideoAt: (_ index: Int) -> Void
    var onShareAll: () -> Void
    var onDeleteMemo: () -> Void

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    private enum Metrics {
        static let tileSize: CGFloat = 106
        static let spacing: CGFloat = 1
        static let cornerRadius: CGFloat = 2
    }

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

        let fullCount = (merged.count / 3) * 3
        let head = Array(merged.prefix(fullCount))
        let tail = Array(merged.suffix(merged.count - fullCount))

        return VStack(spacing: Metrics.spacing) {
            // Full rows in 3-column grid
            if !head.isEmpty {
                // Arrange rows: rows 1..(n-1) right-to-left, last row (if tail is empty and thus full) left-to-right
                let headRowCount = head.count / 3
                // If total items are exactly 2 or 3, force RTL even for the last row
                let forceRTLAllRows = (merged.count == 2 || merged.count == 3)
                let orderedHead: [CombinedItem] = (0..<headRowCount).flatMap { rowIndex -> [CombinedItem] in
                    let start = rowIndex * 3
                    let end = start + 3
                    let rowItems = Array(head[start..<end])
                    let isLastOverallRow = tail.isEmpty && (rowIndex == headRowCount - 1)
                    if forceRTLAllRows { return rowItems.reversed() }
                    return isLastOverallRow ? rowItems : rowItems.reversed()
                }
                LazyVGrid(columns: columns, spacing: Metrics.spacing) {
                    ForEach(orderedHead.indices, id: \.self) { idx in
                        let item = orderedHead[idx]
                        if item.isImage {
                            let img = images[item.index]
                            APEXMediaTile(source: .image(img.data))
                                .frame(width: Metrics.tileSize, height: Metrics.tileSize)
                                .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                .overlay {
                                    if let progress = img.progress {
                                        ProgressOverlay(progress: progress)
                                            .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                    }
                                }
                            .contentShape(Rectangle())
                            .onTapGesture { onOpen(true, item.index) }
                        } else {
                            let video = videos[item.index]
                            APEXMediaTile(source: .video(video.url), showVideoIcon: true, variant: .grid, showsDuration: false)
                                .frame(width: Metrics.tileSize, height: Metrics.tileSize)
                                .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                .overlay {
                                    if let progress = video.progress {
                                        ProgressOverlay(progress: progress)
                                            .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                    }
                                }
                                // Always show duration above any overlays to prevent hide after upload completes
                                .overlay(alignment: .bottomLeading) {
                                    Text(format(durationOf: video.url))
                                        .font(.caption1)
                                        .foregroundStyle(.white)
                                        .padding(12)
                                }
                            .contentShape(Rectangle())
                            .onTapGesture { onOpen(false, item.index) }
                        }
                    }
                }
            }

            // Last row special spanning when bundle count >= 4
            if !tail.isEmpty {
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    let spacing = Metrics.spacing
                    if tail.count == 1 {
                        // One item spans all 3 columns
                        let item = tail[0]
                        HStack(spacing: 0) {
                            if item.isImage {
                                let img = images[item.index]
                                APEXMediaTile(source: .image(img.data))
                                    .frame(width: totalWidth, height: Metrics.tileSize)
                                    .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                    .overlay {
                                        if let progress = img.progress {
                                            ProgressOverlay(progress: progress)
                                                .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { onOpen(true, item.index) }
                            } else {
                                let video = videos[item.index]
                                APEXMediaTile(source: .video(video.url), showVideoIcon: true, variant: .grid, showsDuration: false)
                                    .frame(width: totalWidth, height: Metrics.tileSize)
                                    .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                    .overlay {
                                        if let progress = video.progress {
                                            ProgressOverlay(progress: progress)
                                                .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                        }
                                    }
                                    .overlay(alignment: .bottomLeading) {
                                        Text(format(durationOf: video.url))
                                            .font(.caption1)
                                            .foregroundStyle(.white)
                                            .padding(12)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { onOpen(false, item.index) }
                            }
                        }
                    } else if tail.count == 2 {
                        // Two items each span 1.5 columns (half width)
                        let width = (merged.count == 2) ? Metrics.tileSize : (totalWidth - spacing) / 2
                        HStack(spacing: spacing) {
                            // If total is exactly 2, display RTL by reversing order
                            ForEach((merged.count == 2 ? Array(tail.indices.reversed()) : Array(tail.indices)), id: \.self) { j in
                                let item = tail[j]
                                if item.isImage {
                                    let img = images[item.index]
                                    APEXMediaTile(source: .image(img.data))
                                        .frame(width: width, height: Metrics.tileSize)
                                        .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                        .overlay {
                                            if let progress = img.progress {
                                                ProgressOverlay(progress: progress)
                                                    .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                            }
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture { onOpen(true, item.index) }
                                } else {
                                    let video = videos[item.index]
                                    APEXMediaTile(source: .video(video.url), showVideoIcon: true, variant: .grid, showsDuration: false)
                                        .frame(width: width, height: Metrics.tileSize)
                                        .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                        .overlay {
                                            if let progress = video.progress {
                                                ProgressOverlay(progress: progress)
                                                    .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                                            }
                                        }
                                        .overlay(alignment: .bottomLeading) {
                                            Text(format(durationOf: video.url))
                                                .font(.caption1)
                                                .foregroundStyle(.white)
                                                .padding(12)
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture { onOpen(false, item.index) }
                                }
                            }
                        }
                    }
                }
                .frame(width: (merged.count == 2) ? (Metrics.tileSize * 2 + Metrics.spacing) : (Metrics.tileSize * 3 + Metrics.spacing * 2), height: Metrics.tileSize)
            }
        }
    }
}

// FilesGrid removed: file memos upload as single-file notes

private func openFileURL(_ url: URL) {
    if FileManager.default.fileExists(atPath: url.path) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

// removed: local dismissKeyboard() in favor of UIApplication.apexDismissKeyboard()

extension Notification.Name {
    static let apexInputFocused = Notification.Name("apex.inputFocused")
    static let apexInputBlurred = Notification.Name("apex.inputBlurred")
    static let apexNavigateToNote = Notification.Name("apex.navigateToNote")
    static let apexNavigateToDate = Notification.Name("apex.navigateToDate")
    static let apexAudioRenamed = Notification.Name("apex.audioRenamed")
    static let apexAudioDeleted = Notification.Name("apex.audioDeleted")
    static let apexOpenDocumentPicker = Notification.Name("apex.openDocumentPicker")
    static let apexOpenCamera = Notification.Name("apex.openCamera")
    static let apexOpenPhotoPicker = Notification.Name("apex.openPhotoPicker")
    static let apexSendSelectedAttachments = Notification.Name("apex.sendSelectedAttachments")
    static let apexStopAllAudioPlayback = Notification.Name("apex.stopAllAudioPlayback")
    static let apexMediaSheetVisibilityChanged = Notification.Name("apex.mediaSheetVisibilityChanged")
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

// normalizeURL is provided by Presentation/Common/LinkPreviewSupport.swift

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

// (removed) SelectCopySheet

// LinkPreviewLoader moved to Presentation/Common/LinkPreviewSupport.swift

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

// LPImageFromProvider moved to Presentation/Common/LinkPreviewSupport.swift

// Helper: Host text from metadata or fallback URL
private func hostText(from meta: LPLinkMetadata?, fallback: URL) -> String {
    let urlToShow = meta?.url ?? meta?.originalURL ?? fallback
    return urlToShow.host ?? urlToShow.absoluteString
}

// subtitleText is provided by Presentation/Common/LinkPreviewSupport.swift

// (reverted) removed openURL scheme correction helper

// LinkPreviewCard is provided by Presentation/Common/LinkPreviewSupport.swift

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
        let threshold: CGFloat = 60
        let drag = DragGesture()
            .updating($dragY) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                switch mode {
                case .collapsed:
                    // Smooth snap based on where the user ended and momentum
                    let base = collapsedHeight
                    // Allow both directions while deciding snap target
                    let offset = -value.translation.height * 0.9
                    let endHeight = min(max(base + offset, 0), expandedHeight)
                    let towardExpanded = (value.predictedEndTranslation.height < -threshold) || (endHeight > (collapsedHeight + expandedHeight) / 2)
                    let towardHidden = (value.predictedEndTranslation.height > threshold) || (endHeight < collapsedHeight * 0.45)
                    if towardExpanded {
                        mode = .expanded
                    } else if towardHidden {
                        mode = .hidden
                    } else {
                        mode = .collapsed
                    }
                case .expanded:
                    // Downward drag collapses
                    let base = expandedHeight
                    let offset = -max(0, value.translation.height) * 1.0
                    let endHeight = min(max(base + offset, collapsedHeight), expandedHeight)
                    let towardCollapsed = (value.predictedEndTranslation.height > threshold) || (endHeight < (collapsedHeight + expandedHeight) / 2)
                    mode = towardCollapsed ? .collapsed : .expanded
                case .hidden:
                    break
                }
            }

        // Interactive height while dragging
        let interactiveOffset: CGFloat = {
            switch mode {
            case .collapsed:
                // Allow both: upward to expand, downward to reduce toward hidden
                let upward = min(0, dragY)     // negative or zero
                let downward = max(0, dragY)   // positive or zero
                if downward > 0 {
                    return -downward * 0.9
                } else {
                    return -upward * 0.9
                }
            case .expanded:
                // allow only downward drag (positive), decrease height down to collapsed
                let allowed = max(0, dragY)
                return -allowed * 1.0 // soften tracking
            case .hidden:
                return 0
            }
        }()
        let baseHeight = targetHeight
        let unclampedHeight = baseHeight + interactiveOffset
        let displayedHeight: CGFloat = {
            switch mode {
            case .collapsed:
                // Allow interactive growth up to expanded and reduction down to 0 while dragging
                return min(max(unclampedHeight, 0), expandedHeight)
            case .expanded:
                return min(max(unclampedHeight, collapsedHeight), expandedHeight)
            case .hidden:
                return 0
            }
        }()

        VStack(spacing: 0) {
            if mode != .expanded {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }

            content()
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(0, displayedHeight))
        .background(Color("Background"))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: -2)
        .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.92), value: mode)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.9), value: dragY)
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
        .onChange(of: dragY) { _, _ in
            // Continuously reflect current displayed height to parent while dragging
            onHeightChanged(displayedHeight, mode)
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
    ChattingView(clientId: UUID(), chatTitle: "Preview", initialNotes: [])
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

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
        _viewModel = StateObject(wrappedValue: ChattingViewModel(clientId: clientId, chatTitle: chatTitle, initialNotes: initialNotes))
    }
    @StateObject private var viewModel: ChattingViewModel
    // Custom bottom sheet state
    enum BottomSheetMode { case hidden, collapsed, expanded }
    @State private var sheetMode: BottomSheetMode = .hidden
    @State private var stagedAttachments: [ShareAttachmentItem] = []
    @State private var bottomBarOffsetY: CGFloat = 0
    @State private var timestampRevealProgress: CGFloat = 0   // 0.0 ~ 1.0
    @State var visibleDateForIndicator: Date?
    @State var isShowingDateIndicator: Bool = false
    @State var isUserScrolling: Bool = false  // 사용자 스크롤 감지용
    @State var hideIndicatorWork: DispatchWorkItem?
    @State private var didReceiveInitialPositions: Bool = false
    @State private var indicatorOffsetY: CGFloat = 0
    @State private var canScroll: Bool = false
    @State private var isAtScrollEdge: Bool = false
    @State private var chipHeight: CGFloat = 0
    @State var showScrollToBottom: Bool = false
    @State private var keyboardScrollWork: DispatchWorkItem?
    @State private var bottomInsetHeight: CGFloat = 0
    @State private var isEditorCurrentlyFocused: Bool = false
    @State private var showCopyToast: Bool = false
    @FocusState private var isSearchFieldFocused: Bool
    // Search state
    // moved into view model
    // Suppress auto-scroll-to-bottom when navigating to a specific note
    @State private var suppressAutoScroll: Bool = false
    @State private var sheetModeBeforeSearch: BottomSheetMode?
    // Date search
    @State private var showDatePicker: Bool = false
    @State private var datePickerSelection: Date = Date()
    @State var highlightedDate: Date?
    @State var dateHighlightOffsetY: CGFloat = 0
    private struct EditingPayload: Identifiable { let id = UUID(); let noteId: UUID; var text: String }
    @State private var editing: EditingPayload?
    // Ensure initial bottom scroll even with delayed layout/data updates
    @State var initialBottomScrollAttemptsRemaining: Int = 3
    // Pin the scroll position to bottom without animation during first load (e.g., CloudKit warm-up)
    @State private var isBootstrappingToBottom: Bool = true
    // Store viewport height separately to avoid multiple preference updates per frame
    @State private var storedViewportHeight: CGFloat = 0
    // Selection delete confirmation
    @State private var showSelectionDeleteAlert: Bool = false
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
    let bottomSentinelId: String = "chat-bottom-sentinel"
    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    ChatMessageListSection(
                        notes: viewModel.notes,
                        chatTitle: chatTitle,
                        clientId: clientId,
                        isDeleteSelecting: viewModel.isDeleteSelecting,
                        isSelected: { viewModel.selectedNoteIds.contains($0) },
                        onToggleSelection: { noteId in
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                viewModel.send(.toggleSelection(noteId))
                            }
                        },
                        highlightQueryFor: { noteId in
                            (
                                viewModel.isSearchActive &&
                                !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                                !viewModel.matchedNoteIds.isEmpty &&
                                viewModel.matchedNoteIds.indices.contains(viewModel.currentMatchIndex) &&
                                viewModel.matchedNoteIds[viewModel.currentMatchIndex] == noteId
                            ) ? viewModel.searchText : nil
                        },
                        isSTTLoading: { viewModel.sttInProgress.contains($0) },
                        buildViewerPayload: { anchor in
                            buildGlobalViewerPayload(startingFrom: anchor)
                        },
                        onOpenViewer: { anchor in
                            openViewer(anchor: anchor)
                        },
                        onOpenShareText: { selectedText in
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
                            viewModel.send(.deleteFile(noteId: noteId, fileIndex: fileIndex))
                        },
                        onOpenRecord: { url in
                            NotificationCenter.default.post(name: .apexStopAllAudioPlayback, object: nil)
                            recordPayload = RecordPayload(url: url)
                        },
                        onDeleteMedia: { anchor in
                            viewModel.send(.deleteMedia(anchor: anchor))
                        },
                        onDeleteAudio: { noteId, url in
                            viewModel.send(.deleteAudio(noteId: noteId, url: url))
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
                        },
                        timestampRevealProgress: timestampRevealProgress,
                        timeTextWidth: { date in timeTextWidth(for: date) },
                        timeWidth: Metrics.timeWidth,
                        timeGap: Metrics.timeGap,
                        leftSelectWidth: Metrics.leftSelectWidth,
                        bottomSentinelId: bottomSentinelId,
                        dateHeader: { date in AnyView(dateHeaderView(date)) }
                    )
                    .padding(.horizontal, 12)
                    .background(
                        GeometryReader { geo in
                            let frame = geo.frame(in: .named("chatScroll"))
                            let top = frame.minY
                            let bottom = frame.maxY
                            Color.clear.preference(
                                key: ScrollMetricsKey.self,
                                value: ScrollMetrics(topY: top, bottomY: bottom, viewportHeight: nil)
                            )
                        }
                    )
                }
                .textSelection(.disabled)
                .padding(.bottom, bottomInsetHeight + max(0, -bottomBarOffsetY))
                .coordinateSpace(name: "chatScroll")
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.visible)
                .ignoresSafeArea(.keyboard) // Prevent double lift: we manually pad for the input bar
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: ViewportHeightKey.self, value: geo.size.height)
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
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { _ in
                            // 사용자가 스크롤 중임을 감지
                            if !isUserScrolling {
                                isUserScrolling = true
                            }
                        }
                        .onEnded { _ in
                            // 스크롤 제스처가 끝나면 잠시 후 상태 리셋
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isUserScrolling = false
                            }
                        }
                )
                .onAppear {
                    DispatchQueue.main.async {
                        // Pin bottom during bootstrapping window to avoid visible jumps
                        isBootstrappingToBottom = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            isBootstrappingToBottom = false
                        }
                        // Capture pending initial target (if any) from router once
                        if initialTargetNoteId == nil, let pending = router.pendingScrollToNoteId {
                            initialTargetNoteId = pending
                            router.pendingScrollToNoteId = nil
                        }
                        viewModel.send(.onAppear)
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
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                proxy.scrollTo(bottomSentinelId, anchor: .bottom)
                            }
                            ensureInitialScrollToBottom(proxy)
                        }
                        viewModel.send(.kickOffPendingUploadsIfNeeded)
                    }
                }
                .onChange(of: viewModel.notes.count) { _ in
                    guard !suppressAutoScroll else { return }
                    // 1) 즉시 비애니메이션 스크롤(레이아웃 완료 전에도 가능한 한 빠르게 고정)
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        proxy.scrollTo(bottomSentinelId, anchor: .bottom)
                    }
                    self.showScrollToBottom = false
                    // 2) 레이아웃 정착 직후 한 번 더 보정
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        var tx2 = Transaction()
                        tx2.disablesAnimations = true
                        withTransaction(tx2) {
                            proxy.scrollTo(bottomSentinelId, anchor: .bottom)
                        }
                    }
                }
                // If CloudKit mutates notes without changing count (e.g., text/attachments), still keep to bottom on initial load
                .onChange(of: viewModel.notes.last?.id) { _ in
                    guard !suppressAutoScroll else { return }
                    guard !showScrollToBottom else { return }
                    // 즉시 비애니메이션 스크롤
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        proxy.scrollTo(bottomSentinelId, anchor: .bottom)
                    }
                    // 짧은 지연 후 재시도로 보정
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        var tx2 = Transaction()
                        tx2.disablesAnimations = true
                        withTransaction(tx2) {
                            proxy.scrollTo(bottomSentinelId, anchor: .bottom)
                        }
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
                    let deltaX = value.translation.width
                    let deltaY = value.translation.height
                    guard abs(deltaX) > abs(deltaY) else { return }
                    if deltaX < 0 {
                        let progress = min(1, max(0, -deltaX / 80))
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
            updateScrollDateIndicator(with: positions)
        }
        .onPreferenceChange(ScrollMetricsKey.self) { metrics in
            // Compute thumb-aligned vertical offset for the indicator
            guard let topY = metrics.topY, let bottomY = metrics.bottomY else { return }
            let viewport = storedViewportHeight
            guard viewport > 0 else { return }
            let contentHeight = bottomY - topY
            guard contentHeight > 0 else { return }
            let newCanScroll = (contentHeight - viewport) > 1
            if canScroll != newCanScroll { canScroll = newCanScroll }

            // Offset/progress within scrollable range
            let maxOffset = max(contentHeight - viewport, 1)
            let offset = min(max(-topY, 0), maxOffset)
            let progress = min(max(offset / maxOffset, 0), 1)

            // Detect rubber-band overscroll to clamp visually at edges
            let overscrollTop = topY > 0
            let overscrollBottom = bottomY < viewport
            let verticalPadding: CGFloat = 8
            let trackHeight = max(viewport - verticalPadding * 2, 0)
            let clampedProgress: CGFloat = overscrollTop ? 0 : (overscrollBottom ? 1 : progress)

            // Estimate the scrollbar thumb height (proportional to viewport/content), with a reasonable minimum
            let estimatedThumbHeight = max(24, trackHeight * (viewport / max(contentHeight, 1)))

            // Align chip center with the thumb center:
            // thumbCenter = verticalPadding + clampedProgress * (trackHeight - estimatedThumbHeight) + estimatedThumbHeight/2
            // chipTop = thumbCenter - chipHeight/2
            let chipH = max(chipHeight, 0)
            let thumbTravel = max(trackHeight - estimatedThumbHeight, 0)
            let thumbCenter = verticalPadding + clampedProgress * thumbTravel + estimatedThumbHeight / 2
            let desiredTop = thumbCenter - chipH / 2

            let minTop = verticalPadding
            let maxTop = verticalPadding + max(trackHeight - chipH, 0)
            indicatorOffsetY = min(max(desiredTop, minTop), maxTop)

            // Show while scrolling; auto-hide after idle
            if visibleDateForIndicator == nil {
                // Fallback: when headers are not yet realized, seed with a known date
                visibleDateForIndicator = viewModel.notes.last?.uploadedAt ?? viewModel.notes.first?.uploadedAt
            }
            // 실제로 사용자가 스크롤하는 중일 때만 표시
            if isUserScrolling && visibleDateForIndicator != nil {
                isShowingDateIndicator = true
                hideIndicatorWork?.cancel()
                let work = DispatchWorkItem { self.isShowingDateIndicator = false }
                hideIndicatorWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
            }

            // Update visibility for scroll-to-bottom chevron based on content length and distance from bottom
            let minDistanceToShow: CGFloat = 200     // Show when at least 200pt above bottom
            let distanceFromBottom = maxOffset - offset   // Remaining scrollable distance to bottom (pt)
            let sufficientlyAboveBottom = distanceFromBottom > minDistanceToShow
            let atBottom = overscrollBottom || distanceFromBottom <= 4
            showScrollToBottom = (canScroll && sufficientlyAboveBottom) && !atBottom
        }
        .onPreferenceChange(ChipHeightKey.self) { newHeight in
            if newHeight > 0 { chipHeight = newHeight }
        }
        .onPreferenceChange(ViewportHeightKey.self) { newHeight in
            let height = max(0, newHeight)
            // Avoid same-frame feedback loops by ignoring no-op changes and deferring the state write
            guard abs(height - storedViewportHeight) > 0.5 else { return }
            DispatchQueue.main.async {
                storedViewportHeight = height
            }
        }
        .onChange(of: viewModel.isSearchActive) { _, active in
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
                viewModel.searchText = ""
                viewModel.matchedNoteIds.removeAll()
                viewModel.currentMatchIndex = 0
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
            if viewModel.isSearchActive {
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
            } else if viewModel.isDeleteSelecting {
                APEXSheetTopBar(
                    title: "삭제",
                    rightTitle: "선택 해제",
                    isRightEnabled: !viewModel.selectedNoteIds.isEmpty,
                    onRightTap: {
                        viewModel.selectedNoteIds.removeAll()
                    },
                    onClose: {
                        viewModel.send(.cancelDeleteSelection)
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
                        onSearch: { withAnimation { viewModel.isSearchActive = true } },
                        onMenu: { router.push(.chatArchive(clientId)) }
                    )
                )
            }
        }
        .safeAreaBar(edge: .bottom) {
            if viewModel.isDeleteSelecting {
                // Bottom action bar for selection delete
                Button {
                    showSelectionDeleteAlert = true
                } label: {
                    Text("\(viewModel.selectedNoteIds.count) 삭제하기")
                        .font(.body2)
                        .foregroundColor(viewModel.selectedNoteIds.isEmpty ? Color("BackgroundDisabled") : Color("Error"))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(viewModel.selectedNoteIds.isEmpty ? Color("BackgroundSecondary") : Color("ErrorContainer"))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .disabled(viewModel.selectedNoteIds.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !viewModel.isDeleteSelecting {
                VStack(spacing: 8) {
                    if viewModel.isSearchActive {
                        APEXSearchBar(
                            text: $viewModel.searchText,
                            isFocused: _isSearchFieldFocused,
                            onPrev: { viewModel.send(.navigateToPrevMatch) },
                            onNext: { viewModel.send(.navigateToNextMatch) },
                            onClose: {
                                isSearchFieldFocused = false
                                withAnimation { viewModel.isSearchActive = false }
                                viewModel.searchText = ""
                                viewModel.matchedNoteIds.removeAll()
                            },
                            onTextChange: { _ in
                                viewModel.send(.recomputeMatches)
                                viewModel.send(.scrollToCurrentMatch)
                            }
                        )
                    } else {
                        if !stagedAttachments.isEmpty {
                            AttachBar(items: stagedAttachments) { removed in
                                stagedAttachments.removeAll { $0.id == removed.id }
                            }
                        }

                        InputBar({ note in
                            viewModel.send(.handleIncoming(note))
                        }, onSheetVisibilityChanged: { visible in
                         // If in delete selection mode, force sheet hidden and ignore requests
                         if viewModel.isDeleteSelecting {
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
                        }, ownerClientId: clientId)
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

                    BottomSheetHost(
                        mode: $sheetMode,
                        onHeightChanged: { height, mode in
                            // When partially up, lift the input bar together; when fully expanded, keep input bar at bottom
                            if mode == .collapsed {
                                bottomBarOffsetY = -(height + 8)
                            } else {
                                bottomBarOffsetY = 0
                            }
                        },
                        content: {
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
                    )
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
        .onChange(of: viewModel.isDeleteSelecting) { _, selecting in
            if selecting {
                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.2)) {
                    sheetMode = .hidden
                    bottomBarOffsetY = 0
                }
            }
        }
        .onPreferenceChange(BottomInsetHeightKey.self) { height in bottomInsetHeight = height }
        .alert("\(viewModel.selectedNoteIds.count)개의 노트를 삭제하겠습니까?", isPresented: $showSelectionDeleteAlert) {
            Button("삭제", role: .destructive) {
                viewModel.send(.performDeleteSelected)
            }
            Button("취소", role: .cancel) { }
        }
        .sheet(item: $editing) { payload in
            TextEditSheet(
                initialText: payload.text,
                onCancel: { editing = nil },
                onSave: { newText in
                    viewModel.send(.editNoteText(noteId: payload.noteId, newText: newText))
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
                    viewModel.send(.deleteNote(noteId: payload.noteId))
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
                    if let resolvedType = type, resolvedType.conforms(to: .image), let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                        items.append(ShareAttachmentItem(id: UUID(), kind: .image(image)))
                    } else if let resolvedType = type, resolvedType.conforms(to: .movie) || resolvedType.conforms(to: .audiovisualContent) {
                        let thumb = generateThumbnail(for: url)
                        items.append(ShareAttachmentItem(id: UUID(), kind: .video(url, thumbnail: thumb)))
                    } else {
                        items.append(ShareAttachmentItem(id: UUID(), kind: .file(url)))
                    }
                }
                // Also include any explicitly provided images/videos (if present)
                for image in seed.images {
                    items.append(ShareAttachmentItem(id: UUID(), kind: .image(image)))
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
            let memoDays: Set<Date> = Set(viewModel.notes.map { Calendar.current.startOfDay(for: $0.uploadedAt) })
            ChatDatePickerSheet(date: $datePickerSelection, hasMemoDays: memoDays, onClose: {
                showDatePicker = false
            }, onSelect: { selected in
                showDatePicker = false
                highlightedDate = selected
                triggerDateBounce()
                NotificationCenter.default.post(name: .apexNavigateToDate, object: nil, userInfo: ["date": selected])
            })
            .presentationDetents([.height(369)])
            .presentationDragIndicator(.hidden)
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
        viewModel.send(.startDeleteSelection(noteId))
    }
    func buildGlobalViewerPayload(startingFrom anchor: ChatMessageView.ChatAnchor) -> MediaGalleryPayload {
        var allItems: [MediaSource] = []
        var allAnchors: [ChatMessageView.ChatAnchor] = []
        for noteItem in viewModel.notes {
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
        return MediaGalleryPayload(items: allItems, anchors: allAnchors, index: start)
    }

    private func openViewer(anchor: ChatMessageView.ChatAnchor) {
        let payload = buildGlobalViewerPayload(startingFrom: anchor)
        let currentAnchor = payload.anchors.indices.contains(payload.index) ? payload.anchors[payload.index] : nil
        let initialUploadedAt = currentAnchor.flatMap { anchor in
            viewModel.notes.first(where: { $0.id == anchor.noteId })?.uploadedAt
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
                viewModel.send(.deleteMedia(anchor: anchor))
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

#Preview {
    NavigationStack {
        ChattingView(
            clientId: UUID(), 
            chatTitle: "테스트 채팅", 
            initialNotes: [
                Note(
                    id: UUID(),
                    uploadedAt: Date(),
                    text: "안녕하세요! 테스트 메시지입니다.",
                    bundle: nil
                ),
                Note(
                    id: UUID(),
                    uploadedAt: Date().addingTimeInterval(-3600),
                    text: "이전 메시지 예시",
                    bundle: nil
                )
            ]
        )
    }
    .environmentObject(NavigationRouter())
    .previewDisplayName("채팅뷰 프리뷰")
}

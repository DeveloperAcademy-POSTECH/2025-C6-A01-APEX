//
//  InputBar.swift
//  APEX
//
//  Created by 조운경 on 10/26/25.
//

import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import Photos

// MARK: - Transferables

private struct PickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { exporting in
            .init(exporting.url)
        } importing: { received in
            let src = received.file
            let ext = src.pathExtension.isEmpty ? "mov" : src.pathExtension
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)

            var started = false
            if src.startAccessingSecurityScopedResource() {
                started = true
            }
            defer {
                if started { src.stopAccessingSecurityScopedResource() }
            }

            do {
                try? FileManager.default.removeItem(at: tmp)
                try FileManager.default.copyItem(at: src, to: tmp)
                return PickedVideo(url: tmp)
            } catch {
                // 최후 수단: 데이터를 읽어서 tmp에 기록
                do {
                    let data = try Data(contentsOf: src)
                    try data.write(to: tmp, options: .atomic)
                    return PickedVideo(url: tmp)
                } catch {
                    // 그래도 실패하면 로드를 포기(원본 URL 반환하지 않음)
                    throw error
                }
            }
        }
    }
}

// MARK: - InputBar logic (moved out for lint compliance)
private extension InputBar {
    func calculateHeight() {
        // Subtract internal left padding and the reserved trailing space for the right button
        let contentInsets: CGFloat = (editorLeftPadding / 2) + editorRightPaddingForButton
        // Also subtract a small bias so wrapping happens slightly earlier to match visual behavior
        let effectiveWidth = max(0, (editorAvailableWidth ?? maxTextWidth) - contentInsets - editorInternalPaddingBias)
        let lineCount = autoLineCount(text: memo, font: font, maxTextWidth: effectiveWidth)
        currentLineCount = Int(lineCount)
        let lineHeight = font.lineHeight
        let verticalPadding: CGFloat = editorVerticalPadding * 2 // matches .padding top/bottom
        let minHeight: CGFloat = 48

        // Cap visible height at 5 lines; show expand button when exceeded
        let visibleLines = min(lineCount, 5)
        let contentHeight = lineHeight * visibleLines + verticalPadding
        textHeight = max(minHeight, contentHeight)
    }

    private func autoLineCount(text: String, font: UIFont, maxTextWidth: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 1 }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.hyphenationFactor = 0 // 필요시 0~1로 조정

        let attr = NSAttributedString(
            string: text,
            attributes: [.font: font, .paragraphStyle: paragraph]
        )
        let rect = attr.boundingRect(
            with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return max(1, ceil(rect.height / font.lineHeight))
    }

    func sendText() {
        let text = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stagedAttachments.isEmpty {
            sendSelectedAttachmentsAndText()
            return
        }
        guard !text.isEmpty else { return }
        let note = Note(uploadedAt: Date(), text: text, bundle: nil)
        onSend(note)
        memo = ""
        showActions = false
        isEditorFocused = false
    }

    func sendSelectedAttachmentsAndText() {
        // Build attachments from staged items
        var images: [ImageAttachment] = []
        var videos: [VideoAttachment] = []
        var orderCounter = 0
        for item in stagedAttachments {
            switch item.kind {
            case .image(let uiImage):
                if let data = uiImage.jpegData(compressionQuality: 0.9) ?? uiImage.pngData() {
                    images.append(ImageAttachment(data: data, progress: 0, orderIndex: orderCounter))
                    orderCounter += 1
                }
            case .video(let urlOpt, _):
                if let url = urlOpt {
                    videos.append(VideoAttachment(url: url, progress: 0, orderIndex: orderCounter))
                    orderCounter += 1
                }
            }
        }

        let text = memo.trimmingCharacters(in: .whitespacesAndNewlines)

        if images.isEmpty && videos.isEmpty && text.isEmpty {
            return
        }

        let bundle: AttachmentBundle? =
            (images.isEmpty && videos.isEmpty)
            ? nil
            : .media(images: images, videos: videos)
        let note = Note(uploadedAt: Date(), text: text.isEmpty ? nil : text, bundle: bundle)
        onSend(note)

        // Reset UI state
        memo = ""
        stagedAttachments.removeAll()
        isMediaSheetPresented = false
        shouldRestoreMediaSheetAfterKeyboard = false
        showActions = false
        isEditorFocused = false
    }

    @MainActor
    func handlePicked(items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        var images: [ImageAttachment] = []
        var videos: [VideoAttachment] = []
        var failedCount: Int = 0

        for (selectionIndex, item) in items.enumerated() {
            var handled = false

            // 1) Try robust video import using custom Transferable (copies into tmp)
            if let pickedVideo = try? await item.loadTransferable(type: PickedVideo.self) {
                videos.append(VideoAttachment(url: pickedVideo.url, progress: 0, orderIndex: selectionIndex))
                handled = true
            }

            // 2) If not handled as video, try raw Data (image most common; can also be video data in some cases)
            if !handled, let data = try? await item.loadTransferable(type: Data.self) {
                if UIImage(data: data) != nil {
                    images.append(ImageAttachment(data: data, progress: 0, orderIndex: selectionIndex))
                    handled = true
                } else {
                    // Data that isn't an image: treat as movie by writing to tmp (best-effort)
                    let tmp = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("mov")
                    do {
                        try data.write(to: tmp, options: .atomic)
                        videos.append(VideoAttachment(url: tmp, progress: 0, orderIndex: selectionIndex))
                        handled = true
                    } catch {
                        // fall through
                    }
                }
            }

            // 3) (removed) UIImage does not conform to Transferable; rely on Data/URL fallbacks

            // 4) Last resort: try URL and copy out to a tmp file
            if !handled, let url = try? await item.loadTransferable(type: URL.self) {
                let ext = url.pathExtension.lowercased()
                var started = false
                if url.startAccessingSecurityScopedResource() { started = true }
                defer { if started { url.stopAccessingSecurityScopedResource() } }

                if ["mov", "mp4", "m4v", "avi", "hevc", "heif", "heic"].contains(ext) {
                    // Treat as video; copy to tmp to avoid sandbox issues later
                    let tmp = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(ext.isEmpty ? "mov" : ext)
                    do {
                        try? FileManager.default.removeItem(at: tmp)
                        try FileManager.default.copyItem(at: url, to: tmp)
                        videos.append(VideoAttachment(url: tmp, progress: 0, orderIndex: selectionIndex))
                        handled = true
                    } catch {
                        // fall through
                    }
                }

                if !handled {
                    // Try reading as image data
                    if let data = try? Data(contentsOf: url), UIImage(data: data) != nil {
                        images.append(ImageAttachment(data: data, progress: 0, orderIndex: selectionIndex))
                        handled = true
                    }
                }
            }

            if !handled { failedCount += 1 }
        }

        guard !images.isEmpty || !videos.isEmpty else {
            if failedCount > 0 {
                presentToast(text: "선택한 항목 중 \(failedCount)개를 불러오지 못했어요.", buttonTitle: "확인", action: {})
            }
            return
        }
        // Progress and orderIndex already assigned
        let note = Note(uploadedAt: Date(), text: nil, bundle: .media(images: images, videos: videos))
        onSend(note)
        pickedItems.removeAll()
        showActions = false
        isEditorFocused = false
        if failedCount > 0 {
            presentToast(text: "일부 항목(\(failedCount)개)을 불러올 수 없어 제외했어요.", buttonTitle: "확인", action: {})
        }
    }

    // MARK: - Permission handling with contextual messages (Chat)

    func handleAlbumTap() {
        isMediaSheetPresented = true
    }

    func handleCameraTap() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            CameraManager.shared.prewarmIfPossible()
            showCamera = true
        case .notDetermined:
            presentToast(
                text: "채팅에서 촬영하여 보내려면 카메라 권한이 필요합니다.",
                buttonTitle: "허용하기"
            ) {
                Task {
                    let granted = await AVCaptureDevice.requestAccess(for: .video)
                    if granted {
                        CameraManager.shared.prewarmIfPossible()
                        showCamera = true
                    }
                }
            }
        case .denied, .restricted:
            presentToast(
                text: "카메라 접근이 차단되어 있어요. 설정 > APEX에서 권한을 허용해 주세요.",
                buttonTitle: "설정 열기"
            ) {
                openAppSettings()
            }
        @unknown default:
            showCamera = true
        }
    }

    func handleFilesTap() {
        showDocumentPicker = true
    }

    func presentToast(text: String, buttonTitle: String, action: @escaping () -> Void) {
        toastText = text
        toastButtonTitle = buttonTitle
        toastAction = action
        withAnimation { showToast = true }
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

struct InputBar: View {
    @State private var memo: String = ""
    @State private var showActions: Bool = false
    @FocusState private var isEditorFocused: Bool
    // TextEditor (fixed height)

    // constants kept for placeholder alignment only
    private let editorLeftPadding: CGFloat = 16
    private let editorVerticalPadding: CGFloat = 16
    private let editorRightPaddingForButton: CGFloat = 56
    // Bias to account for internal TextEditor text container padding and rounding
    private let editorInternalPaddingBias: CGFloat = 10.5
    private let font: UIFont = UIFont(name: "PretendardVariable-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
    private var maxTextWidth: CGFloat { UIScreen.main.bounds.width - 16 - editorRightPaddingForButton - 32 }
    @State private var textHeight: CGFloat = 48
    @State private var currentLineCount: Int = 1
    @State private var editorAvailableWidth: CGFloat?

    // Album
    @State private var showPhotoPicker: Bool = false
    @State private var pickedItems: [PhotosPickerItem] = []
    @AppStorage("apex.albumPermissionShown") private var albumPermissionShown: Bool = false

    // Camera
    @State private var showCamera: Bool = false

    // Files
    @State private var showDocumentPicker: Bool = false

    // Audio recording
    @State private var isRecording: Bool = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var levelTimer: Timer?
    @State private var waveformLevels: [CGFloat] = []
    private let maxWaveformBars: Int = 40
    @State private var recordingURL: URL?
    @State private var recordingDuration: TimeInterval = 0
    @State private var wavePhase: CGFloat = 0

    // Media sheet (album/camera/files)
    @State private var isMediaSheetPresented: Bool = false
    // Remember the last partial offset to keep position stable when toggling detents
    @State private var lastPartialBarOffset: CGFloat = 0
    // Restore media sheet after keyboard hides if it was temporarily dismissed
    @State private var shouldRestoreMediaSheetAfterKeyboard: Bool = false
    // (reverted) no combined sheet/keyboard lifts
    // Restore editor focus after sheet closes if we opened sheet while focused
    @State private var shouldRestoreEditorAfterSheet: Bool = false

    // Placeholder text adapts when media sheet is presented
    private var placeholderText: String {
        isMediaSheetPresented ? "(선택) 메모 입력" : "메모 입력"
    }

    // Expanded editor sheet
    @State private var isExpandedEditorPresented: Bool = false
    @State private var shouldFocusExpandedEditor: Bool = false

    // Left button accessibility label
    private var leftButtonA11yLabel: String {
        return (isMediaSheetPresented || shouldRestoreMediaSheetAfterKeyboard) ? "닫기" : "추가"
    }

    private var leftButtonRotation: Angle {
        (isMediaSheetPresented || shouldRestoreMediaSheetAfterKeyboard) ? .degrees(45) : .degrees(0)
    }

    private func handleLeftButtonTap() {
        let animation = Animation.interactiveSpring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.2)
        withAnimation(animation) {
            if isMediaSheetPresented {
                // Closing sheet: restore focus if we opened it while focused
                isMediaSheetPresented = false
                if shouldRestoreEditorAfterSheet {
                    shouldRestoreEditorAfterSheet = false
                    DispatchQueue.main.async { isEditorFocused = true }
                }
            } else {
                // Opening sheet: remember focus and hide keyboard
                shouldRestoreEditorAfterSheet = isEditorFocused
                shouldRestoreMediaSheetAfterKeyboard = false
                isEditorFocused = false
                isMediaSheetPresented = true
            }
        }
    }

    @ViewBuilder
    private func rightActionButton() -> some View {
        if !stagedAttachments.isEmpty {
            Button { sendSelectedAttachmentsAndText() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Color("Primary"))
                    .clipShape(Circle())
                    .glassEffect()
            }
            .buttonStyle(FloatingCirclePrimaryButtonStyle())
            .accessibilityLabel(Text("업로드"))
            .transition(.scale.combined(with: .opacity))
        } else if memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button {
                if isRecording { stopRecordingAndSend() } else { startRecording() }
            } label: {
                Image(systemName: isRecording ? "stop.fill" : "waveform")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(isRecording ? Color("Primary") : .black)
                    .clipShape(Circle())
                    .glassEffect()
            }
            .buttonStyle(FloatingCirclePrimaryButtonStyle())
            .accessibilityLabel(Text(isRecording ? "녹음 중지" : "음성 입력"))
            .transition(.scale.combined(with: .opacity))
        } else {
            Button { sendText() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Color("Primary"))
                    .clipShape(Circle())
                    .glassEffect()
            }
            .buttonStyle(FloatingCirclePrimaryButtonStyle())
            .accessibilityLabel(Text("보내기"))
            .transition(.scale.combined(with: .opacity))
        }
    }

    // Send hook
    var onSend: (Note) -> Void = { _ in }
    var onSheetVisibilityChanged: (Bool) -> Void = { _ in }
    @Binding var stagedAttachments: [ShareAttachmentItem]
    var onBarOffsetChanged: (CGFloat) -> Void = { _ in }

    // Custom initializer to allow trailing closure usage and extra callbacks
    init(
        _ onSend: @escaping (Note) -> Void = { _ in },
        onSheetVisibilityChanged: @escaping (Bool) -> Void = { _ in },
        stagedAttachments: Binding<[ShareAttachmentItem]> = .constant([]),
        onBarOffsetChanged: @escaping (CGFloat) -> Void = { _ in }
    ) {
        self.onSend = onSend
        self.onSheetVisibilityChanged = onSheetVisibilityChanged
        self._stagedAttachments = stagedAttachments
        self.onBarOffsetChanged = onBarOffsetChanged
    }
    // Toast state
    @State private var showToast: Bool = false
    @State private var toastText: String = ""
    @State private var toastButtonTitle: String = "확인"
    @State private var toastAction: () -> Void = {}

    var body: some View {
        VStack {
            HStack(alignment: .bottom, spacing: 4) {
                if isRecording {
                    // 왼쪽 버튼 자리부터 텍스트 에디터 영역까지 사인 파형으로 덮기
                    ZStack(alignment: .bottomTrailing) {
                        HStack(alignment: .center, spacing: 4) {
                            SineWaveRow(levels: waveformLevels, phase: wavePhase)
                                .frame(maxWidth: .infinity)
                                .frame(height: textHeight)

                            Text(formatDurationString(recordingDuration))
                                .font(.caption1)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isMediaSheetPresented {
                                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.2)) {
                                    isMediaSheetPresented = false
                                }
                            }
                        }
                        .padding(.leading, 0)
                        .padding(.trailing, editorRightPaddingForButton)
                        .glassEffect(
                            in: UnevenRoundedRectangle(
                                topLeadingRadius: 4,
                                bottomLeadingRadius: 4,
                                bottomTrailingRadius: 32,
                                topTrailingRadius: 32
                            )
                        )

                        rightActionButton()
                    }
                } else {
                    // Plus button (toggle attachments)
                    Button {
                        handleLeftButtonTap()
                    } label: {
                        Image(systemName: "plus")
                            .rotationEffect(leftButtonRotation)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 48, height: 48)
                            .glassEffect()
                            .accessibilityLabel(Text(leftButtonA11yLabel))
                    }

                    ZStack(alignment: .bottomTrailing) {
                        TextEditor(text: $memo)
                            .font(.body6)
                            .scrollContentBackground(.hidden)
                            .scrollDisabled(currentLineCount <= 5)
                            .focused($isEditorFocused)
                            .padding(.top, editorVerticalPadding / 2)
                            .padding(.leading, editorLeftPadding / 2)
                            .padding(.trailing, editorRightPaddingForButton)
                            .frame(maxWidth: .infinity)
                            .frame(height: textHeight)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear
                                        .onAppear { editorAvailableWidth = proxy.size.width }
                                        .onChange(of: proxy.size.width) { _, newWidth in editorAvailableWidth = newWidth }
                                }
                            )
                            .onAppear {
                                calculateHeight()
                            }
                            .onChange(of: memo) { _, _ in
                                calculateHeight()
                            }
                            .glassEffect(
                                in: UnevenRoundedRectangle(
                                    topLeadingRadius: 4,
                                    bottomLeadingRadius: 4,
                                    bottomTrailingRadius: 32,
                                    topTrailingRadius: 32
                                )
                            )
                            .overlay(alignment: .bottomLeading) {
                                if memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(placeholderText)
                                        .font(.body6)
                                        .foregroundColor(Color.gray.opacity(0.6))
                                        .padding(.vertical, editorVerticalPadding)
                                        .padding(.leading, editorLeftPadding)
                                        .padding(.trailing, editorRightPaddingForButton)   // 버튼 패딩과 동일
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                        .contentTransition(.identity)      // 전환 비활성화
                                        .animation(nil, value: memo)       // 텍스트 변화 애니메이션 비활성화
                                        .allowsHitTesting(false)
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                if currentLineCount > 4 {
                                    Button {
                                        shouldFocusExpandedEditor = isEditorFocused
                                        isExpandedEditorPresented = true
                                    } label: {
                                        Image(systemName: "arrow.down.left.and.arrow.up.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Color("Primary"))
                                            .padding(8)
                                    }
                                    .padding(.top, 8)
                                    .padding(.trailing, 8)
                                    .accessibilityLabel(Text("확장"))
                                }
                            }

                        rightActionButton()
                    }
                }
            }
        }
        .padding(8)
        // Media picker sheet moved to parent (ChattingView)
        // Listen to commands from parent to trigger internal pickers/actions
        .onReceive(NotificationCenter.default.publisher(for: .apexOpenDocumentPicker)) { _ in
            showDocumentPicker = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .apexOpenCamera)) { _ in
            CameraManager.shared.prewarmIfPossible()
            showCamera = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .apexOpenPhotoPicker)) { _ in
            showPhotoPicker = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .apexSendSelectedAttachments)) { _ in
            sendSelectedAttachmentsAndText()
        }
        // Expanded text editor sheet
        .sheet(isPresented: $isExpandedEditorPresented) {
            ExpandedEditorSheet(
                text: $memo,
                shouldFocusOnAppear: shouldFocusExpandedEditor,
                onUpload: {
                    sendText()
                },
                onClose: {
                    isExpandedEditorPresented = false
                }
            )
            .presentationDetents([.large])
        }
        // Album picker
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $pickedItems,
            maxSelectionCount: 24,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: isMediaSheetPresented) { _, visible in
            onSheetVisibilityChanged(visible)
            if !visible && !isEditorFocused { onBarOffsetChanged(0) }
            if !visible && !isEditorFocused {
                shouldRestoreMediaSheetAfterKeyboard = false
            }
        }
        // (reverted) removed external sheet dismiss via notification
        .onChange(of: isEditorFocused) { _, focused in
            if focused {
                // Notify chat view to scroll when editor gains focus
                NotificationCenter.default.post(name: .apexInputFocused, object: nil)
                shouldRestoreMediaSheetAfterKeyboard = isMediaSheetPresented
                if isMediaSheetPresented {
                    isMediaSheetPresented = false
                }
            } else {
                // Notify chat view when editor loses focus
                NotificationCenter.default.post(name: .apexInputBlurred, object: nil)
                if shouldRestoreMediaSheetAfterKeyboard {
                    isMediaSheetPresented = true
                    shouldRestoreMediaSheetAfterKeyboard = false
                }
            }
        }
        // Rely on SwiftUI's keyboard-safe-area handling via safeAreaInset in parent.
        .onChange(of: pickedItems) { _, newItems in
            Task { await handlePicked(items: newItems) }
        }
        // Camera sheet
        .fullScreenCover(isPresented: $showCamera) {
            ChatCameraPicker { image, videoURL in
                var images: [ImageAttachment] = []
                var videos: [VideoAttachment] = []
                var orderCounter = 0
                if let img = image, let data = img.jpegData(compressionQuality: 0.9) {
                    images.append(ImageAttachment(data: data, progress: 0, orderIndex: orderCounter))
                    orderCounter += 1
                }
                if let url = videoURL {
                    videos.append(VideoAttachment(url: url, progress: 0, orderIndex: orderCounter))
                    orderCounter += 1
                }
                guard !images.isEmpty || !videos.isEmpty else { return }
                // Already assigned progress and orderIndex above; keep as-is
                let note = Note(uploadedAt: Date(), text: nil, bundle: .media(images: images, videos: videos))
                onSend(note)
                showActions = false
                isEditorFocused = false
            }
            .ignoresSafeArea()
        }
        // Contextual toast
        .apexToast(
            isPresented: $showToast,
            image: Image(systemName: "info.circle.fill"),
            text: toastText,
            buttonTitle: toastButtonTitle,
            duration: 3.0
        ) {
            toastAction()
        }
        .onDisappear { cleanupRecording() }
        // Files picker
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { urls in
                // Map picked URLs to FileAttachment and send
                let files: [FileAttachment] = urls.map {
                    let type = try? $0.resourceValues(forKeys: [.contentTypeKey]).contentType
                    return FileAttachment(url: $0, contentType: type, progress: 0)
                }
                guard !files.isEmpty else { return }
                let note = Note(uploadedAt: Date(), text: nil, bundle: .files(files))
                onSend(note)
                showActions = false
                isEditorFocused = false
            }
        }
    }

    func formatDurationString(_ time: TimeInterval) -> String {
        let total = Int(time.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Expanded Editor Sheet
private struct ExpandedEditorSheet: View {
    @Binding var text: String
    let shouldFocusOnAppear: Bool
    var onUpload: () -> Void
    var onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    TextEditor(text: $text)
                        .font(.body6)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .focused($isFocused)
                    Spacer(minLength: 0)
                }

                Button {
                    onUpload()
                    dismiss()
                    onClose()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(FloatingCirclePrimaryButtonStyle())
                .padding(.trailing, 20)
                .padding(.bottom, 28)
                .accessibilityLabel(Text("업로드"))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                        onClose()
                    } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            if shouldFocusOnAppear {
                DispatchQueue.main.async { isFocused = true }
            }
        }
    }
}

private struct FloatingCirclePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle().fill(configuration.isPressed ? Color("PrimaryHover") : Color("Primary"))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    InputBar()
}

// UIKit camera bridge
struct ChatCameraPicker: UIViewControllerRepresentable {
    var onPicked: (UIImage?, URL?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
        picker.videoQuality = .typeHigh
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onPicked: (UIImage?, URL?) -> Void
        init(onPicked: @escaping (UIImage?, URL?) -> Void) { self.onPicked = onPicked }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            defer { picker.dismiss(animated: true) }
            if let url = info[.mediaURL] as? URL {
                onPicked(nil, url)
                return
            }
            if let image = info[.originalImage] as? UIImage {
                onPicked(image, nil)
            }
        }
    }
}

// UIKit document picker bridge
private struct DocumentPickerView: UIViewControllerRepresentable {
    var onPicked: ([URL]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: ([URL]) -> Void
        init(onPicked: @escaping ([URL]) -> Void) { self.onPicked = onPicked }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPicked(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}

// GrowingTextView removed (revert)

// removed WidthReader (no dynamic sizing)
// MARK: - SteppedGrowingTextView

struct SteppedGrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    let rightPadding: CGFloat
    let maxLines: Int

    private let font: UIFont = UIFont(name: "PretendardVariable-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14) ?? .systemFont(ofSize: 14, weight: .regular)
    private let baseInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 0)

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = font
        textView.isScrollEnabled = false
        textView.textContainerInset = baseInsets.adjusting(right: rightPadding)
        textView.textContainer.lineFragmentPadding = 4
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
        recalcHeight(for: uiView)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    private func recalcHeight(for textView: UITextView) {
        let lineHeight = font.lineHeight
        let maxHeight = lineHeight * CGFloat(max(1, maxLines)) + baseInsets.top + baseInsets.bottom

        let fitting = textView
            .sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude))
            .height
        // Compute number of lines required, rounded up
        let contentLines = max(1, Int(ceil((fitting - baseInsets.top - baseInsets.bottom) / lineHeight)))
        let clampedLines = min(contentLines, maxLines)
        let stepped = lineHeight * CGFloat(clampedLines) + baseInsets.top + baseInsets.bottom

        let clampedHeight = min(stepped, maxHeight)
        if abs(height - clampedHeight) > 0.5 {
            DispatchQueue.main.async { self.height = clampedHeight }
        }

        textView.isScrollEnabled = contentLines > maxLines
        let currentInsets = textView.textContainerInset
        let desired = baseInsets.adjusting(right: rightPadding)
        if currentInsets != desired { textView.textContainerInset = desired }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: SteppedGrowingTextView
        init(_ parent: SteppedGrowingTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.recalcHeight(for: textView)
        }
    }
}

private extension UIEdgeInsets {
    func adjusting(right: CGFloat) -> UIEdgeInsets {
        UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
    }
}

// MARK: - Recording helpers & waveform

private extension InputBar {
    func startRecording() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                guard granted else {
                    presentToast(
                        text: "마이크 접근이 차단되어 있어요. 설정 > APEX에서 권한을 허용해 주세요.",
                        buttonTitle: "설정 열기"
                    ) { openAppSettings() }
                    return
                }
                // 녹음 시작 시 미디어 시트가 열려 있으면 먼저 내린다
                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.2)) {
                    isMediaSheetPresented = false
                }
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
                    try session.setActive(true)

                    let url = nextSequentialRecordingURL()

                    let settings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatMPEG4AAC,
                        AVSampleRateKey: 44_100,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                    ]

                    let recorder = try AVAudioRecorder(url: url, settings: settings)
                    recorder.isMeteringEnabled = true
                    recorder.record()

                    self.audioRecorder = recorder
                    self.isRecording = true
                    self.recordingDuration = 0
                    self.recordingURL = url
                    self.waveformLevels.removeAll()
                    self.levelTimer?.invalidate()

                    let dt = 1.0 / 60.0
                    let waveSpeed: CGFloat = 1 // 초당 0.6 사이클

                    self.levelTimer = Timer.scheduledTimer(withTimeInterval: dt, repeats: true) { _ in
                        updateMeters()
                        wavePhase += .pi * 2 * waveSpeed * dt
                        if wavePhase > .pi * 2 { wavePhase -= .pi * 2 }
                        if let current = audioRecorder?.currentTime { recordingDuration = current }
                    }
                } catch {
                    presentToast(text: "녹음을 시작할 수 없어요.", buttonTitle: "확인") {}
                }
            }
        }
    }

    func stopRecordingAndSend() {
        guard let recorder = audioRecorder else { return }
        recorder.stop()
        recordingDuration = recorder.currentTime
        audioRecorder = nil
        levelTimer?.invalidate(); levelTimer = nil
        isRecording = false

        guard let url = recordingURL else { return }
        let audio = AudioAttachment(url: url, duration: recordingDuration)
        let note = Note(uploadedAt: Date(), text: nil, bundle: .audio([audio]))
        onSend(note)
        recordingURL = nil
        waveformLevels.removeAll()
        showActions = false
        isEditorFocused = false
    }

    func cleanupRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        levelTimer?.invalidate(); levelTimer = nil
        isRecording = false
        waveformLevels.removeAll()
    }

    func updateMeters() {
        guard let recorder = audioRecorder else { return }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0) // -160...0 dB
        let normalized = max(0, min(1, pow(10, power / 20)))
        waveformLevels.append(CGFloat(normalized))
        if waveformLevels.count > maxWaveformBars { waveformLevels.removeFirst(waveformLevels.count - maxWaveformBars) }
    }

    func nextSequentialRecordingURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
        let base = "새로운 녹음"
        var index = 1
        while true {
            let candidate = directory
                .appendingPathComponent("\(base) \(index)")
                .appendingPathExtension("m4a")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
        return directory
            .appendingPathComponent("\(base) \(index)")
            .appendingPathExtension("m4a")
    }
}

private struct RecordingWaveform: View {
    let levels: [CGFloat]
    let phase: CGFloat
    let duration: TimeInterval
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let baseAmplitude = max(6, height * 0.15)
            let level = CGFloat(levels.last ?? 0.2)
            let amplitude = baseAmplitude + height * 0.35 * level

            ZStack {
                SineWaveShape(amplitude: amplitude, phase: phase, frequency: 1.2)
                    .stroke(Color("Primary").opacity(0.8), lineWidth: 2)
                SineWaveShape(amplitude: amplitude * 0.66, phase: phase + .pi/2, frequency: 1.6)
                    .stroke(Color("Primary").opacity(0.5), lineWidth: 2)
                SineWaveShape(amplitude: amplitude * 0.4, phase: phase + .pi, frequency: 2.0)
                    .stroke(Color("Primary").opacity(0.3), lineWidth: 2)
            }
            .frame(width: width, height: height)
            .background(.regularMaterial)
            .overlay(
                HStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("녹음 중...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                , alignment: .topLeading
            )
        }
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let total = Int(time.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct SineWaveShape: Shape {
    var amplitude: CGFloat
    var phase: CGFloat
    var frequency: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let width = rect.width
        let step: CGFloat = 2
        var currentX: CGFloat = 0
        var first = true
        while currentX <= width {
            let normalized = currentX / width
            let angle = normalized * frequency * .pi * 2 + phase
            let currentY = midY + sin(angle) * amplitude * envelope(normalized)
            if first {
                path.move(to: CGPoint(x: currentX, y: currentY))
                first = false
            } else {
                path.addLine(to: CGPoint(x: currentX, y: currentY))
            }
            currentX += step
        }
        return path
    }

    private func envelope(_ time: CGFloat) -> CGFloat {
        // Soft taper on both ends
        let edge = min(time, 1 - time)
        return max(0.2, edge * 3)
    }
}

// MARK: - Sine waveform row (left button 자리부터 전체를 덮는 사인 파형)

private struct SineWaveRow: View {
    let levels: [CGFloat]
    let phase: CGFloat

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let baseAmplitude = max(6, height * 0.15)
            let level = CGFloat(levels.last ?? 0.2)
            let amplitude = baseAmplitude + height * 0.35 * level
            SineWaveShape(amplitude: amplitude, phase: phase, frequency: 6.5)
                .stroke(
                    Color("Primary"),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Linear waveform row (left button 자리부터 전체를 덮는 파형)

private struct LinearWaveRow: View {
    let levels: [CGFloat]

    var body: some View {
        GeometryReader { geo in
            PolylineWaveformShape(levels: levels)
                .stroke(
                    Color("Primary").opacity(0.6),
                    style: StrokeStyle(lineWidth: 2, lineJoin: .round)
                )
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

private struct PolylineWaveformShape: Shape {
    var levels: [CGFloat]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let count = max(levels.count, 2)
        let stepX = rect.width / CGFloat(count - 1)
        let midY = rect.midY
        let amplitude = max(6, rect.height * 0.2)

        for sampleIndex in 0..<count {
            let level = sampleIndex < levels.count ? CGFloat(levels[sampleIndex]) : 0
            let yCoordinate = midY + (0.5 - level) * amplitude
            let xCoordinate = CGFloat(sampleIndex) * stepX
            if sampleIndex == 0 {
                path.move(to: CGPoint(x: xCoordinate, y: yCoordinate))
            } else {
                path.addLine(to: CGPoint(x: xCoordinate, y: yCoordinate))
            }
        }
        return path
    }
}

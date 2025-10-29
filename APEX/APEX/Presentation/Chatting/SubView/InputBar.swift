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
// swiftlint:disable type_body_length

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

struct InputBar: View {
    @State private var memo: String = ""
    @State private var showActions: Bool = false
    @FocusState private var isEditorFocused: Bool
    // TextEditor (fixed height)

    // constants kept for placeholder alignment only
    private let editorLeftPadding: CGFloat = 16
    private let editorVerticalPadding: CGFloat = 14
    private let editorRightPaddingForButton: CGFloat = 56
    private let font: UIFont = UIFont(name: "PretendardVariable-Medium", size: 16) ?? UIFont.systemFont(ofSize: 16)
    private var maxTextWidth: CGFloat = UIScreen.main.bounds.width - 16 - 56 - 32
    @State private var textHeight: CGFloat = 48

    // Album
    @State private var showPhotoPicker: Bool = false
    @State private var pickedItems: [PhotosPickerItem] = []
    @AppStorage("apex.albumPermissionShown") private var albumPermissionShown: Bool = false

    // Camera
    @State private var showCamera: Bool = false

    // Files
    @State private var showDocumentPicker: Bool = false

    // Media bottom sheet
    @State private var showMediaSheet: Bool = false
    @State private var plusRotation: Double = 0
    @State private var sheetDetentIsLarge: Bool = false
    @State private var barOffsetY: CGFloat = 0

    // Audio recording
    @State private var isRecording: Bool = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var levelTimer: Timer?
    @State private var waveformLevels: [CGFloat] = []
    private let maxWaveformBars: Int = 40
    @State private var recordingURL: URL?
    @State private var recordingDuration: TimeInterval = 0
    @State private var wavePhase: CGFloat = 0

    // Attachments staged from media sheet
    @Binding var stagedAttachments: [ShareAttachmentItem]

    // Send hook
    var onSend: (Note) -> Void = { _ in }
    var onSheetVisibilityChanged: (Bool) -> Void = { _ in }
    var onBarOffsetChanged: (CGFloat) -> Void = { _ in }

    // Custom initializer to allow trailing closure usage: InputBar { note in ... } onSheetVisibilityChanged: { visible in ... }
    init(
        _ onSend: @escaping (Note) -> Void = { _ in },
        onSheetVisibilityChanged: @escaping (Bool) -> Void = { _ in },
        stagedAttachments: Binding<[ShareAttachmentItem]> = .constant([]),
        onBarOffsetChanged: @escaping (CGFloat) -> Void = { _ in }
    ) {
        self.onSend = onSend
        self.onSheetVisibilityChanged = onSheetVisibilityChanged
        _stagedAttachments = stagedAttachments
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
                // Plus / Keyboard button (sheet or dismiss keyboard)
                Button {
                    if isEditorFocused {
                        isEditorFocused = false
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            plusRotation += 45
                        }
                        if showMediaSheet {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                barOffsetY = targetBarOffset(isLarge: sheetDetentIsLarge, isVisible: false)
                                onBarOffsetChanged(barOffsetY)
                            }
                            showMediaSheet = false
                            onSheetVisibilityChanged(false)
                        } else {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                barOffsetY = targetBarOffset(isLarge: false, isVisible: true)
                                onBarOffsetChanged(barOffsetY)
                            }
                            showMediaSheet = true
                            onSheetVisibilityChanged(true)
                        }
                    }
                } label: {
                    Group {
                        if isEditorFocused {
                            Image(systemName: "keyboard.chevron.compact.down")
                        } else {
                            Image(systemName: "plus")
                                .rotationEffect(.degrees(plusRotation))
                        }
                    }
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color("Primary"))
                    .frame(width: 48, height: 48)
                    .glassEffect()
                    .accessibilityLabel(Text(isEditorFocused ? "키보드 내리기" : "추가"))
                }

                ZStack(alignment: .bottomTrailing) {
                    if isRecording {
                        RecordingWaveform(levels: waveformLevels, phase: wavePhase, duration: recordingDuration)
                            .frame(maxWidth: .infinity)
                            .frame(height: textHeight)
                            .padding(.vertical, editorVerticalPadding / 2)
                            .padding(.leading, editorLeftPadding / 2)
                            .padding(.trailing, 56)
                            .glassEffect(
                                in: UnevenRoundedRectangle(
                                    topLeadingRadius: 4,
                                    bottomLeadingRadius: 4,
                                    bottomTrailingRadius: 32,
                                    topTrailingRadius: 32
                                )
                            )
                    } else {
                        TextEditor(text: $memo)
                            .font(.body2)
                            .scrollContentBackground(.hidden)
                            .scrollDisabled(true)
                            .focused($isEditorFocused)
                            .padding(.top, editorVerticalPadding / 2)
                            .padding(.leading, editorLeftPadding / 2)
                            .padding(.trailing, 56)
                            .frame(maxWidth: .infinity)
                            .frame(height: textHeight)
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
                    }

                    if memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isRecording {
                        Text("메모 입력")
                            .font(.body2)
                            .foregroundColor(Color.gray.opacity(0.6))
                            .padding(.vertical, editorVerticalPadding)
                            .padding(.leading, editorLeftPadding)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                    }

                    Group {
                        if memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button {
                                if isRecording { stopRecordingAndSend() } else { startRecording() }
                            } label: {
                                Image(systemName: isRecording ? "stop.fill" : "waveform")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Color("Primary"))
                                    .clipShape(Circle())
                                    .glassEffect()
                            }
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
                            .accessibilityLabel(Text("보내기"))
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }

            // (Inline action row removed in favor of media sheet)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, showMediaSheet ? 0 : 8)
        .onChange(of: showMediaSheet) { _, visible in
            onSheetVisibilityChanged(visible)
        }
        // Album picker
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $pickedItems,
            maxSelectionCount: 24,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: pickedItems) { _, newItems in
            Task { await handlePicked(items: newItems) }
        }
        // Camera sheet
        .sheet(isPresented: $showCamera) {
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
        // Media bottom sheet for quick actions + recents
        .sheet(isPresented: $showMediaSheet) {
            ChatMediaPickerSheet(
                isPresented: $showMediaSheet,
                onTapFile: { handleFilesTap() },
                onTapCamera: { handleCameraTap() },
                onOpenSystemAlbum: { handleAlbumTap() },
                onDetentChanged: { detent in
                    let isLarge = (detent == .large)
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        sheetDetentIsLarge = isLarge
                        barOffsetY = targetBarOffset(isLarge: isLarge, isVisible: true)
                        onBarOffsetChanged(barOffsetY)
                    }
                },
                selectedAttachmentItems: $stagedAttachments
            )
            .background(Color("Background"))
        }
    }

    private func targetBarOffset(isLarge: Bool, isVisible: Bool) -> CGFloat {
        guard isVisible else { return 0 }
        let screenHeight = UIScreen.main.bounds.height
        if isLarge {
            return -8
        } else {
            // Attach to 2/5 sheet top with zero gap; ChattingView bottom padding is already 0 in this state
            return -(screenHeight * 0.4) - 1
        }
    }

    private func calculateHeight() {
        let lineCount = autoLineCount(text: memo, font: font, maxTextWidth: maxTextWidth - 40)
        let lineHeight = font.lineHeight
        let verticalPadding: CGFloat = editorVerticalPadding * 2 // matches .padding top/bottom
        let minHeight: CGFloat = 48

        let contentHeight = lineHeight * lineCount + verticalPadding
        textHeight = max(minHeight, contentHeight)
    }

    private func autoLineCount(text: String, font: UIFont, maxTextWidth: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 1 }
        var lineCount: CGFloat = 0

        text.components(separatedBy: .newlines).forEach { line in
            if line.isEmpty {
                lineCount += 1
                return
            }
            let width = (line as NSString).boundingRect(
                with: CGSize(width: .greatestFiniteMagnitude, height: font.lineHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            ).width
            lineCount += max(1, ceil(width / maxTextWidth))
        }

        return lineCount
    }

    private func sendText() {
        let text = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let note = Note(uploadedAt: Date(), text: text, bundle: nil)
        onSend(note)
        memo = ""
        showActions = false
        isEditorFocused = false
    }

    @MainActor
    private func handlePicked(items: [PhotosPickerItem]) async {
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

    private func handleAlbumTap() {
        if albumPermissionShown {
            showPhotoPicker = true
            return
        }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .denied, .restricted:
            presentToast(
                text: "사진 접근이 차단되어 있어요. 설정 > APEX에서 권한을 허용해 주세요.",
                buttonTitle: "설정 열기"
            ) {
                openAppSettings()
            }
        default:
            presentToast(
                text: "채팅에서 사진/영상을 보내려면 사진 선택이 필요합니다.",
                buttonTitle: "허용하기"
            ) {
                albumPermissionShown = true
                showPhotoPicker = true
            }
        }
    }

    private func handleCameraTap() {
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

    private func handleFilesTap() {
        showDocumentPicker = true
    }

    private func presentToast(text: String, buttonTitle: String, action: @escaping () -> Void) {
        toastText = text
        toastButtonTitle = buttonTitle
        toastAction = action
        withAnimation { showToast = true }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
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

    private let font = UIFont(name: "PretendardVariable-Medium", size: 16) ?? .systemFont(ofSize: 16, weight: .medium)
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
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
                    try session.setActive(true)

                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("apex-recording-\(UUID().uuidString)")
                        .appendingPathExtension("m4a")

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
                    self.levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                        updateMeters()
                        wavePhase += 0.25
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

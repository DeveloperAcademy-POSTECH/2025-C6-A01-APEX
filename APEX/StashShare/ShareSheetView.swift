//
//  ShareSheetView.swift
//  StashShare
//
//  Minimal share UI for the extension: select recipients and upload.
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct ShareSheetView: View {
    @State private var selectedIds: Set<UUID> = []
    @State private var inputText: String = ""
    @State private var attachments: [ShareAttachmentItem]
    private let onFinished: (() -> Void)?
    
    @State private var clients: [PClient] = []
    
    init(attachments: [ShareAttachmentItem], onFinished: (() -> Void)?) {
        _attachments = State(initialValue: attachments)
        self.onFinished = onFinished
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                visualAttachBar
                
                List {
                    Section(header: Text("연결 대상")) {
                        ForEach(clients) { c in
                            Button(action: { toggleSelect(c.id) }) {
                                HStack {
                                    Text("\(c.name) \(c.surname)")
                                    Spacer()
                                    if selectedIds.contains(c.id) {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                                    } else {
                                        Image(systemName: "circle").foregroundColor(.gray)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                
                HStack(spacing: 8) {
                    TextField("(선택) 메모 입력", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                    Button(action: send) {
                        Image(systemName: "arrow.up")
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(selectedIds.isEmpty ? Color.gray.opacity(0.4) : Color.blue)
                            .clipShape(Circle())
                    }
                    .disabled(selectedIds.isEmpty)
                }
                .padding(.horizontal)
            }
            .navigationTitle("노트에 공유")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            clients = LocalStoreExt.shared.loadClients()
        }
    }
    
    private var visualAttachBar: some View {
        let visualItems = attachments.filter { item in
            switch item.kind { case .image, .video: return true; default: return false }
        }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visualItems) { item in
                    ZStack(alignment: .topTrailing) {
                        content(for: item)
                            .frame(width: 72, height: 72)
                            .clipped()
                            .cornerRadius(6)
                        Button(action: { removeAttachment(item) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .shadow(radius: 1)
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func content(for item: ShareAttachmentItem) -> some View {
        switch item.kind {
        case .image(let uiImage):
            Image(uiImage: uiImage).resizable().scaledToFill()
        case .video(_, let thumbnail):
            ZStack {
                if let thumb = thumbnail {
                    Image(uiImage: thumb).resizable().scaledToFill()
                } else {
                    Color.gray.opacity(0.2)
                }
                Image(systemName: "play.fill").foregroundColor(.white)
            }
        default:
            Color.clear
        }
    }
    
    private func toggleSelect(_ id: UUID) {
        if selectedIds.contains(id) { selectedIds.remove(id) } else { selectedIds.insert(id) }
    }
    
    private func removeAttachment(_ item: ShareAttachmentItem) {
        attachments.removeAll { $0.id == item.id }
    }
    
    private func send() {
        guard !selectedIds.isEmpty else { return }
        
        // Build text parts
        let typed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let seeded = attachments.compactMap { item -> String? in
            if case let .text(text) = item.kind { return text } else { return nil }
        }.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // Build bundle (media/files/audio)
        let bundle = makePersistedBundle()
        if bundle == nil && typed.isEmpty && seeded.isEmpty { return }
        
        var updated = clients
        for idx in updated.indices {
            guard selectedIds.contains(updated[idx].id) else { continue }
            var notesToAppend: [PNote] = []
            if let bundle {
                notesToAppend.append(PNote(id: UUID(), uploadedAt: Date(), text: nil, bundle: bundle))
            }
            if !seeded.isEmpty {
                notesToAppend.append(PNote(id: UUID(), uploadedAt: Date(), text: seeded, bundle: nil))
            }
            if !typed.isEmpty {
                notesToAppend.append(PNote(id: UUID(), uploadedAt: Date(), text: typed, bundle: nil))
            }
            updated[idx].notes.append(contentsOf: notesToAppend)
        }
        clients = updated
        LocalStoreExt.shared.saveClients(updated)
        onFinished?()
    }
    
    private func makePersistedBundle() -> PAttachmentBundle? {
        var images: [PImageAttachment] = []
        var videos: [PVideoAttachment] = []
        var files: [PFileAttachment] = []
        var audios: [PAudioAttachment] = []
        
        for (order, item) in attachments.enumerated() {
            switch item.kind {
            case .image(let uiImage):
                if let data = uiImage.jpegData(compressionQuality: 0.9) {
                    images.append(PImageAttachment(data: data, progress: nil, orderIndex: order))
                }
            case .video(let url, _):
                if let url {
                    let copied = ensureSharedCopy(of: url, directoryName: "SharedVideos", defaultExtension: "mov")
                    videos.append(PVideoAttachment(url: copied.absoluteString, progress: nil, orderIndex: order))
                }
            case .file(let url):
                let defaultExt = url.pathExtension.isEmpty ? "dat" : url.pathExtension
                let copied = ensureSharedCopy(of: url, directoryName: "SharedFiles", defaultExtension: defaultExt)
                files.append(PFileAttachment(url: copied.absoluteString, progress: nil))
            case .audio(let url):
                let defaultExt = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
                let copied = ensureSharedCopy(of: url, directoryName: "SharedAudios", defaultExtension: defaultExt)
                audios.append(PAudioAttachment(url: copied.absoluteString, duration: assetDuration(for: copied)))
            case .text:
                break
            }
        }
        if !images.isEmpty || !videos.isEmpty { return .media(images: images, videos: videos) }
        if !files.isEmpty { return .files(files) }
        if !audios.isEmpty { return .audio(audios) }
        return nil
    }
}

// MARK: - Utilities (copy into App Group + audio duration)
private func ensureSharedCopy(of sourceURL: URL, directoryName: String, defaultExtension: String) -> URL {
    let fileManager = FileManager.default
    let baseDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.apex.StashShareExtension") ??
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
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

private func assetDuration(for url: URL) -> Double? {
    let asset = AVAsset(url: url)
    let seconds = asset.duration.seconds
    return seconds.isFinite && seconds > 0 ? seconds : nil
}



//
//  ShareSheetView.swift
//  StashShare
//
//  UI mirrored from the main app's ShareView for visual parity.
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct ShareSheetView: View {
    enum Tab: String, CaseIterable, Identifiable { case connects = "연결", recents = "최근"; var id: String { rawValue } }
    
    @State private var selectedTab: Tab = .connects
    @State private var selectedIds: Set<UUID> = []
    @State private var inputText: String = ""
    @State private var attachments: [ShareAttachmentItem]
    private let onFinished: (() -> Void)?
    
    @State private var clients: [PClient] = []
    @State private var inputBarHeight: CGFloat = 0
    
    private struct InputBarHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }
    
    init(attachments: [ShareAttachmentItem], onFinished: (() -> Void)?) {
        _attachments = State(initialValue: attachments)
        self.onFinished = onFinished
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch selectedTab {
                case .connects:
                    if !connectsFavorites.isEmpty {
                        ForEach(connectsFavorites) { client in
                            ShareRowExt(
                                client: client,
                                mode: .contacts,
                                isSelected: selectedIds.contains(client.id),
                                onToggleSelect: { toggleSelect(client.id) }
                            )
                        }
                    }
                    ForEach(connectsCompanyKeys, id: \.self) { key in
                        Text(key).font(.body1).foregroundColor(.primary)
                            .padding(.top, 8)
                        ForEach(connectsGrouped[key] ?? []) { client in
                            ShareRowExt(
                                client: client,
                                mode: .contacts,
                                isSelected: selectedIds.contains(client.id),
                                onToggleSelect: { toggleSelect(client.id) }
                            )
                        }
                    }
                case .recents:
                    ForEach(recentsPinned) { client in
                        ShareRowExt(
                            client: client,
                            mode: .recents,
                            isSelected: selectedIds.contains(client.id),
                            onToggleSelect: { toggleSelect(client.id) }
                        )
                    }
                    ForEach(recentsUnpinned) { client in
                        ShareRowExt(
                            client: client,
                            mode: .recents,
                            isSelected: selectedIds.contains(client.id),
                            onToggleSelect: { toggleSelect(client.id) }
                        )
                    }
                }
            }
        }
        .background(ShareTheme.background)
        .padding(.horizontal, 16)
        // Tap-to-dismiss keyboard removed for app extension compatibility
        .overlay(alignment: .bottom) {
            VStack(spacing: 6) {
                let visualItems: [ShareAttachmentItem] = attachments.filter { item in
                    switch item.kind { case .image, .video: return true; default: return false }
                }
                if !visualItems.isEmpty {
                    AttachBarExt(
                        items: visualItems,
                        onRemove: { removeAttachment($0) }
                    )
                }
            }
            .padding(.bottom, inputBarHeight + 8)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                ShareTopBarExt(
                    title: "노트에 공유",
                    selectedCount: selectedIds.count,
                    onClose: { onFinished?() },
                    onSearch: { }
                )
                .padding(.top, 16)
                .background(ShareTheme.background)
                
                Group {
                    if !selectedIds.isEmpty {
                        selectedClientsBar
                            .padding(.vertical, 8)
                            .background(ShareTheme.background)
                            .padding(.horizontal, 16)
                    } else {
                        tabPicker
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ShareInputBarExt(
                text: $inputText,
                isEnabled: !selectedIds.isEmpty,
                onSend: { send() }
            )
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: InputBarHeightKey.self, value: proxy.size.height)
                }
            )
        }
        .onPreferenceChange(InputBarHeightKey.self) { inputBarHeight = $0 }
        .onAppear {
            clients = LocalStoreExt.shared.loadClients()
        }
    }
    
    private var selectedClientsBar: some View {
        let selected: [PClient] = clients
            .filter { selectedIds.contains($0.id) }
            .sorted(by: { lhs, rhs in
                let lhsName = "\(lhs.name) \(lhs.surname)"
                let rhsName = "\(rhs.name) \(rhs.surname)"
                return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
            })
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(selected) { client in
                    chip(for: client)
                }
            }
        }
    }
    
    private func chip(for client: PClient) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                let initials = Profile.makeInitials(name: client.name, surname: client.surname)
                let image = client.profileImageData.flatMap { UIImage(data: $0) }
                Profile(
                    image: image,
                    initials: initials,
                    size: .extraSmall,
                    fontSize: 30.72,
                    backgroundColor: ShareTheme.primaryContainer,
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
            
            Text("\(client.name) \(client.surname)")
                .font(.caption2)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 4)
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
                            .foregroundColor(selectedTab == tab ? ShareTheme.primary : ShareTheme.backgroundHover)
                        Rectangle()
                            .fill(selectedTab == tab ? ShareTheme.primary : ShareTheme.backgroundHover)
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
    
    private var connectsFavorites: [PClient] {
        clients.filter { $0.favorite }
            .sorted {
                "\($0.name) \($0.surname)".localizedCaseInsensitiveCompare("\($1.name) \($1.surname)") == .orderedAscending
            }
    }
    private var connectsGrouped: [String: [PClient]] {
        let nonFavs = clients.filter { !$0.favorite }
        let grouped = Dictionary(grouping: nonFavs, by: { $0.company })
        var sorted: [String: [PClient]] = [:]
        for key in grouped.keys.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) {
            sorted[key] = grouped[key]!.sorted {
                "\($0.name) \($0.surname)".localizedCaseInsensitiveCompare("\($1.name) \($1.surname)") == .orderedAscending
            }
        }
        return sorted
    }
    private var connectsCompanyKeys: [String] { Array(connectsGrouped.keys).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending } }
    
    private var recentsSorted: [PClient] {
        clients.sorted {
            let l = $0.notes.max(by: { $0.uploadedAt < $1.uploadedAt })?.uploadedAt ?? .distantPast
            let r = $1.notes.max(by: { $0.uploadedAt < $1.uploadedAt })?.uploadedAt ?? .distantPast
            return l > r
        }
    }
    private var recentsPinned: [PClient] { recentsSorted.filter { $0.pin } }
    private var recentsUnpinned: [PClient] { recentsSorted.filter { !$0.pin } }
    
    private func toggleSelect(_ id: UUID) {
        if selectedIds.contains(id) { selectedIds.remove(id) } else { selectedIds.insert(id) }
    }
    
    private func removeAttachment(_ item: ShareAttachmentItem) {
        attachments.removeAll { $0.id == item.id }
    }
    
    private func send() {
        guard !selectedIds.isEmpty else { return }
        
        let typed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let seeded = attachments.compactMap { item -> String? in
            if case let .text(text) = item.kind { return text } else { return nil }
        }.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
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
 
struct ShareTopBarExt: View {
    let title: String
    let selectedCount: Int
    let onClose: () -> Void
    let onSearch: () -> Void
    
    init(
        title: String,
        selectedCount: Int,
        onClose: @escaping () -> Void,
        onSearch: @escaping () -> Void
    ) {
        self.title = title
        self.selectedCount = selectedCount
        self.onClose = onClose
        self.onSearch = onSearch
    }
    
    private var background: Color = Color("Background")
    private var foreground: Color = .black
    private var height: CGFloat = 52
    
    var body: some View {
        ZStack(alignment: .center) {
            HStack(spacing: 0) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    .foregroundColor(foreground)
                        .frame(width: 44, height: 44)
                        .glassEffect()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("닫기"))
                
                Spacer(minLength: 0)
                
                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                    .foregroundColor(foreground)
                        .frame(width: 44, height: 44)
                        .glassEffect()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("검색"))
            }
            .frame(height: height)
            .padding(.horizontal, 12)
            
            VStack(spacing: 0) {
                Text(title)
                    .lineLimit(1)
                    .font(.title5)
                    .foregroundColor(foreground)
                if selectedCount > 0 {
                    Text("\(selectedCount)명")
                        .lineLimit(1)
                        .font(.caption2)
                        .foregroundColor(ShareTheme.primary)
                }
            }
            .frame(height: height)
            .padding(.horizontal, 12)
            .allowsHitTesting(false)
        }
        .padding(.vertical, 8)
        .background(ShareTheme.background)
    }
}
 
struct AttachBarExt: View {
    let items: [ShareAttachmentItem]
    var onRemove: (ShareAttachmentItem) -> Void
    
    private enum Metrics {
        static let itemSize: CGFloat = 72
        static let corner: CGFloat = 3.95
        static let spacing: CGFloat = 8
        static let xSize: CGFloat = 16
        static let xTapSize: CGFloat = 28
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Metrics.spacing) {
                ForEach(items.filter { item in
                    switch item.kind {
                    case .image, .video:
                        return true
                    default:
                        return false
                    }
                }) { item in
                    itemView(item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private func itemView(_ item: ShareAttachmentItem) -> some View {
        ZStack(alignment: .topTrailing) {
            content(for: item)
                .frame(width: Metrics.itemSize, height: Metrics.itemSize)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
            
            Button {
                onRemove(item)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: Metrics.xSize, weight: .medium))
                    .foregroundColor(.gray)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: Metrics.xTapSize, height: Metrics.xTapSize, alignment: .topTrailing)
        }
        .background(Color("BackgroundSecondary"))
        .clipShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
    }
    
    @ViewBuilder
    private func content(for item: ShareAttachmentItem) -> some View {
        switch item.kind {
        case .image(let uiImage):
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        case .video(_, let thumbnail):
            ZStack {
                if let thumb = thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(Color("BackgroundSecondary"))
                }
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))
                    .shadow(radius: 2)
            }
        default:
            Color.clear
        }
    }
}
 
struct ShareInputBarExt: View {
    @Binding var text: String
    var isEnabled: Bool
    var placeholder: String = "(선택) 메모 입력"
    var onSend: () -> Void
    
    init(
        text: Binding<String>,
        isEnabled: Bool,
        placeholder: String = "(선택) 메모 입력",
        onSend: @escaping () -> Void
    ) {
        self._text = text
        self.isEnabled = isEnabled
        self.placeholder = placeholder
        self.onSend = onSend
    }
    @State private var isEditing: Bool = false
    @FocusState private var isFocused: Bool
    
    private enum Metrics {
        static let barHeight: CGFloat = 56
        static let horizontalPadding: CGFloat = 12
        static let fieldHeight: CGFloat = 40
        static let fieldRadius: CGFloat = 32
        static let sendSize: CGFloat = 48
        static let sendIcon: CGFloat = 20
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if isEditing {
                Button(
                    action: {
                        isFocused = false
                        isEditing = false
                    },
                    label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(width: 44, height: 44)
                    }
                )
                .buttonStyle(.plain)
                .accessibilityLabel(Text("지우기"))
                .glassEffect()
            }
            
            TextField(
                placeholder,
                text: $text,
                onEditingChanged: { editing in
                    isEditing = editing
                },
                onCommit: {
                    if computedIsEnabled { onSend() }
                }
            )
            .font(.body5)
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .frame(height: Metrics.fieldHeight)
            .focused($isFocused)
            .glassEffect(
                in: UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: Metrics.fieldRadius,
                    topTrailingRadius: Metrics.fieldRadius
                )
            )
            .submitLabel(.send)
            
            Button(
                action: {
                    if computedIsEnabled { onSend() }
                },
                label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: Metrics.sendIcon, weight: .medium))
                        .foregroundStyle(.white)
                }
            )
            .buttonStyle(.plain)
            .frame(width: Metrics.sendSize, height: Metrics.sendSize)
            .background(computedIsEnabled ? ShareTheme.primary : ShareTheme.backgroundSecondary)
            .clipShape(Circle())
            .disabled(!computedIsEnabled)
            .accessibilityLabel(Text("전송"))
            .glassEffect()
        }
        .padding(.horizontal, Metrics.horizontalPadding)
        .frame(height: Metrics.barHeight)
    }
    
    private var computedIsEnabled: Bool { isEnabled }
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
 
 
 


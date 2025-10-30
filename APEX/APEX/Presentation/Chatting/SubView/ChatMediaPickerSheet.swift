//
//  ChatMediaPickerSheet.swift
//  APEX
//
//  Created by AI Assistant on 10/28/25.
//

import SwiftUI
import Photos

struct ChatMediaPickerSheet: View {
    @Binding var isPresented: Bool
    var onTapFile: () -> Void
    var onTapCamera: () -> Void
    var onOpenSystemAlbum: () -> Void
    var onDetentChanged: (PresentationDetent) -> Void = { _ in }
    var onHeightChanged: (CGFloat) -> Void = { _ in }
    var onConfirmUpload: () -> Void = {}
    @Binding var selectedAttachmentItems: [ShareAttachmentItem]

    @State private var detentSelection: PresentationDetent = .fraction(0.4)
    @State private var assets: [PHAsset] = []
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var selectedIds: Set<String> = []

    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    init(
        isPresented: Binding<Bool>,
        onTapFile: @escaping () -> Void,
        onTapCamera: @escaping () -> Void,
        onOpenSystemAlbum: @escaping () -> Void,
        onDetentChanged: @escaping (PresentationDetent) -> Void = { _ in },
        onHeightChanged: @escaping (CGFloat) -> Void = { _ in },
        onConfirmUpload: @escaping () -> Void = {},
        selectedAttachmentItems: Binding<[ShareAttachmentItem]> = .constant([])
    ) {
        self._isPresented = isPresented
        self.onTapFile = onTapFile
        self.onTapCamera = onTapCamera
        self.onOpenSystemAlbum = onOpenSystemAlbum
        self.onDetentChanged = onDetentChanged
        self.onHeightChanged = onHeightChanged
        self.onConfirmUpload = onConfirmUpload
        self._selectedAttachmentItems = selectedAttachmentItems
    }

    var body: some View {
        VStack(spacing: 0) {
            if detentSelection == .large { headerLarge } else { headerCollapsed }

            ScrollView {
                VStack(spacing: 8) {
                    fileWideTile

                    LazyVGrid(columns: gridColumns, spacing: 2) {
                        cameraTile

                        ForEach(assets.indices, id: \.self) { index in
                            let asset = assets[index]
                            let isSelected = selectedIds.contains(asset.localIdentifier)
                            ZStack(alignment: .topTrailing) {
                                ZStack(alignment: .bottomLeading) {
                                    if let image = thumbnails[asset.localIdentifier] {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 122, height: 122)
                                            .clipped()
                                            .cornerRadius(12)
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.15))
                                            .frame(height: 122)
                                            .overlay(ProgressView().tint(.secondary))
                                            .task { loadThumbnail(for: asset) }
                                    }

                                    if asset.mediaType == .video {
                                        Text(formatClock(asset.duration))
                                            .font(.caption2)
                                            .foregroundStyle(.white)
                                            .padding(8)
                                    }
                                }

                                if isSelected {
                                    Color.black.opacity(0.4)
                                        .frame(width: 122, height: 122)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color("Background"))
                                        .padding(12)
                                }
                            }
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture { toggleSelection(for: asset) }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8.5)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if detentSelection == .large {
                Button {
                    onConfirmUpload()
                    isPresented = false
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(Color("Primary"))
                        .clipShape(Circle())
                        .glassEffect()
                }
                .buttonStyle(.plain)
                .disabled(selectedIds.isEmpty)
                .padding(16)
            }
        }
        .onAppear { requestAndFetchRecents() }
        .onAppear { onDetentChanged(detentSelection) }
        .presentationDetents([.fraction(0.4), .large], selection: $detentSelection)
        .presentationDragIndicator(detentSelection == .large ? .hidden : .visible)
        .presentationCornerRadius(16)
        .presentationBackgroundInteraction(.enabled)
        .interactiveDismissDisabled(detentSelection == .large)
        .onChange(of: detentSelection) { _, newValue in
            onDetentChanged(newValue)
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: SheetHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(SheetHeightKey.self) { height in
            onHeightChanged(height)
        }
    }

    private func toggleSelection(for asset: PHAsset) {
        let id = asset.localIdentifier
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
        synchronizeSelectedItems()
    }

    private func formatClock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let secondsRemainder = total % 60
        return String(format: "%02d:%02d", minutes, secondsRemainder)
    }

    private func synchronizeSelectedItems() {
        var newItems: [ShareAttachmentItem] = []
        for asset in assets where selectedIds.contains(asset.localIdentifier) {
            switch asset.mediaType {
            case .image:
                let ui = thumbnails[asset.localIdentifier] ?? makeThumbSync(for: asset)
                let image = ui ?? UIImage(systemName: "photo") ?? UIImage()
                newItems.append(ShareAttachmentItem(id: UUID(), kind: .image(image)))
            case .video:
                let thumb = thumbnails[asset.localIdentifier] ?? makeThumbSync(for: asset)
                let id = UUID()
                newItems.append(ShareAttachmentItem(id: id, kind: .video(nil, thumbnail: thumb)))
                // Try to resolve a temporary URL for the selected video asset
                fetchVideoURL(for: asset) { url in
                    DispatchQueue.main.async {
                        if let idx = selectedAttachmentItems.firstIndex(where: { $0.id == id }) {
                            selectedAttachmentItems[idx].kind = .video(url, thumbnail: thumb)
                        }
                    }
                }
            default:
                break
            }
        }
        selectedAttachmentItems = newItems
    }

    private func fetchVideoURL(for asset: PHAsset, completion: @escaping (URL?) -> Void) {
        let resources = PHAssetResource.assetResources(for: asset).filter { res in
            return res.type == .video || res.type == .pairedVideo
        }
        guard let resource = resources.first else {
            completion(nil)
            return
        }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        PHAssetResourceManager.default().writeData(for: resource, toFile: tmp, options: nil) { error in
            if error != nil {
                completion(nil)
            } else {
                completion(tmp)
            }
        }
    }

    private func makeThumbSync(for asset: PHAsset, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        var resultImage: UIImage?
        manager.requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            resultImage = image
        }
        if let img = resultImage { thumbnails[asset.localIdentifier] = img }
        return resultImage
    }

    private var headerCollapsed: some View { Color.clear.frame(height: 8) }

    private var headerLarge: some View {
        ZStack(alignment: .center) {
            HStack(alignment: .center) {
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect()

                Spacer(minLength: 0)

                Button {
                    onOpenSystemAlbum()
                    isPresented = false
                } label: {
                    Text("전체 앨범")
                        .font(.body5)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .glassEffect()
            }

            VStack(spacing: 2) {
                Text("앨범").font(.title5).foregroundStyle(.black)
                if !selectedIds.isEmpty {
                    Text("\(selectedIds.count)/24개 선택됨").font(.caption3).foregroundStyle(Color("Primary"))
                } else {
                    Text("최대 24개 선택").font(.caption3).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(Color("Background"))
    }

    private var cameraTile: some View {
        Button {
            onTapCamera()
            isPresented = false
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("Primary"))
                Text("카메라")
                    .font(.caption2)
            }
            .frame(width: 122, height: 122)
            .background(Color("BackgroundSecondary"))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var fileWideTile: some View {
        Button {
            onTapFile()
            isPresented = false
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color("Primary"))
                Text("파일")
                    .font(.caption2)
                    .foregroundColor(.black)
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func requestAndFetchRecents(limit: Int = 60) {
        let auth = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if auth == .authorized || auth == .limited {
            fetchRecents(limit: limit)
        } else if auth == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                if status == .authorized || status == .limited {
                    DispatchQueue.main.async { fetchRecents(limit: limit) }
                }
            }
        }
    }

    private func fetchRecents(limit: Int) {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        options.predicate = NSPredicate(
            format: "mediaType == %d || mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )
        let result = PHAsset.fetchAssets(with: options)
        var list: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in list.append(asset) }
        assets = list
    }

    private func loadThumbnail(
        for asset: PHAsset,
        targetSize: CGSize = CGSize(width: 300, height: 300)
    ) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        options.resizeMode = .fast
        manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            guard let image else { return }
            thumbnails[asset.localIdentifier] = image
        }
    }
}

// PreferenceKey for reporting the presented sheet height to parent
private struct SheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    ChatMediaPickerSheet(
        isPresented: .constant(true),
        onTapFile: {},
        onTapCamera: {},
        onOpenSystemAlbum: {},
        selectedAttachmentItems: .constant([])
    )
}

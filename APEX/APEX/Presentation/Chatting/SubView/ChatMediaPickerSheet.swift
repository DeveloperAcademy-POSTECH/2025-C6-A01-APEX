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
        selectedAttachmentItems: Binding<[ShareAttachmentItem]> = .constant([])
    ) {
        self._isPresented = isPresented
        self.onTapFile = onTapFile
        self.onTapCamera = onTapCamera
        self.onOpenSystemAlbum = onOpenSystemAlbum
        self.onDetentChanged = onDetentChanged
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
        .onAppear { requestAndFetchRecents() }
        .onAppear { onDetentChanged(detentSelection) }
        .presentationDetents([.fraction(0.4), .large], selection: $detentSelection)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(16)
        .presentationBackgroundInteraction(detentSelection == .large ? .disabled : .enabled)
        .interactiveDismissDisabled(detentSelection == .fraction(0.4))
        .onChange(of: detentSelection) { _, newValue in
            onDetentChanged(newValue)
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
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
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
                newItems.append(ShareAttachmentItem(id: UUID(), kind: .video(nil, thumbnail: thumb)))
            default:
                break
            }
        }
        selectedAttachmentItems = newItems
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
        HStack(alignment: .center) {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .glassEffect()
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text("앨범").font(.title5).foregroundStyle(.black)
                Text("최대 24개 선택").font(.caption3).foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                onOpenSystemAlbum()
                isPresented = false
            } label: {
                Image(systemName: "photo")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .glassEffect()
            }
            .buttonStyle(.plain)
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

#Preview {
    ChatMediaPickerSheet(
        isPresented: .constant(true),
        onTapFile: {},
        onTapCamera: {},
        onOpenSystemAlbum: {},
        selectedAttachmentItems: .constant([])
    )
}


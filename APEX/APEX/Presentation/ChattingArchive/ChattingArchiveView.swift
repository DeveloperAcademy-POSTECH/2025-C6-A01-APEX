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

// swiftlint:disable type_body_length file_length
struct ChattingArchiveView: View {
    @StateObject private var viewModel: ChattingArchiveViewModel
    @EnvironmentObject private var router: NavigationRouter
    @Environment(\.dismiss) private var dismiss
 
    init(client: Client? = sampleClients.first, onDeletedContact: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ChattingArchiveViewModel(client: client, onDeletedContact: onDeletedContact))
    }
    
    private enum Metrics {
        static let headerAndMediaGap: CGFloat = 24
        static let mediaGap: CGFloat = 8
        static let buttonAndMediaGap: CGFloat = 40
        static let buttonGap: CGFloat = 12
        static let profileAndNameGap: CGFloat = 8
        static let nameAndPositionGap: CGFloat = 2
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                    .padding(.bottom, Metrics.headerAndMediaGap)

                sharedMediaSection
                    .padding(.bottom, Metrics.mediaGap)
                
                sharedFilesSection
                    .padding(.bottom, Metrics.mediaGap)

                sharedLinksSection
                    .padding(.bottom, Metrics.mediaGap)

                sharedAudioSection
                    .padding(.bottom, Metrics.buttonAndMediaGap)
                
                bottomActionsBar
            }
            .padding(.leading, 16)
            .padding(.vertical, 12)
        }
        .background(Color("Background"))
        .scrollEdgeEffectStyle(.soft, for: .top)
        .safeAreaBar(edge: .top) { topBar }
        .overlay(alignment: .center) { contactDeleteOverlay }
        .onAppear { viewModel.send(.onAppear) }
        .fullScreenCover(item: $viewModel.recordPayload) { payload in
            RecordView(audioURL: payload.url)
        }
        .fullScreenCover(item: $viewModel.archiveSheet) { payload in
            let displayName = (viewModel.client?.autoFormattedName ?? "").trimmingCharacters(in: .whitespaces)
            ArchiveListView(
                section: payload.section,
                media: viewModel.mediaItems,
                files: viewModel.fileItems,
                links: viewModel.linkItems,
                audios: viewModel.audioItems,
                viewerTitle: displayName.isEmpty ? "Archive" : displayName,
                excludedClientIds: viewModel.client.map { [$0.id] } ?? [],
                onClose: { viewModel.send(.dismissArchive) }
            )
        }
        // Hidden NavigationLink for archive push removed; Router handles navigation
    }

    // MARK: - Sections

    private var headerSection: some View {
        let initials = Profile.makeInitials(name: viewModel.client?.name ?? "", surname: viewModel.client?.surname ?? "")
        let displayName = viewModel.client?.autoFormattedName ?? ""
        return ChatDetailHeader(
            image: viewModel.client?.profile,
            initials: initials,
            name: displayName,
            company: viewModel.client?.company,
            position: viewModel.client?.position,
            phone: viewModel.client?.phoneNumber,
            favorite: viewModel.isFavorite
        )
    }

    private var sharedMediaSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "사진/동영상", iconName: "Photo", iconColor: Color("Primary"), action: {
                viewModel.send(.presentArchive(.media))
            })
            let allItems = viewModel.mediaItems
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
                            .frame(width: 124, height: 124)
                            .clipShape(Rectangle())
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
                                title: viewModel.client.map { "\($0.name) \($0.surname)"} ?? "Shared Media",
                                uploadedAt: previewItems[idx].uploadedAt,
                                excludedClientIds: viewModel.client.map { [$0.id] } ?? [],
                                onDelete: { removedIndex, _ in
                                    guard previewItems.indices.contains(removedIndex) else { return }
                                    let target = previewItems[removedIndex]
                                    viewModel.send(.deleteFlattenedMedia(target))
                                },
                                onTitleTap: { current in
                                    guard let clientId = viewModel.client?.id else { return }
                                    let anchors: [UUID?] = previewItems.map { mediaItem in
                                        return viewModel.noteId(fromFlattenedMediaId: mediaItem.id)
                                    }
                                    guard anchors.indices.contains(current),
                                          let noteId = anchors[current] else { return }
                                    // Delay slightly to ensure MediaView route has been popped before navigation.
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        // Set pending target so chat can position immediately without visible scrolling
                                        router.pendingScrollToNoteId = noteId
                                        // If a chat for this client already exists in the stack, pop back to it; otherwise push.
                                        if let idx = router.path.lastIndex(where: {
                                            if case let .chat(id) = $0 { return id == clientId }
                                            return false
                                        }) {
                                            let newPath = Array(router.path.prefix(idx + 1))
                                            router.setPath(newPath)
                                        } else {
                                            router.push(.chat(clientId))
                                        }
                                        // Keep notification fallback for legacy flows if needed (optional)
                                    }
                                }
                            )
                        }
                        if shouldShowSeeAll {
                            SeeAllTile(size: 124, title: "전체보기")
                                .onTapGesture { viewModel.send(.presentArchive(.media)) }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
    }

    private var sharedLinksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "링크", iconName: "URL", iconColor: Color(hex: "BC0D59"), action: {
                viewModel.send(.presentArchive(.links))
            })
            ScrollView(.horizontal, showsIndicators: false) {
                let allItems = viewModel.linkItems
                let shouldShowSeeAll = allItems.count >= 9
                let previewItems = shouldShowSeeAll ? Array(allItems.prefix(8)) : allItems
                HStack(spacing: 2) {
                    ForEach(previewItems, id: \.id) { item in
                        APEXLinkTile(url: item.url, width: 124)
                    }
                    if shouldShowSeeAll {
                        SeeAllTile(size: 124, title: "전체보기")
                            .onTapGesture { viewModel.send(.presentArchive(.links)) }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private var sharedFilesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "파일", iconName: "File", iconColor: Color(hex: "00B22D"), action: {
                viewModel.send(.presentArchive(.files))
            })
            ScrollView(.horizontal, showsIndicators: false) {
                let allItems = viewModel.fileItems
                let shouldShowSeeAll = allItems.count >= 9
                let previewItems = shouldShowSeeAll ? Array(allItems.prefix(8)) : allItems
                HStack(spacing: 2) {
                    ForEach(previewItems, id: \.id) { item in
                        APEXFileTile(
                            url: item.url,
                            contentType: item.contentType,
                            highlightQuery: nil,
                            size: 124,
                            onTap: {
                                if FileManager.default.fileExists(atPath: item.url.path) {
                                    UIApplication.shared.open(item.url, options: [:], completionHandler: nil)
                                }
                            }
                        )
                    }
                    if shouldShowSeeAll {
                        SeeAllTile(size: 124, title: "전체보기")
                            .onTapGesture { viewModel.send(.presentArchive(.files)) }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private var sharedAudioSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "음성메모", iconName: "Waveform", iconColor: Color(hex: "E28822"), action: {
                viewModel.send(.presentArchive(.audio))
            })
            ScrollView(.horizontal, showsIndicators: false) {
                let allItems = viewModel.audioItems
                let shouldShowSeeAll = allItems.count >= 9
                let previewItems = shouldShowSeeAll ? Array(allItems.prefix(8)) : allItems
                HStack(spacing: 2) {
                    ForEach(previewItems, id: \.id) { item in
                        ZStack {
                            AudioSquareTile(
                                url: item.url,
                                duration: item.duration,
                                preferredLength: 124,
                                titleOverride: nil,
                                highlightQuery: nil
                            )
                            .allowsHitTesting(false)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.send(.openRecord(item.url)) }
                    }
                    if shouldShowSeeAll {
                        SeeAllTile(size: 124, title: "전체보기")
                            .onTapGesture { viewModel.send(.presentArchive(.audio)) }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }
    // MARK: - Helpers

    private var topBar: some View {
        ZStack(alignment: .center) {
            HStack(spacing: 0) {
                Button(action: { router.pop() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium, design: .default))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect()

                Spacer(minLength: 0)

                // Hide favorite button for my own profile
                let myId = ClientsStore.shared.clients.first?.id
                let isMe = (viewModel.client?.id == myId)
                if !isMe {
                    Button(action: { viewModel.send(.toggleFavorite) }) {
                        Image(systemName: viewModel.isFavorite ? "star.fill" : "star")
                            .font(.title4)
                            .foregroundColor(Color("Primary"))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect()
                }
            }
            .frame(height: 52)
            .padding(.horizontal, 12)
        }
    }

    private var bottomActionsBar: some View {
        VStack(spacing: Metrics.buttonGap) {
            DeleteMediaButton(
                title: "미디어 데이터 모두 삭제하기 (\(formatBytes(viewModel.totalMediaBytes)))",
                isDisabled: viewModel.totalMediaBytes == 0,
                action: { viewModel.send(.showDeleteMediaPrompt(true)) }
            )

            // Hide contact delete for my own profile
            let myId = ClientsStore.shared.clients.first?.id
            let isMe = (viewModel.client?.id == myId)
            if !isMe {
                DeleteContactButton(
                    action: { viewModel.send(.showDeleteContactOverlay(true)) }
                )
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 24)
        .padding(.top, 24)
        .padding(.bottom, 8)
        // Confirmations
        .alert("모든 미디어 데이터를 삭제할까요?", isPresented: $viewModel.showDeleteMediaAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) { viewModel.send(.deleteAllMedia) }
        } message: {
            Text("사진/영상, 파일, 음성메모 데이터를 모두 삭제합니다. 이 작업은 되돌릴 수 없습니다.")
        }
        .background(Color("Background").ignoresSafeArea())
    }

    private func sectionHeader(title: String, iconName: String, iconColor: Color, action: @escaping (() -> Void)) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                Image(iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
                
                Text(title)
                    .font(.body2)
                    .foregroundStyle(Color("BlackLabel"))
                
                Spacer()
                Image(systemName: "arrow.forward")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color("Primary"))
                    .frame(width: 19, height: 14)
            }
            .padding(.vertical, 10)
        }
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .buttonStyle(SectionHeaderPressedStyle())
    }

    // NotesView 방식의 오버레이 (로컬 상태 사용)
    private var contactDeleteOverlay: some View {
        Group {
            if viewModel.showDeleteContactOverlay {
                ZStack {
                    // 딤 배경
                    Color.black.opacity(0.35)
                        .ignoresSafeArea(.all)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.send(.showDeleteContactOverlay(false))
                        }
                    
                    ContactDeleteConfirmCard(
                        isChecked: $viewModel.isDeleteConfirmChecked,
                        onCancel: {
                            viewModel.send(.showDeleteContactOverlay(false))
                        },
                        onDelete: {
                            viewModel.send(.confirmDeleteContact)
                        }
                    )
                    .padding(.horizontal, 46)
                    .contentShape(Rectangle()) // 모달 카드 영역의 터치를 차단
                    .onTapGesture { } // 빈 제스처로 터치 이벤트 흡수
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
            VStack(alignment: .center, spacing: 0) {
                Profile(
                    image: image,
                    initials: initials,
                    size: .small,
                    fontSize: 64,
                    backgroundColor: Color("PrimaryContainer"),
                    textColor: .white,
                    fontWeight: .semibold
                )
                .padding(.bottom, Metrics.profileAndNameGap)

                Text(name)
                    .font(.title5)
                    .foregroundColor(Color("BlackLabel"))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, Metrics.nameAndPositionGap)

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

// MARK: - Action Buttons (Consistent Design)

private struct DeleteMediaButton: View {
    let title: String
    let isDisabled: Bool
    let action: () -> Void
    @State private var isPressed: Bool = false
    
    // 색상 정의 (편집시트와 일관성)
    private let normalBackground = Color("BackgroundSecondary")
    private let pressedBackground = Color(red: 0xED/255.0, green: 0xF0/255.0, blue: 1.0) // #EDF0FF
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body2)
                .foregroundColor(Color("BlackLabel"))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
        }
        .buttonStyle(.plain)
        .background(isPressed ? pressedBackground : normalBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isDisabled {
                        withAnimation(.easeInOut(duration: 0.12)) { isPressed = true }
                    }
                }
                .onEnded { _ in
                    if !isDisabled {
                        withAnimation(.easeInOut(duration: 0.12)) { isPressed = false }
                    }
                }
        )
    }
}

private struct DeleteContactButton: View {
    let action: () -> Void
    @State private var isPressed: Bool = false
    
    // 색상 정의 (편집시트와 일관성)
    private let normalBackground = Color("ErrorContainer")
    private let pressedBackground = Color(red: 1.0, green: 0xE8/255.0, blue: 0xE5/255.0) // #FFE8E5
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "trash.fill")
                    .foregroundColor(Color("Error"))
                Text("연락처 삭제하기")
                    .font(.body2)
                    .foregroundColor(Color("Error"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(.plain)
        .background(isPressed ? pressedBackground : normalBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.12)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.12)) { isPressed = false }
                }
        )
    }
}

// MARK: - ButtonStyles
private struct SectionHeaderPressedStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color("BackgroundSecondary") : Color.clear)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - DeleteConfirmCard (NotesView 스타일 완전 일치)
private struct ContactDeleteConfirmCard: View {
    @Binding var isChecked: Bool
    var onCancel: () -> Void
    var onDelete: () -> Void
    
    private enum Metrics {
        // 통일된 값들
        static let cornerRadius: CGFloat = 32
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 16
        
        // 간격들
        static let titleTop: CGFloat = 8
        static let sectionSpacing: CGFloat = 16
        static let checkboxToButtonSpacing: CGFloat = 24  // 체크박스와 버튼 사이
        static let buttonSpacing: CGFloat = 16
        
        // 체크박스
        static let checkboxSize: CGFloat = 24
        static let confirmSpacing: CGFloat = 16
        
        // 버튼
        static let buttonHeight: CGFloat = 48
        static let buttonWidth: CGFloat = 120
        static let buttonCorner: CGFloat = 100
    }
    
    // 색상 스펙
    private let deleteActiveRed = Color("Error")
    private let deleteActiveBackground = Color("ErrorHover")
    private let disabledGrayText = Color("GrayLabel")
    private let checkboxStroke = Color("BackgroundDisabled")

    var body: some View {
        VStack(spacing: 0) {
            titleSection
            
            Spacer()
                .frame(height: Metrics.sectionSpacing)
            
            bodySection
            
            Spacer()
                .frame(height: Metrics.sectionSpacing)
            
            confirmSection
            
            Spacer()
                .frame(height: Metrics.checkboxToButtonSpacing)
            
            buttonsSection
        }
        .padding(Metrics.horizontalPadding)
        .glassEffect(in: .rect(cornerRadius: Metrics.cornerRadius))
    }
    
    // MARK: - Sections
    
    private var titleSection: some View {
        Text("해당 연락처를 노트를 영구적으로 삭제하겠습니까?")
            .font(.body1)
            .foregroundColor(Color("BlackLabel"))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.top, 8)
    }
    
    private var bodySection: some View {
        Text("연락처 내 모든 노트와 파일이 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.")
            .font(.body3)
            .foregroundColor(.black)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }
    
    private var confirmSection: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.1)) {
                isChecked.toggle()
            }
        } label: {
            HStack(spacing: Metrics.confirmSpacing) {
                checkboxView
                Text("위 내용을 모두 확인했습니다.")
                    .font(.body2)
                    .foregroundColor(.black)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8) // 본문과 시작점 맞추기 위해 동일한 패딩
    }
    
    private var buttonsSection: some View {
        HStack(spacing: Metrics.buttonSpacing) {
            cancelButton
            deleteButton
        }
    }
    
    // MARK: Components
    private var checkboxView: some View {
        ZStack {
            Circle()
                .fill(isChecked ? Color("Primary") : Color.white)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(isChecked ? Color("Primary") : checkboxStroke, lineWidth: 1)
                )
            
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .opacity(isChecked ? 1 : 0)
        }
        .frame(width: Metrics.checkboxSize, height: Metrics.checkboxSize)
        .animation(.easeInOut(duration: 0.2), value: isChecked)
    }
    
    private var cancelButton: some View {
        Button(action: onCancel) {
            HStack(alignment: .center, spacing: 10) {
                Text("취소")
                    .font(.title5)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(width: Metrics.buttonWidth, height: Metrics.buttonHeight, alignment: .center)
            .background(Color("BackgroundSecondary"))
            .cornerRadius(Metrics.buttonCorner)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var deleteButton: some View {
        Button(action: { if isChecked { onDelete() } }) {
            HStack(alignment: .center, spacing: 10) {
                Text("삭제")
                    .font(.title5)
                    .foregroundColor(isChecked ? deleteActiveRed : disabledGrayText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(width: Metrics.buttonWidth, height: Metrics.buttonHeight, alignment: .center)
            .background(isChecked ? deleteActiveBackground : Color("BackgroundSecondary"))
            .cornerRadius(Metrics.buttonCorner)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isChecked)
        .accessibilityHint("확인 후 활성화됩니다.")
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

 

 

// normalizeURL is provided by LinkPreviewSupport.swift

// MARK: - Video duration helper
 

// (moved media deletion helpers to ChattingArchiveViewModel)

#Preview {
    ChattingArchiveView()
}

#Preview("전체보기 타일") {
    ChattingArchiveView.SeeAllTile(size: 124, title: "전체보기")
        .padding()
        .background(Color("Background"))
}

//
//  ArchiveListView.swift
//  APEX
//
//  Created by 조운경 on 11/8/25.
//

import SwiftUI
import UIKit
import AVFoundation
import LinkPresentation

enum ArchiveSection {
	case media, files, links, audio
}

struct ArchiveListView: View {
    @StateObject private var viewModel: ArchiveListViewModel
    var onClose: () -> Void
    @EnvironmentObject private var router: NavigationRouter
    private struct MediaViewerHandle: Identifiable { let id: UUID }
    @State private var mediaViewer: MediaViewerHandle?
    
    init(
        section: ArchiveSection,
        media: [FlattenedMediaItem],
        files: [FlattenedFileItem],
        links: [FlattenedLinkItem],
        audios: [FlattenedAudioItem],
        viewerTitle: String,
        excludedClientIds: [UUID],
        onClose: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: ArchiveListViewModel(
            section: section,
            media: media,
            files: files,
            links: links,
            audios: audios,
            viewerTitle: viewerTitle,
            excludedClientIds: excludedClientIds
        ))
        self.onClose = onClose
    }
    
    private enum Metrics {
        static let horizontalPadding: CGFloat = 16
        static let tapBetweenContentGap: CGFloat = 16
        static let groupMonthMediaGap: CGFloat = 16
        static let monthAndMediaGap: CGFloat = 6
        static let mediaGap: CGFloat = 2
        static let mediaSize: CGFloat = 121.67
    }
    
	var body: some View {
		VStack(spacing: 0) {
			APEXSheetTopBar(
				title: viewModel.viewerTitle,
				rightTitle: "",
				isRightEnabled: false,
				onRightTap: {},
				onClose: { onClose() },
				rightIconSystemName: nil,
                showsRightButton: false,
                leftIconSystemName: "xmark"
			)

			APEXUnderlineTabs(
				items: ["사진/동영상", "파일", "링크", "음성메모"],
				selectedIndex: Binding(
					get: { viewModel.tabIndex(from: viewModel.selectedTab) },
					set: { newIdx in viewModel.send(.setSelectedIndex(newIdx)) }
				)
			)
			.background(Color("Background"))

			content
                .padding(.vertical, Metrics.tapBetweenContentGap)
                .padding(.horizontal, Metrics.horizontalPadding)
				.background(Color("Background"))
				.ignoresSafeArea(edges: .bottom)
		}
		.contentShape(Rectangle())
		.simultaneousGesture(
			DragGesture(minimumDistance: 20)
				.onEnded { value in
					let dx = value.translation.width
					let dy = value.translation.height
					guard abs(dx) > abs(dy), abs(dx) > 40 else { return }
					let currentIndex = viewModel.tabIndex(from: viewModel.selectedTab)
					if dx < 0 {
						let next = min(3, currentIndex + 1)
						if next != currentIndex {
							withAnimation(.easeInOut(duration: 0.25)) {
								viewModel.selectedTab = viewModel.indexToTab(next)
							}
						}
					} else {
						let prev = max(0, currentIndex - 1)
						if prev != currentIndex {
							withAnimation(.easeInOut(duration: 0.25)) {
								viewModel.selectedTab = viewModel.indexToTab(prev)
							}
						}
					}
				}
		)
		.background(Color("Background"))
        // Present MediaView above this list locally so it doesn't appear behind this fullScreen cover
        .environment(\.apexOpenMediaViewer, { payload in
            APEXMediaViewerStore.shared.put(payload)
            mediaViewer = MediaViewerHandle(id: payload.id)
        })
        .fullScreenCover(item: $mediaViewer) { handle in
            if let payload = APEXMediaViewerStore.shared.get(handle.id) {
                MediaView(
                    items: payload.items,
                    selectedIndex: payload.index,
                    title: payload.title,
                    uploadedAt: payload.uploadedAt,
                    excludedClientIds: payload.excludedClientIds,
                    onSave: payload.onSave,
                    onDelete: payload.onDelete,
                    onTitleTap: payload.onTitleTap
                )
                .onDisappear {
                    APEXMediaViewerStore.shared.remove(handle.id)
                }
                .toolbar(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
            } else {
                Color.clear
            }
        }
        .fullScreenCover(item: $viewModel.recordPayload) { payload in
            RecordView(audioURL: payload.url)
        }
        .onAppear { viewModel.send(.onAppear) }
	}

	@ViewBuilder
	private var content: some View {
		ScrollView {
            LazyVStack(alignment: .leading, spacing: Metrics.groupMonthMediaGap) {
				switch viewModel.selectedTab {
				case .media:
					let groups = groupByMonth(viewModel.media, date: { $0.uploadedAt })
					ForEach(groups.indices, id: \.self) { gIdx in
						let group = groups[gIdx]
                        VStack(alignment: .leading, spacing: Metrics.monthAndMediaGap) {
                            sectionHeader(group.keyDate)
                            let columns = [GridItem(.flexible(minimum: Metrics.mediaSize), spacing: Metrics.mediaGap),
                                       GridItem(.flexible(minimum: Metrics.mediaSize), spacing: Metrics.mediaGap),
                                       GridItem(.flexible(minimum: Metrics.mediaSize), spacing: Metrics.mediaGap)]
                        LazyVGrid(columns: columns, spacing: Metrics.mediaGap) {
                                ForEach(Array(group.items.enumerated()), id: \.element.id) { idx, item in
                                APEXMediaTile(
                                    source: item.isVideo
                                        ? .video(item.videoURL ?? URL(fileURLWithPath: "/dev/null"))
                                        : .image(item.imageData ?? Data()),
                                    showVideoIcon: true,
                                    variant: .grid,
                                    showsDuration: false
                                )
                                .frame(width: Metrics.mediaSize, height: Metrics.mediaSize)
                                        .clipShape(Rectangle())
                                        // Keep duration always visible on top for videos
                                        .overlay(alignment: .bottomLeading) {
                                            if item.isVideo, let url = item.videoURL {
                                                Text(format(durationOf: url))
                                                    .font(.caption1)
                                                    .foregroundStyle(.white)
                                                    .padding(12)
                                            }
                                        }
										.apexOpensMediaViewer(
											items: group.items.map { mediaItem in
												if mediaItem.isVideo, let url = mediaItem.videoURL {
													return .video(url)
												} else {
													return .image(mediaItem.imageData ?? Data())
												}
											},
											index: idx,
											title: viewModel.ownerName(for: item) ?? viewModel.viewerTitle,
											uploadedAt: group.items[idx].uploadedAt,
                                            excludedClientIds: viewModel.excludedClientIds,
                                            onDelete: { removedIndex, _ in
                                                let flat = group.items
                                                guard flat.indices.contains(removedIndex) else { return }
                                                viewModel.deleteFlattenedMedia(flat[removedIndex])
                                            },
                                            onTitleTap: { current in
                                                guard let anchor = viewModel.anchor(in: group.items, current: current) else { return }
                                                // Dismiss ArchiveListView first, then push chat to ensure it appears on top
                                                onClose()
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                    // If a chat for this client already exists in the stack, pop back to it; otherwise push.
                                                    if let idx = router.path.lastIndex(where: {
                                                        if case let .chat(id) = $0 { return id == anchor.clientId }
                                                        return false
                                                    }) {
                                                        let newPath = Array(router.path.prefix(idx + 1))
                                                        router.setPath(newPath)
                                                    } else {
                                                        router.push(.chat(anchor.clientId))
                                                    }
                                                    // Post after chat has mounted to guarantee ScrollViewReader is ready
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                        NotificationCenter.default.post(
                                                            name: .apexNavigateToNote,
                                                            object: nil,
                                                            userInfo: ["noteId": anchor.noteId]
                                                        )
                                                    }
                                                    // Retry once more to cover edge cases where initial post races with mount/data load
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                                        NotificationCenter.default.post(
                                                            name: .apexNavigateToNote,
                                                            object: nil,
                                                            userInfo: ["noteId": anchor.noteId]
                                                        )
                                                    }
                                                    // Extra retry for slower mount paths (e.g., presented from Search)
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                                        NotificationCenter.default.post(
                                                            name: .apexNavigateToNote,
                                                            object: nil,
                                                            userInfo: ["noteId": anchor.noteId]
                                                        )
                                                    }
                                                }
                                            }
										)
                                }
                            }
                        }
					}
				case .files:
					let groups = groupByMonth(viewModel.files, date: { $0.uploadedAt })
					ForEach(groups.indices, id: \.self) { gIdx in
						let group = groups[gIdx]
                        VStack(alignment: .leading, spacing: Metrics.monthAndMediaGap) {
                            sectionHeader(group.keyDate)
                            let columns = [GridItem(.flexible(minimum: 100), spacing: Metrics.mediaGap),
                                           GridItem(.flexible(minimum: Metrics.mediaSize), spacing: Metrics.mediaGap),
                                           GridItem(.flexible(minimum: Metrics.mediaSize), spacing: Metrics.mediaGap)]
                            LazyVGrid(columns: columns, spacing: Metrics.mediaGap) {
                                ForEach(group.items, id: \.id) { item in
                                    APEXFileTile(
                                        url: item.url,
                                        contentType: item.contentType,
                                        highlightQuery: nil,
                                        size: Metrics.mediaSize,
                                        onTap: {
                                            if FileManager.default.fileExists(atPath: item.url.path) {
                                                UIApplication.shared.open(item.url, options: [:], completionHandler: nil)
                                            }
                                        }
                                    )
                                }
                            }
                        }
					}
				case .links:
					let groups = groupByMonth(viewModel.links, date: { $0.uploadedAt })
                    let colWidth = (UIScreen.main.bounds.width - Metrics.horizontalPadding * 2 - Metrics.mediaGap) / 2.0
					ForEach(groups.indices, id: \.self) { gIdx in
						let group = groups[gIdx]
                        VStack(alignment: .leading, spacing: Metrics.monthAndMediaGap) {
                            sectionHeader(group.keyDate)
                            let columns = [GridItem(.flexible(minimum: colWidth), spacing: Metrics.mediaGap),
                                           GridItem(.flexible(minimum: colWidth), spacing: Metrics.mediaGap)]
                            LazyVGrid(columns: columns, spacing: Metrics.mediaGap) {
                                ForEach(group.items, id: \.id) { item in
                                    LinkPreviewCard(url: item.url, width: colWidth)
                                }
                            }
                        }
					}
				case .audio:
					let groups = groupByMonth(viewModel.audios, date: { $0.uploadedAt })
					ForEach(groups.indices, id: \.self) { gIdx in
						let group = groups[gIdx]
                        VStack(alignment: .leading, spacing: Metrics.monthAndMediaGap) {
                            sectionHeader(group.keyDate)
                            let columns = [
                                GridItem(.flexible(minimum: Metrics.mediaSize), spacing: Metrics.mediaGap),
                                GridItem(.flexible(minimum: Metrics.mediaSize), spacing: Metrics.mediaGap),
                                GridItem(.flexible(minimum: Metrics.mediaSize), spacing: Metrics.mediaGap)
                            ]
                            LazyVGrid(columns: columns, spacing: Metrics.mediaGap) {
                                ForEach(group.items, id: \.id) { item in
                                    AudioSquareTile(
                                        url: item.url,
                                        duration: item.duration,
                                        preferredLength: 121.67,
                                        titleOverride: nil,
                                        highlightQuery: nil
                                    )
                                    .allowsHitTesting(false)
                                    .contentShape(Rectangle())
                                    .onTapGesture { viewModel.send(.openRecord(item.url)) }
                                }
                            }
                        }
					}
				}
			}
			.padding(.top, 8)
			.id(viewModel.selectedTab)
		}
	}

	private struct MonthGroup<T> {
		let keyDate: Date
		let items: [T]
	}

	private func groupByMonth<T>(_ items: [T], date: (T) -> Date) -> [MonthGroup<T>] {
		let cal = Calendar.current
		var buckets: [Date: [T]] = [:]
		for item in items {
			let itemDate = date(item)
			let comps = cal.dateComponents([.year, .month], from: itemDate)
			let key = cal.date(from: comps) ?? itemDate
			buckets[key, default: []].append(item)
		}
		let sortedKeys = buckets.keys.sorted(by: { $0 > $1 })
		return sortedKeys.map { MonthGroup(keyDate: $0, items: (buckets[$0] ?? [])) }
	}

	private func sectionHeader(_ date: Date) -> some View {
		let cal = Calendar.current
		let nowYear = cal.component(.year, from: Date())
		let year = cal.component(.year, from: date)
		let month = cal.component(.month, from: date)
		let title = (year == nowYear) ? "\(month)월" : String(format: "%d.%02d", year, month)
		return Text(title)
			.font(.caption3)
			.foregroundColor(Color("GrayLabel"))
			.padding(.horizontal, 4)
	}

}

// Media tile moved to common: APEXMediaTile

#Preview {
	ArchiveListView(section: .media, media: [], files: [], links: [], audios: [], viewerTitle: "홍 길동", excludedClientIds: [], onClose: {})
}

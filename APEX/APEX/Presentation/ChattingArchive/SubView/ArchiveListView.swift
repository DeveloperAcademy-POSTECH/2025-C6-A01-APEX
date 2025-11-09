//
//  ArchiveListView.swift
//  APEX
//
//  Created by 조운경 on 11/8/25.
//

import SwiftUI
import AVFoundation
import LinkPresentation

enum ArchiveSection {
	case media, files, links, audio
}

struct ArchiveListView: View {
	let section: ArchiveSection
	let media: [FlattenedMediaItem]
	let files: [FlattenedFileItem]
	let links: [FlattenedLinkItem]
	let audios: [FlattenedAudioItem]
	let viewerTitle: String
	let excludedClientIds: [UUID]
	var onClose: () -> Void
	@State private var selectedTab: ArchiveSection = .media
    // Record viewer
    private struct ArchiveRecordPayload: Identifiable { let id = UUID(); let url: URL }
    @State private var recordPayload: ArchiveRecordPayload?

	var body: some View {
		VStack(spacing: 0) {
			APEXSheetTopBar(
				title: viewerTitle,
				rightTitle: "",
				isRightEnabled: false,
				onRightTap: {},
				onClose: { onClose() },
				rightIconSystemName: nil,
                showsRightButton: false,
                leftIconSystemName: "chevron.left"
			)
			.padding(.bottom, 4)

			APEXUnderlineTabs(
				items: ["사진/동영상", "파일", "링크", "음성메모"],
				selectedIndex: Binding(
					get: { tabIndex(from: selectedTab) },
					set: { newIdx in selectedTab = indexToTab(newIdx) }
				)
			)
			.background(Color("Background"))

			content
				.padding(.horizontal, 16)
				.padding(.bottom, 16)
				.background(Color("Background"))
				.ignoresSafeArea(edges: .bottom)
		}
		.background(Color("Background"))
        .fullScreenCover(item: $recordPayload) { payload in
            RecordView(audioURL: payload.url)
        }
        // Reflect audio rename/delete from RecordView across archive list (infer clientId from excludedClientIds.first)
        .onReceive(NotificationCenter.default.publisher(for: .apexAudioRenamed)) { notif in
            guard let oldURL = notif.userInfo?["oldURL"] as? URL,
                  let newURL = notif.userInfo?["newURL"] as? URL,
                  let clientId = excludedClientIds.first else { return }
            var notes = ChatStore.shared.notes(for: clientId)
            var changed = false
            for idx in notes.indices {
                if case var .audio(audios) = notes[idx].bundle {
                    var updated = false
                    for j in audios.indices where audios[j].url == oldURL {
                        audios[j] = AudioAttachment(url: newURL, duration: audios[j].duration)
                        updated = true
                    }
                    if updated {
                        notes[idx].bundle = .audio(audios)
                        changed = true
                    }
                }
            }
            if changed { ChatStore.shared.setNotes(notes, for: clientId) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .apexAudioDeleted)) { notif in
            guard let url = notif.userInfo?["url"] as? URL,
                  let clientId = excludedClientIds.first else { return }
            var notes = ChatStore.shared.notes(for: clientId)
            var changed = false
            for idx in notes.indices {
                if case var .audio(audios) = notes[idx].bundle {
                    let before = audios.count
                    audios.removeAll { $0.url == url }
                    if audios.count != before {
                        notes[idx].bundle = audios.isEmpty ? nil : .audio(audios)
                        changed = true
                    }
                }
            }
            if changed { ChatStore.shared.setNotes(notes, for: clientId) }
        }
		.onAppear { selectedTab = section }
	}

	@ViewBuilder
	private var content: some View {
		ScrollView {
			LazyVStack(alignment: .leading, spacing: 16) {
				switch selectedTab {
				case .media:
					let groups = groupByMonth(media, date: { $0.uploadedAt })
					ForEach(groups.indices, id: \.self) { gIdx in
						let group = groups[gIdx]
                        VStack(alignment: .leading, spacing: 6) {
                            sectionHeader(group.keyDate)
                        let columns = [GridItem(.flexible(minimum: 121.67), spacing: 2),
                                       GridItem(.flexible(minimum: 121.67), spacing: 2),
                                       GridItem(.flexible(minimum: 121.67), spacing: 2)]
                        LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(Array(group.items.enumerated()), id: \.element.id) { idx, item in
                                APEXMediaTile(
                                    source: item.isVideo
                                        ? .video(item.videoURL ?? URL(fileURLWithPath: "/dev/null"))
                                        : .image(item.imageData ?? Data()),
                                    showVideoIcon: true,
                                    variant: .grid,
                                    showsDuration: false
                                )
                                    .frame(height: 121.67)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
											title: viewerTitle,
											uploadedAt: nil,
                                            excludedClientIds: excludedClientIds,
                                            onDelete: { removedIndex, _ in
                                                let flat = group.items
                                                guard flat.indices.contains(removedIndex) else { return }
                                                // Try to infer clientId from excludedClientIds first (ChatDetail passes single client id)
                                                if let clientId = excludedClientIds.first {
                                                    deleteFlattenedMedia(item: flat[removedIndex], clientId: clientId)
                                                }
                                            }
										)
                                }
                            }
                        }
					}
				case .files:
					let groups = groupByMonth(files, date: { $0.uploadedAt })
					ForEach(groups.indices, id: \.self) { gIdx in
						let group = groups[gIdx]
                        VStack(alignment: .leading, spacing: 6) {
                            sectionHeader(group.keyDate)
                            let columns = [GridItem(.flexible(minimum: 100), spacing: 8),
                                           GridItem(.flexible(minimum: 100), spacing: 8),
                                           GridItem(.flexible(minimum: 100), spacing: 8)]
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(group.items, id: \.id) { item in
                                    APEXFileTile(
                                        url: item.url,
                                        contentType: item.contentType,
                                        highlightQuery: nil,
                                        size: 119,
                                        onTap: nil
                                    )
                                }
                            }
                        }
					}
				case .links:
					let groups = groupByMonth(links, date: { $0.uploadedAt })
					let spacing: CGFloat = 8
					let colWidth = (UIScreen.main.bounds.width - 32 - spacing) / 2.0
					ForEach(groups.indices, id: \.self) { gIdx in
						let group = groups[gIdx]
                        VStack(alignment: .leading, spacing: 6) {
                            sectionHeader(group.keyDate)
                            let columns = [GridItem(.flexible(minimum: colWidth), spacing: spacing),
                                           GridItem(.flexible(minimum: colWidth), spacing: spacing)]
                            LazyVGrid(columns: columns, spacing: spacing) {
                                ForEach(group.items, id: \.id) { item in
                                    LinkPreviewCard(url: item.url, width: colWidth)
                                }
                            }
                        }
					}
				case .audio:
					let groups = groupByMonth(audios, date: { $0.uploadedAt })
					ForEach(groups.indices, id: \.self) { gIdx in
						let group = groups[gIdx]
                        VStack(alignment: .leading, spacing: 6) {
                            sectionHeader(group.keyDate)
                            let columns = [GridItem(.flexible(minimum: 100), spacing: 8),
                                           GridItem(.flexible(minimum: 100), spacing: 8),
                                           GridItem(.flexible(minimum: 100), spacing: 8)]
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(group.items, id: \.id) { item in
                                    ZStack {
                                        AudioSquareTile(
                                            url: item.url,
                                            duration: item.duration,
                                            preferredLength: 119,
                                            titleOverride: nil,
                                            highlightQuery: nil
                                        )
                                        .allowsHitTesting(false)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { recordPayload = ArchiveRecordPayload(url: item.url) }
                                }
                            }
                        }
					}
				}
			}
			.padding(.top, 8)
			.id(selectedTab)
		}
	}

	private func tabIndex(from tab: ArchiveSection) -> Int {
		switch tab {
		case .media: return 0
		case .files: return 1
		case .links: return 2
		case .audio: return 3
		}
	}
	private func indexToTab(_ idx: Int) -> ArchiveSection {
		switch idx {
		case 0: return .media
		case 1: return .files
		case 2: return .links
		case 3: return .audio
		default: return .media
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

// MARK: - Video duration helper
private func format(durationOf url: URL) -> String {
    let asset = AVAsset(url: url)
    let seconds = Int(CMTimeGetSeconds(asset.duration).rounded())
    let minutes = seconds / 60
    let remainingSeconds = seconds % 60
    return String(format: "%02d:%02d", minutes, remainingSeconds)
}

// MARK: - Media deletion helper (mirrors ChattingDetailView logic)
private func deleteFlattenedMedia(item: FlattenedMediaItem, clientId: UUID) {
    var notes = ChatStore.shared.notes(for: clientId)
    guard let parsed = parseFlattenedMediaId(item.id),
          let noteIndex = notes.firstIndex(where: { $0.id == parsed.noteId }),
          case var .media(images, videos) = notes[noteIndex].bundle else { return }
    if parsed.isImage {
        guard images.indices.contains(parsed.localIndex) else { return }
        images.remove(at: parsed.localIndex)
    } else {
        guard videos.indices.contains(parsed.localIndex) else { return }
        videos.remove(at: parsed.localIndex)
    }
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
    notes[noteIndex].bundle = (images.isEmpty && videos.isEmpty) ? nil : .media(images: images, videos: videos)
    ChatStore.shared.setNotes(notes, for: clientId)
}

private func parseFlattenedMediaId(_ id: String) -> (noteId: UUID, isImage: Bool, localIndex: Int)? {
    if let range = id.range(of: "-i-", options: .backwards) {
        let uuidPart = String(id[..<range.lowerBound])
        let indexPart = String(id[range.upperBound...])
        guard let noteId = UUID(uuidString: uuidPart), let localIndex = Int(indexPart) else { return nil }
        return (noteId, true, localIndex)
    } else if let range = id.range(of: "-v-", options: .backwards) {
        let uuidPart = String(id[..<range.lowerBound])
        let indexPart = String(id[range.upperBound...])
        guard let noteId = UUID(uuidString: uuidPart), let localIndex = Int(indexPart) else { return nil }
        return (noteId, false, localIndex)
    } else {
        return nil
    }
}

#Preview {
	ArchiveListView(section: .media, media: [], files: [], links: [], audios: [], viewerTitle: "홍 길동", excludedClientIds: [], onClose: {})
}

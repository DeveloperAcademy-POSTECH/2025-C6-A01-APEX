//
//  SearchView.swift
//  APEX
//
//  Created by 조운경 on 11/12/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct SearchView: View {
	@EnvironmentObject private var router: NavigationRouter
    @ObservedObject private var clientsStore = ClientsStore.shared
	private let onCloseAction: (() -> Void)?
	
	// Search
	@State private var query: String = ""
	@FocusState private var isSearchFocused: Bool
	
	// Preview initializer to seed states
	init(
		onClose: (() -> Void)? = nil,
		previewQuery: String? = nil,
		previewRecentQueries: [String] = [],
		previewAllMedia: [FlattenedMediaItem] = [],
		previewAllFiles: [FlattenedFileItem] = [],
		previewAllLinks: [FlattenedLinkItem] = [],
		previewAllAudios: [FlattenedAudioItem] = []
	) {
		self.onCloseAction = onClose
		if let previewQuery {
			_query = State(initialValue: previewQuery)
		}
		_recentQueries = State(initialValue: previewRecentQueries)
		_allMedia = State(initialValue: previewAllMedia)
		_allFiles = State(initialValue: previewAllFiles)
		_allLinks = State(initialValue: previewAllLinks)
		_allAudios = State(initialValue: previewAllAudios)
	}
	
	// Recent searches
	@AppStorage("apex.search.recentQueries") private var recentQueriesStorage: String = ""
	@State private var recentQueries: [String] = []
	
	// Aggregated data across all clients
	@State private var allMedia: [FlattenedMediaItem] = []
	@State private var allFiles: [FlattenedFileItem] = []
	@State private var allAudios: [FlattenedAudioItem] = []
	@State private var allLinks: [FlattenedLinkItem] = []
	
	// Navigation to archive list from headers
	private struct ArchivePushPayload: Identifiable, Hashable {
		let id = UUID()
		let section: ArchiveSection
		let media: [FlattenedMediaItem]
		let files: [FlattenedFileItem]
		let links: [FlattenedLinkItem]
		let audios: [FlattenedAudioItem]
		let title: String
		let excludedClientIds: [UUID]
		
		static func == (lhs: ArchivePushPayload, rhs: ArchivePushPayload) -> Bool {
			lhs.id == rhs.id
		}
		func hash(into hasher: inout Hasher) {
			hasher.combine(id)
		}
	}
	@State private var archivePayload: ArchivePushPayload?
    // Record viewer
    private struct RecordPayload: Identifiable { let id = UUID(); let url: URL }
    @State private var recordPayload: RecordPayload?
	
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				// 검색 전 상태
				if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
					recentSearchesSection
					globalMediaSection
					globalFilesSection
					globalLinksSection
					globalAudioSection
				} else {
					// 검색 중 상태
					matchedClientsSection
					matchedNotesSection
					filteredMediaSection
					filteredFilesSection
					filteredLinksSection
					filteredAudioSection
				}
			}
			.padding(.leading, 16)
			.padding(.vertical, 12)
		}
		.background(Color("Background"))
		.scrollEdgeEffectStyle(.soft, for: .top)
		.toolbar(.hidden, for: .tabBar)
		.safeAreaInset(edge: .bottom) {
			let isSearching = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
			APEXSearchBar(
				text: $query,
				isFocused: _isSearchFocused,
				onPrev: {},
				onNext: {},
				onClose: {
					isSearchFocused = false
					if !query.isEmpty {
						saveRecent(query)
					}
					query = ""
					onCloseAction?()
				},
				onTextChange: { _ in
					// no-op; lists are computed reactively
				},
				placeholder: "검색",
				showNavButtons: isSearching,
				showSearchIcon: !isSearching
			)
			.background(Color("Background"))
		}
		.toolbar(.hidden, for: .navigationBar)
		.onAppear {
			loadRecent()
			reloadAllAggregates()
		}
		.navigationDestination(item: $archivePayload) { payload in
			ArchiveListView(
				section: payload.section,
				media: payload.media,
				files: payload.files,
				links: payload.links,
				audios: payload.audios,
				viewerTitle: payload.title,
				excludedClientIds: payload.excludedClientIds,
				onClose: { archivePayload = nil }
			)
			.toolbar(.hidden, for: .navigationBar)
			.toolbar(.hidden, for: .tabBar)
		}
        .fullScreenCover(item: $recordPayload) { payload in
            RecordView(audioURL: payload.url)
        }
	}
}

// MARK: - Sections (Idle)
private extension SearchView {
	var recentSearchesSection: some View {
		Group {
			if !recentQueries.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					sectionHeader(title: "최근 검색", iconName: "clock.arrow.circlepath", iconColor: Color("Primary"), onTapArrow: {
						// No destination; keep behavior as non-clickable header
					}, showsArrow: false)
					.overlay(alignment: .trailing) {
						Button {
							clearRecent()
						} label: {
							Text("초기화")
								.font(.body3)
								.foregroundStyle(Color("Primary"))
								.padding(.horizontal, 8)
								.padding(.vertical, 6)
								.background(Color("BackgroundSecondary"))
								.clipShape(Capsule())
						}
						.buttonStyle(.plain)
                        .padding(.trailing, 16)
					}
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 8) {
							ForEach(recentQueries, id: \.self) { item in
								Button {
									query = item
									isSearchFocused = true
								} label: {
									Text(item)
										.font(.caption2)
										.foregroundStyle(Color("BlackLabel"))
										.padding(.horizontal, 12)
										.padding(.vertical, 8)
										.background(Color("BackgroundSecondary"))
										.clipShape(Capsule())
								}
								.buttonStyle(.plain)
							}
						}
						.padding(.horizontal, 2)
					}
				}
			}
		}
	}
	
	var globalMediaSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			sectionHeader(title: "사진/동영상", iconName: "photo", iconColor: Color("Primary"), onTapArrow: {
				archivePayload = ArchivePushPayload(section: .media, media: allMedia, files: [], links: [], audios: [], title: "모든 클라이언트", excludedClientIds: [])
			})
			if !allMedia.isEmpty {
				let shouldShowSeeAll = allMedia.count >= 9
				let previewItems = shouldShowSeeAll ? Array(allMedia.prefix(8)) : allMedia
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 2) {
						ForEach(Array(previewItems.enumerated()), id: \.element.id) { _, item in
							let owner = ownerForFlattenedMedia(item)
							let payload = owner.flatMap { mediaPayloadForClient($0.client) }
							let parsed = parseFlattenedMediaId(item.id)
							let selectedIndex = payload.flatMap { payloadData in
								payloadData.anchors.firstIndex(where: { $0.noteId == parsed?.noteId && $0.isImage == (parsed?.isImage ?? false) && $0.localIndex == (parsed?.localIndex ?? -1) })
							} ?? 0
							APEXMediaTile(
								source: item.isVideo ? .video(item.videoURL!) : .image(item.imageData ?? Data()),
								showVideoIcon: true,
								variant: .grid,
								showsDuration: false
							)
							.frame(width: 121.67, height: 121.67)
							.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
							.apexOpensMediaViewer(
								items: payload?.items ?? [],
								index: max(0, selectedIndex),
								title: owner.map { "\($0.client.name) \($0.client.surname)" } ?? "Shared Media",
								uploadedAt: nil,
								excludedClientIds: owner.map { [$0.client.id] } ?? [],
								onTitleTap: { current in
									guard let owner, let payload, payload.anchors.indices.contains(current) else { return }
									let anchor = payload.anchors[current]
									router.push(.chat(owner.client.id))
									DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
										NotificationCenter.default.post(name: .apexNavigateToNote, object: nil, userInfo: ["noteId": anchor.noteId])
									}
								}
							)
						}
						if shouldShowSeeAll {
							ChattingArchiveView.SeeAllTile(size: 121.67, title: "전체보기")
								.onTapGesture {
									archivePayload = ArchivePushPayload(section: .media, media: allMedia, files: [], links: [], audios: [], title: "모든 클라이언트", excludedClientIds: [])
								}
						}
					}
					.padding(.horizontal, 2)
				}
			}
		}
	}
	
	var globalFilesSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			sectionHeader(title: "파일", iconName: "document", iconColor: Color(hex: "00B22D"), onTapArrow: {
				archivePayload = ArchivePushPayload(section: .files, media: [], files: allFiles, links: [], audios: [], title: "모든 클라이언트", excludedClientIds: [])
			})
			if !allFiles.isEmpty {
				let shouldShowSeeAll = allFiles.count >= 9
				let previewItems = shouldShowSeeAll ? Array(allFiles.prefix(8)) : allFiles
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 2) {
						ForEach(previewItems, id: \.id) { item in
							APEXFileTile(
								url: item.url,
								contentType: item.contentType,
								highlightQuery: nil,
								size: 121.67,
								onTap: {
									if FileManager.default.fileExists(atPath: item.url.path) {
										UIApplication.shared.open(item.url, options: [:], completionHandler: nil)
									}
								}
							)
						}
						if shouldShowSeeAll {
							ChattingArchiveView.SeeAllTile(size: 121.67, title: "전체보기")
								.onTapGesture {
									archivePayload = ArchivePushPayload(section: .files, media: [], files: allFiles, links: [], audios: [], title: "모든 클라이언트", excludedClientIds: [])
								}
						}
					}
					.padding(.horizontal, 2)
				}
			}
		}
	}
	
	var globalLinksSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			sectionHeader(title: "링크", iconName: "link", iconColor: Color(hex: "BC0D59"), onTapArrow: {
				archivePayload = ArchivePushPayload(section: .links, media: [], files: [], links: allLinks, audios: [], title: "모든 클라이언트", excludedClientIds: [])
			})
			if !allLinks.isEmpty {
				let shouldShowSeeAll = allLinks.count >= 9
				let previewItems = shouldShowSeeAll ? Array(allLinks.prefix(8)) : allLinks
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 2) {
						ForEach(previewItems, id: \.id) { item in
							APEXLinkTile(url: item.url, width: 121.67)
						}
						if shouldShowSeeAll {
							ChattingArchiveView.SeeAllTile(size: 121.67, title: "전체보기")
								.onTapGesture {
									archivePayload = ArchivePushPayload(section: .links, media: [], files: [], links: allLinks, audios: [], title: "모든 클라이언트", excludedClientIds: [])
								}
						}
					}
					.padding(.horizontal, 2)
				}
			}
		}
	}
	
	var globalAudioSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			sectionHeader(title: "음성메모", iconName: "waveform", iconColor: Color(hex: "E28822"), onTapArrow: {
				archivePayload = ArchivePushPayload(section: .audio, media: [], files: [], links: [], audios: allAudios, title: "모든 클라이언트", excludedClientIds: [])
			})
			if !allAudios.isEmpty {
				let shouldShowSeeAll = allAudios.count >= 9
				let previewItems = shouldShowSeeAll ? Array(allAudios.prefix(8)) : allAudios
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 2) {
						ForEach(previewItems, id: \.id) { item in
							ZStack {
								AudioSquareTile(
									url: item.url,
									duration: item.duration,
									preferredLength: 121.67,
									titleOverride: nil,
									highlightQuery: nil
								)
								.allowsHitTesting(false)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { recordPayload = RecordPayload(url: item.url) }
						}
						if shouldShowSeeAll {
							ChattingArchiveView.SeeAllTile(size: 121.67, title: "전체보기")
								.onTapGesture {
									archivePayload = ArchivePushPayload(section: .audio, media: [], files: [], links: [], audios: allAudios, title: "모든 클라이언트", excludedClientIds: [])
								}
						}
					}
					.padding(.horizontal, 2)
				}
			}
		}
	}
}

// MARK: - Sections (Searching)
private extension SearchView {
	var matchedClientsSection: some View {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		let clients = clientsStore.clients
		let filtered = clients.filter { client in
			guard !trimmed.isEmpty else { return false }
			let haystacks: [String] = [
				client.name, client.surname,
				client.company, client.position ?? "",
				client.email ?? "", client.phoneNumber ?? ""
			]
			return haystacks.contains(where: { $0.localizedCaseInsensitiveContains(trimmed) })
		}
		return Group {
			if !filtered.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					sectionHeader(title: "연락처", iconName: "person.crop.circle.fill", iconColor: Color("Primary"), onTapArrow: {
						// no-op
					}, showsArrow: false)
					VStack(spacing: 0) {
						ForEach(filtered) { client in
							Button {
								saveRecent(trimmed)
								let isMe = (client.email ?? "") == sampleMyProfileClient.email
								if isMe {
									router.push(.myProfile)
								} else {
									router.push(.profileDetail(client.id))
								}
							} label: {
								HStack(spacing: 12) {
									Profile(
										image: client.profile,
										initials: Profile.makeInitials(name: client.name, surname: client.surname),
										size: .extraSmall,
                                        fontSize: 30.72,
										backgroundColor: Color("PrimaryContainer"),
										textColor: .white,
										fontWeight: .semibold
									)
									VStack(alignment: .leading, spacing: 0) {
										highlightedText("\(client.name) \(client.surname)", highlight: trimmed)
											.font(.body2)
											.foregroundStyle(Color("BlackLabel"))
										if !client.company.isEmpty {
											highlightedText(client.company, highlight: trimmed)
												.font(.body5)
												.foregroundStyle(Color("GrayLabel"))
										}
									}
									Spacer()
								}
								.padding(.vertical, 8)
								.contentShape(Rectangle())
							}
							.buttonStyle(.plain)
						}
					}
				}
			}
		}
	}
	
	var matchedNotesSection: some View {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		let pairs: [(Client, Note)] = allClientNotes().compactMap { pair in
			let (client, note) = pair
			guard let text = note.text, !trimmed.isEmpty else { return nil }
			if text.localizedCaseInsensitiveContains(trimmed) {
				return (client, note)
			}
			return nil
		}
		return Group {
			if !pairs.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					sectionHeader(title: "텍스트", iconName: "text.quote", iconColor: Color("Primary"), onTapArrow: {
						// no-op
					}, showsArrow: false)
					VStack(spacing: 8) {
						ForEach(pairs, id: \.1.id) { client, note in
							Button {
								saveRecent(trimmed)
								router.push(.chat(client.id))
							} label: {
								HStack(alignment: .top, spacing: 8) {
									Profile(
										image: client.profile,
										initials: Profile.makeInitials(name: client.name, surname: client.surname),
										size: .extraSmall,
                                        fontSize: 30.72,
										backgroundColor: Color("PrimaryContainer"),
										textColor: .white,
										fontWeight: .semibold
									)
									VStack(alignment: .leading, spacing: 6) {
                                        highlightedText("\(client.name) \(client.surname)", highlight: trimmed)
                                            .font(.caption1)
                                            .foregroundStyle(Color("BlackLabel"))
                                            .lineLimit(1)
										highlightedText(note.text ?? "", highlight: trimmed)
											.font(.body6)
											.foregroundStyle(Color("BlackLabel"))
											.lineLimit(2)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(Color("BackgroundSecondary"))
                                            .cornerRadius(15)
									}
                                    Spacer()
								}
								.contentShape(Rectangle())
							}
							.buttonStyle(.plain)
						}
					}
				}
			}
		}
	}
	
	var filteredMediaSection: some View {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		let noteIdsWithMatch: Set<UUID> = Set(allClientNotes().compactMap { (_, note) in
			guard let text = note.text, !trimmed.isEmpty else { return nil }
			return text.localizedCaseInsensitiveContains(trimmed) ? note.id : nil
		})
		let items = allMedia.filter { item in
			guard let parsed = parseFlattenedMediaId(item.id) else { return false }
			return noteIdsWithMatch.contains(parsed.noteId)
		}
		return filteredMediaSectionCore(items: items, title: "사진/동영상")
	}
	
	private func filteredMediaSectionCore(items: [FlattenedMediaItem], title: String) -> some View {
		Group {
			if !items.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					sectionHeader(title: title, iconName: "photo", iconColor: Color("Primary"), onTapArrow: {
						archivePayload = ArchivePushPayload(section: .media, media: items, files: [], links: [], audios: [], title: "검색 결과", excludedClientIds: [])
					})
					let shouldShowSeeAll = items.count >= 9
					let previewItems = shouldShowSeeAll ? Array(items.prefix(8)) : items
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 2) {
							ForEach(Array(previewItems.enumerated()), id: \.element.id) { _, item in
								let owner = ownerForFlattenedMedia(item)
								let payload = owner.flatMap { mediaPayloadForClient($0.client) }
								let parsed = parseFlattenedMediaId(item.id)
								let selectedIndex = payload.flatMap { payloadData in
									payloadData.anchors.firstIndex(where: { $0.noteId == parsed?.noteId && $0.isImage == (parsed?.isImage ?? false) && $0.localIndex == (parsed?.localIndex ?? -1) })
								} ?? 0
								APEXMediaTile(
									source: item.isVideo ? .video(item.videoURL!) : .image(item.imageData ?? Data()),
									showVideoIcon: true,
									variant: .grid,
									showsDuration: false
								)
								.frame(width: 121.67, height: 121.67)
								.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
								.apexOpensMediaViewer(
									items: payload?.items ?? [],
									index: max(0, selectedIndex),
									title: owner.map { "\($0.client.name) \($0.client.surname)" } ?? "Shared Media",
									uploadedAt: nil,
									excludedClientIds: owner.map { [$0.client.id] } ?? [],
									onTitleTap: { current in
										guard let owner, let payload, payload.anchors.indices.contains(current) else { return }
										let anchor = payload.anchors[current]
										router.push(.chat(owner.client.id))
										DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
											NotificationCenter.default.post(name: .apexNavigateToNote, object: nil, userInfo: ["noteId": anchor.noteId])
										}
									}
								)
							}
							if shouldShowSeeAll {
								ChattingArchiveView.SeeAllTile(size: 121.67, title: "전체보기")
									.onTapGesture {
										archivePayload = ArchivePushPayload(section: .media, media: items, files: [], links: [], audios: [], title: "검색 결과", excludedClientIds: [])
									}
							}
						}
						.padding(.horizontal, 2)
					}
				}
			}
		}
	}
	
	var filteredFilesSection: some View {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		let items = allFiles.filter { file in
			file.url.lastPathComponent.localizedCaseInsensitiveContains(trimmed)
		}
		return Group {
			if !items.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					sectionHeader(title: "파일", iconName: "document", iconColor: Color(hex: "00B22D"), onTapArrow: {
						archivePayload = ArchivePushPayload(section: .files, media: [], files: items, links: [], audios: [], title: "검색 결과", excludedClientIds: [])
					})
					let shouldShowSeeAll = items.count >= 9
					let previewItems = shouldShowSeeAll ? Array(items.prefix(8)) : items
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 2) {
							ForEach(previewItems, id: \.id) { item in
								APEXFileTile(
									url: item.url,
									contentType: item.contentType,
									highlightQuery: trimmed,
									size: 121.67,
									onTap: {
										if FileManager.default.fileExists(atPath: item.url.path) {
											UIApplication.shared.open(item.url, options: [:], completionHandler: nil)
										}
									}
								)
							}
							if shouldShowSeeAll {
								ChattingArchiveView.SeeAllTile(size: 121.67, title: "전체보기")
									.onTapGesture {
										archivePayload = ArchivePushPayload(section: .files, media: [], files: items, links: [], audios: [], title: "검색 결과", excludedClientIds: [])
									}
							}
						}
						.padding(.horizontal, 2)
					}
				}
			}
		}
	}
	
	var filteredLinksSection: some View {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		let items = allLinks.filter { link in
			link.url.absoluteString.localizedCaseInsensitiveContains(trimmed)
		}
		return Group {
			if !items.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					sectionHeader(title: "링크", iconName: "link", iconColor: Color(hex: "BC0D59"), onTapArrow: {
						archivePayload = ArchivePushPayload(section: .links, media: [], files: [], links: items, audios: [], title: "검색 결과", excludedClientIds: [])
					})
					let shouldShowSeeAll = items.count >= 9
					let previewItems = shouldShowSeeAll ? Array(items.prefix(8)) : items
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 2) {
							ForEach(previewItems, id: \.id) { item in
								APEXLinkTile(url: item.url, width: 121.67)
							}
							if shouldShowSeeAll {
								ChattingArchiveView.SeeAllTile(size: 121.67, title: "전체보기")
									.onTapGesture {
										archivePayload = ArchivePushPayload(section: .links, media: [], files: [], links: items, audios: [], title: "검색 결과", excludedClientIds: [])
									}
							}
						}
						.padding(.horizontal, 2)
					}
				}
			}
		}
	}
	
	var filteredAudioSection: some View {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		let items = allAudios.filter { audio in
			let base = audio.url.deletingPathExtension().lastPathComponent
			return base.localizedCaseInsensitiveContains(trimmed)
		}
		return Group {
			if !items.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					sectionHeader(title: "음성메모", iconName: "waveform", iconColor: Color(hex: "E28822"), onTapArrow: {
						archivePayload = ArchivePushPayload(section: .audio, media: [], files: [], links: [], audios: items, title: "검색 결과", excludedClientIds: [])
					})
					let shouldShowSeeAll = items.count >= 9
					let previewItems = shouldShowSeeAll ? Array(items.prefix(8)) : items
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 2) {
							ForEach(previewItems, id: \.id) { item in
								ZStack {
									AudioSquareTile(
										url: item.url,
										duration: item.duration,
										preferredLength: 121.67,
										titleOverride: nil,
										highlightQuery: trimmed
									)
									.allowsHitTesting(false)
								}
								.contentShape(Rectangle())
                                .onTapGesture { recordPayload = RecordPayload(url: item.url) }
							}
							if shouldShowSeeAll {
								ChattingArchiveView.SeeAllTile(size: 121.67, title: "전체보기")
									.onTapGesture {
										archivePayload = ArchivePushPayload(section: .audio, media: [], files: [], links: [], audios: items, title: "검색 결과", excludedClientIds: [])
									}
							}
						}
						.padding(.horizontal, 2)
					}
				}
			}
		}
	}
}

// MARK: - Helpers
private extension SearchView {
	func loadRecent() {
		recentQueries = recentQueriesStorage
			.split(separator: "\n")
			.map { String($0) }
			.filter { !$0.isEmpty }
	}
	
    func saveRecent(_ queryString: String) {
        let trimmed = queryString.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		var set = [trimmed] + recentQueries.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
		if set.count > 12 { set = Array(set.prefix(12)) }
		recentQueries = set
		recentQueriesStorage = set.joined(separator: "\n")
	}
	
	func reloadAllAggregates() {
		let notes = allClientNotes().map { $0.1 }
		allMedia = computeMediaItems(from: notes)
		allFiles = computeFileItems(from: notes)
		allAudios = computeAudioItems(from: notes)
		allLinks = computeLinkItems(from: notes)
	}
	
	func clearRecent() {
		recentQueries = []
		recentQueriesStorage = ""
	}
	
	func computeMediaItems(from notes: [Note]) -> [FlattenedMediaItem] {
		var result: [FlattenedMediaItem] = []
		for note in notes {
			guard case let .media(images, videos)? = note.bundle else { continue }
			struct LocalEntry { let isImage: Bool; let index: Int; let order: Int }
			var merged: [LocalEntry] = []
			for (imageIndex, img) in images.enumerated() {
				let order = img.orderIndex ?? imageIndex
				merged.append(LocalEntry(isImage: true, index: imageIndex, order: order))
			}
			for (videoIndex, vid) in videos.enumerated() {
				let order = vid.orderIndex ?? (images.count + videoIndex)
				merged.append(LocalEntry(isImage: false, index: videoIndex, order: order))
			}
			merged.sort { $0.order < $1.order }
			for entry in merged {
				if entry.isImage {
					result.append(.init(id: "\(note.id.uuidString)-i-\(entry.index)", isVideo: false, imageData: images[entry.index].data, videoURL: nil, uploadedAt: note.uploadedAt, localOrder: entry.order))
				} else {
					result.append(.init(id: "\(note.id.uuidString)-v-\(entry.index)", isVideo: true, imageData: nil, videoURL: videos[entry.index].url, uploadedAt: note.uploadedAt, localOrder: entry.order))
				}
			}
		}
		return result.sorted {
			if $0.uploadedAt != $1.uploadedAt { return $0.uploadedAt > $1.uploadedAt }
			if $0.id.prefix(36) == $1.id.prefix(36) { return $0.localOrder > $1.localOrder }
			return $0.id > $1.id
		}
	}
	
	func computeFileItems(from notes: [Note]) -> [FlattenedFileItem] {
		var result: [FlattenedFileItem] = []
		for note in notes {
			if case let .files(fileSet)? = note.bundle {
				for (index, fileAttachment) in fileSet.enumerated() {
					result.append(.init(id: "\(note.id.uuidString)-f-\(index)", url: fileAttachment.url, contentType: fileAttachment.contentType, uploadedAt: note.uploadedAt, localIndex: index))
				}
			}
		}
		return result.sorted {
			if $0.uploadedAt != $1.uploadedAt { return $0.uploadedAt > $1.uploadedAt }
			if $0.id.prefix(36) == $1.id.prefix(36) { return $0.localIndex < $1.localIndex }
			return $0.id > $1.id
		}
	}
	
	func computeAudioItems(from notes: [Note]) -> [FlattenedAudioItem] {
		var result: [FlattenedAudioItem] = []
		for note in notes {
			if case let .audio(audioSet)? = note.bundle {
				for (index, audioAttachment) in audioSet.enumerated() {
					result.append(.init(id: "\(note.id.uuidString)-a-\(index)", url: audioAttachment.url, duration: audioAttachment.duration, uploadedAt: note.uploadedAt, localIndex: index))
				}
			}
		}
		return result.sorted {
			if $0.uploadedAt != $1.uploadedAt { return $0.uploadedAt > $1.uploadedAt }
			if $0.id.prefix(36) == $1.id.prefix(36) { return $0.localIndex < $1.localIndex }
			return $0.id > $1.id
		}
	}
	
	func computeLinkItems(from notes: [Note]) -> [FlattenedLinkItem] {
		var all: [FlattenedLinkItem] = []
		for note in notes {
			guard let text = note.text else { continue }
			let found = urls(in: text, limit: Int.max)
			for foundURL in found {
				all.append(.init(id: "\(note.id.uuidString)-l-\(foundURL.absoluteString)", url: foundURL, uploadedAt: note.uploadedAt))
			}
		}
		let sorted = all.sorted { $0.uploadedAt == $1.uploadedAt ? $0.id > $1.id : $0.uploadedAt > $1.uploadedAt }
		var seen = Set<String>()
		var dedup: [FlattenedLinkItem] = []
		for item in sorted where seen.insert(item.url.absoluteString).inserted {
			dedup.append(item)
		}
		return dedup
	}
	
	func urls(in text: String, limit: Int = 3) -> [URL] {
		let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
		let textAsNSString = text as NSString
		let fullRange = NSRange(location: 0, length: textAsNSString.length)
		let matches = detector?.matches(in: text, options: [], range: fullRange) ?? []
		var seen = Set<String>()
		var extractedURLs: [URL] = []
		for match in matches {
			guard let url = match.url else { continue }
			if seen.insert(url.absoluteString).inserted {
				extractedURLs.append(url)
				if extractedURLs.count >= limit { break }
			}
		}
		return extractedURLs
	}
	
	func allClientNotes() -> [(Client, Note)] {
		var pairs: [(Client, Note)] = []
        for client in clientsStore.clients {
            var notesForClient = ChatStore.shared.notes(for: client.id)
            if notesForClient.isEmpty {
                notesForClient = client.notes
            }
            for noteItem in notesForClient {
                pairs.append((client, noteItem))
            }
        }
		return pairs
	}
	
	func parseFlattenedMediaId(_ id: String) -> (noteId: UUID, isImage: Bool, localIndex: Int)? {
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
    
    func ownerForFlattenedMedia(_ item: FlattenedMediaItem) -> (client: Client, noteId: UUID)? {
        guard let parsed = parseFlattenedMediaId(item.id) else { return nil }
        for client in clientsStore.clients {
            var notesForClient = ChatStore.shared.notes(for: client.id)
            if notesForClient.isEmpty { notesForClient = client.notes }
            if notesForClient.contains(where: { $0.id == parsed.noteId }) {
                return (client, parsed.noteId)
            }
        }
        return nil
    }
    
    func mediaPayloadForClient(_ client: Client) -> (items: [MediaSource], anchors: [(noteId: UUID, isImage: Bool, localIndex: Int)]) {
        var notesForClient = ChatStore.shared.notes(for: client.id)
        if notesForClient.isEmpty { notesForClient = client.notes }
        let flattened = computeMediaItems(from: notesForClient)
        let items: [MediaSource] = flattened.map { flattenedItem in
            if flattenedItem.isVideo, let url = flattenedItem.videoURL {
                return .video(url)
            } else {
                return .image(flattenedItem.imageData ?? Data())
            }
        }
        let anchors: [(UUID, Bool, Int)] = flattened.compactMap { flattenedItem in
            guard let parsed = parseFlattenedMediaId(flattenedItem.id) else { return nil }
            return (parsed.noteId, parsed.isImage, parsed.localIndex)
        }
        return (items, anchors)
    }
	
	func sectionHeader(title: String, iconName: String, iconColor: Color, onTapArrow: @escaping () -> Void, showsArrow: Bool = true) -> some View {
		Button(action: onTapArrow) {
			HStack(alignment: .center, spacing: 8) {
				Image(systemName: iconName)
					.font(.system(size: 16, weight: .medium))
					.foregroundStyle(iconColor)
				Text(title)
					.font(.body2)
					.foregroundStyle(Color("BlackLabel"))
				Spacer()
				if showsArrow {
					Image(systemName: "chevron.right")
						.font(.system(size: 16, weight: .semibold))
						.foregroundStyle(Color("Primary"))
						.frame(width: 32, height: 32)
				}
			}
			.padding(.vertical, 10)
		}
		.buttonStyle(.plain)
		.contentShape(Rectangle())
	}
	
	func highlightedText(_ text: String, highlight: String) -> Text {
		let nsText = text as NSString
		let mas = NSMutableAttributedString(string: text)
		let full = NSRange(location: 0, length: nsText.length)
		let options: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
		var searchRange = full
		while true {
			let found = nsText.range(of: highlight, options: options, range: searchRange)
			if found.location == NSNotFound { break }
			mas.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.45), range: found)
			let nextLoc = found.location + found.length
			if nextLoc >= nsText.length { break }
			searchRange = NSRange(location: nextLoc, length: nsText.length - nextLoc)
		}
		return Text(AttributedString(mas))
	}
}

#Preview {
	SearchView()
		.environmentObject(NavigationRouter())
}

// MARK: - Section Previews
private enum SearchSectionPreviewData {
	static let sampleDate = Date()
	static let media: [FlattenedMediaItem] = [
		.init(id: UUID().uuidString + "-i-0", isVideo: false, imageData: Data(repeating: 0xFF, count: 16), videoURL: nil, uploadedAt: sampleDate, localOrder: 0),
		.init(id: UUID().uuidString + "-v-0", isVideo: true, imageData: nil, videoURL: URL(fileURLWithPath: "/tmp/sample.mov"), uploadedAt: sampleDate, localOrder: 1),
		.init(id: UUID().uuidString + "-i-1", isVideo: false, imageData: Data(repeating: 0xAA, count: 16), videoURL: nil, uploadedAt: sampleDate, localOrder: 2),
		.init(id: UUID().uuidString + "-i-2", isVideo: false, imageData: Data(repeating: 0xCC, count: 16), videoURL: nil, uploadedAt: sampleDate, localOrder: 3)
	]
	static let files: [FlattenedFileItem] = [
		.init(id: UUID().uuidString, url: URL(fileURLWithPath: "/tmp/report.pdf"), contentType: UTType.pdf, uploadedAt: sampleDate, localIndex: 0),
		.init(id: UUID().uuidString, url: URL(fileURLWithPath: "/tmp/spec.txt"), contentType: UTType.plainText, uploadedAt: sampleDate, localIndex: 1),
		.init(id: UUID().uuidString, url: URL(fileURLWithPath: "/tmp/data.csv"), contentType: UTType.commaSeparatedText, uploadedAt: sampleDate, localIndex: 2)
	]
	static let links: [FlattenedLinkItem] = [
		.init(id: UUID().uuidString, url: URL(string: "https://example.com")!, uploadedAt: sampleDate),
		.init(id: UUID().uuidString, url: URL(string: "https://apple.com")!, uploadedAt: sampleDate),
		.init(id: UUID().uuidString, url: URL(string: "https://github.com")!, uploadedAt: sampleDate)
	]
	static let audios: [FlattenedAudioItem] = [
		.init(id: UUID().uuidString, url: URL(fileURLWithPath: "/tmp/memo1.m4a"), duration: 63, uploadedAt: sampleDate, localIndex: 0),
		.init(id: UUID().uuidString, url: URL(fileURLWithPath: "/tmp/memo2.m4a"), duration: 148, uploadedAt: sampleDate, localIndex: 1),
		.init(id: UUID().uuidString, url: URL(fileURLWithPath: "/tmp/memo3.m4a"), duration: 19, uploadedAt: sampleDate, localIndex: 2)
	]
}

#Preview("Section - Recent Searches") {
	SearchView(previewRecentQueries: ["보고서", "홍길동", "계약서", "회의록"])
		.recentSearchesSection
		.background(Color("Background"))
}

#Preview("Section - Global Media") {
	SearchView(previewAllMedia: SearchSectionPreviewData.media)
		.globalMediaSection
		.background(Color("Background"))
}

#Preview("Section - Global Files") {
	SearchView(previewAllFiles: SearchSectionPreviewData.files)
		.globalFilesSection
		.background(Color("Background"))
}

#Preview("Section - Global Links") {
	SearchView(previewAllLinks: SearchSectionPreviewData.links)
		.globalLinksSection
		.background(Color("Background"))
}

#Preview("Section - Global Audio") {
	SearchView(previewAllAudios: SearchSectionPreviewData.audios)
		.globalAudioSection
		.background(Color("Background"))
}

private struct MatchedClientsSectionPreview: View {
	init() {
		// Seed sample clients for preview
		let c1 = Client(surname: "길동", name: "홍", company: "가나다 상사")
		let c2 = Client(surname: "수민", name: "김", company: "마바사 주식회사")
		let c3 = Client(surname: "Dane", name: "Chris", company: "Zeta Corp")
		ClientsStore.shared.clients = [c1, c2, c3]
	}
	var body: some View {
		SearchView(previewQuery: "홍")
			.matchedClientsSection
			.background(Color("Background"))
	}
}

#Preview("Section - Matched Clients") {
    MatchedClientsSectionPreview()
}

private struct MatchedNotesSectionPreview: View {
    private let clientAlpha: Client
    private let clientBeta: Client
	init() {
        let clientA = Client(surname: "길동", name: "홍", company: "가나다 상사")
        let clientB = Client(surname: "수민", name: "김", company: "마바사 주식회사")
        clientAlpha = clientA
        clientBeta = clientB
        ClientsStore.shared.clients = [clientA, clientB]
		// Seed notes
        let note1 = Note(uploadedAt: Date(), text: "회의 메모: 액션 아이템 정리", bundle: nil)
        let note2 = Note(uploadedAt: Date().addingTimeInterval(-3600), text: "점심 식사", bundle: nil)
        let note3 = Note(uploadedAt: Date().addingTimeInterval(-7200), text: "주간 회의 안건 초안", bundle: nil)
        ChatStore.shared.setNotes([note1, note2], for: clientA.id)
        ChatStore.shared.setNotes([note3], for: clientB.id)
	}
	var body: some View {
		SearchView(previewQuery: "회의")
			.matchedNotesSection
			.background(Color("Background"))
	}
}

#Preview("Section - Matched Notes") {
    MatchedNotesSectionPreview()
}

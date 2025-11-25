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
	private let onCloseAction: (() -> Void)?
	
	// VM
	@StateObject private var viewModel: SearchViewModel
	// Search focus
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
		_viewModel = .init(wrappedValue: SearchViewModel(
			initialQuery: previewQuery ?? "",
			previewRecentQueries: previewRecentQueries,
			previewAllMedia: previewAllMedia,
			previewAllFiles: previewAllFiles,
			previewAllLinks: previewAllLinks,
			previewAllAudios: previewAllAudios
		))
	}
	
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				// 검색 전 상태
				if viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
		.simultaneousGesture(TapGesture().onEnded {
			// 외부 탭 시 포커스 및 검색모드 해제
			if isSearchFocused {
				isSearchFocused = false
				if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
					viewModel.send(.updateQuery(""))
				}
			}
		})
		.toolbar(.hidden, for: .tabBar)
		.safeAreaInset(edge: .bottom) {
			let isSearching = !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
			APEXSearchBar(
				text: Binding(
					get: { viewModel.query },
					set: { viewModel.send(.updateQuery($0)) }
				),
				isFocused: _isSearchFocused,
				onPrev: {},
				onNext: {},
				onClose: {
					isSearchFocused = false
					if !viewModel.query.isEmpty {
						viewModel.send(.saveRecent(viewModel.query))
					}
					viewModel.send(.updateQuery(""))
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
			viewModel.send(.onAppear)
			// Focus search field when the view appears
			DispatchQueue.main.async {
				isSearchFocused = true
			}
		}
		.fullScreenCover(item: $viewModel.archivePayload) { payload in
			ArchiveListView(
				section: payload.section,
				media: payload.media,
				files: payload.files,
				links: payload.links,
				audios: payload.audios,
				viewerTitle: payload.title,
				excludedClientIds: payload.excludedClientIds,
				onClose: { viewModel.archivePayload = nil }
			)
		}
        .fullScreenCover(item: $viewModel.recordPayload) { payload in
            RecordView(audioURL: payload.url)
        }
	}
}

// MARK: - Sections (Idle)
private extension SearchView {
	var recentSearchesSection: some View {
		Group {
			if !viewModel.recentQueries.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					sectionHeader(title: "최근 검색", iconName: "Recent", onTapArrow: {
						// No destination; keep behavior as non-clickable header
					}, showsArrow: false)
					.overlay(alignment: .trailing) {
						Button {
							viewModel.send(.clearRecent)
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
							ForEach(viewModel.recentQueries, id: \.self) { item in
								Button {
									viewModel.send(.updateQuery(item))
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
			sectionHeader(title: "사진/동영상", iconName: "Photo", onTapArrow: {
				viewModel.send(.openArchiveAll(.media))
			})
			if !viewModel.allMedia.isEmpty {
				let shouldShowSeeAll = viewModel.allMedia.count >= 9
				let previewItems = shouldShowSeeAll ? Array(viewModel.allMedia.prefix(8)) : viewModel.allMedia
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 2) {
						ForEach(Array(previewItems.enumerated()), id: \.element.id) { _, item in
							let owner = viewModel.ownerForFlattenedMedia(item)
							let payload = owner.flatMap { viewModel.mediaPayloadForClient($0.client) }
							let parsed = viewModel.parseFlattenedMediaId(item.id)
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
								title: owner.map { $0.client.autoFormattedName } ?? "Shared Media",
								uploadedAt: item.uploadedAt,
								excludedClientIds: owner.map { [$0.client.id] } ?? [],
								onTitleTap: { current in
									guard let owner, let payload, payload.anchors.indices.contains(current) else { return }
									let anchor = payload.anchors[current]
									// Delay slightly to ensure media viewer is dismissed before navigation.
									DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
										// Pop to existing chat if present; else push
										if let idx = router.path.lastIndex(where: {
											if case let .chat(id) = $0 { return id == owner.client.id }
											return false
										}) {
											let newPath = Array(router.path.prefix(idx + 1))
											router.setPath(newPath)
										} else {
											router.push(.chat(owner.client.id))
										}
										// Post after chat mounted; then retry once
										DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
											NotificationCenter.default.post(name: .apexNavigateToNote, object: nil, userInfo: ["noteId": anchor.noteId])
										}
										DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
											NotificationCenter.default.post(name: .apexNavigateToNote, object: nil, userInfo: ["noteId": anchor.noteId])
										}
									}
								}
							)
						}
						if shouldShowSeeAll {
							ChattingArchiveView.SeeAllTile(size: 121.67, title: "전체보기")
								.onTapGesture {
									viewModel.send(.openArchiveAll(.media))
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
			sectionHeader(title: "파일", iconName: "File", onTapArrow: {
				viewModel.send(.openArchiveAll(.files))
			})
			if !viewModel.allFiles.isEmpty {
				let shouldShowSeeAll = viewModel.allFiles.count >= 9
				let previewItems = shouldShowSeeAll ? Array(viewModel.allFiles.prefix(8)) : viewModel.allFiles
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
									viewModel.send(.openArchiveAll(.files))
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
			sectionHeader(title: "링크", iconName: "URL", onTapArrow: {
				viewModel.send(.openArchiveAll(.links))
			})
			if !viewModel.allLinks.isEmpty {
				let shouldShowSeeAll = viewModel.allLinks.count >= 9
				let previewItems = shouldShowSeeAll ? Array(viewModel.allLinks.prefix(8)) : viewModel.allLinks
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 2) {
						ForEach(previewItems, id: \.id) { item in
							APEXLinkTile(url: item.url, width: 121.67)
						}
						if shouldShowSeeAll {
							ChattingArchiveView.SeeAllTile(size: 121.67, title: "전체보기")
								.onTapGesture {
									viewModel.send(.openArchiveAll(.links))
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
			sectionHeader(title: "음성메모", iconName: "Waveform", onTapArrow: {
				viewModel.send(.openArchiveAll(.audio))
			})
			if !viewModel.allAudios.isEmpty {
				let shouldShowSeeAll = viewModel.allAudios.count >= 9
				let previewItems = shouldShowSeeAll ? Array(viewModel.allAudios.prefix(8)) : viewModel.allAudios
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
                            .onTapGesture { viewModel.send(.openRecord(item.url)) }
						}
						if shouldShowSeeAll {
							ChattingArchiveView.SeeAllTile(size: 121.67, title: "전체보기")
								.onTapGesture {
									viewModel.send(.openArchiveAll(.audio))
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
		let trimmed = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
		let filtered = viewModel.filteredClients(trimmed)
		return Group {
			if !filtered.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					sectionHeader(title: "연락처", iconName: "Profile", onTapArrow: {
						// no-op
					}, showsArrow: false)
					VStack(spacing: 0) {
						ForEach(filtered) { client in
							Button {
								viewModel.send(.saveRecent(trimmed))
								let myId = ClientsStore.shared.clients.first?.id
								let isMe = (client.id == myId)
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
										backgroundColor: Color("PrimaryContainer"),
										textColor: .white,
										fontWeight: .semibold
									)
									VStack(alignment: .leading, spacing: 0) {
										highlightedText(client.autoFormattedName, highlight: trimmed)
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
		let trimmed = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
		let pairs: [(Client, Note)] = viewModel.matchedClientNotes(trimmed)
		return Group {
			if !pairs.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					sectionHeader(title: "텍스트", iconName: "Note", onTapArrow: {
						// no-op
					}, showsArrow: false)
					VStack(spacing: 8) {
						ForEach(pairs, id: \.1.id) { client, note in
							Button {
								viewModel.send(.saveRecent(trimmed))
								router.push(.chat(client.id))
								DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
									NotificationCenter.default.post(name: .apexNavigateToNote, object: nil, userInfo: ["noteId": note.id])
								}
							} label: {
								HStack(alignment: .top, spacing: 8) {
									Profile(
										image: client.profile,
										initials: Profile.makeInitials(name: client.name, surname: client.surname),
										size: .extraSmall,
										backgroundColor: Color("PrimaryContainer"),
										textColor: .white,
										fontWeight: .semibold
									)
									VStack(alignment: .leading, spacing: 6) {
                                        highlightedText(client.autoFormattedName, highlight: trimmed)
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
		let trimmed = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
		let matched = viewModel.matchedClientNotes(trimmed)
		let noteIdsWithMatch: Set<UUID> = Set(matched.map { $0.1.id })
		let items = viewModel.allMedia.filter { item in
			guard let parsed = viewModel.parseFlattenedMediaId(item.id) else { return false }
			return noteIdsWithMatch.contains(parsed.noteId)
		}
		return filteredMediaSectionCore(items: items, title: "사진/동영상")
	}
	
	private func filteredMediaSectionCore(items: [FlattenedMediaItem], title: String) -> some View {
		Group {
			if !items.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					sectionHeader(title: title, iconName: "photo", onTapArrow: {
						viewModel.send(.openArchiveFiltered(.media))
					})
					let shouldShowSeeAll = items.count >= 9
					let previewItems = shouldShowSeeAll ? Array(items.prefix(8)) : items
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 2) {
							ForEach(Array(previewItems.enumerated()), id: \.element.id) { _, item in
								let owner = viewModel.ownerForFlattenedMedia(item)
								let payload = owner.flatMap { viewModel.mediaPayloadForClient($0.client) }
								let parsed = viewModel.parseFlattenedMediaId(item.id)
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
									title: owner.map { $0.client.autoFormattedName } ?? "Shared Media",
									uploadedAt: item.uploadedAt,
									excludedClientIds: owner.map { [$0.client.id] } ?? [],
									onTitleTap: { current in
										guard let owner, let payload, payload.anchors.indices.contains(current) else { return }
										let anchor = payload.anchors[current]
										DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
											if let idx = router.path.lastIndex(where: {
												if case let .chat(id) = $0 { return id == owner.client.id }
												return false
											}) {
												let newPath = Array(router.path.prefix(idx + 1))
												router.setPath(newPath)
											} else {
												router.push(.chat(owner.client.id))
											}
											DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
												NotificationCenter.default.post(name: .apexNavigateToNote, object: nil, userInfo: ["noteId": anchor.noteId])
											}
											DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
												NotificationCenter.default.post(name: .apexNavigateToNote, object: nil, userInfo: ["noteId": anchor.noteId])
											}
										}
									}
								)
							}
							if shouldShowSeeAll {
								ChattingArchiveView.SeeAllTile(size: 121.67, title: "전체보기")
									.onTapGesture {
										viewModel.send(.openArchiveFiltered(.media))
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
		let trimmed = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
		let items = viewModel.allFiles.filter { file in
			file.url.lastPathComponent.localizedCaseInsensitiveContains(trimmed)
		}
		return Group {
			if !items.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					sectionHeader(title: "파일", iconName: "document", onTapArrow: {
						viewModel.send(.openArchiveFiltered(.files))
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
										viewModel.send(.openArchiveFiltered(.files))
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
		let trimmed = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
		let items = viewModel.allLinks.filter { link in
			link.url.absoluteString.localizedCaseInsensitiveContains(trimmed)
		}
		return Group {
			if !items.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					sectionHeader(title: "링크", iconName: "URL", onTapArrow: {
						viewModel.send(.openArchiveFiltered(.links))
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
										viewModel.send(.openArchiveFiltered(.links))
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
		let trimmed = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
		let items = viewModel.allAudios.filter { audio in
			let base = audio.url.deletingPathExtension().lastPathComponent
			return base.localizedCaseInsensitiveContains(trimmed)
		}
		return Group {
			if !items.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					sectionHeader(title: "음성메모", iconName: "Waveform", onTapArrow: {
						viewModel.send(.openArchiveFiltered(.audio))
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
                                .onTapGesture { viewModel.send(.openRecord(item.url)) }
							}
							if shouldShowSeeAll {
								ChattingArchiveView.SeeAllTile(size: 121.67, title: "전체보기")
									.onTapGesture {
										viewModel.send(.openArchiveFiltered(.audio))
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
	func sectionHeader(title: String, iconName: String, onTapArrow: @escaping () -> Void, showsArrow: Bool = true) -> some View {
		Button(action: onTapArrow) {
			HStack(alignment: .center, spacing: 8) {
				Image(iconName)
				Text(title)
					.font(.body2)
					.foregroundStyle(Color("BlackLabel"))
				Spacer()
				if showsArrow {
					Image(systemName: "arrow.forward")
						.font(.system(size: 16, weight: .regular))
						.foregroundStyle(Color("Primary"))
						.frame(width: 19, height: 14)
				}
			}
			.padding(.vertical, 10)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
        .padding(.trailing, 16)
		.buttonStyle(SectionHeaderPressedStyle())
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

#warning("Temporary duplication; consider moving to a shared file if reused further")
private struct SectionHeaderPressedStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.background(configuration.isPressed ? Color("BackgroundSecondary") : Color.clear)
			.contentShape(Rectangle())
			.animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
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

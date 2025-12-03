//
//  ChatMessageListSection.swift
//  APEX
//
//  Extracted message list section from ChattingView.
//

import SwiftUI

struct ChatMessageListSection: View {
    let notes: [Note]
    let chatTitle: String
    let clientId: UUID

    // Selection
    let isDeleteSelecting: Bool
    let isSelected: (UUID) -> Bool
    let onToggleSelection: (UUID) -> Void

    // Highlight
    let highlightQueryFor: (UUID) -> String?
    let isSTTLoading: (UUID) -> Bool

    // Media/viewer actions
    let buildViewerPayload: (ChatMessageView.ChatAnchor) -> MediaGalleryPayload
    let onOpenViewer: (ChatMessageView.ChatAnchor) -> Void
    let onOpenShareText: (String?) -> Void
    let onOpenShareFiles: ([URL]) -> Void
    let onOpenShareAudio: (URL) -> Void
    let onDeleteFile: (UUID, Int) -> Void
    let onOpenRecord: (URL) -> Void
    let onDeleteMedia: (ChatMessageView.ChatAnchor) -> Void
    let onDeleteAudio: (UUID, URL) -> Void
    let onCopyText: (String) -> Void
    let onStartEdit: (UUID, String) -> Void
    let onStartMultiDelete: (UUID) -> Void

    // Layout
    let timestampRevealProgress: CGFloat
    let timeTextWidth: (Date) -> CGFloat
    let timeWidth: CGFloat
    let timeGap: CGFloat
    let leftSelectWidth: CGFloat
    let bottomSentinelId: String

    // Header builder
    let dateHeader: (Date) -> AnyView

    var body: some View {
        LazyVStack(alignment: .trailing, spacing: 6) {
            ForEach(Array(notes.enumerated()), id: \.element.id) { idx, note in
                if idx == 0 || !Calendar.current.isDate(note.uploadedAt, inSameDayAs: notes[idx - 1].uploadedAt) {
                    dateHeader(note.uploadedAt)
                }
                HStack(alignment: .center, spacing: 12) {
                    Group {
                        if isDeleteSelecting {
                            let checked = isSelected(note.id)
                            Button {
                                onToggleSelection(note.id)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(checked ? Color("Primary") : Color.white)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .stroke(checked ? Color("Primary") : Color("BackgroundDisabled"), lineWidth: 1)
                                        )
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .opacity(checked ? 1 : 0)
                                }
                                .frame(width: 24, height: 24, alignment: .center)
                                .contentTransition(.identity)
                                .animation(.easeInOut(duration: 0.2), value: checked)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear
                                .frame(width: 24, height: 24)
                        }
                    }
                    .padding(.horizontal, 6.5)
                    .animation(nil, value: isDeleteSelecting)

                    HStack {
                        Spacer(minLength: 0)

                        ZStack(alignment: .trailing) {
                            Text(note.uploadedAt.formattedChatTime)
                                .font(.caption2)
                                .foregroundStyle(Color.secondary)
                                .frame(width: timeWidth, alignment: .trailing)
                                .lineLimit(1)
                                .opacity(Double(timestampRevealProgress))
                                .offset(x: (1 - timestampRevealProgress) * 8)

                            ChatMessageView(
                                note: note,
                                chatTitle: chatTitle,
                                currentClientId: clientId,
                                highlightQuery: highlightQueryFor(note.id),
                                leadingReservedWidth: leftSelectWidth,
                                isSTTLoading: isSTTLoading(note.id),
                                buildViewerPayload: { anchor in
                                    buildViewerPayload(anchor)
                                },
                                onOpenViewer: { anchor in
                                    onOpenViewer(anchor)
                                },
                                onOpenShare: { selectedText in
                                    onOpenShareText(selectedText)
                                },
                                onOpenShareFiles: { urls in
                                    onOpenShareFiles(urls)
                                },
                                onOpenShareAudio: { url in
                                    onOpenShareAudio(url)
                                },
                                onDeleteFile: { noteId, fileIndex in
                                    onDeleteFile(noteId, fileIndex)
                                },
                                onOpenRecord: { url in
                                    onOpenRecord(url)
                                },
                                onDelete: { anchor in
                                    onDeleteMedia(anchor)
                                },
                                onDeleteAudio: { noteId, url in
                                    onDeleteAudio(noteId, url)
                                },
                                onCopyText: { text in
                                    onCopyText(text)
                                },
                                onStartEdit: { noteId, currentText in
                                    onStartEdit(noteId, currentText)
                                },
                                onStartMultiDelete: { noteId in
                                    onStartMultiDelete(noteId)
                                }
                            )
                            .offset(x: -timestampRevealProgress * (timeTextWidth(note.uploadedAt) + timeGap))
                            .allowsHitTesting(!isDeleteSelecting)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isDeleteSelecting {
                                onToggleSelection(note.id)
                            }
                        }
                    }
                }
                .id(note.id)
            }
            Color.clear
                .id(bottomSentinelId)
        }
    }
}


//
//  NotesListView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

struct NotesListView: View {
    let clients: [Client]
    @Binding var selectedFilter: NotesFilter
    var onTogglePin: (Client) -> Void
    var onDelete: (Client) -> Void

    var body: some View {
        Group {
            let filtered = NotesListModel.sort(
                NotesListModel.filter(clients, by: selectedFilter)
            )

            if filtered.isEmpty {
                EmptyNotesState()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 40)
            } else {
                List {
                    ForEach(filtered) { client in
                        Button {
                            // TODO: 상세 화면 이동
                            print("Tapped client: \(client.name)")
                        } label: {
                            NotesRow(client: client)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                onDelete(client)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .tint(Color("Error"))
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                onTogglePin(client)
                            } label: {
                                Image(systemName: client.pin ? "pin.slash" : "pin")
                            }
                            .tint(Color("Primary"))
                        }
                    }
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 64)
            }
        }
    }
}

// MARK: - Row

private struct NotesRow: View {
    let client: Client

    private var fullName: String { "\(client.name) \(client.surname)" }
    private var summary: String { NotesTextFormatter.latestSummary(from: client.notes) ?? "기록 없음" }
    private var timeText: String { NotesTextFormatter.timeText(for: client.notes) ?? "" }

    var body: some View {
        HStack(spacing: 12) {
            // 핀 자리(있으면 파란 핀, 없으면 투명 공간)
            Group {
                if client.pin {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("Primary"))
                        .frame(width: 20)
                } else {
                    Color.clear.frame(width: 20)
                }
            }

            avatar

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(fullName)
                        .font(.body2)
                        .foregroundColor(Color("Dark"))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if !timeText.isEmpty {
                        Text(timeText)
                            .font(.caption)
                            .foregroundColor(Color("Gray"))
                            .lineLimit(1)
                    }
                }

                Text(summary)
                    .font(.body6)
                    .foregroundColor(Color("Gray"))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(height: 64)
        .contentShape(Rectangle())
        .padding(.vertical, 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(fullName), \(summary)\(timeText.isEmpty ? "" : ", \(timeText)")")
    }

    private var avatar: some View {
        Group {
            if let uiImage = client.profile {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image("ProfileS")
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
    }
}

// MARK: - Empty State

private struct EmptyNotesState: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("표시할 노트가 없습니다")
                .font(.body2)
                .foregroundColor(Color("Gray"))
            Text("다른 그룹을 선택하거나 새 노트를 추가해 보세요.")
                .font(.body6)
                .foregroundColor(Color("Gray"))
                .foregroundColor(Color("Gray"))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }
}

// MARK: - Formatting & Helpers

enum NotesTextFormatter {
    // DateFormatter 캐시
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        return f
    }()
    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    static func timeText(for notes: [Note]) -> String? {
        guard let latest = notes.max(by: { $0.uploadedAt < $1.uploadedAt }) else { return nil }
        let cal = Calendar.current
        let now = Date()
        if cal.isDate(latest.uploadedAt, inSameDayAs: now) {
            return timeFormatter.string(from: latest.uploadedAt).lowercased()
        } else if let y = cal.date(byAdding: .day, value: -1, to: now),
                  cal.isDate(latest.uploadedAt, inSameDayAs: y) {
            return "어제"
        } else {
            return monthDayFormatter.string(from: latest.uploadedAt)
        }
    }

    static func latestSummary(from notes: [Note]) -> String? {
        guard let latest = notes.max(by: { $0.uploadedAt < $1.uploadedAt }) else { return nil }

        if let text = latest.text?
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return text
        }

        switch latest.bundle {
        case .media(let images, let videos):
            let hasImages = !images.isEmpty
            let hasVideos = !videos.isEmpty
            if hasImages && hasVideos { return "사진/영상" }
            if hasImages { return "사진" }
            if hasVideos { return "영상 [\(videoIdPlaceholder())]" }
            return "미디어"
        case .files(let files):
            if files.count == 1, let first = files.first { return first.url.lastPathComponent }
            return "\(files.count)개 파일"
        case .audio(let audios):
            return audios.count <= 1 ? "음성 메모" : "\(audios.count)개 음성 메모"
        case .none:
            return nil
        }
    }

    private static func videoIdPlaceholder() -> String {
        "94128942198382"
    }
}

// MARK: - Filtering/Sorting Model

enum NotesListModel {
    static func filter(_ clients: [Client], by filter: NotesFilter) -> [Client] {
        switch filter {
        case .all:
            return clients
        case .company(let companyName):
            let key = companyName.trimmingCharacters(in: .whitespacesAndNewlines)
            return clients.filter { $0.company.trimmingCharacters(in: .whitespacesAndNewlines) == key }
        }
    }

    static func sort(_ clients: [Client]) -> [Client] {
        clients.sorted { a, b in
            if a.pin != b.pin { return a.pin } // 핀 우선
            let d1 = a.notes.max { $0.uploadedAt < $1.uploadedAt }?.uploadedAt ?? .distantPast
            let d2 = b.notes.max { $0.uploadedAt < $1.uploadedAt }?.uploadedAt ?? .distantPast
            return d1 > d2
        }
    }
}

#Preview {
    struct Container: View {
        @State private var selected: NotesFilter = .all
        @State private var data: [Client] = sampleClients.filter { !$0.notes.isEmpty }

        var body: some View {
            NotesListView(
                clients: data,
                selectedFilter: $selected,
                onTogglePin: { _ in },
                onDelete: { _ in }
            )
            .background(Color("Background"))
        }
    }
    return Container()
}

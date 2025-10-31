//
//  NotesListView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/29/25.
//

import SwiftUI

struct NotesListView: View {
    @Binding var clients: [Client]  // let에서 @Binding으로 변경
    @Binding var selectedFilter: NotesFilter
    var onTogglePin: (Client) -> Void
    var onDelete: (Client) -> Void
    var onTapRow: (Client) -> Void

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
                        NotesRow(
                            client: client,
                            onTogglePin: { onTogglePin(client) },
                            onDelete: { onDelete(client) },
                            onTap: { onTapRow(client) }
                        )
                        .applyListRowCleaning()
                    }
                }
                .listStyle(.plain)
                .listRowSpacing(0)
                .environment(\.defaultMinListRowHeight, 1)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color("Background"))
    }
}

// MARK: - Row

private struct NotesRow: View {
    let client: Client
    var onTogglePin: (() -> Void)?
    var onDelete: (() -> Void)?
    var onTap: (() -> Void)?

    private var fullName: String { "\(client.name) \(client.surname)" }
    
    private var summary: String {
        let live = ChatStore.shared.notes(for: client.id)
        let source = live.isEmpty ? client.notes : live
        return NotesTextFormatter.latestSummary(from: source) ?? ""
    }
    
    private var timeText: String {
        let live = ChatStore.shared.notes(for: client.id)
        let source = live.isEmpty ? client.notes : live
        return NotesTextFormatter.timeText(for: source) ?? ""
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                avatar

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(fullName)
                            .font(.body2)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        // 핀 아이콘 (이름 끝에 표시)
                        if client.pin {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color("Primary"))
                        }
                        
                        Spacer()
                        
                        // 시간 텍스트 
                        Text(timeText)
                            .font(.body5)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }

                    Text(summary)
                        .font(.body6)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .frame(height: 38)
                .frame(maxWidth: .infinity, alignment: .leading)

            }
            .padding(.horizontal, 16)
            .frame(height: 64)
        }
        .buttonStyle(BackgroundHoverRowStyle())
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if let onTogglePin {
                Button {
                    onTogglePin()
                } label: {
                    Image(systemName: client.pin ? "pin.slash" : "pin")
                }
                .tint(Color("Primary"))
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .tint(Color("Error"))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(fullName), \(summary), \(timeText)")
        .accessibilityAddTraits(.isButton)
    }

    private var avatar: some View {
        Group {
            if let uiImage = client.profile {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
            } else {
                let initials = makeInitials(name: client.name, surname: client.surname)
                ZStack {
                    Circle()
                        .fill(Color("PrimaryContainer"))
                    Text(initials)
                        .font(.system(size: 30.72, weight: .semibold))
                        .foregroundColor(.white)
                }
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
            // 우선 영상 파일명이 있으면 표시, 여러 개면 "첫 파일명 외 n개"
            if let firstVideo = videos.first {
                let name = firstVideo.url.lastPathComponent
                let extra = videos.count + images.count - 1
                return extra > 0 ? "\(name) 외 \(extra)개" : name
            }
            // 이미지에는 파일명이 없어 대표 라벨 사용
            if !images.isEmpty {
                let extra = images.count - 1
                return extra > 0 ? "사진 외 \(extra)개" : "사진"
            }
            return "미디어"
        case .files(let files):
            guard let first = files.first else { return nil }
            let name = first.url.lastPathComponent
            let extra = files.count - 1
            return extra > 0 ? "\(name) 외 \(extra)개" : name
        case .audio(let audios):
            guard let first = audios.first else { return nil }
            let name = first.url.lastPathComponent
            let extra = audios.count - 1
            return extra > 0 ? "\(name) 외 \(extra)개" : name
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
        func latestDate(for client: Client) -> Date {
            let live = ChatStore.shared.notes(for: client.id)
            let source = live.isEmpty ? client.notes : live
            return source.max(by: { $0.uploadedAt < $1.uploadedAt })?.uploadedAt ?? .distantPast
        }
        return clients.sorted { a, b in
            if a.pin != b.pin { return a.pin }
            return latestDate(for: a) > latestDate(for: b)
        }
    }
}

#Preview {
    @Previewable @State var clients = sampleClients
    @Previewable @State var selectedFilter: NotesFilter = .all
    
    NotesListView(
        clients: $clients,
        selectedFilter: $selectedFilter,
        onTogglePin: { _ in },
        onDelete: { _ in },
        onTapRow: { _ in }
    )
    .background(Color("Background"))
}

// MARK: - View Modifiers (ContactsListSection와 동일)

private extension View {
    func applyListRowCleaning() -> some View {
        self
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

// MARK: - BackgroundHoverRowStyle (ContactsRow와 동일)

private struct BackgroundHoverRowStyle: ButtonStyle {
    // 컬러 자산(프로젝트에 존재하는 키 사용)
    private let normal = Color("Background")
    private let pressed = Color("BackgroundHover")

    // 미세한 눌림 감(과하지 않게)
    private let pressedBrightness: CGFloat = -0.015
    private let pressedScale: CGFloat = 0.997
    private let duration: Double = 0.12

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        return configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                shape.fill(isPressed ? pressed : normal)
            )
            .brightness(isPressed ? pressedBrightness : 0)
            .scaleEffect(isPressed ? pressedScale : 1.0)
            .animation(.easeInOut(duration: duration), value: isPressed)
    }
}

// MARK: - Initials helpers (ContactsRow와 동일)

private func makeInitials(name: String, surname: String) -> String {
    let givenName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let familyName = surname.trimmingCharacters(in: .whitespacesAndNewlines)
    if givenName.isEmpty && familyName.isEmpty { return "" }
    if containsHangul(givenName) || containsHangul(familyName) {
        return String((familyName.isEmpty ? givenName : familyName).prefix(1))
    } else {
        let first = givenName.isEmpty ? "" : String(givenName.prefix(1)).uppercased()
        let last = familyName.isEmpty ? "" : String(familyName.prefix(1)).uppercased()
        return first + last
    }
}

private func containsHangul(_ text: String) -> Bool {
    for scalar in text.unicodeScalars {
        let scalarValue = scalar.value
        if (0xAC00...0xD7A3).contains(scalarValue) || (0x1100...0x11FF).contains(scalarValue) || (0x3130...0x318F).contains(scalarValue) {
            return true
        }
    }
    return false
}

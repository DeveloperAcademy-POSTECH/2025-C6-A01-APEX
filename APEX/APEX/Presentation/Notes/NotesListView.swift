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
                        NotesRow(
                            client: client,
                            onTogglePin: { onTogglePin(client) },
                            onDelete: { onDelete(client) },
                            onTap: {
                                // TODO: 상세 화면 이동
                                print("Tapped client: \(client.name)")
                            }
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
        return "Video [9412894219382]" // 고정값으로 테스트
    }
    
    private var timeText: String { 
        return "4:00pm" // 고정값으로 테스트
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

                Spacer(minLength: 8)
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
    NotesListView(
        clients: sampleClients,
        selectedFilter: .constant(.all),
        onTogglePin: { _ in },
        onDelete: { _ in }
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

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
                List(filtered, id: \.id) { client in
                    NotesRow(
                        client: client,
                        onTogglePin: { onTogglePin(client) },
                        onDelete: { onDelete(client) },
                        onTap: { onTapRow(client) }
                    )
                    .equatable()
                    .applyListRowCleaning()
                }
                .listStyle(.plain)
                .listRowSpacing(0)
                .environment(\.defaultMinListRowHeight, 1)
                .scrollContentBackground(.hidden)
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear.frame(height: 16)
                }
            }
        }
        .background(Color("Background"))
        .animation(nil)
    }
}

// MARK: - Row

private struct NotesRow: View {
    let client: Client
    var onTogglePin: (() -> Void)?
    var onDelete: (() -> Void)?
    var onTap: (() -> Void)?

    private var fullName: String { 
        client.autoFormattedName
    }
    
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
            .frame(height: 72)
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
                let initials = Profile.makeInitials(name: client.name, surname: client.surname)
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

// MARK: - Equatable Optimization
extension NotesRow: Equatable {
    static func == (lhs: NotesRow, rhs: NotesRow) -> Bool {
        // 동일 클라이언트 행이고, 표시값 기준으로 변동 없으면 재렌더링 방지
        guard lhs.client.id == rhs.client.id else { return false }
        // 텍스트/아이콘에 영향을 주는 필드 비교 (notes의 최신 시간까지)
        let lhsLatest = lhs.client.notes.max(by: { $0.uploadedAt < $1.uploadedAt })?.uploadedAt
        let rhsLatest = rhs.client.notes.max(by: { $0.uploadedAt < $1.uploadedAt })?.uploadedAt
        return lhs.client.pin == rhs.client.pin
        && lhs.client.favorite == rhs.client.favorite
        && lhs.client.name == rhs.client.name
        && lhs.client.surname == rhs.client.surname
        && lhs.client.position == rhs.client.position
        && lhs.client.company == rhs.client.company
        && lhsLatest == rhsLatest
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
    // 시스템 설정에 따라 동적으로 formatter 생성
    private static func createTimeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        // 시스템 설정에 따라 12/24시간 자동 결정하되, 12시간제일 때 공백 추가
        if DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current)?.contains("a") == true {
            // 12시간제: 공백 있는 패턴 사용
            formatter.dateFormat = "h:mm a"
        } else {
            // 24시간제: AM/PM 없는 패턴 사용
            formatter.dateFormat = "H:mm"
        }
        return formatter
    }
    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()
    
    private static let yearMonthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        return formatter
    }()

    static func timeText(for notes: [Note]) -> String? {
        guard let latest = notes.max(by: { $0.uploadedAt < $1.uploadedAt }) else { return nil }
        let cal = Calendar.current
        let now = Date()
        let timeFormatter = createTimeFormatter() // 동적 생성
        
        if cal.isDate(latest.uploadedAt, inSameDayAs: now) {
            // 오늘: 시간만
            return timeFormatter.string(from: latest.uploadedAt) // 3:00 PM 또는 15:00
        } else if let yesterday = cal.date(byAdding: .day, value: -1, to: now),
                  cal.isDate(latest.uploadedAt, inSameDayAs: yesterday) {
            // 어제: "어제 + 시간"
            return "어제 " + timeFormatter.string(from: latest.uploadedAt) // 어제 3:00 PM
        } else if cal.component(.year, from: latest.uploadedAt) == cal.component(.year, from: now) {
            // 그제~올해 이전: 월/일 + 시간
            return monthDayFormatter.string(from: latest.uploadedAt) + " " + timeFormatter.string(from: latest.uploadedAt) // 10/30 3:00 PM
        } else {
            // 전년도 이전: 년/월/일 + 시간
            return yearMonthDayFormatter.string(from: latest.uploadedAt) + " " + timeFormatter.string(from: latest.uploadedAt) // 2024/12/25 3:00 PM
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

        // 첨부 타입별 UUID 형식 파일명 출력
        let id = videoIdPlaceholder() // TODO: 실제 ID 노출로 대체 예정
        switch latest.bundle {
        case .media(let images, let videos):
            if !videos.isEmpty { return "Video [\(id)]" }
            if !images.isEmpty { return "Photo [\(id)]" }
            return nil
        case .files(let files):
            return files.isEmpty ? nil : "File [\(id)]"
        case .audio(let audios):
            return audios.isEmpty ? nil : "Audio [\(id)]"
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
        func liveNotes(for client: Client) -> [Note] {
            let live = ChatStore.shared.notes(for: client.id)
            return live.isEmpty ? client.notes : live
        }
        func latestDate(for client: Client) -> Date {
            let notes = liveNotes(for: client)
            return notes.max(by: { $0.uploadedAt < $1.uploadedAt })?.uploadedAt ?? .distantPast
        }
        func hasAnyNotes(_ client: Client) -> Bool {
            !liveNotes(for: client).isEmpty
        }
        func insertionIndex(_ client: Client) -> Int {
            if let idx = ClientsStore.shared.clients.firstIndex(where: { $0.id == client.id }) { return idx }
            return Int.max
        }
        return clients.sorted { lhs, rhs in
            // 1) 핀 우선
            if lhs.pin != rhs.pin { return lhs.pin }
            
            // 2) 둘 다 핀된 경우, PinOrderManager의 순서 사용 (최근 핀한 순)
            if lhs.pin && rhs.pin {
                let lhsIndex = PinOrderManager.shared.getPinIndex(for: lhs.id) ?? Int.max
                let rhsIndex = PinOrderManager.shared.getPinIndex(for: rhs.id) ?? Int.max
                if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
            }
            
            // 3) 최신 노트 시간 내림차순 (없으면 .distantPast 처리 → 아래로)
            let lhsDate = latestDate(for: lhs)
            let rhsDate = latestDate(for: rhs)
            if lhsDate != rhsDate { return lhsDate > rhsDate }
            
            // 4) 동률 시 삽입 순서(ClientsStore 기준) 유지
            return insertionIndex(lhs) < insertionIndex(rhs)
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

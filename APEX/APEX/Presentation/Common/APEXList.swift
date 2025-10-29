//
//  APEXList.swift
//  APEX
//
//  Created by 조운경 on 10/19/25.
//

import SwiftUI

// MARK: - Public API

enum APEXListRowStyle {
    case contact              // 직책 표시
    case note          // 최근 기록 요약 표시
}

struct APEXList: View {
    let clients: [Client]
    let rowStyle: APEXListRowStyle
    var onTap: ((Client) -> Void)?
    var onDelete: ((Client) -> Void)?
    var onToggleFavorite: ((Client) -> Void)?
    var onTogglePin: ((Client) -> Void)?

    init(
        clients: [Client],
        rowStyle: APEXListRowStyle,
        onTap: ((Client) -> Void)? = nil,
        onDelete: ((Client) -> Void)? = nil,
        onToggleFavorite: ((Client) -> Void)? = nil,
        onTogglePin: ((Client) -> Void)? = nil
    ) {
        self.clients = clients
        self.rowStyle = rowStyle
        self.onTap = onTap
        self.onDelete = onDelete
        self.onToggleFavorite = onToggleFavorite
        self.onTogglePin = onTogglePin
    }

    var body: some View {
        List {
            ForEach(clients) { client in
                Button {
                    onTap?(client)
                } label: {
                    APEXListRow(client: client, style: rowStyle)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                // Trailing: Delete
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        onDelete?(client)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(Color("Error"))
                }
                // Leading: Favorite (contact) or Pin (note)
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    switch rowStyle {
                    case .contact:
                        Button {
                            onToggleFavorite?(client)
                        } label: {
                            Image(systemName: client.favorite ? "star.slash" : "star")
                        }
                        .tint(Color("Primary"))
                    case .note:
                        Button {
                            onTogglePin?(client)
                        } label: {
                            Image(systemName: client.pin ? "pin.slash" : "pin")
                        }
                        .tint(Color("Primary"))
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Row

struct APEXListRow: View {
    let client: Client
    let style: APEXListRowStyle

    private var fullName: String {
        "\(client.name) \(client.surname)"
    }

    private var subtitle: String {
        switch style {
        case .contact:
            return client.position?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "직책 없음"
        case .note:
            return APEXListRow.makeLatestRecordSummary(from: client.notes) ?? "기록 없음"
        }
    }
    
    private var timeText: String {
        guard style == .note, let latestNote = client.notes.max(by: { $0.date < $1.date }) else { return "" }
        
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDate(latestNote.date, inSameDayAs: Date()) {
            formatter.dateFormat = "h:mma"
            return formatter.string(from: latestNote.date).lowercased()
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()),
                  calendar.isDate(latestNote.date, inSameDayAs: yesterday) {
            return "어제"
        } else {
            formatter.dateFormat = "M/d"
            return formatter.string(from: latestNote.date)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 핀 아이콘 (notes 스타일일 때만)
            if style == .note && client.pin {
                Image(systemName: "pin.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("Primary"))
                    .frame(width: 20)
            } else if style == .note {
                // 핀이 없을 때도 공간 유지
                Color.clear.frame(width: 20)
            }
            
            avatar
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(fullName)
                        .font(.body2)
                        .foregroundColor(Color("Dark"))  // .primary 대신 명확한 색상
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 시간 표시 (notes 스타일일 때만)
                    if style == .note && !timeText.isEmpty {
                        Text(timeText)
                            .font(.caption)
                            .foregroundColor(Color("Gray"))  // .gray 대신 명확한 색상
                    }
                }

                Text(subtitle)
                    .font(.body6)
                    .foregroundColor(Color("Gray"))  // .gray 대신 명확한 색상
                    .lineLimit(1)
            }
            
            if style == .contact {
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color("Gray"))  // .gray 대신 명확한 색상
            }
        }
        .frame(height: 64)
        .contentShape(Rectangle())
        .padding(.horizontal, 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(fullName), \(subtitle)")
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

// MARK: - Helpers

private extension APEXListRow {
    static func makeLatestRecordSummary(from notes: [Note]) -> String? {
        guard let latest = notes.max(by: { $0.date < $1.date }) else { return nil }
        switch latest.attachment {
        case .text(let text):
            return text
                .split(whereSeparator: \.isNewline)
                .first
                .map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty ?? "텍스트"
        case .image:
            return "Photo"
        case .video:
            return "Video [\(generateVideoId())]"
        case .audio:
            return "Audio"
        case .file(let url):
            return url.lastPathComponent
        }
    }
    
    static func generateVideoId() -> String {
        // 이미지에서 보이는 형식과 동일하게 생성
        return "941289421983\(Int.random(in: 10...99))"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

#Preview("APEXList (position/recentRecord)") {
    VStack(spacing: 24) {
        APEXList(
            clients: sampleClients,
            rowStyle: .contact
        )

        let withNotes: [Client] = {
            let now = Date()
            let clientOne = Client(
                profile: nil,
                nameCardFront: nil,
                nameCardBack: nil,
                surname: "Choi",
                name: "Ara",
                position: "Account Executive",
                company: "BluePeak",
                email: nil,
                phoneNumber: nil,
                linkedinURL: nil,
                memo: nil,
                action: nil,
                favorite: false,
                pin: true,
                notes: [
                    Note(date: now.addingTimeInterval(-3600), attachment: .text("미팅 노트 첫 줄\n다음 줄")),
                    Note(date: now.addingTimeInterval(-1800), attachment: .image(data: Data()))
                ]
            )
            let clientTwo = Client(
                profile: nil,
                nameCardFront: nil,
                nameCardBack: nil,
                surname: "Han",
                name: "Yuri",
                position: "Marketer",
                company: "Nova",
                email: nil,
                phoneNumber: nil,
                linkedinURL: nil,
                memo: nil,
                action: nil,
                favorite: false,
                pin: false,
                notes: [
                    Note(
                        date: now.addingTimeInterval(-7200),
                        attachment: .file(
                            url: URL(fileURLWithPath: "/tmp/견적서.pdf")
                        )
                    )
                ]
            )
            return [clientOne, clientTwo]
        }()

        APEXList(
            clients: withNotes,
            rowStyle: .note
        )
    }
}

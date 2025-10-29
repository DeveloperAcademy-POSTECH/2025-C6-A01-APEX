//
//  ShareRow.swift
//  APEX
//
//  Created by 조운경 on 10/29/25.
//

import SwiftUI

struct ShareRow: View {
    enum Mode { case contacts, recents }

    let client: Client
    let mode: Mode
    var isSelected: Bool = false
    var onToggleSelect: (() -> Void)?

    private enum Metrics {
        static let rowHeight: CGFloat = 64
        static let hStackSpacing: CGFloat = 12
        static let avatarSize: CGFloat = 48
        static let textBoxHeight: CGFloat = 38
        static let nameSubtitleSpacing: CGFloat = 2
        static let trailingSpacerMin: CGFloat = 8
        static let checkboxSize: CGFloat = 22
        static let iconFontSize: CGFloat = 13
    }

    var body: some View {
        HStack(alignment: .center, spacing: Metrics.hStackSpacing) {
            avatarWithBadge

            VStack(alignment: .leading, spacing: Metrics.nameSubtitleSpacing) {
                Text("\(client.name) \(client.surname)")
                    .font(.body2)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.body6)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            .frame(height: Metrics.textBoxHeight)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: Metrics.trailingSpacerMin)

            // Trailing checkbox
            Button {
                onToggleSelect?()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: Metrics.checkboxSize, weight: .semibold))
                    .foregroundColor(isSelected ? Color("Primary") : .gray)
                    .frame(width: Metrics.checkboxSize, height: Metrics.checkboxSize)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(client.name) \(client.surname), \(subtitle)")
    }

    private var subtitle: String {
        latestMemoText(from: client.notes) ?? ""
    }

    private var avatarWithBadge: some View {
        avatar
            .overlay(alignment: .topTrailing) {
                switch mode {
                case .contacts:
                    if client.favorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: Metrics.iconFontSize, weight: .medium))
                            .foregroundColor(Color("Primary"))
                    }
                case .recents:
                    if client.pin {
                        Image(systemName: "pin.fill")
                            .font(.system(size: Metrics.iconFontSize, weight: .medium))
                            .foregroundColor(Color("Primary"))
                    }
                }
            }
    }

    private var avatar: some View {
        let initials = makeInitials(name: client.name, surname: client.surname)
        return Profile(
            image: client.profile,
            initials: initials,
            size: Metrics.avatarSize,
            fontSize: 30.72
        )
    }
}

// MARK: - Initials helpers
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
        let isHangulSyllables = (0xAC00...0xD7A3).contains(scalarValue)
        let isHangulJamo = (0x1100...0x11FF).contains(scalarValue)
        let isHangulCompatibility = (0x3130...0x318F).contains(scalarValue)
        if isHangulSyllables || isHangulJamo || isHangulCompatibility {
            return true
        }
    }
    return false
}

#warning("최신 메모 텍스트를 부제목으로 표시 (텍스트 없는 경우 빈 문자열)")
private func latestMemoText(from notes: [Note]) -> String? {
    guard let latest = notes.max(by: { $0.uploadedAt < $1.uploadedAt }) else { return nil }
    if let text = latest.text?
        .split(whereSeparator: \.isNewline)
        .first
        .map(String.init)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
       !text.isEmpty {
        return text
    }
    return nil
}

#Preview {
    VStack(spacing: 12) {
        ShareRow(client: sampleClients.first!, mode: .contacts)
            .background(.blue)
        ShareRow(client: sampleClients.first!, mode: .recents)
            .background(.blue)
    }
}

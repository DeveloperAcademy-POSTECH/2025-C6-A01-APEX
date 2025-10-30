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
        static let iconFontSize: CGFloat = 10
    }

    var body: some View {
        HStack(alignment: .center, spacing: Metrics.hStackSpacing) {
            avatarWithBadge

            VStack(alignment: .leading, spacing: Metrics.nameSubtitleSpacing) {
                HStack(spacing: 1) {
                    Text("\(client.name) \(client.surname)")
                        .font(.body2)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if let icon = nameBadgeIconName {
                        Image(systemName: icon)
                            .font(.system(size: Metrics.iconFontSize, weight: .medium))
                            .foregroundColor(Color("Primary"))
                    }
                }

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

    private var nameBadgeIconName: String? {
        switch mode {
        case .contacts:
            return client.favorite ? "star.fill" : nil
        case .recents:
            return client.pin ? "pin.fill" : nil
        }
    }

    private var avatarWithBadge: some View {
        avatar
    }

    private var avatar: some View {
        let initials = Profile.makeInitials(name: client.name, surname: client.surname)
        return Profile(
            image: client.profile,
            initials: initials,
            size: .small,
            fontSize: 30.72,
            backgroundColor: Color("PrimaryContainer"),
            textColor: .white,
            fontWeight: .semibold
        )
    }
}

// makeInitials moved to common component: Profile.makeInitials

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
            .background(.cyan)
        ShareRow(client: sampleClients.first!, mode: .recents)
            .background(.cyan)
    }
}

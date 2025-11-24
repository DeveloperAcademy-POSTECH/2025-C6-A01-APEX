//
//  ShareRowExt.swift
//  StashShare
//
//  Share row UI for extension, matching app's ShareRow visuals.
//

import SwiftUI

struct ShareRowExt: View {
    enum Mode { case contacts, recents }
    
    let client: PClient
    let mode: Mode
    var isSelected: Bool = false
    var onToggleSelect: (() -> Void)?
    
    private enum Metrics {
        static let rowHeight: CGFloat = 64
        static let hStackSpacing: CGFloat = 12
        static let textBoxHeight: CGFloat = 38
        static let nameSubtitleSpacing: CGFloat = 2
        static let trailingSpacerMin: CGFloat = 8
        static let checkboxSize: CGFloat = 22
        static let iconFontSize: CGFloat = 10
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: Metrics.hStackSpacing) {
            avatar
            
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
            
            Button {
                onToggleSelect?()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: Metrics.checkboxSize, weight: .semibold))
                    .foregroundColor(isSelected ? ShareTheme.primary : .gray)
                    .frame(width: Metrics.checkboxSize, height: Metrics.checkboxSize)
            }
            .buttonStyle(.plain)
        }
        .frame(height: Metrics.rowHeight, alignment: .center)
        .padding(.vertical, 0)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(client.name) \(client.surname), \(subtitle)")
    }
    
    private var subtitle: String {
        switch mode {
        case .contacts:
            return client.position ?? ""
        case .recents:
            return latestMemoText(from: client.notes) ?? ""
        }
    }
    
    private var nameBadgeIconName: String? {
        switch mode {
        case .contacts:
            return client.favorite ? "star.fill" : nil
        case .recents:
            return client.pin ? "pin.fill" : nil
        }
    }
    
    private var avatar: some View {
        let initials = Profile.makeInitials(name: client.name, surname: client.surname)
        let image: UIImage? = client.profileImageData.flatMap { UIImage(data: $0) }
        return Profile(
            image: image,
            initials: initials,
            size: .extraSmall,
            fontSize: 30.72,
            backgroundColor: ShareTheme.primaryContainer,
            textColor: .white,
            fontWeight: .semibold
        )
    }
}

private func latestMemoText(from notes: [PNote]) -> String? {
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



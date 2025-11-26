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
                    Text(client.autoFormattedName)
                        .font(.body2)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if let icon = nameBadgeIconName {
                        Image(systemName: icon)
                            .font(.system(size: Metrics.iconFontSize, weight: .medium))
                            .foregroundColor(ShareTheme.primary)
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
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(client.autoFormattedName), \(subtitle)")
    }
    
    private var subtitle: String {
        switch mode {
        case .contacts:
            return client.position ?? ""
        case .recents:
            return NotesTextFormatterExt.latestSummary(from: client.notes) ?? ""
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
            fontSize: 26.88, // 48 * 0.56
            backgroundColor: ShareTheme.primaryContainer,
            textColor: .white,
            fontWeight: .semibold
        )
    }
}

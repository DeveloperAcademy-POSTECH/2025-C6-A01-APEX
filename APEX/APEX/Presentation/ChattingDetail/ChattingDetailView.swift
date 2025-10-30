//
//  ChattingDetailView.swift
//  APEX
//
//  Created by 조운경 on 10/30/25.
//

import SwiftUI

struct ChattingDetailView: View {
    // In real usage, pass the actual conversation/client data
    var client: Client? = sampleClients.first

    @State private var isMuted: Bool = false
    @State private var isFavorite: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection

                actionsRow

                sharedMediaSection

                sharedLinksSection

                sharedFilesSection

                settingsSection

                dangerSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color("Background"))
        .safeAreaInset(edge: .top) { topBar }
        .onAppear { isFavorite = client?.favorite ?? false }
    }

    // MARK: - Sections

    private var headerSection: some View {
        let initials = Profile.makeInitials(name: client?.name ?? "", surname: client?.surname ?? "")
        let fullName = ((client?.name ?? "") + " " + (client?.surname ?? "")).trimmingCharacters(in: .whitespaces)
        return ChatDetailHeader(
            image: client?.profile,
            initials: initials,
            name: fullName,
            company: client?.company,
            position: client?.position,
            phone: client?.phoneNumber,
            favorite: client?.favorite ?? false
        )
    }

    private var actionsRow: some View {
        HStack(spacing: 12) {
            ActionButton(title: "Audio", systemImage: "phone.fill") { }
            ActionButton(title: "Video", systemImage: "video.fill") { }
            ActionButton(title: "Share", systemImage: "square.and.arrow.up") { }
        }
    }

    private var sharedMediaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "Shared Media", actionTitle: "See all") { }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                ForEach(0..<6, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private var sharedLinksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "Links", actionTitle: "See all") { }
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { idx in
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .font(.system(size: 13, weight: .medium))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("example-site-\(idx).com")
                                .font(.caption2)
                                .foregroundStyle(.primary)
                            Text("/path/to/resource")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color("BackgroundSecondary"))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private var sharedFilesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "Files", actionTitle: "See all") { }
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { idx in
                    HStack(spacing: 12) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 13, weight: .medium))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Document_\(idx + 1).pdf")
                                .font(.caption2)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text("256 KB")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color("BackgroundSecondary"))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "Settings")
            VStack(spacing: 8) {
                HStack {
                    Text("Mute notifications")
                        .font(.body2)
                        .foregroundStyle(.primary)
                    Spacer()
                    Toggle("", isOn: $isMuted)
                        .labelsHidden()
                }
                .padding(12)
                .background(Color("BackgroundSecondary"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "Danger")
            VStack(spacing: 8) {
                Button {
                    // Block user
                } label: {
                    HStack {
                        Text("차단")
                            .font(.body2)
                            .foregroundStyle(Color("Error"))
                        Spacer()
                    }
                    .padding(12)
                    .background(Color("BackgroundSecondary"))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    // Report
                } label: {
                    HStack {
                        Text("신고")
                            .font(.body2)
                            .foregroundStyle(Color("Error"))
                        Spacer()
                    }
                    .padding(12)
                    .background(Color("BackgroundSecondary"))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    // Leave chat
                } label: {
                    HStack {
                        Text("채팅방 나가기")
                            .font(.body2)
                            .foregroundStyle(Color("Error"))
                        Spacer()
                    }
                    .padding(12)
                    .background(Color("BackgroundSecondary"))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var topBar: some View {
        ZStack(alignment: .center) {
            HStack(spacing: 0) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title4)
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect()

                Spacer(minLength: 0)

                Button(action: { isFavorite.toggle() }) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.title4)
                        .foregroundColor(Color("Primary"))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassEffect()
            }
            .frame(height: 52)
            .padding(.horizontal, 12)
            .background(Color("Background"))
        }
    }

    private func sectionHeader(title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.body4)
                .foregroundStyle(.secondary)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                            .font(.caption2)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(Color("Primary"))
            }
        }
    }

    private struct ChatDetailHeader: View {
        let image: UIImage?
        let initials: String
        let name: String
        let company: String?
        let position: String?
        let phone: String?
        let favorite: Bool

        var body: some View {
            VStack(alignment: .center, spacing: 8) {
                Profile(
                    image: image,
                    initials: initials,
                    size: .large,
                    fontSize: 48,
                    backgroundColor: Color("PrimaryContainer"),
                    textColor: .white,
                    fontWeight: .semibold
                )

                Text(name)
                    .font(.title3)
                    .foregroundColor(Color("Dark"))
                    .multilineTextAlignment(.center)

                Group {
                    if let company, let position, !company.isEmpty, !position.isEmpty {
                        Text("\(company) · \(position)")
                    } else if let company, !company.isEmpty {
                        Text(company)
                    } else if let position, !position.isEmpty {
                        Text(position)
                    }
                }
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private struct ActionButton: View {
        let title: String
        let systemImage: String
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color("Primary"))
                    Text(title)
                        .font(.caption2)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color("BackgroundSecondary"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ChattingDetailView()
}

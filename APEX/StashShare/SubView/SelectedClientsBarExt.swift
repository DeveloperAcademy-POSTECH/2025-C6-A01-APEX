//
//  SelectedClientsBarExt.swift
//  StashShare
//
//  New subview extracted from ShareSheetView: selected chips row.
//

import SwiftUI

struct SelectedClientsBarExt: View {
    let clients: [PClient]
    let onToggleSelect: (UUID) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(clients) { client in
                    chip(for: client)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func chip(for client: PClient) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                let initials = Profile.makeInitials(name: client.name, surname: client.surname)
                let image = client.profileImageData.flatMap { UIImage(data: $0) }
                Profile(
                    image: image,
                    initials: initials,
                    size: .extraSmall,
                    fontSize: 30.72,
                    backgroundColor: ShareTheme.primaryContainer,
                    textColor: .white,
                    fontWeight: .semibold
                )
                Button { onToggleSelect(client.id) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)
            }
            
            Text("\(client.name) \(client.surname)")
                .font(.caption2)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }
}



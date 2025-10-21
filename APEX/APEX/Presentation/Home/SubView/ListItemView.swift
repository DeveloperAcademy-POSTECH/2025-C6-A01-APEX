//
//  ListItemView.swift
//  APEX
//
//  Created by 조운경 on 10/10/25.
//

import SwiftUI

struct ListItemView: View {
    let client: Client

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let profile = client.profile {
                    Image(uiImage: profile)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image("DefaultProfile")
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("\(client.name) \(client.surname)")
                    .font(.body2)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let position = client.position, !position.isEmpty {
                    Text(position)
                        .font(.body6)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.vertical, 5)

            Spacer()
        }
        .padding(.vertical, 8)
        .background(.white)
        .contentShape(Rectangle())
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                // toggle favorite action hook
            } label: {
                ZStack {
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(width: 64, height: 56)
                    Image(systemName: client.favorite ? "star.fill" : "star")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .semibold))
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                // delete action hook
            } label: {
                Image(systemName: "trash.fill")
            }
        }
    }
}

#Preview {
    ListItemView(
        client: Client(
            profile: nil,
            nameCard: nil,
            surname: "Jo",
            name: "Unkyung",
            position: "iOS Developer",
            company: "애플 디벨로퍼 아카데미",
            email: "pos10022@naver.com",
            phoneNumber: "010-4923-2775",
            linkedinURL: nil,
            memo: nil,
            action: nil,
            favorite: true,
            pin: false,
            notes: []
        )
    )
}

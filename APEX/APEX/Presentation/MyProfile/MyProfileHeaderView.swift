//
//  MyProfileHeaderView.swift
//  APEX
//
//  Created by AI Assistant on 10/27/25.
//

import SwiftUI

struct MyProfileHeaderView: View {
    let client: Client
    @Binding var page: Int

    private enum Page: Int, CaseIterable { case profile = 0, cardFront = 1, cardBack = 2 }

    var body: some View {
        VStack(spacing: 12) {
            // Avatar / Card
            ZStack {
                Group {
                    switch Page(rawValue: page) ?? .profile {
                    case .profile:
                        avatar
                    case .cardFront:
                        cardImage(client.nameCardFront)
                    case .cardBack:
                        cardImage(client.nameCardBack)
                    }
                }
                .frame(width: 160, height: 160)
                .clipShape(Circle())
                .contentShape(Circle())
            }
            .padding(.top, 8)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        let dx = value.translation.width
                        if dx < -30 { // left
                            page = min(page + 1, Page.allCases.count - 1)
                        } else if dx > 30 { // right
                            page = max(page - 1, 0)
                        }
                    }
            )
            .onTapGesture {
                page = (page + 1) % Page.allCases.count
            }

            // Page indicator
            HStack(spacing: 6) {
                ForEach(Page.allCases, id: \.self) { p in
                    Circle()
                        .fill(p.rawValue == page ? Color.black : Color("BackgroundSecondary"))
                        .frame(width: 6, height: 6)
                        .onTapGesture { page = p.rawValue }
                }
            }
            .padding(.bottom, 4)

            // Name
            Text("\(client.surname) \(client.name)")
                .font(.title5)
                .foregroundColor(.black)

            // Subtitle: 회사 + 직책
            Text(subtitle)
                .font(.body6)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    private var subtitle: String {
        let company = client.company.trimmingCharacters(in: .whitespacesAndNewlines)
        let position = (client.position ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if company.isEmpty && position.isEmpty { return "" }
        if company.isEmpty { return position }
        if position.isEmpty { return company }
        return "\(company) \(position)"
    }

    @ViewBuilder
    private var avatar: some View {
        if let img = client.profile {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .background(Color("BackgroundSecondary"))
        } else {
            let initials = makeInitials(name: client.name, surname: client.surname)
            InitialAvatar(letter: initials.isEmpty ? "?" : initials, size: 160, fontSize: 96)
        }
    }

    @ViewBuilder
    private func cardImage(_ image: Image?) -> some View {
        if let image {
            image
                .resizable()
                .scaledToFit()
                .background(Color("BackgroundSecondary"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(width: 232, height: 140)
                .clipShape(Circle()) // 원형 안에 카드 비율을 넣기 위해 간단 처리
        } else {
            ZStack {
                Circle()
                    .fill(Color("BackgroundSecondary"))
                Image("CardS")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 72)
            }
        }
    }
}

// 재사용 initials (ContactsRow/others와 동일 로직)
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
        let v = scalar.value
        if (0xAC00...0xD7A3).contains(v) || (0x1100...0x11FF).contains(v) || (0x3130...0x318F).contains(v) {
            return true
        }
    }
    return false
}

#Preview {
    MyProfileHeaderView(client: sampleClients.first!, page: .constant(0))
}


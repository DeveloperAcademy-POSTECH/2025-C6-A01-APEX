//
//  MyProfileHeader.swift
//  APEX
//
//  Created by AI Assistant on 10/27/25.
//

import SwiftUI

// MARK: - Navigation Bar

struct MyProfileNavigationBar: View {
    let title: String
    var onBack: () -> Void
    var onEdit: () -> Void
    var isEditEnabled: Bool = true

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // 뒤로 버튼
            Button(action: onBack) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        .frame(width: 44, height: 44)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color.black)
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .accessibilityLabel("뒤로")
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // 제목
            Text(title)
                .font(.title5)
                .foregroundColor(.black)
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
            
            // 편집 버튼 (상태별 처리)
            Button(action: onEdit) {
                Text("편집")
                    .font(.title6)
                    .foregroundColor(isEditEnabled ? Color.black : Color.gray)
                    .frame(width: 52, height: 44)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    )
                    .opacity(isEditEnabled ? 1.0 : 0.6)
            }
            .buttonStyle(.plain)
            .disabled(!isEditEnabled)
            .accessibilityLabel("편집")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 0)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(.white)
    }
}

// MARK: - Profile Header View

struct MyProfileHeaderView: View {
    let client: Client
    @Binding var page: Int
    var onCardTapped: (() -> Void)? = nil

    private enum Kind { case profile(UIImage), cardFront(Image), cardBack(Image), avatar(String) }

    private var pages: [Kind] {
        var arr: [Kind] = []
        
        if client.nameCardFront != nil || client.nameCardBack != nil {
            let initials = makeInitials(name: client.name, surname: client.surname)
            arr.append(.avatar(initials))
            if let f = client.nameCardFront { arr.append(.cardFront(f)) }
            if let b = client.nameCardBack { arr.append(.cardBack(b)) }
        } else {
            if let img = client.profile {
                arr.append(.profile(img))
            } else {
                let initials = makeInitials(name: client.name, surname: client.surname)
                arr.append(.avatar(initials))
            }
        }
        return arr
    }

    var body: some View {
        let items = pages
        
        VStack(alignment: .center, spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(items.indices), id: \.self) { index in
                    content(for: items[index])
                        .tag(index)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let current = items[index]
                            if case .cardFront(_) = current {
                                onCardTapped?()
                            } else if case .cardBack(_) = current {
                                onCardTapped?()
                            }
                        }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 250)

            Spacer().frame(height: 4)
            
            HStack(spacing: 8) {
                ForEach(0..<max(1, items.count), id: \.self) { idx in
                    if idx < items.count {
                        Circle()
                            .fill(idx == page ? Color(hex: "404040") : Color(hex: "D9D9D9"))
                            .frame(width: 8, height: 8)
                    } else {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(items.count > 1 ? Color.white.opacity(0.8) : Color.clear)
            .cornerRadius(50)
            .opacity(items.count > 1 ? 1.0 : 0.0)
            
            Spacer().frame(height: 4)
            
            VStack(alignment: .center, spacing: 0) {
                Text("\(client.surname)\(client.name)")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                Spacer().frame(height: 2)
                
                Text(subtitle)
                    .font(.body5)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .onChange(of: pages.count) { _ in
            page = min(page, max(pages.count - 1, 0))
        }
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
    private func content(for kind: Kind) -> some View {
        switch kind {
        case .profile(let ui):
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: 200, height: 200)
                .clipShape(Circle())
        case .cardFront(let image), .cardBack(let image):
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: 232)
                .background(Color("PrimaryContainer"))
                .clipShape(RoundedRectangle(cornerRadius: 9.28, style: .continuous))
        case .avatar(let initials):
            InitialAvatar(letter: initials, size: 232, fontSize: 128)
        }
    }
}

// MARK: - Helpers

private func makeInitials(name: String, surname: String) -> String {
    let givenName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let familyName = surname.trimmingCharacters(in: .whitespacesAndNewlines)
    if givenName.isEmpty && familyName.isEmpty { return "?" }
    if containsHangul(familyName) || containsHangul(givenName) {
        if !familyName.isEmpty {
            return String(familyName.prefix(1))
        } else {
            return String(givenName.prefix(1))
        }
    } else {
        let first = givenName.isEmpty ? "" : String(givenName.prefix(1)).uppercased()
        let last = familyName.isEmpty ? "" : String(familyName.prefix(1)).uppercased()
        let result = first + last
        return result.isEmpty ? "?" : result
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        (startIndex..<endIndex).contains(index) ? self[index] : nil
    }
}

// MARK: - Color Extensions

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview("Navigation Bar - 기본") {
    MyProfileNavigationBar(
        title: "김하경",
        onBack: { print("Back tapped") },
        onEdit: { print("Edit tapped") },
        isEditEnabled: true
    )
    .background(Color("Background"))
}

#Preview("Navigation Bar - 디스에이블드") {
    MyProfileNavigationBar(
        title: "김하경",
        onBack: { print("Back tapped") },
        onEdit: { print("Edit tapped") },
        isEditEnabled: false
    )
    .background(Color("Background"))
}

#Preview("Profile Header - 이니셜만") {
    MyProfileHeaderView(
        client: Client(
            profile: nil,
            nameCardFront: nil, 
            nameCardBack: nil,
            surname: "김",
            name: "하경",
            position: "크리에이티브 디렉터", 
            company: "전략기획 마케팅부",
            email: "karynkim@postech.ac.kr",
            phoneNumber: "+82 010-2360-6221",
            linkedinURL: "https://www.linkedin.com/in/karyn",
            memo: "태국 박람회에서 만남...",
            action: nil,
            favorite: false,
            pin: false,
            notes: []
        ),
        page: .constant(0),
        onCardTapped: { print("Card tapped") }
    )
}

#Preview("Profile Header - 명함 있음") {
    MyProfileHeaderView(
        client: Client(
            profile: nil,
            nameCardFront: Image("CardL"), 
            nameCardBack: Image("CardL"),
            surname: "김",
            name: "하경",
            position: "크리에이티브 디렉터", 
            company: "전략기획 마케팅부",
            email: "karynkim@postech.ac.kr",
            phoneNumber: "+82 010-2360-6221",
            linkedinURL: "https://www.linkedin.com/in/karyn",
            memo: "태국 박람회에서 만남...",
            action: nil,
            favorite: false,
            pin: false,
            notes: []
        ),
        page: .constant(0),
        onCardTapped: { print("Card tapped") }
    )
}

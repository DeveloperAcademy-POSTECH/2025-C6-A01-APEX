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
                        .foregroundColor(Color.black) // 명시적으로 Color.black 사용
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
                    .foregroundColor(isEditEnabled ? Color.black : Color.gray) // 명시적으로 Color.black 사용
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
        .padding(.vertical, 8)
        .frame(width: 393, alignment: .center)
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
        if let img = client.profile { arr.append(.profile(img)) }
        if let f = client.nameCardFront { arr.append(.cardFront(f)) }
        if let b = client.nameCardBack { arr.append(.cardBack(b)) }
        if arr.isEmpty {
            let initials = makeInitials(name: client.name, surname: client.surname)
            arr = [.avatar(initials)]
        }
        return arr
    }

    var body: some View {
        let items = pages
        
        VStack(alignment: .center, spacing: 16) {
            // 원형 컨테이너 (메인 프로필/명함/아바타 영역)
            ZStack {
                // 원형 배경
                Circle()
                    .fill(Color(red: 0.93, green: 0.94, blue: 0.96))
                    .frame(width: 232, height: 232)
                
                // TabView로 스와이프 가능한 콘텐츠
                TabView(selection: $page) {
                    ForEach(Array(items.indices), id: \.self) { index in
                        content(for: items[index])
                            .tag(index)
                            .onTapGesture {
                                let current = items[index]
                                if case .cardFront(_) = current, let callback = onCardTapped {
                                    callback()
                                } else if case .cardBack(_) = current, let callback = onCardTapped {
                                    callback()
                                }
                            }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // 기본 인디케이터 숨김
                .frame(width: 232, height: 232)
            }
            
            // 커스텀 도트 인디케이터 (여러 페이지가 있을 때만 표시)
            if items.count > 1 {
                HStack(spacing: 8) {
                    ForEach(Array(items.indices), id: \.self) { idx in
                        Circle()
                            .fill(idx == page ? Color.black : Color.gray.opacity(0.4))
                            .frame(width: 6, height: 6)
                            .onTapGesture { 
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    page = idx 
                                }
                            }
                    }
                }
                .padding(.vertical, 4)
            }
            
            // 텍스트 섹션 (원형 영역 밖)
            VStack(alignment: .center, spacing: 2) {
                // 이름 (title/title02)
                Text("\(client.surname)\(client.name)")
                    .font(.pretandard(.medium, size: 24))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                
                // 직책 (body/body05)
                Text(subtitle)
                    .font(.pretandard(.medium, size: 14))
                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))
            }
        }
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
                .frame(maxWidth: 180, maxHeight: 108)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        case .avatar(let initials):
            // 이니셜 아바타 - 큰 사이즈로 원형 배경에 맞춤
            Text(initials)
                .font(.pretandard(.medium, size: 96))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Helpers

private func makeInitials(name: String, surname: String) -> String {
    let givenName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let familyName = surname.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // 빈 문자열 처리
    if givenName.isEmpty && familyName.isEmpty { return "?" }
    
    // 한글의 경우 성씨 우선, 없으면 이름 첫 글자
    if containsHangul(familyName) || containsHangul(givenName) {
        if !familyName.isEmpty {
            return String(familyName.prefix(1))
        } else {
            return String(givenName.prefix(1))
        }
    } else {
        // 영문의 경우 이름과 성씨 첫 글자 조합
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

#Preview("Profile Header") {
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

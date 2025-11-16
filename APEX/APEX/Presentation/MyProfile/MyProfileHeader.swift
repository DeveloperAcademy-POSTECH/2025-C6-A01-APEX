//
//  MyProfileHeader.swift
//  APEX
//
//  Created by AI Assistant on 10/27/25.
//

import SwiftUI

// MARK: - Navigation Bar

public struct MyProfileNavigationBar: View {
    let title: String
    var onBack: () -> Void
    var onEdit: () -> Void
    var isEditEnabled: Bool = true

    // Theme - APEXSheetTopBar와 동일하게
    private var background: Color = Color("Background")
    private var foreground: Color = .black
    private var height: CGFloat = 52

    public init(
        title: String,
        onBack: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        isEditEnabled: Bool = true
    ) {
        self.title = title
        self.onBack = onBack
        self.onEdit = onEdit
        self.isEditEnabled = isEditEnabled
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .center) {
                // Left/right lane (APEXSheetTopBar와 동일한 구조)
                HStack(spacing: 0) {
                    leftButton
                    Spacer(minLength: 0)
                    rightButton
                }
                .frame(height: height)
                .padding(.horizontal, 12)

                // Center title overlay
                Text(title)
                    .font(.title5)
                    .foregroundColor(foreground)
                    .lineLimit(1)
                    .frame(height: height)
                    .padding(.horizontal, 12)
                    .allowsHitTesting(false)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    private var leftButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .medium, design: .default))
                .foregroundColor(foreground)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect()
        .accessibilityLabel("뒤로")
    }

    private var rightButton: some View {
        Button(action: onEdit) {
            Text("편집")
                .font(.title6)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundColor(isEditEnabled ? foreground : .gray)
                .frame(height: 44)
                .padding(.horizontal, 8)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
                .glassEffect()
                .opacity(isEditEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!isEditEnabled)
        .accessibilityLabel("편집")
    }
}


// MARK: - Profile Header View

public struct MyProfileHeaderView: View {
    let client: Client
    @Binding var page: Int
    var onCardTapped: (() -> Void)? = nil

    private enum Kind { case profile(UIImage), cardFront(Image), cardBack(Image), avatar(String) }

    private var pages: [Kind] {
        var arr: [Kind] = []
        
        if let img = client.profile {
            arr.append(.profile(img))
        } else {
            let initials = Profile.makeInitials(name: client.name, surname: client.surname)
            arr.append(.avatar(initials))
        }
        
        if client.nameCardFront != nil || client.nameCardBack != nil {
            if let f = client.nameCardFront { arr.append(.cardFront(f)) }
            if let b = client.nameCardBack { arr.append(.cardBack(b)) }
        } else {
            arr.append(.cardFront(Image("CardL")))
            arr.append(.cardBack(Image("CardL")))
        }
        return arr
    }

    public var body: some View {
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
                            .fill(idx == page ? Color("Primary") : Color(hex: "D9D9D9"))
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
                Text(client.autoFormattedName)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                Spacer().frame(height: 4)
                
                Text(subtitle)
                    .font(.body5)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
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
            Profile(
                image: ui,
                initials: Profile.makeInitials(name: client.name, surname: client.surname),
                size: .large,
                fontSize: 128
            )
        case .cardFront(let image), .cardBack(let image):
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: 214)
                .background(Color("PrimaryContainer"))
                .clipShape(RoundedRectangle(cornerRadius: 9.28, style: .continuous))
        case .avatar(let initials):
            Profile(image: nil, initials: initials, size: .large, fontSize: 128)
        }
    }
}

// MARK: - Helpers


private extension Array {
    subscript(safe index: Int) -> Element? {
        (startIndex..<endIndex).contains(index) ? self[index] : nil
    }
}

// MARK: - Color Extensions

// Color extensions moved to Util/Extension/Color+Ex.swift

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

#Preview("명함 케이스 테스트") {
    struct TestView: View {
        @State private var currentPage1 = 0
        @State private var currentPage2 = 0
        @State private var currentPage3 = 0
        @State private var currentPage4 = 0
        @State private var currentPage5 = 0
        
        var body: some View {
            ScrollView {
                VStack(spacing: 32) {
                    
                    // 케이스 1: 이니셜만 (프로필 사진 없음, 명함 없음)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("케이스 1: 이니셜만")
                            .font(.headline)
                            .padding(.horizontal, 16)
                        
                        MyProfileHeaderView(
                            client: Client(
                                profile: nil,
                                nameCardFront: nil, 
                                nameCardBack: nil,
                                surname: "김",
                                name: "철수",
                                position: "개발자", 
                                company: "테크 컴퍼니",
                                email: nil, phoneNumber: nil, linkedinURL: nil, memo: nil,
                                action: nil, favorite: false, pin: false, notes: []
                            ),
                            page: $currentPage1,
                            onCardTapped: { print("Card tapped - Case 1") }
                        )
                    }
                    
                    // 케이스 2: 명함 앞면만
                    VStack(alignment: .leading, spacing: 8) {
                        Text("케이스 2: 이니셜 + 명함 앞면만")
                            .font(.headline)
                            .padding(.horizontal, 16)
                        
                        MyProfileHeaderView(
                            client: Client(
                                profile: nil,
                                nameCardFront: Image("CardL"), 
                                nameCardBack: nil,
                                surname: "박",
                                name: "영희",
                                position: "디자이너", 
                                company: "크리에이티브 스튜디오",
                                email: nil, phoneNumber: nil, linkedinURL: nil, memo: nil,
                                action: nil, favorite: false, pin: false, notes: []
                            ),
                            page: $currentPage2,
                            onCardTapped: { print("Card tapped - Case 2") }
                        )
                    }
                    
                    // 케이스 3: 명함 뒷면만
                    VStack(alignment: .leading, spacing: 8) {
                        Text("케이스 3: 이니셜 + 명함 뒷면만")
                            .font(.headline)
                            .padding(.horizontal, 16)
                        
                        MyProfileHeaderView(
                            client: Client(
                                profile: nil,
                                nameCardFront: nil, 
                                nameCardBack: Image("CardL"),
                                surname: "이",
                                name: "민수",
                                position: "마케터", 
                                company: "마케팅 에이전시",
                                email: nil, phoneNumber: nil, linkedinURL: nil, memo: nil,
                                action: nil, favorite: false, pin: false, notes: []
                            ),
                            page: $currentPage3,
                            onCardTapped: { print("Card tapped - Case 3") }
                        )
                    }
                    
                    // 케이스 4: 명함 앞면 + 뒷면
                    VStack(alignment: .leading, spacing: 8) {
                        Text("케이스 4: 이니셜 + 명함 앞면 + 뒷면")
                            .font(.headline)
                            .padding(.horizontal, 16)
                        
                        MyProfileHeaderView(
                            client: Client(
                                profile: nil,
                                nameCardFront: Image("CardL"), 
                                nameCardBack: Image("CardL"),
                                surname: "정",
                                name: "수현",
                                position: "PM", 
                                company: "스타트업",
                                email: nil, phoneNumber: nil, linkedinURL: nil, memo: nil,
                                action: nil, favorite: false, pin: false, notes: []
                            ),
                            page: $currentPage4,
                            onCardTapped: { print("Card tapped - Case 4") }
                        )
                    }
                    
                    // 케이스 5: 프로필 사진만 (명함 없음)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("케이스 5: 프로필 사진만")
                            .font(.headline)
                            .padding(.horizontal, 16)
                        
                        MyProfileHeaderView(
                            client: Client(
                                profile: UIImage(systemName: "person.crop.circle.fill")?.withTintColor(.blue, renderingMode: .alwaysOriginal),
                                nameCardFront: nil, 
                                nameCardBack: nil,
                                surname: "최",
                                name: "지혜",
                                position: "기획자", 
                                company: "엔터테인먼트",
                                email: nil, phoneNumber: nil, linkedinURL: nil, memo: nil,
                                action: nil, favorite: false, pin: false, notes: []
                            ),
                            page: $currentPage5,
                            onCardTapped: { print("Card tapped - Case 5") }
                        )
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color("Background"))
            .navigationTitle("명함 케이스 테스트")
        }
    }
    
    return NavigationView {
        TestView()
    }
}

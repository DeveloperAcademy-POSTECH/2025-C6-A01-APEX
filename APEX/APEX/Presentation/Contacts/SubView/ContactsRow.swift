import SwiftUI

/// 연락처 리스트의 한 행(공통) - 플랫 스타일
/// 기본 배경: Background, 눌림 시: BackgroundHover로 자연스럽게 전환
struct ContactsRow: View {
    let client: Client
    var onToggleFavorite: (() -> Void)?
    var onDelete: (() -> Void)?
    var onTap: (() -> Void)?

    // 새로 추가: 행 높이/부제 오버라이드
    var rowHeight: CGFloat?
    var subtitleOverride: String?

    // Style tokens
    private enum Metrics {
        static let cellHeight: CGFloat = 64
        static let avatarSize: CGFloat = 48
        static let textBoxHeight: CGFloat = 38
        static let hStackSpacing: CGFloat = 12
        static let nameSubtitleSpacing: CGFloat = 2
        static let contentHorizontalPadding: CGFloat = 16
        static let trailingSpacerMin: CGFloat = 8
    }

    // 임시 디폴트(직책 없음 표시)
    private static let placeholderSubtitle = "Designer"

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .center, spacing: Metrics.hStackSpacing) {
                avatar

                VStack(alignment: .leading, spacing: Metrics.nameSubtitleSpacing) {
                    Text(fullName)
                        .font(.body2)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.body6)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .frame(height: Metrics.textBoxHeight)
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: Metrics.trailingSpacerMin)
            }
            .padding(.horizontal, Metrics.contentHorizontalPadding)
            .frame(height: rowHeight ?? Metrics.cellHeight)
            // label 내부 contentShape는 제거(중복 방지)
        }
        // 기본 Background, 눌림 시 BackgroundHover로 자연스럽게 전환
        .buttonStyle(BackgroundHoverRowStyle())
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle()) // 터치 영역 명확화(외부 한 곳만 유지)
        // 좌측 스와이프: 즐겨찾기 토글
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if let onToggleFavorite {
                Button {
                    onToggleFavorite()
                } label: {
                    Image(systemName: client.favorite ? "star.slash" : "star")
                }
                .tint(Color("Primary"))
            }
        }
        // 우측 스와이프: 삭제
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .tint(Color("Error"))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(fullName), \(subtitle)")
        .accessibilityAddTraits(.isButton) // 행이 버튼 역할임을 명확히
    }

    private var fullName: String {
        let trimmedName = client.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSurname = client.surname.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let components = [trimmedName, trimmedSurname].filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }

    private var subtitle: String {
        if let override = subtitleOverride, !override.isEmpty {
            return override
        }
        let trimmed = client.position?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = trimmed, !value.isEmpty {
            return value
        } else {
            return Self.placeholderSubtitle
        }
    }

    private var avatar: some View {
        Group {
            if let uiImage = client.profile {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
            } else {
                let initials = Profile.makeInitials(name: client.name, surname: client.surname)
                ZStack {
                    Circle()
                        .fill(Color("PrimaryContainer"))
                    Text(initials)
                        .font(.system(size: 30.72, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: Metrics.avatarSize, height: Metrics.avatarSize)
        .clipShape(Circle())
    }
}

// MARK: - ButtonStyle: Background ↔ BackgroundHover 전환(자연스러운 눌림 감)

// makeInitials moved to common component: Profile.makeInitials

private struct BackgroundHoverRowStyle: ButtonStyle {
    // 컬러 자산(프로젝트에 존재하는 키 사용)
    private let normal = Color("Background")
    private let pressed = Color("BackgroundHover")

    // 미세한 눌림 감(과하지 않게)
    private let pressedBrightness: CGFloat = -0.015
    private let pressedScale: CGFloat = 0.997
    private let duration: Double = 0.12

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        return configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                shape.fill(isPressed ? pressed : normal)
            )
            .brightness(isPressed ? pressedBrightness : 0)
            .scaleEffect(isPressed ? pressedScale : 1.0)
            .animation(.easeInOut(duration: duration), value: isPressed)
    }
}

#Preview {
    struct TestView: View {
        // 다양한 이름/성 조합 테스트 케이스들
        let testCases: [(name: String, surname: String, description: String)] = [
            ("John", "Doe", "정상 케이스"),
            ("", "Smith", "이름 없음"),
            ("Jane", "", "성 없음"),
            ("", "", "둘 다 없음"),
            ("   ", "Brown", "이름이 공백만"),
            ("Mike", "   ", "성이 공백만"),
            ("   ", "   ", "둘 다 공백만"),
            ("Very Long Name", "Very Long Surname", "긴 이름"),
            ("A", "B", "짧은 이름")
        ]
        
        var body: some View {
            NavigationView {
                List {
                    ForEach(Array(testCases.enumerated()), id: \.offset) { index, testCase in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(testCase.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                            
                            ContactsRow(
                                client: Client(
                                    profile: nil,
                                    nameCardFront: nil,
                                    nameCardBack: nil,
                                    surname: testCase.surname,
                                    name: testCase.name,
                                    position: "Test Position",
                                    company: "Test Company",
                                    email: "test@example.com",
                                    phoneNumber: "010-1234-5678",
                                    linkedinURL: nil,
                                    memo: nil,
                                    action: nil,
                                    favorite: false,
                                    pin: false,
                                    notes: []
                                ),
                                onToggleFavorite: { print("Toggle favorite: \(testCase.description)") },
                                onDelete: { print("Delete: \(testCase.description)") },
                                onTap: { print("Tap: \(testCase.description)") }
                            )
                        }
                        .background(Color("Background"))
                    }
                }
                .listStyle(.plain)
                .navigationTitle("ContactsRow 테스트")
                .background(Color("Background"))
            }
        }
    }
    
    return TestView()
}

//
//  MyProfileModals.swift
//  APEX
//
//  Created by AI Assistant on 10/27/25.
//

import SwiftUI

// MARK: - Card Viewer

struct CardViewer: View {
    let images: [Image]
    let onClose: () -> Void
    @State private var currentIndex = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // 닫기 버튼
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 16)
                }
                
                Spacer()
                
                // 명함 이미지들
                TabView(selection: $currentIndex) {
                    ForEach(images.indices, id: \.self) { index in
                        images[index]
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                Spacer()
                
                // 페이지 인디케이터 (수동으로 추가, 더 명확한 표시를 위해)
                if images.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(images.indices, id: \.self) { index in
                            Circle()
                                .fill(currentIndex == index ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Edit Sheet

struct MyProfileEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    // 원본
    let client: DummyClient

    // 편집 상태
    @State private var profileUIImage: UIImage?
    @State private var cardFrontUIImage: UIImage?
    @State private var cardBackUIImage: UIImage?

    @State private var surname: String
    @State private var name: String
    @State private var company: String
    @State private var position: String
    @State private var email: String
    @State private var phone: String
    @State private var linkedin: String
    @State private var memo: String

    // Photo picker
    @State private var presentedPhotoType: PhotoAddView.PhotoType?

    var onCancel: () -> Void
    var onSave: (DummyClient) -> Void

    init(client: DummyClient, onCancel: @escaping () -> Void, onSave: @escaping (DummyClient) -> Void) {
        self.client = client
        self.onCancel = onCancel
        self.onSave = onSave

        _profileUIImage = State(initialValue: client.profile)
        _cardFrontUIImage = State(initialValue: client.nameCardFront?.asUIImage())
        _cardBackUIImage = State(initialValue: client.nameCardBack?.asUIImage())

        _surname = State(initialValue: client.surname)
        _name = State(initialValue: client.name)
        _company = State(initialValue: client.company)
        _position = State(initialValue: client.position ?? "")
        _email = State(initialValue: client.email ?? "")
        _phone = State(initialValue: client.phoneNumber ?? "")
        _linkedin = State(initialValue: client.linkedinURL ?? "")
        _memo = State(initialValue: client.memo ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button { onCancel(); dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.title4)
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("편집")
                    .font(.title3)
                    .foregroundColor(.black)
                Spacer()
                Button {
                    let updated = DummyClient(
                        profile: profileUIImage,
                        nameCardFront: cardFrontUIImage.map { Image(uiImage: $0) },
                        nameCardBack: cardBackUIImage.map { Image(uiImage: $0) },
                        surname: surname,
                        name: name,
                        position: position.isEmpty ? nil : position,
                        company: company,
                        email: email.isEmpty ? nil : email,
                        phoneNumber: phone.isEmpty ? nil : phone,
                        linkedinURL: linkedin.isEmpty ? nil : linkedin,
                        memo: memo.isEmpty ? nil : memo,
                        action: client.action,
                        favorite: client.favorite,
                        pin: client.pin,
                        notes: client.notes
                    )
                    onSave(updated)
                    dismiss()
                } label: {
                    Text("완료")
                        .font(.title6)
                        .frame(width: 52, height: 44)
                        .background(
                            Capsule()
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(Color("Background"))

            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Image pickers
                    HStack(spacing: 16) {
                        Button {
                            presentedPhotoType = .profile
                        } label: {
                            VStack(spacing: 8) {
                                Profile(
                                    image: profileUIImage,
                                    initials: Profile.makeInitials(name: name, surname: surname),
                                    size: .medium,
                                    fontSize: 42
                                )
                                Text("프로필").font(.body6).foregroundColor(.gray)
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            presentedPhotoType = .card
                        } label: {
                            VStack(spacing: 8) {
                                if let img = cardFrontUIImage ?? cardBackUIImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Image("CardS")
                                }
                                Text("명함").font(.body6).foregroundColor(.gray)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // Fields
                    Group {
                        APEXTextField(style: .field, placeholder: "성", text: $surname)
                        APEXTextField(style: .field, placeholder: "이름", text: $name)
                        APEXTextField(style: .field, placeholder: "회사", text: $company)
                        APEXTextField(style: .field, placeholder: "직책", text: $position)
                        APEXTextField(style: .field, placeholder: "이메일", text: $email)
                        ContactsField(phone: $phone, placeholder: "전화번호", isRegionInteractive: true)
                        APEXTextField(style: .field, placeholder: "링크드인 URL", text: $linkedin)
                        APEXTextField(style: .editor, label: "메모", placeholder: "메모 입력", text: $memo, maxLength: 100)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 24)
            }
        }
        .sheet(item: $presentedPhotoType) { t in
            PhotoAddView(
                type: t,
                onCroppedProfile: { profileUIImage = $0 },
                onCroppedCard: { img, isFront in
                    if isFront { cardFrontUIImage = img } else { cardBackUIImage = img }
                },
                initialProfile: profileUIImage,
                initialFront: cardFrontUIImage,
                initialBack: cardBackUIImage
            )
            .padding(.top, 30)
        }
        .background(Color("Background"))
    }
}

// MARK: - Helpers

private extension Image {
    func asUIImage() -> UIImage? { nil }
}

// makeInitials moved to common component: Profile.makeInitials

// MARK: - Previews

#Preview("Card Viewer") {
    CardViewer(
        images: [
            Image("CardL"),
            Image("CardL")
        ],
        onClose: { print("Close tapped") }
    )
}

#Preview("Edit Sheet") {
    MyProfileEditSheet(
        client: sampleMyProfileClient,
        onCancel: { print("Cancel tapped") },
        onSave: { _ in print("Save tapped") }
    )
}

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
    
    // AddItem 관련 상태  
    @State private var isAddItemPresented: Bool = false
    @State private var addItemConfig: AddItemConfig = .default
    
    // 삭제 확인 모달 상태
    @State private var showDeleteDialog: Bool = false
    @State private var isDeleteConfirmed: Bool = false

    var onCancel: () -> Void
    var onSave: (DummyClient) -> Void
    var onDelete: (() -> Void)? = nil  // 삭제 콜백 추가
    var showDeleteButton: Bool = false  // 삭제 버튼 표시 여부

    init(client: DummyClient, onCancel: @escaping () -> Void, onSave: @escaping (DummyClient) -> Void, onDelete: (() -> Void)? = nil, showDeleteButton: Bool = false) {
        self.client = client
        self.onCancel = onCancel
        self.onSave = onSave
        self.onDelete = onDelete
        self.showDeleteButton = showDeleteButton

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
        ZStack {
            mainContent
            if showDeleteDialog {
                deleteOverlay
            }
        }
        .background(Color("Background"))
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack {
                // Image pickers (ProfileAddView 스타일로 변경)
                HStack {
                    Button {
                        presentedPhotoType = .profile
                    } label: {
                        VStack(spacing: 10) {
                            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            let trimmedSurname = surname.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let image = profileUIImage {
                                Profile(
                                    image: image,
                                    initials: Profile.makeInitials(name: trimmedName, surname: trimmedSurname),
                                    size: .small,
                                    fontSize: 64
                                )
                            } else if trimmedName.isEmpty && trimmedSurname.isEmpty {
                                Image("ProfileS")
                            } else {
                                Profile(
                                    image: nil,
                                    initials: Profile.makeInitials(name: trimmedName, surname: trimmedSurname),
                                    size: .small,
                                    fontSize: 64
                                )
                            }
                            Text("프로필")
                                .font(.body5)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button {
                        presentedPhotoType = .card
                    } label: {
                        VStack(spacing: 13) {
                            if let ui = cardFrontUIImage {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 154, height: 92)
                                    .cornerRadius(4)
                            } else if let existing = client.nameCardFront {
                                existing
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 154, height: 92)
                                    .cornerRadius(4)
                            } else {
                                Image("CardS")
                            }
                            Text("명함")
                                .font(.body5)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 48)
                
                // 이름 필드들
                APEXTextField(style: .field, placeholder: "성", text: $surname)
                    .padding(.bottom, 8)
                APEXTextField(style: .field, placeholder: "이름", text: $name)
                    .padding(.bottom, 48)
                
                // 회사 정보 필드들
                APEXTextField(style: .field, placeholder: "회사", text: $company)
                    .padding(.bottom, 8)
                APEXTextField(style: .field, placeholder: "직책", text: $position)
                    .padding(.bottom, 48)
                
                // 연락처 정보 필드들
                APEXTextField(style: .field, placeholder: "이메일", text: $email)
                    .padding(.bottom, 8)
                ContactsField(phone: $phone, placeholder: "연락처", isRegionInteractive: true)
                    .padding(.bottom, 8)
                APEXTextField(style: .field, placeholder: "링크드인 URL", text: $linkedin)
                    .padding(.bottom, 48)
                
                // 메모 필드
                APEXTextField(style: .editor, label: "메모", placeholder: "주요 대화", text: $memo, maxLength: 100)
                    .padding(.bottom, 48)
                
                // 항목 수정하기 버튼
                AddItemButton {
                    isAddItemPresented = true
                }
                .padding(.bottom, showDeleteButton ? 12 : 16)
                
                // 연락처 삭제하기 버튼 (ProfileDetailView에서만)
                if showDeleteButton {
                    DeleteContactButton {
                        showDeleteConfirmation()
                    }
                    .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, 24)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .sheet(item: $presentedPhotoType) { sheetType in
            PhotoAddView(
                type: sheetType,
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
        .sheet(isPresented: $isAddItemPresented) {
            AddItemView(config: $addItemConfig)
                .padding(.top, 30)
        }
        .safeAreaBar(edge: .top) {
            APEXSheetTopBar(
                title: "프로필 편집",
                rightTitle: "완료",
                isRightEnabled: true,
                onRightTap: {
                    let updated = DummyClient(
                        profile: profileUIImage,
                        nameCardFront: (cardFrontUIImage.map { Image(uiImage: $0) }) ?? client.nameCardFront,
                        nameCardBack: (cardBackUIImage.map { Image(uiImage: $0) }) ?? client.nameCardBack,
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
                },
                onClose: {
                    onCancel()
                    dismiss()
                }
            )
            .padding(.top, 10)
        }
    }
    
    // MARK: - Delete Overlay
    
    private var deleteOverlay: some View {
        EditSheetOverlayLayer(
            isVisible: $showDeleteDialog,
            isChecked: $isDeleteConfirmed,
            clientName: NameFormatter.autoFormat(name: name, surname: surname),
            onConfirmDelete: executeDelete
        )
        .transition(.asymmetric(
            insertion: .scale(scale: 0.98).combined(with: .opacity),
            removal: .opacity
        ))
        .zIndex(10)
        .compositingGroup()
    }
    
    // MARK: - Delete Actions
    
    private func showDeleteConfirmation() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showDeleteDialog = true
        }
    }
    
    private func executeDelete() {
        onDelete?()
        showDeleteDialog = false
        isDeleteConfirmed = false
        dismiss()
    }
}

// MARK: - Helpers

private extension Image {
    func asUIImage() -> UIImage? {
        // Render the SwiftUI Image into a UIImage for use in pickers/croppers
        let targetSize = CGSize(width: 358, height: 214)
        let rendered = ImageRenderer(
            content: self
                .resizable()
                .scaledToFit()
                .frame(width: targetSize.width, height: targetSize.height)
        )
        rendered.scale = UIScreen.main.scale
        return rendered.uiImage
    }
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

// MARK: - Add Item Button

private struct AddItemButton: View {
    let action: () -> Void
    @State private var isPressed: Bool = false
    
    // 색상 정의
    private let normalBackground = Color(red: 0xEE/255.0, green: 0xF0/255.0, blue: 0xF5/255.0) // #EEF0F5
    private let pressedBackground = Color(red: 0xED/255.0, green: 0xF0/255.0, blue: 1.0) // #EDF0FF
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Color("Primary"))
                Text("항목 수정하기")
                    .font(.body2)
                    .foregroundColor(Color("Primary"))
            }
            .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56)
            .background(isPressed ? pressedBackground : normalBackground)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.12)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.12)) { isPressed = false }
                }
        )
    }
}

// MARK: - Delete Contact Button

private struct DeleteContactButton: View {
    let action: () -> Void
    @State private var isPressed: Bool = false
    
    // 색상 정의
    private let normalBackground = Color(red: 1.0, green: 0xF6/255.0, blue: 0xF5/255.0) // #FFF6F5
    private let pressedBackground = Color(red: 1.0, green: 0xE8/255.0, blue: 0xE5/255.0) // #FFE8E5
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(Color.red)
                Text("연락처 삭제하기")
                    .font(.body2)
                    .foregroundColor(Color.red)
            }
            .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56)
            .background(isPressed ? pressedBackground : normalBackground)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.12)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.12)) { isPressed = false }
                }
        )
    }
}

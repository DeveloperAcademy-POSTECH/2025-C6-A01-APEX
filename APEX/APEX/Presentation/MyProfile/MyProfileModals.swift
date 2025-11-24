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
                .tabViewStyle(.page(indexDisplayMode: .never))
                
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
    @State private var department: String
    @State private var position: String
    @State private var email: String
    @State private var phone: String
    @State private var linkedin: String
    @State private var memo: String
    
    // 추가 정보 필드들
    @State private var industry: String
    @State private var address: String
    @State private var faxNumber: String
    @State private var revenue: String
    @State private var employees: String
    
    // 동적 항목 배열 (추가 이메일/연락처/URL 포함)
    @State private var emails: [String]
    @State private var contacts: [String]
    @State private var urls: [String]

    // Photo picker
    @State private var presentedPhotoType: PhotoAddView.PhotoType?
    
    // AddItem 관련 상태  
    @State private var isAddItemPresented: Bool = false
    @State private var addItemConfig: AddItemConfig
    
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
        _department = State(initialValue: client.department ?? "")
        _position = State(initialValue: client.position ?? "")
        _email = State(initialValue: client.email ?? "")
        _phone = State(initialValue: client.phoneNumber ?? "")
        _linkedin = State(initialValue: client.linkedinURL ?? "")
        _memo = State(initialValue: client.memo ?? "")
        
        // 추가 정보 초기값
        _industry = State(initialValue: client.industry ?? "")
        _address = State(initialValue: client.address ?? "")
        _faxNumber = State(initialValue: client.faxNumber ?? "")
        _revenue = State(initialValue: client.revenue ?? "")
        _employees = State(initialValue: client.employees ?? "")
        
        // 동적 배열 초기값 (항상 최소 1칸 보장)
        let initialEmails: [String] = {
            var arr: [String] = [client.email ?? ""]
            arr.append(contentsOf: client.additionalEmails)
            return arr
        }()
        let initialContacts: [String] = {
            var arr: [String] = [client.phoneNumber ?? ""]
            arr.append(contentsOf: client.additionalPhones)
            return arr
        }()
        let initialURLs: [String] = client.additionalURLs
        _emails = State(initialValue: initialEmails)
        _contacts = State(initialValue: initialContacts)
        _urls = State(initialValue: initialURLs)
        
        // 편집 시트의 항목 구성은 기존 데이터 기반으로 설정
        let hasPrimaryEmail = !(client.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPrimaryPhone = !(client.phoneNumber ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let emailCount = max(1, (hasPrimaryEmail ? 1 : 0) + client.additionalEmails.count)
        let phoneCount = max(1, (hasPrimaryPhone ? 1 : 0) + client.additionalPhones.count)
        let urlCount = client.additionalURLs.count
        let showsLinkedIn = !(client.linkedinURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let showsIndustry = !(client.industry ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let showsAddress = !(client.address ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let showsFax = !(client.faxNumber ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let showsRevenue = !(client.revenue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let showsEmployees = !(client.employees ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        _addItemConfig = State(initialValue: AddItemConfig(
            items: AddItemConfig.default.items,
            emailCount: emailCount,
            phoneCount: phoneCount,
            urlCount: urlCount,
            showsLinkedIn: showsLinkedIn,
            showsIndustry: showsIndustry,
            showsAddress: showsAddress,
            showsFax: showsFax,
            showsRevenue: showsRevenue,
            showsEmployees: showsEmployees
        ))
    }

    var body: some View {
        ZStack {
            mainContent
            if showDeleteDialog {
                deleteOverlay
            }
        }
        .background(Color("Background"))
        .onAppear { ensureFieldArrays() }
        .onChange(of: addItemConfig.emailCount) { _ in ensureFieldArrays() }
        .onChange(of: addItemConfig.phoneCount) { _ in ensureFieldArrays() }
        .onChange(of: addItemConfig.urlCount) { _ in ensureFieldArrays() }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack {
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
                                    size: .small
                                )
                            } else if trimmedName.isEmpty && trimmedSurname.isEmpty {
                                Image("ProfileS")
                            } else {
                                Profile(
                                    image: nil,
                                    initials: Profile.makeInitials(name: trimmedName, surname: trimmedSurname),
                                    size: .small
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
                APEXTextField(style: .field, placeholder: "부서", text: $department)
                    .padding(.bottom, 8)
                APEXTextField(style: .field, placeholder: "직책", text: $position)
                    .padding(.bottom, 48)
                
                // 연락처/URL 그룹
                contactInfoGroup
                
                // 추가 회사 정보
                if addItemConfig.showsIndustry {
                    APEXTextField(style: .field, placeholder: "회사 업종", text: $industry)
                        .padding(.bottom, 8)
                }
                if addItemConfig.showsAddress {
                    APEXTextField(style: .field, placeholder: "주소", text: $address)
                        .padding(.bottom, 8)
                }
                if addItemConfig.showsFax {
                    APEXTextField(style: .field, placeholder: "팩스번호", text: $faxNumber)
                        .padding(.bottom, 8)
                }
                if addItemConfig.showsRevenue {
                    APEXTextField(style: .field, placeholder: "연매출", text: $revenue)
                        .padding(.bottom, 8)
                }
                if addItemConfig.showsEmployees {
                    APEXTextField(style: .field, placeholder: "근무 인원", text: $employees)
                        .padding(.bottom, 48)
                } else {
                    // 연락처 그룹 후 기본 간격 유지
                    Spacer(minLength: 0).frame(height: 16)
                }
                
                // 메모 필드
                APEXTextField(style: .editor, label: "메모", placeholder: "주요 대화", text: $memo, maxLength: 100)
                    .padding(.bottom, 48)
                
                // 항목 수정하기 버튼
                AddItemButton {
                    isAddItemPresented = true
                }
                .padding(.bottom, showDeleteButton ? 8 : 12)
                
                // 연락처 삭제하기 버튼 (ProfileDetailView에서만)
                if showDeleteButton {
                    DeleteContactButton {
                        showDeleteConfirmation()
                    }
                    .padding(.bottom, 12)
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
        }
        .sheet(isPresented: $isAddItemPresented) {
            AddItemView(config: $addItemConfig)
        }
        .safeAreaBar(edge: .top) {
            APEXSheetTopBar(
                title: "프로필 편집",
                rightTitle: "완료",
                isRightEnabled: true,
                onRightTap: {
                    // 저장용 값 정리
                    let trimmedEmails = emails.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    let primaryEmail = trimmedEmails.first ?? ""
                    let savedEmail: String? = primaryEmail.isEmpty ? nil : primaryEmail
                    let savedAdditionalEmails: [String] = Array(trimmedEmails.dropFirst()).filter { !$0.isEmpty }
                    
                    let trimmedContacts = contacts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    let primaryPhone = trimmedContacts.first ?? ""
                    let savedPhone: String? = primaryPhone.isEmpty ? nil : primaryPhone
                    let savedAdditionalPhones: [String] = Array(trimmedContacts.dropFirst()).filter { !$0.isEmpty }
                    
                    let savedLinkedIn: String? = {
                        if addItemConfig.showsLinkedIn {
                            let v = linkedin.trimmingCharacters(in: .whitespacesAndNewlines)
                            return v.isEmpty ? nil : v
                        } else {
                            return nil
                        }
                    }()
                    
                    let savedURLs: [String] = urls.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    
                    let savedIndustry: String? = {
                        guard addItemConfig.showsIndustry else { return nil }
                        let v = industry.trimmingCharacters(in: .whitespacesAndNewlines)
                        return v.isEmpty ? nil : v
                    }()
                    let savedAddress: String? = {
                        guard addItemConfig.showsAddress else { return nil }
                        let v = address.trimmingCharacters(in: .whitespacesAndNewlines)
                        return v.isEmpty ? nil : v
                    }()
                    let savedFax: String? = {
                        guard addItemConfig.showsFax else { return nil }
                        let v = faxNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                        return v.isEmpty ? nil : v
                    }()
                    let savedRevenue: String? = {
                        guard addItemConfig.showsRevenue else { return nil }
                        let v = revenue.trimmingCharacters(in: .whitespacesAndNewlines)
                        return v.isEmpty ? nil : v
                    }()
                    let savedEmployees: String? = {
                        guard addItemConfig.showsEmployees else { return nil }
                        let v = employees.trimmingCharacters(in: .whitespacesAndNewlines)
                        return v.isEmpty ? nil : v
                    }()
                    
                    let updated = DummyClient(
                        profile: profileUIImage ?? client.profile,
                        nameCardFront: (cardFrontUIImage.map { Image(uiImage: $0) }) ?? client.nameCardFront,
                        nameCardBack: (cardBackUIImage.map { Image(uiImage: $0) }) ?? client.nameCardBack,
                        surname: surname,
                        name: name,
                        position: position.isEmpty ? nil : position,
                        company: company,
                        department: department.isEmpty ? nil : department,
                        email: savedEmail,
                        phoneNumber: savedPhone,
                        linkedinURL: savedLinkedIn,
                        memo: memo.isEmpty ? nil : memo,
                        action: client.action,
                        favorite: client.favorite,
                        pin: client.pin,
                        notes: client.notes,
                        industry: savedIndustry,
                        address: savedAddress,
                        faxNumber: savedFax,
                        revenue: savedRevenue,
                        employees: savedEmployees,
                        additionalEmails: savedAdditionalEmails,
                        additionalPhones: savedAdditionalPhones,
                        additionalURLs: savedURLs
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
private extension MyProfileEditSheet {
    // 연락처/URL 그룹 (편집 시트 버전)
    @ViewBuilder
    var contactInfoGroup: some View {
        let totalBlockCount = addItemConfig.emailCount
            + addItemConfig.phoneCount
            + (addItemConfig.showsLinkedIn ? 1 : 0)
            + addItemConfig.urlCount
        
        if addItemConfig.emailCount > 0 {
            ForEach(0..<addItemConfig.emailCount, id: \.self) { idx in
                APEXTextField(
                    style: .field,
                    placeholder: emailPlaceholder(for: idx),
                    text: emailBinding(index: idx)
                )
                .padding(.bottom, bottomPaddingForGroup(globalIndex: idx, total: totalBlockCount))
            }
        }
        
        if addItemConfig.phoneCount > 0 {
            ForEach(0..<addItemConfig.phoneCount, id: \.self) { idx in
                ContactsField(
                    phone: contactBinding(index: idx),
                    placeholder: phonePlaceholder(for: idx),
                    isRegionInteractive: true
                )
                .padding(.bottom, bottomPaddingForGroup(globalIndex: addItemConfig.emailCount + idx, total: totalBlockCount))
            }
        }
        
        if addItemConfig.showsLinkedIn {
            APEXTextField(style: .field, placeholder: "링크드인 URL", text: $linkedin)
                .padding(
                    .bottom,
                    bottomPaddingForGroup(
                        globalIndex: addItemConfig.emailCount + addItemConfig.phoneCount,
                        total: totalBlockCount
                    )
                )
        }
        
        if addItemConfig.urlCount > 0 {
            ForEach(0..<addItemConfig.urlCount, id: \.self) { idx in
                APEXTextField(
                    style: .field,
                    placeholder: "URL \(idx + 1)",
                    text: urlBinding(index: idx)
                )
                .padding(
                    .bottom,
                    bottomPaddingForGroup(
                        globalIndex: addItemConfig.emailCount + addItemConfig.phoneCount + (addItemConfig.showsLinkedIn ? 1 : 0) + idx,
                        total: totalBlockCount
                    )
                )
            }
        }
    }
    
    private func ensureFieldArrays() {
        // 이메일 배열 길이 보정
        if emails.count < addItemConfig.emailCount {
            emails.append(contentsOf: Array(repeating: "", count: addItemConfig.emailCount - emails.count))
        } else if emails.count > addItemConfig.emailCount {
            emails = Array(emails.prefix(addItemConfig.emailCount))
        }
        // 연락처 배열 길이 보정
        if contacts.count < addItemConfig.phoneCount {
            contacts.append(contentsOf: Array(repeating: "", count: addItemConfig.phoneCount - contacts.count))
        } else if contacts.count > addItemConfig.phoneCount {
            contacts = Array(contacts.prefix(addItemConfig.phoneCount))
        }
        // URL 배열 길이 보정
        if urls.count < addItemConfig.urlCount {
            urls.append(contentsOf: Array(repeating: "", count: addItemConfig.urlCount - urls.count))
        } else if urls.count > addItemConfig.urlCount {
            urls = Array(urls.prefix(addItemConfig.urlCount))
        }
    }
    
    private func emailBinding(index: Int) -> Binding<String> {
        Binding<String>(
            get: { emails.indices.contains(index) ? emails[index] : "" },
            set: { value in
                if emails.indices.contains(index) { emails[index] = value }
            }
        )
    }
    
    private func contactBinding(index: Int) -> Binding<String> {
        Binding<String>(
            get: { contacts.indices.contains(index) ? contacts[index] : "" },
            set: { value in
                if contacts.indices.contains(index) { contacts[index] = value }
            }
        )
    }
    
    private func urlBinding(index: Int) -> Binding<String> {
        Binding<String>(
            get: { urls.indices.contains(index) ? urls[index] : "" },
            set: { value in
                if urls.indices.contains(index) { urls[index] = value }
            }
        )
    }
    
    private func bottomPaddingForGroup(globalIndex: Int, total: Int) -> CGFloat {
        return (globalIndex == total - 1) ? 40 : 8
    }
    
    private func emailPlaceholder(for index: Int) -> String {
        return addItemConfig.emailCount == 1 ? "이메일" : "이메일 \(index + 1)"
    }
    
    private func phonePlaceholder(for index: Int) -> String {
        return addItemConfig.phoneCount == 1 ? "연락처" : "연락처 \(index + 1)"
    }
}

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
                Image(systemName: "trash.fill")
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

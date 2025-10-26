//
//  ProfileAddView.swift
//  APEX
//
//  Created by 조운경 on 10/8/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ProfileAddView: View {
    @Environment(\.dismiss) private var dismiss
    
    var onComplete: ((Client) -> Void)? = nil
    @State private var profileUIImage: UIImage? = nil
    @State private var cardFrontUIImage: UIImage? = nil
    @State private var cardBackUIImage: UIImage? = nil
    @State private var presentedPhotoType: PhotoAddView.PhotoType?
    @State private var isAddItemPresented: Bool = false
    @State private var addItemConfig: AddItemConfig = .default
    @State private var surname: String = ""
    @State private var name: String = ""
    @State private var company: String = ""
    @State private var department: String = ""
    @State private var position: String = ""
    @State private var emails: [String] = []
    @State private var contacts: [String] = []
    @State private var urls: [String] = []
    @State private var linkedinLink: String = ""
    @State private var industry: String = ""
    @State private var address: String = ""
    @State private var faxNumber: String = ""
    @State private var revenue: String = ""
    @State private var employees: String = ""
    @State private var memo: String = ""
    
    var body: some View {
        ScrollView {
            VStack {
                HStack {
                    Button {
                        presentedPhotoType = .profile
                    } label: {
                        VStack(spacing: 10) {
                            if let image = profileUIImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                            } else {
                                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                                let trimmedSurname = surname.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmedName.isEmpty && trimmedSurname.isEmpty {
                                    Image("ProfileS")
                                } else {
                                    let initials = makeInitials(name: trimmedName, surname: trimmedSurname)
                                    InitialAvatar(
                                        letter: initials,
                                        size: 100,
                                        fontSize: 64
                                    )
                                }
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
                            if let image = cardFrontUIImage {
                                Image(uiImage: image)
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
                
                APEXTextField(style: .field, placeholder: "성", text: $surname)
                    .padding(.bottom, 8)
                APEXTextField(style: .field, placeholder: "이름", text: $name)
                    .padding(.bottom, 48)
                
                APEXTextField(style: .field, placeholder: "회사", text: $company)
                    .padding(.bottom, 8)
                APEXTextField(style: .field, placeholder: "부서", text: $department)
                    .padding(.bottom, 8)
                APEXTextField(style: .field, placeholder: "직책", text: $position)
                    .padding(.bottom, 48)
                
                
                contactInfoGroup
                // Remove extra group padding; per-row bottom padding now controls spacing

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
                }
                
                if isFieldEnabled(.memo) {
                    APEXTextField(style: .editor, label: "메모", placeholder: "주요 대화", text: $memo, maxLength: 100)
                        .padding(.bottom, 48)
                }
                
                Button {
                    isAddItemPresented = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color("Primary"))
                        Text("항목 수정하기")
                            .font(.body2)
                            .foregroundColor(Color("Primary"))
                    }
                    .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56)
                    .background(Color("PrimaryContainer"))
                    .cornerRadius(4)
                }
                .padding(.vertical, 16)
            }
            .padding(.horizontal, 24)
        }
        .scrollEdgeEffectStyle(.hard, for: .all)
        .sheet(item: $presentedPhotoType) { sheetType in
            PhotoAddView(
                type: sheetType,
                onCroppedProfile: { uiImage in
                    profileUIImage = uiImage
                },
                onCroppedCard: { uiImage, isFront in
                    if isFront { cardFrontUIImage = uiImage } else { cardBackUIImage = uiImage }
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
        .safeAreaInset(edge: .top) {
            APEXSheetTopBar(
                title: "연락처 추가",
                rightTitle: "완료",
                isRightEnabled: !surname
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty || !name
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty,
                onRightTap: {
                let client = Client(
                    profile: profileUIImage,
                    nameCardFront: cardFrontUIImage.map { Image(uiImage: $0) },
                    nameCardBack: cardBackUIImage.map { Image(uiImage: $0) },
                    surname: surname,
                    name: name,
                    position: position.isEmpty ? nil : position,
                    company: company,
                    email: emails.first,
                    phoneNumber: contacts.first,
                    linkedinURL: linkedinLink.isEmpty ? nil : linkedinLink,
                    memo: memo.isEmpty ? nil : memo,
                    action: nil,
                    favorite: false,
                    pin: false,
                    notes: []
                )
                onComplete?(client)
            }, onClose: {
                dismiss()
            })
        }
        .onAppear { ensureFieldArrays() }
        .onChange(of: addItemConfig.emailCount) { _ in ensureFieldArrays() }
        .onChange(of: addItemConfig.phoneCount) { _ in ensureFieldArrays() }
        .onChange(of: addItemConfig.urlCount) { _ in ensureFieldArrays() }
    }

    // MARK: - Helpers
    @ViewBuilder
    private var contactInfoGroup: some View {
        let totalBlockCount = addItemConfig.emailCount + addItemConfig.phoneCount + (addItemConfig.showsLinkedIn ? 1 : 0) + addItemConfig.urlCount

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
            APEXTextField(style: .field, placeholder: "링크드인 URL", text: $linkedinLink)
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

    private func isFieldEnabled(_ field: AddItemConfig.Field) -> Bool {
        // Required fields are always enabled; otherwise use toggled state
        if let item = addItemConfig.items.first(where: { $0.field == field }) {
            return item.isEnabled || item.isRequired
        }
        return true
    }

    private func ensureFieldArrays() {
        resize(&emails, to: addItemConfig.emailCount)
        resize(&contacts, to: addItemConfig.phoneCount)
        resize(&urls, to: addItemConfig.urlCount)
    }

    // Calculates per-row bottom padding within the first grouped block (emails, phones, LinkedIn, URLs)
    private func bottomPaddingForGroup(globalIndex: Int, total: Int) -> CGFloat {
        // If this is the last item in the group, use 40; otherwise 8
        return (globalIndex == total - 1) ? 40 : 8
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

    private func emailPlaceholder(for index: Int) -> String {
        return addItemConfig.emailCount == 1 ? "이메일" : "이메일 \(index + 1)"
    }

    private func phonePlaceholder(for index: Int) -> String {
        return addItemConfig.phoneCount == 1 ? "연락처" : "연락처 \(index + 1)"
    }

    private func resize(_ array: inout [String], to newCount: Int) {
        if newCount < 0 { return }
        if array.count < newCount {
            array.append(contentsOf: Array(repeating: "", count: newCount - array.count))
        } else if array.count > newCount {
            array = Array(array.prefix(newCount))
        }
    }
}

#Preview {
    ProfileAddView()
}

// MARK: - Initials helpers
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
        let scalarValue = scalar.value
        if (0xAC00...0xD7A3).contains(scalarValue) || (0x1100...0x11FF).contains(scalarValue) || (0x3130...0x318F).contains(scalarValue) {
            return true
        }
    }
    return false
}

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
    @StateObject private var viewModel = ProfileAddViewModel()
    
    var body: some View {
        ZStack {
            mainContent
        }
        .background(Color("Background"))
        .onAppear { viewModel.ensureFieldArrays() }
        .onChange(of: viewModel.addItemConfig.emailCount) { _ in viewModel.ensureFieldArrays() }
        .onChange(of: viewModel.addItemConfig.phoneCount) { _ in viewModel.ensureFieldArrays() }
        .onChange(of: viewModel.addItemConfig.urlCount) { _ in viewModel.ensureFieldArrays() }
    }

    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack {
                HStack {
                    /* 닫기 */
                    Button {
                        viewModel.send(.tapPhoto(.profile))
                    } label: {
                        VStack(spacing: 10) {
                            let trimmedName = viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines)
                            let trimmedSurname = viewModel.surname.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let image = viewModel.profileUIImage {
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
                        viewModel.send(.tapPhoto(.card))
                    } label: {
                        VStack(spacing: 13) {
                            if let image = (viewModel.cardFrontUIImage ?? viewModel.cardBackUIImage) {
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
                .padding(.top, 24)  // 원래대로 복구
                .padding(.bottom, 48)
                
                APEXTextField(style: .field, placeholder: "성", text: $viewModel.surname)
                    .padding(.bottom, 8)
                APEXTextField(style: .field, placeholder: "이름", text: $viewModel.name)
                    .padding(.bottom, 48)
                
                APEXTextField(style: .field, placeholder: "회사", text: $viewModel.company)
                    .padding(.bottom, 8)
                APEXTextField(style: .field, placeholder: "부서", text: $viewModel.department)
                    .padding(.bottom, 8)
                APEXTextField(style: .field, placeholder: "직책", text: $viewModel.position)
                    .padding(.bottom, 48)
                
                
                contactInfoGroup
                // Remove extra group padding; per-row bottom padding now controls spacing

                if viewModel.addItemConfig.showsIndustry {
                    APEXTextField(style: .field, placeholder: "회사 업종", text: $viewModel.industry)
                        .padding(.bottom, 8)
                }
                if viewModel.addItemConfig.showsAddress {
                    APEXTextField(style: .field, placeholder: "주소", text: $viewModel.address)
                        .padding(.bottom, 8)
                }
                if viewModel.addItemConfig.showsFax {
                    APEXTextField(style: .field, placeholder: "팩스번호", text: $viewModel.faxNumber)
                        .padding(.bottom, 8)
                }
                if viewModel.addItemConfig.showsRevenue {
                    APEXTextField(style: .field, placeholder: "연매출", text: $viewModel.revenue)
                        .padding(.bottom, 8)
                }
                if viewModel.addItemConfig.showsEmployees {
                    APEXTextField(style: .field, placeholder: "근무 인원", text: $viewModel.employees)
                        .padding(.bottom, 48)
                }
                
                if isFieldEnabled(.memo) {
                    APEXTextField(style: .editor, label: "메모", placeholder: "주요 대화", text: $viewModel.memo, maxLength: 100)
                        .padding(.bottom, 48)
                }
                
                Button {
                    viewModel.send(.presentAddItems(true))
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
        .scrollEdgeEffectStyle(.soft, for: .all)
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.apexDismissKeyboard()
            }
        )
        .sheet(item: $viewModel.presentedPhotoType) { sheetType in
            PhotoAddView(
                type: sheetType,
                onCroppedProfile: { uiImage in
                    viewModel.send(.setProfileImage(uiImage))
                },
                onCroppedCard: { uiImage, isFront in
                    viewModel.send(.setCardImage(uiImage, isFront: isFront))
                },
                initialProfile: viewModel.profileUIImage,
                initialFront: viewModel.cardFrontUIImage,
                initialBack: viewModel.cardBackUIImage
            )
            .padding(.top, 30)
        }
        .sheet(isPresented: $viewModel.isAddItemPresented) {
            AddItemView(config: $viewModel.addItemConfig)
                .padding(.top, 30)
        }
        .safeAreaBar(edge: .top) {
            APEXSheetTopBar(
                title: "연락처 추가",
                rightTitle: "완료",
                isRightEnabled: viewModel.isDoneEnabled,
                onRightTap: {
                let client = viewModel.makeClient()
                onComplete?(client)
            }, onClose: {
                dismiss()
            })
        }
        .onAppear { viewModel.send(.onAppear) }
        .onChange(of: viewModel.addItemConfig.emailCount) { _ in viewModel.ensureFieldArrays() }
        .onChange(of: viewModel.addItemConfig.phoneCount) { _ in viewModel.ensureFieldArrays() }
        .onChange(of: viewModel.addItemConfig.urlCount) { _ in viewModel.ensureFieldArrays() }
    }

    // MARK: - Helpers
    @ViewBuilder
    private var contactInfoGroup: some View {
        let totalBlockCount = viewModel.addItemConfig.emailCount + viewModel.addItemConfig.phoneCount + (viewModel.addItemConfig.showsLinkedIn ? 1 : 0) + viewModel.addItemConfig.urlCount

        if viewModel.addItemConfig.emailCount > 0 {
            ForEach(0..<viewModel.addItemConfig.emailCount, id: \.self) { idx in
                APEXTextField(
                    style: .field,
                    placeholder: emailPlaceholder(for: idx),
                    text: emailBinding(index: idx)
                )
                .padding(.bottom, bottomPaddingForGroup(globalIndex: idx, total: totalBlockCount))
            }
        }

        if viewModel.addItemConfig.phoneCount > 0 {
            ForEach(0..<viewModel.addItemConfig.phoneCount, id: \.self) { idx in
                ContactsField(
                    phone: contactBinding(index: idx),
                    placeholder: phonePlaceholder(for: idx),
                    isRegionInteractive: true
                )
                .padding(.bottom, bottomPaddingForGroup(globalIndex: viewModel.addItemConfig.emailCount + idx, total: totalBlockCount))
            }
        }

        if viewModel.addItemConfig.showsLinkedIn {
            APEXTextField(style: .field, placeholder: "링크드인 URL", text: $viewModel.linkedinLink)
                .padding(
                    .bottom,
                    bottomPaddingForGroup(
                        globalIndex: viewModel.addItemConfig.emailCount + viewModel.addItemConfig.phoneCount,
                        total: totalBlockCount
                    )
                )
        }

        if viewModel.addItemConfig.urlCount > 0 {
            ForEach(0..<viewModel.addItemConfig.urlCount, id: \.self) { idx in
                APEXTextField(
                    style: .field,
                    placeholder: "URL \(idx + 1)",
                    text: urlBinding(index: idx)
                )
                .padding(
                    .bottom,
                    bottomPaddingForGroup(
                        globalIndex: viewModel.addItemConfig.emailCount + viewModel.addItemConfig.phoneCount + (viewModel.addItemConfig.showsLinkedIn ? 1 : 0) + idx,
                        total: totalBlockCount
                    )
                )
            }
        }
    }

    private func isFieldEnabled(_ field: AddItemConfig.Field) -> Bool {
        // Required fields are always enabled; otherwise use toggled state
        if let item = viewModel.addItemConfig.items.first(where: { $0.field == field }) {
            return item.isEnabled || item.isRequired
        }
        return true
    }

    // Calculates per-row bottom padding within the first grouped block (emails, phones, LinkedIn, URLs)
    private func bottomPaddingForGroup(globalIndex: Int, total: Int) -> CGFloat {
        // If this is the last item in the group, use 40; otherwise 8
        return (globalIndex == total - 1) ? 40 : 8
    }

    private func emailBinding(index: Int) -> Binding<String> {
        Binding<String>(
            get: { viewModel.emails.indices.contains(index) ? viewModel.emails[index] : "" },
            set: { value in
                if viewModel.emails.indices.contains(index) { viewModel.emails[index] = value }
            }
        )
    }

    private func contactBinding(index: Int) -> Binding<String> {
        Binding<String>(
            get: { viewModel.contacts.indices.contains(index) ? viewModel.contacts[index] : "" },
            set: { value in
                if viewModel.contacts.indices.contains(index) { viewModel.contacts[index] = value }
            }
        )
    }

    private func urlBinding(index: Int) -> Binding<String> {
        Binding<String>(
            get: { viewModel.urls.indices.contains(index) ? viewModel.urls[index] : "" },
            set: { value in
                if viewModel.urls.indices.contains(index) { viewModel.urls[index] = value }
            }
        )
    }

    private func emailPlaceholder(for index: Int) -> String {
        return viewModel.addItemConfig.emailCount == 1 ? "이메일" : "이메일 \(index + 1)"
    }

    private func phonePlaceholder(for index: Int) -> String {
        return viewModel.addItemConfig.phoneCount == 1 ? "연락처" : "연락처 \(index + 1)"
    }
}


#Preview {
    ProfileAddView()
}

// makeInitials moved to common component: Profile.makeInitials


//
//  ContactsField.swift
//  APEX
//
//  Created by 조운경 on 10/17/25.
//

import SwiftUI

struct ContactsField: View {
    @Binding var phone: String

    var label: String
    var placeholder: String
    var isRequired: Bool
    var helper: String?
    var isRegionInteractive: Bool

    @State private var localText: String
    @State private var region: String
    @State private var isShowingPicker: Bool = false
    @Environment(\.apexTextFieldTheme) private var theme
    @State private var isPhoneValid: Bool?

    init(
        phone: Binding<String>,
        label: String = "전화번호",
        placeholder: String = "전화번호 입력",
        isRequired: Bool = true,
        helper: String? = nil,
        isRegionInteractive: Bool = true
    ) {
        self._phone = phone
        self._localText = State(initialValue: phone.wrappedValue)
        self._region = State(initialValue: PhoneNumberManager.shared.currentRegion)
        self.label = label
        self.placeholder = placeholder
        self.isRequired = isRequired
        self.helper = helper
        self.isRegionInteractive = isRegionInteractive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !label.isEmpty {
                HStack(spacing: 4) {
                    Text(label)
                        .font(theme.labelFont)
                        .foregroundColor(theme.labelColor)
                    if isRegionInteractive && isRequired {
                        Text("*")
                            .font(theme.labelFont.weight(.semibold))
                            .foregroundColor(theme.errorColor)
                    }
                }
            }

            HStack(spacing: 8) {
                if isRegionInteractive {
                    Button {
                        isShowingPicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Text(PhoneNumberManager.shared.dialCode(for: region) ?? "+")
                                .font(.body2)
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        .padding(.trailing, 4)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(UnderlineButtonStyle(normalColor: .gray, pressedColor: theme.lineFocused))
                } else {
                    Text(PhoneNumberManager.shared.dialCode(for: region) ?? "+")
                        .font(.body2)
                        .foregroundColor(.primary)
                        .padding(.trailing, 4)
                        .padding(.vertical, 9)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray)
                        }
                }

                if isRegionInteractive {
                    APEXTextField(
                        kind: .singleLine,
                        placeholder: placeholder,
                        text: $localText,
                        state: .normal(helper: nil),
                        isRequired: isRequired,
                        onEditingEndValidate: { text in
                            let valid = PhoneNumberManager.shared.isValid(text, region: region)
                            isPhoneValid = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : valid
                            return valid ? .success(message: nil) : .error(message: nil)
                        }
                    )
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .textInputAutocapitalization(.never)
                } else {
                    Text(localText)
                        .font(.body2)
                        .foregroundColor(.primary)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray)
                        }
                }
            }

            if !isRegionInteractive && localText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("전화번호가 필요합니다")
                    .font(theme.helperFont)
                    .foregroundColor(theme.errorColor)
                    .padding(.top, 4)
            } else if isPhoneValid == false {
                Text("전화번호 형식이 올바르지 않습니다")
                    .font(theme.helperFont)
                    .foregroundColor(theme.errorColor)
                    .padding(.top, 4)
            } else if let helper, !helper.isEmpty {
                Text(helper)
                    .font(theme.helperFont)
                    .foregroundColor(theme.helperColor)
                    .padding(.top, 4)
            }
        }
        .onChange(of: localText) { newValue in
            let formatted = PhoneNumberManager.shared.formatPartial(newValue, region: region)
            if formatted != newValue { localText = formatted }
            phone = formatted
            let trimmed = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                isPhoneValid = nil
            } else {
                isPhoneValid = PhoneNumberManager.shared.isValid(trimmed, region: region)
            }
        }
        .overlay(alignment: .leading) {
            // 외부 라벨 요구 시: 필요하면 여기서 좌측 상단 라벨 배치 가능
        }
        .onChange(of: region) { _ in
            let reformatted = PhoneNumberManager.shared.formatPartial(localText, region: region)
            if reformatted != localText { localText = reformatted }
            phone = reformatted
            let trimmed = reformatted.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                isPhoneValid = nil
            } else {
                isPhoneValid = PhoneNumberManager.shared.isValid(trimmed, region: region)
            }
        }
        .conditionalSheet(isPresented: $isShowingPicker, enabled: isRegionInteractive) {
            RegionPicker(selectedRegion: $region)
        }
    }
}

// MARK: - Private ButtonStyle
private struct UnderlineButtonStyle: ButtonStyle {
    var normalColor: Color
    var pressedColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(alignment: .bottom) {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(configuration.isPressed ? pressedColor : normalColor)
                    .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            }
    }
}

// MARK: - Conditional Sheet Helper
private extension View {
    @ViewBuilder
    func conditionalSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        enabled: Bool,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        if enabled {
            self.sheet(isPresented: isPresented, content: content)
        } else {
            self
        }
    }
}

private struct RegionPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedRegion: String
    @State private var query: String = ""

    private var allRegions: [String] { PhoneNumberManager.shared.allRegions() }

    // Filtering
    private var filteredAll: [String] {
        let loweredQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !loweredQuery.isEmpty else { return allRegions }
        return allRegions.filter { match($0, loweredQuery) }
    }

    private func match(_ region: String, _ lower: String) -> Bool {
        let name = PhoneNumberManager.shared.localizedRegionName(for: region).lowercased()
        let code = region.lowercased()
        let dial = (PhoneNumberManager.shared.dialCode(for: region) ?? "").lowercased()
        return name.contains(lower) || code.contains(lower) || dial.contains(lower)
    }

    var body: some View {
        NavigationView {
            List(filteredAll, id: \.self) { region in
                regionRow(region)
            }
            .listStyle(.plain)
            .searchable(text: $query)
            .navigationTitle("국가 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func regionRow(_ region: String) -> some View {
        Button {
            selectedRegion = region
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Text(PhoneNumberManager.shared.localizedRegionName(for: region))
                    .foregroundColor(.primary)
                Spacer()
                Text(PhoneNumberManager.shared.dialCode(for: region) ?? "")
                    .foregroundColor(.gray)
                if region == selectedRegion {
                    Image(systemName: "checkmark")
                        .foregroundColor(Color("Primary"))
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .frame(height: 20)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    struct Container: View {
        @State var phone: String = ""
        @State var phoneStatic: String = "01049232775"
        @State var phoneHelper: String = ""
        var body: some View {
            VStack(spacing: 20) {
                ContactsField(phone: $phone)
                ContactsField(phone: $phoneStatic, isRegionInteractive: false)
                ContactsField(
                    phone: $phoneHelper,
                    label: "전화번호",
                    placeholder: "전화번호 입력",
                    isRequired: true,
                    helper: "예: +82 10-1234-5678"
                )
                Text(phone).font(.body2)
            }
            .padding()
            .background(Color("Background"))
        }
    }
    return Container()
}

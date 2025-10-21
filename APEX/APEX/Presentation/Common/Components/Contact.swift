//
//  Contact.swift
//  APEX
//
//  Created by 조운경 on 10/16/25.
//

import SwiftUI

/// 전화번호 입력 전용 공통 컴포넌트 (Figma 사양 준수)
struct ContactPhoneInput: View {
    @Binding var phone: String

    var label: String
    var placeholder: String
    var isRequired: Bool
    var helper: String?

    @State private var localText: String
    @State private var region: String
    @State private var isShowingPicker: Bool = false

    init(
        phone: Binding<String>,
        label: String = "전화번호",
        placeholder: String = "전화번호 입력",
        isRequired: Bool = true,
        helper: String? = nil
    ) {
        self._phone = phone
        self._localText = State(initialValue: phone.wrappedValue)
        self._region = State(initialValue: PhoneService.shared.currentRegion)
        self.label = label
        self.placeholder = placeholder
        self.isRequired = isRequired
        self.helper = helper
    }

    var body: some View {
        HStack(spacing: 8) {
            Button { isShowingPicker = true } label: {
                HStack(spacing: 8) {
                    Text(PhoneService.shared.dialCode(for: region) ?? "+")
                        .font(.body2)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .frame(height: 44)
                .padding(.horizontal, 12)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .frame(height: 1)
                }
            }
            .buttonStyle(.plain)

            APEXTextField(
                kind: .singleLine,
                placeholder: placeholder,
                text: $localText,
                state: .normal(helper: helper),
                isRequired: isRequired,
                onEditingEndValidate: { text in
                    PhoneService.shared.isValid(text, region: region) ? .success(message: nil) : .error(message: nil)
                }
            )
            .keyboardType(.phonePad)
            .textContentType(.telephoneNumber)
            .textInputAutocapitalization(.never)
        }
        .onChange(of: localText) { newValue in
            let formatted = PhoneService.shared.formatPartial(newValue, region: region)
            if formatted != newValue { localText = formatted }
            phone = formatted
        }
        .overlay(alignment: .leading) {
            // 외부 라벨 요구 시: 필요하면 여기서 좌측 상단 라벨 배치 가능
        }
        .onChange(of: region) { _ in
            let reformatted = PhoneService.shared.formatPartial(localText, region: region)
            if reformatted != localText { localText = reformatted }
            phone = reformatted
        }
        .sheet(isPresented: $isShowingPicker) { RegionPicker(selectedRegion: $region) }
    }
}

private struct RegionPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedRegion: String
    @State private var query: String = ""

    private var allRegions: [String] { PhoneService.shared.allRegions() }

    // Filtering
    private var filteredAll: [String] {
        let loweredQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !loweredQuery.isEmpty else { return allRegions }
        return allRegions.filter { match($0, loweredQuery) }
    }

    private func match(_ region: String, _ lower: String) -> Bool {
        let name = PhoneService.shared.localizedRegionName(for: region).lowercased()
        let code = region.lowercased()
        let dial = (PhoneService.shared.dialCode(for: region) ?? "").lowercased()
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
                Text(PhoneService.shared.localizedRegionName(for: region))
                    .foregroundColor(.primary)
                Spacer()
                Text(PhoneService.shared.dialCode(for: region) ?? "")
                    .foregroundColor(.gray)
                if region == selectedRegion {
                    Image(systemName: "checkmark")
                        .foregroundColor(Color("PrimaryDefault"))
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
        var body: some View {
            VStack(spacing: 20) {
                ContactPhoneInput(phone: $phone)
                Text(phone).font(.body2)
            }
            .padding()
            .background(Color("BackgroundPrimary"))
        }
    }
    return Container()
}

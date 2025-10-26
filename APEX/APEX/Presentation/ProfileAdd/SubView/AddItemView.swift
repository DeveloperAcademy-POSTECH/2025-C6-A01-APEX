//
//  AddItemView.swift
//  APEX
//
//  Created by 조운경 on 10/23/25.
//

import SwiftUI

// MARK: - Model

struct AddItemConfig: Equatable {
    enum Field: String, CaseIterable, Equatable {
            case surname
            case name
            case company
            case department
            case position
            case email
            case phone
            case linkedin
            case memo

            var title: String {
                switch self {
                case .surname: return "성"
                case .name: return "이름"
                case .company: return "회사"
                case .department: return "부서"
                case .position: return "직책"
                case .email: return "이메일"
                case .phone: return "연락처"
                case .linkedin: return "링크드인 URL"
                case .memo: return "메모"
                }
            }
    }

    struct Item: Identifiable, Equatable {
        let id: UUID
        var field: AddItemConfig.Field
        var isRequired: Bool
        var isEnabled: Bool

        init(_ field: AddItemConfig.Field, isRequired: Bool = false, isEnabled: Bool = true) {
            self.id = UUID()
            self.field = field
            self.isRequired = isRequired
            self.isEnabled = isEnabled
        }
    }

    var items: [Item]

    // Counts
    var emailCount: Int
    var phoneCount: Int
    var urlCount: Int

    // Visibility toggles
    var showsLinkedIn: Bool
    var showsIndustry: Bool
    var showsAddress: Bool
    var showsFax: Bool
    var showsRevenue: Bool
    var showsEmployees: Bool

    static var `default`: AddItemConfig {
        .init(
            items: [
            .init(.surname, isRequired: true, isEnabled: true),
            .init(.name, isRequired: true, isEnabled: true),
            .init(.company, isEnabled: true),
            .init(.department, isEnabled: true),
            .init(.position, isEnabled: true),
            .init(.email, isEnabled: true),
            .init(.phone, isEnabled: true),
            .init(.linkedin, isEnabled: true),
            .init(.memo, isEnabled: true)
        ],
        emailCount: 1,
        phoneCount: 1,
        urlCount: 0,
        showsLinkedIn: true,
        showsIndustry: false,
        showsAddress: false,
        showsFax: false,
        showsRevenue: false,
        showsEmployees: false
        )
    }
}

// MARK: - View

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var config: AddItemConfig
    @State private var draft: AddItemConfig

    init(config: Binding<AddItemConfig>) {
        self._config = config
        self._draft = State(initialValue: config.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .safeAreaInset(edge: .top) {
            APEXSheetTopBar(
                title: "항목 추가하기",
                rightTitle: "완료",
                onRightTap: {
                    config = draft
                    dismiss()
                },
                onClose: {
                    // discard changes
                    dismiss()
                }
            )
        }
        .background(Color("Background"))
    }

    private var content: some View {
        List {
            stepperRow(title: "이메일: \(draft.emailCount)가지", value: $draft.emailCount, range: 0...5)
                .listRowSeparator(.hidden)
            stepperRow(title: "연락처: \(draft.phoneCount)가지", value: $draft.phoneCount, range: 0...5)
                .listRowSeparator(.hidden)
            stepperRow(title: "URL: \(draft.urlCount)가지", value: $draft.urlCount, range: 0...5)
                .listRowSeparator(.hidden)
            toggleRow(title: "링크드인 URL 표시 여부", isOn: $draft.showsLinkedIn)
                .listRowSeparator(.hidden)
            toggleRow(title: "회사 업종 표시 여부", isOn: $draft.showsIndustry)
                .listRowSeparator(.hidden)
            toggleRow(title: "주소 표시 여부", isOn: $draft.showsAddress)
                .listRowSeparator(.hidden)
            toggleRow(title: "팩스번호 표시 여부", isOn: $draft.showsFax)
                .listRowSeparator(.hidden)
            toggleRow(title: "연매출 표시 여부", isOn: $draft.showsRevenue)
                .listRowSeparator(.hidden)
            toggleRow(title: "근무 인원 표시 여부", isOn: $draft.showsEmployees)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.body6)
            .foregroundColor(.gray)
    }

    private func itemRow(_ item: AddItemConfig.Item) -> some View {
        HStack(spacing: 12) {
            Text(item.field.title)
                .font(.body2)
                .foregroundColor(.primary)

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(get: {
                item.isEnabled
            }, set: { newValue in
                updateToggle(for: item.id, enabled: newValue)
            }))
            .labelsHidden()
            .disabled(item.isRequired)
        }
        .contentShape(Rectangle())
        .frame(minHeight: 44)
    }

    private func stepperRow(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body2)
                .foregroundColor(value.wrappedValue > 0 ? .black : Color("BackgroundDisabled"))
            Spacer()
            Stepper(value: value, in: range) {

            }
        }
        .frame(minHeight: 48)
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body2)
                .foregroundColor(isOn.wrappedValue ? .black : Color("BackgroundDisabled"))
            Spacer(minLength: 8)
            Button {
                isOn.wrappedValue.toggle()
            } label: {
                Image(systemName: isOn.wrappedValue ? "minus" : "plus")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22, alignment: .center)
                    .background(isOn.wrappedValue ? Color("Error") : Color(red: 0.26, green: 0.8, blue: 0.32))
                    .cornerRadius(100)
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 48)
    }

    // MARK: - Data helpers

    private var requiredItems: [AddItemConfig.Item] {
        draft.items.filter { $0.isRequired }
    }

    private var optionalItems: [AddItemConfig.Item] {
        draft.items.filter { !$0.isRequired }
    }

    private var requiredItemsIDs: [UUID] { requiredItems.map { $0.id } }
    private var optionalItemsIDs: [UUID] { optionalItems.map { $0.id } }

    private func updateToggle(for id: UUID, enabled: Bool) {
        guard let idx = draft.items.firstIndex(where: { $0.id == id }) else { return }
        draft.items[idx].isEnabled = enabled
    }

    private func moveItems(indices: IndexSet, newOffset: Int, within subsetIDs: [UUID]) {
        // Map subset positions back to the primary array order
        let primaryIndices = indices.compactMap { subsetIndex -> Int? in
            let subsetID = subsetIDs[subsetIndex]
            return draft.items.firstIndex(where: { $0.id == subsetID })
        }
        guard !primaryIndices.isEmpty else { return }

        // Compute master destination index
        var destinationID: UUID?
        if newOffset < subsetIDs.count {
            destinationID = subsetIDs[newOffset]
        }
        let destinationPrimaryIndex = destinationID.flatMap { id in
            draft.items.firstIndex(where: { $0.id == id })
        } ?? draft.items.endIndex

        // Extract moving elements preserving order
        let moving = primaryIndices.sorted().map { draft.items[$0] }
        // Remove from master (from highest to lowest index)
        for idx in primaryIndices.sorted(by: >) {
            draft.items.remove(at: idx)
        }
        // Find new destination after removals
        let adjustedDestination: Int = {
            var dest = destinationPrimaryIndex
            let removedBefore = primaryIndices.filter { $0 < destinationPrimaryIndex }.count
            dest -= removedBefore
            return max(min(dest, draft.items.endIndex), 0)
        }()
        // Insert back at destination, ensuring they stay within their subset
        var insertionIndex = adjustedDestination
        for element in moving {
            // Ensure element remains in its subset group by finding nearest allowed boundary
            let boundaryIndices = allowedInsertionBounds(for: element.isRequired)
            let clampedIndex = min(max(insertionIndex, boundaryIndices.lowerBound), boundaryIndices.upperBound)
            draft.items.insert(element, at: clampedIndex)
            insertionIndex = clampedIndex + 1
        }
    }

    private func allowedInsertionBounds(for isRequired: Bool) -> Range<Int> {
        // Required group occupies indices of required items in master order
        let requiredRange: Range<Int> = {
            let requiredIndices = draft.items.enumerated().filter { $0.element.isRequired }.map { $0.offset }
            guard let first = requiredIndices.min(), let last = requiredIndices.max() else {
                return 0..<0
            }
            return first..<(last + 1)
        }()

        let optionalRange: Range<Int> = {
            let optionalIndices = draft.items.enumerated().filter { !$0.element.isRequired }.map { $0.offset }
            guard let first = optionalIndices.min(), let last = optionalIndices.max() else {
                return draft.items.endIndex..<draft.items.endIndex
            }
            return first..<(last + 1)
        }()

        return isRequired ? requiredRange : optionalRange
    }
}

#Preview {
    struct Container: View {
        @State var config: AddItemConfig = .default
        var body: some View {
            AddItemView(config: $config)
        }
    }
    return Container()
}

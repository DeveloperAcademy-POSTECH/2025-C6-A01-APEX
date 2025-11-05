//
//  DataManagementView.swift
//  APEX
//
//  Created by Mr.Penguin on 10/27/25.
//

import SwiftUI
import Combine

// MARK: - Dialog Kind (internal로 공개: ViewModel에서 사용 가능)
enum DMDialogKind: Equatable {
    case deleteAll(totalText: String)
    case deleteContact(name: String, sizeText: String, id: UUID)

    var title: String {
        switch self {
        case .deleteAll: return "모든 미디어 데이터를 삭제하겠습니까?"
        case .deleteContact: return "해당 연락처 노트의\n미디어 데이터를 모두 삭제하겠습니까?"
        }
    }

    var body: String {
        switch self {
        case .deleteAll:
            return "모든 미디어 데이터를 삭제합니다.\nI-Cloud에 백업되지 않은 데이터는\n복원 할 수 없습니다."
        case .deleteContact:
            return "노트를 제외한 모든 미디어 데이터\n(사진, 동영상, 음성, 파일)이 삭제됩니다.\n이 작업은 되돌릴 수 없습니다."
        }
    }
}

// MARK: - ViewModel

@MainActor
final class DataManagementViewModel: ObservableObject {
    // Injected services
    private let sync: StorageSyncService
    private let usage: DataUsageService

    // UI states
    @Published var isAutoSyncOn: Bool = false
    @Published var lastSyncText: String = "—"
    @Published var totalSizeText: String = "—"
    @Published var contacts: [DMContactUsage] = []
    @Published var isRefreshing: Bool = false

    // Dialog
    @Published var showingDialog: Bool = false
    @Published var dialogKind: DMDialogKind? = nil
    @Published var dialogChecked: Bool = false

    init(sync: StorageSyncService, usage: DataUsageService) {
        self.sync = sync
        self.usage = usage
    }

    func load() async {
        do {
            async let auto = try sync.isAutoSyncOn()
            async let last = try sync.lastSyncDate()
            async let total = try usage.totalMediaSizeText()
            async let list = try usage.contactUsages()

            let (isOn, lastDate, totalText, contacts) = try await (auto, last, total, list)
            self.isAutoSyncOn = isOn
            self.lastSyncText = lastDate.map { $0.formatted(date: .numeric, time: .shortened) } ?? "—"
            self.totalSizeText = totalText
            self.contacts = contacts
        } catch {
            // 필요시 토스트/로깅
        }
    }

    func toggleAutoSync(_ newValue: Bool) {
        isAutoSyncOn = newValue
        Task {
            do { try await sync.setAutoSyncOn(newValue) }
            catch {
                await MainActor.run { self.isAutoSyncOn = !newValue }
            }
        }
    }

    func refreshSync() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            defer { Task { @MainActor in self.isRefreshing = false } }
            do {
                let date = try await sync.refreshNow()
                await MainActor.run {
                    self.lastSyncText = date.formatted(date: .numeric, time: .shortened)
                }
            } catch { }
        }
    }

    func requestDeleteAll() {
        dialogKind = .deleteAll(totalText: totalSizeText)
        dialogChecked = false
        showingDialog = true
    }

    func requestDeleteContact(_ id: UUID) {
        guard let target = contacts.first(where: { $0.id == id }) else { return }
        dialogKind = .deleteContact(name: target.name, sizeText: target.sizeText, id: id)
        dialogChecked = false
        showingDialog = true
    }

    func toggleDialogChecked() { dialogChecked.toggle() }

    func cancelDialog() {
        showingDialog = false
        dialogKind = nil
        dialogChecked = false
    }

    func confirmDelete() {
        guard let kind = dialogKind, dialogChecked else { return }
        Task {
            switch kind {
            case .deleteAll:
                do {
                    try await usage.deleteAllMedia()
                    let total = try await usage.totalMediaSizeText()
                    await MainActor.run { self.totalSizeText = total }
                } catch { }
            case .deleteContact(_, _, let id):
                do {
                    try await usage.deleteMedia(for: id)
                    let list = try await usage.contactUsages()
                    await MainActor.run { self.contacts = list }
                } catch { }
            }
            await MainActor.run { self.cancelDialog() }
        }
    }
}

// MARK: - View (조립만)

struct DataManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = DataManagementViewModel(
        sync: MockStorageSyncService(),
        usage: MockDataUsageService()
    )

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                DMTopBar { dismiss() }

                ScrollView {
                    VStack(spacing: 16) {
                        DMToggleSection(
                            title: "iCloud 자동 동기화",
                            helper: "노트에 저장한 미디어는 iCloud에 자동으로 백업하고 기기에서는 삭제하여 스토리지 여유를 가질 수 있어요.",
                            isOn: $vm.isAutoSyncOn,
                            onToggle: { vm.toggleAutoSync($0) }
                        )

                        DMRefreshSection(
                            title: "iCloud 동기화 새로고침",
                            helperPrefix: "노트에 저장한 미디어를 iCloud에 즉시 동기화 합니다.",
                            lastSyncText: vm.lastSyncText,
                            isRefreshing: vm.isRefreshing,
                            onRefresh: { vm.refreshSync() }
                        )

                        DMDeleteAllBlock(totalSizeText: vm.totalSizeText) {
                            vm.requestDeleteAll()
                        }

                        Divider().padding(.horizontal, 16)

                        Text("연락처 노트 데이터 관리")
                            .font(.body4)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)

                        VStack(spacing: 8) {
                            ForEach(vm.contacts) { c in
                                DMContactRow(contact: c) {
                                    vm.requestDeleteContact(c.id)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 16)
                }
                .background(Color("Background"))
            }

            DMConfirmDialog(
                isVisible: $vm.showingDialog,
                isChecked: $vm.dialogChecked,
                title: vm.dialogKind?.title ?? "",
                bodyText: vm.dialogKind?.body ?? "",
                confirmTitle: "삭제",
                cancelTitle: "취소",
                onConfirm: { vm.confirmDelete() },
                onCancel: { vm.cancelDialog() }
            )
        }
        .task { await vm.load() }
        .background(Color("Background"))
    }
}

#Preview {
    DataManagementView()
}

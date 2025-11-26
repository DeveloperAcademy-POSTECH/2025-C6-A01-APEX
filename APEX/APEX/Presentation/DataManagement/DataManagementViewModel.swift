//
//  DataManagementViewModel.swift
//  APEX
//
//  Created by Assistant on 11/23/25.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Dialog Kind
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
            return "모든 미디어 데이터를 삭제합니다.\ni-Cloud에 백업되지 않은 데이터는\n복원 할 수 없습니다."
        case .deleteContact:
            return "노트를 제외한 모든 미디어 데이터\n(사진, 동영상, 음성, 파일)이 삭제됩니다.\n이 작업은 되돌릴 수 없습니다."
        }
    }
}

// MARK: - ViewModel
@MainActor
final class DataManagementViewModel: ViewModelable {
    enum Action {
        case onAppear
        case setAutoSync(Bool)
        case refresh
        case requestDeleteAll
        case requestDeleteContact(UUID)
        case cancelDialog
        case confirmDelete
    }

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

    init(sync: StorageSyncService, usage: DataUsageService) {
        self.sync = sync
        self.usage = usage
    }

    // MARK: - ViewModelable
    func send(_ action: Action) {
        switch action {
        case .onAppear:
            Task { await load() }
        case .setAutoSync(let newValue):
            toggleAutoSync(newValue)
        case .refresh:
            refreshSync()
        case .requestDeleteAll:
            requestDeleteAll()
        case .requestDeleteContact(let id):
            requestDeleteContact(id)
        case .cancelDialog:
            cancelDialog()
        case .confirmDelete:
            confirmDelete()
        }
    }
}

// MARK: - Private
private extension DataManagementViewModel {
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
            // Optionally handle error (toast/logging)
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

    func cancelDialog() {
        showingDialog = false
        dialogKind = nil
    }

    func confirmDelete() {
        guard let kind = dialogKind else { return }
        Task {
            switch kind {
            case .deleteAll:
                do {
                    try await usage.deleteAllMedia()
                    async let total = try usage.totalMediaSizeText()
                    async let list = try usage.contactUsages()
                    let (totalText, contacts) = try await (total, list)
                    await MainActor.run {
                        self.totalSizeText = totalText
                        self.contacts = contacts
                    }
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

// MARK: - Public (View-triggered) actions
extension DataManagementViewModel {
    func requestDeleteAll() {
        dialogKind = .deleteAll(totalText: totalSizeText)
        showingDialog = true
    }

    func requestDeleteContact(_ id: UUID) {
        guard let target = contacts.first(where: { $0.id == id }) else { return }
        dialogKind = .deleteContact(name: target.name, sizeText: target.sizeText, id: id)
        showingDialog = true
    }
}



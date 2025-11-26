//
//  MyProfileViewModel.swift
//  APEX
//
//  Created by Assistant on 11/23/25.
//

import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
final class MyProfileViewModel: ViewModelable {
    enum Action {
        case setPage(Int)
        case presentEdit(Bool)
        case showCardViewer(Bool)
        case onAppear
        case refreshUsage // triggers usage + purge enabled refresh
        case tapPurge
        case confirmPurge
        case setAlert(String?)
        case tapLogout
        case confirmLogout
    }
    
    // MARK: - Inputs
    private var clientBinding: Binding<DummyClient>
    
    // MARK: - UI State
    @Published var isPresentingEdit: Bool = false
    @Published var isShowingCardViewer: Bool = false
    @Published var alertMessage: String? = nil
    @Published var currentPageIndex: Int = 0
    @Published var usedSizeText: String = "—"
    @Published var isPurgeEnabledState: Bool = false
    @Published var showPurgeConfirm: Bool = false
    @Published var showLogoutConfirm: Bool = false
    
    // MARK: - Init
    init(client: Binding<DummyClient>) {
        self.clientBinding = client
    }
    
    // MARK: - Derived
    var client: DummyClient { clientBinding.wrappedValue }
    
    var adaptedClient: Client {
        ClientsStore.convertToClient(clientBinding.wrappedValue)
    }
    
    // MARK: - ViewModelable
    func send(_ action: Action) {
        switch action {
        case .setPage(let idx):
            currentPageIndex = idx
        case .presentEdit(let presented):
            isPresentingEdit = presented
        case .showCardViewer(let show):
            isShowingCardViewer = show
        case .onAppear:
            refreshPurgeEnabled()
        case .refreshUsage:
            refreshPurgeEnabled()
            Task { await updateUsedSize() }
        case .tapPurge:
            showPurgeConfirm = true
        case .confirmPurge:
            purgeTemporaryData()
        case .setAlert(let msg):
            alertMessage = msg
        case .tapLogout:
            showLogoutConfirm = true
        case .confirmLogout:
            performLogout()
        }
    }
}

// MARK: - Public Methods for View Hooks
extension MyProfileViewModel {
    func openExternal(_ url: URL?) {
        guard let url else { alertMessage = "잘못된 주소입니다."; return }
        UIApplication.shared.open(url, options: [:]) { [weak self] success in
            guard let self else { return }
            if !success { self.alertMessage = "열 수 없습니다." }
        }
    }
    
    func copyToPasteboard(_ text: String) {
        UIPasteboard.general.string = text
    }
    
    func ensureMyChatClientId() -> UUID {
        let emailKey = client.email ?? ""
        if let me = ClientsStore.shared.clients.first(where: { ($0.email ?? "") == emailKey }) {
            return me.id
        }
        // Insert myself if missing, then return id
        let newClient = ClientsStore.convertToClient(client)
        ClientsStore.shared.add(newClient, atTop: true)
        return newClient.id
    }
    
    func persistClientUpdate(_ updated: DummyClient, previousEmail: String?) {
        // Push edit result to the bound client
        clientBinding.wrappedValue = updated
        
        // Prefer updating by email when possible
        let candidates = [updated.email, previousEmail].compactMap { $0 }.filter { !$0.isEmpty }
        if let key = candidates.first,
           let existing = ClientsStore.shared.clients.first(where: { ($0.email ?? "") == key }) {
            let newClient = Client(
                id: existing.id,
                profile: updated.profile,
                nameCardFront: updated.nameCardFront,
                nameCardBack: updated.nameCardBack,
                surname: updated.surname,
                name: updated.name,
                position: updated.position,
                company: updated.company,
                department: updated.department,
                email: updated.email,
                phoneNumber: updated.phoneNumber,
                linkedinURL: updated.linkedinURL,
                memo: updated.memo,
                action: existing.action,
                favorite: existing.favorite,
                pin: existing.pin,
                notes: existing.notes,
                industry: updated.industry,
                address: updated.address,
                faxNumber: updated.faxNumber,
                revenue: updated.revenue,
                employees: updated.employees,
                additionalEmails: updated.additionalEmails,
                additionalPhones: updated.additionalPhones,
                additionalURLs: updated.additionalURLs
            )
            ClientsStore.shared.update(newClient)
            return
        }
        
        // Fallback: update the reserved "my profile" slot (index 0) by id
        if let first = ClientsStore.shared.clients.first {
            let newClient = Client(
                id: first.id,
                profile: updated.profile,
                nameCardFront: updated.nameCardFront,
                nameCardBack: updated.nameCardBack,
                surname: updated.surname,
                name: updated.name,
                position: updated.position,
                company: updated.company,
                department: updated.department,
                email: updated.email,
                phoneNumber: updated.phoneNumber,
                linkedinURL: updated.linkedinURL,
                memo: updated.memo,
                action: first.action,
                favorite: first.favorite,
                pin: first.pin,
                notes: first.notes,
                industry: updated.industry,
                address: updated.address,
                faxNumber: updated.faxNumber,
                revenue: updated.revenue,
                employees: updated.employees,
                additionalEmails: updated.additionalEmails,
                additionalPhones: updated.additionalPhones,
                additionalURLs: updated.additionalURLs
            )
            ClientsStore.shared.update(newClient)
        }
    }
}

// MARK: - Private Helpers
private extension MyProfileViewModel {
    func performLogout() {
        // 1) Clear local persisted clients and in-memory state
        LocalStore.shared.clearClients()
        ClientsStore.shared.resetToInitial()
        
        // 2) Clear cached Apple full name so next sign-in won't reuse previous name
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "apple.fullName.given")
        defaults.removeObject(forKey: "apple.fullName.family")
        
        // 3) Clear local CloudKit mirrors/mappings to avoid binding to previous account artifacts
        defaults.removeObject(forKey: "cloudkit.mapping.clientIdToRecordName")
        defaults.removeObject(forKey: "cloudkit.mapping.userRecordName")
        defaults.removeObject(forKey: "cloudkit.mapping.noteIdToRecordName")
        defaults.removeObject(forKey: "cloudkit.token.private")
        defaults.synchronize()
        
        // 4) Route to onboarding to select guest or sign-in again
        NotificationCenter.default.post(name: .apexRequestOnboarding, object: nil)
    }
    
    func refreshPurgeEnabled() {
        isPurgeEnabledState = hasTemporaryData()
    }
    
    func hasTemporaryData() -> Bool {
        let fm = FileManager.default
        let cacheDir = (try? fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? fm.temporaryDirectory
        let uploadsDir = cacheDir.appendingPathComponent("APEXUploads", isDirectory: true)
        if let items = try? fm.contentsOfDirectory(at: uploadsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]), !items.isEmpty {
            return true
        }
        // Only consider our app-owned temp subdirectory to avoid system temp noise
        let apexTmpDir = fm.temporaryDirectory.appendingPathComponent("APEXTmp", isDirectory: true)
        if let tmpItems = try? fm.contentsOfDirectory(at: apexTmpDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]), !tmpItems.isEmpty {
            return true
        }
        return false
    }
    
    func purgeTemporaryData() {
        let fm = FileManager.default
        let cacheDir = (try? fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? fm.temporaryDirectory
        let uploadsDir = cacheDir.appendingPathComponent("APEXUploads", isDirectory: true)
        if fm.fileExists(atPath: uploadsDir.path) {
            do { try fm.removeItem(at: uploadsDir) } catch { }
        }
        // Remove only our app-owned temp directory
        let apexTmpDir = fm.temporaryDirectory.appendingPathComponent("APEXTmp", isDirectory: true)
        if fm.fileExists(atPath: apexTmpDir.path) {
            try? fm.removeItem(at: apexTmpDir)
        }
        URLCache.shared.removeAllCachedResponses()
        LinkPreviewLoader.clearCache()
        refreshPurgeEnabled()
    }
    
    func updateUsedSize() async {
        do {
            let text = try await RealDataUsageService().totalMediaSizeText()
            await MainActor.run { usedSizeText = text }
        } catch { }
    }
}



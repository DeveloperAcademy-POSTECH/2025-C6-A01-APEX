//
//  NotesViewModel.swift
//  APEX
//
//  Created by Assistant on 11/18/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class NotesViewModel: ViewModelable {
    enum Action {
        case togglePin(Client)
        case undoPin
        case showDelete(Client)
        case deleteConfirmed(Client)
        case dismissDelete
        case notesUpdated(clientId: UUID)
    }
    
    // External stores
    private let clientsStore: ClientsStore = .shared
    private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - UI State
    @Published var selectedFilter: NotesFilter = .all
    @Published var showToast: Bool = false
    @Published var toastText: String = ""
    @Published var clientToDelete: Client?
    @Published var showDeleteDialog: Bool = false
    @Published var isDeleteConfirmed: Bool = false
    @Published var availableFilters: [NotesFilterItem] = []
    
    // Undo state
    private var lastToggledClientId: UUID?
    private var lastPinAction: PinAction?
    private enum PinAction {
        case added
        case removed
    }
    
    // Preferences keys (mirror CompanyManagementSheet)
    private let enabledCompaniesDefaultsKey = "apex.notes.enabledCompanies"
    private let companyOrderDefaultsKey = "apex.notes.companyOrder"
    
    init() {
        // Build initial filters
        rebuildFilters()
        
        // Observe company preference updates
        NotificationCenter.default.addObserver(
            forName: .apexCompanyPreferencesUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildFilters()
        }
        
        // Observe clients changes to reflect new/renamed companies
        clientsStore.$clients
            .sink { [weak self] _ in
                self?.rebuildFilters()
            }
            .store(in: &cancellables)
        
        // Observe notes updates to keep clients' notes fresh
        NotificationCenter.default.addObserver(
            forName: .apexChatNotesUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self else { return }
            guard let clientId = notif.userInfo?["clientId"] as? UUID,
                  let idx = self.clientsStore.clients.firstIndex(where: { $0.id == clientId }) else { return }
            
            let old = self.clientsStore.clients[idx]
            let latestNotes = ChatStore.shared.notes(for: clientId)
            
            withAnimation(.easeInOut(duration: 0.25)) {
                self.clientsStore.clients[idx] = Client(
                    id: old.id,
                    profile: old.profile,
                    nameCardFront: old.nameCardFront,
                    nameCardBack: old.nameCardBack,
                    surname: old.surname,
                    name: old.name,
                    position: old.position,
                    company: old.company,
                    department: old.department,
                    email: old.email,
                    phoneNumber: old.phoneNumber,
                    linkedinURL: old.linkedinURL,
                    memo: old.memo,
                    action: old.action,
                    favorite: old.favorite,
                    pin: old.pin,
                    notes: latestNotes,
                    industry: old.industry,
                    address: old.address,
                    faxNumber: old.faxNumber,
                    revenue: old.revenue,
                    employees: old.employees,
                    additionalEmails: old.additionalEmails,
                    additionalPhones: old.additionalPhones,
                    additionalURLs: old.additionalURLs
                )
            }
        }
    }
    
    // MARK: - Computed
    var companyNamesWithNotes: [String] {
        Set(clientsStore.clients.compactMap { client in
            let trimmed = client.company.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }).sorted()
    }
    
    // MARK: - ViewModelable
    func send(_ action: Action) {
        switch action {
        case .togglePin(let client):
            togglePin(client)
        case .undoPin:
            undoPinAction()
        case .showDelete(let client):
            // 배치 업데이트로 리렌더링 최소화
            Task { @MainActor in
                clientToDelete = client
                showDeleteDialog = true
            }
        case .deleteConfirmed(let client):
            deleteClient(client)
        case .dismissDelete:
            showDeleteDialog = false
            clientToDelete = nil
            isDeleteConfirmed = false
        case .notesUpdated(let clientId):
            // Kept for completeness; notifications already handled in init
            guard let idx = clientsStore.clients.firstIndex(where: { $0.id == clientId }) else { return }
            let old = clientsStore.clients[idx]
            let latestNotes = ChatStore.shared.notes(for: clientId)
            withAnimation(.easeInOut(duration: 0.25)) {
                clientsStore.clients[idx] = Client(
                    id: old.id,
                    profile: old.profile,
                    nameCardFront: old.nameCardFront,
                    nameCardBack: old.nameCardBack,
                    surname: old.surname,
                    name: old.name,
                    position: old.position,
                    company: old.company,
                    department: old.department,
                    email: old.email,
                    phoneNumber: old.phoneNumber,
                    linkedinURL: old.linkedinURL,
                    memo: old.memo,
                    action: old.action,
                    favorite: old.favorite,
                    pin: old.pin,
                    notes: latestNotes,
                    industry: old.industry,
                    address: old.address,
                    faxNumber: old.faxNumber,
                    revenue: old.revenue,
                    employees: old.employees,
                    additionalEmails: old.additionalEmails,
                    additionalPhones: old.additionalPhones,
                    additionalURLs: old.additionalURLs
                )
            }
        }
    }
    
    // MARK: - Private actions
    private func rebuildFilters() {
        let allCompaniesSet: Set<String> = Set(
            clientsStore.clients.compactMap { client in
                let trimmed = client.company.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        )
        
        // Load enabled list; default to all companies
        let enabledArray = (UserDefaults.standard.array(forKey: enabledCompaniesDefaultsKey) as? [String]) ?? Array(allCompaniesSet)
        let enabledSet = Set(enabledArray).intersection(allCompaniesSet)
        
        // Load order; fallback to alphabetical of all companies
        let rawOrder = (UserDefaults.standard.array(forKey: companyOrderDefaultsKey) as? [String]) ?? Array(allCompaniesSet).sorted { $0.localizedCompare($1) == .orderedAscending }
        
        // Derive final ordered list: order filtered by enabled and existence, then append any enabled not present in order alphabetically
        var ordered: [String] = rawOrder.filter { enabledSet.contains($0) && allCompaniesSet.contains($0) }
        let missing = enabledSet.subtracting(Set(ordered))
        if !missing.isEmpty {
            ordered.append(contentsOf: missing.sorted { $0.localizedCompare($1) == .orderedAscending })
        }
        
        var newFilters: [NotesFilterItem] = [NotesFilterItem(filter: .all, isEnabled: true)]
        newFilters.append(contentsOf: ordered.map { NotesFilterItem(filter: .company($0), isEnabled: true) })
        availableFilters = newFilters
        
        // Guard current selection
        if case .company(let name) = selectedFilter {
            if !enabledSet.contains(name) {
                selectedFilter = .all
            }
        }
    }
    
    private func togglePin(_ client: Client) {
        guard let index = clientsStore.clients.firstIndex(where: { $0.id == client.id }) else { return }
        
        lastToggledClientId = client.id
        lastPinAction = client.pin ? .removed : .added
        
        let newPinState = !client.pin
        
        if newPinState {
            PinOrderManager.shared.pinClient(client.id)
        } else {
            PinOrderManager.shared.unpinClient(client.id)
        }
        withAnimation(nil) {
            var updated = clientsStore.clients[index]
            updated.pin = newPinState
            clientsStore.clients[index] = updated
        }
        
        toastText = newPinState ? "핀을 추가했습니다" : "핀을 해제했습니다"
        retriggerToast()
    }
    
    private func deleteClient(_ client: Client) {
        // Only clear notes (keep contact)
        ChatStore.shared.setNotes([], for: client.id)
        
        if case .company(let name) = selectedFilter,
           !companyNamesWithNotes.contains(name) {
            selectedFilter = .all
        }
        
        clientToDelete = nil
        isDeleteConfirmed = false
        showDeleteDialog = false
    }
    
    private func retriggerToast() {
        if showToast {
            showToast = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                self.showToast = true
            }
        } else {
            showToast = true
        }
    }
    
    private func undoPinAction() {
        guard let clientId = lastToggledClientId,
              let action = lastPinAction,
              let index = clientsStore.clients.firstIndex(where: { $0.id == clientId }) else {
            return
        }
        
        let currentClient = clientsStore.clients[index]
        
        let originalPinState: Bool
        switch action {
        case .added:
            originalPinState = false
            PinOrderManager.shared.unpinClient(clientId)
        case .removed:
            originalPinState = true
            PinOrderManager.shared.pinClient(clientId)
        }
        withAnimation(nil) {
            var updated = clientsStore.clients[index]
            updated.pin = originalPinState
            clientsStore.clients[index] = updated
        }
        
        lastToggledClientId = nil
        lastPinAction = nil
        showToast = false
    }
}



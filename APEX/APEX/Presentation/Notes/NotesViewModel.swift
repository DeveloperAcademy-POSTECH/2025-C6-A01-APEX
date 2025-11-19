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
    
    // MARK: - UI State
    @Published var selectedFilter: NotesFilter = .all
    @Published var showToast: Bool = false
    @Published var toastText: String = ""
    @Published var clientToDelete: Client?
    @Published var showDeleteDialog: Bool = false
    @Published var isDeleteConfirmed: Bool = false
    
    // Undo state
    private var lastToggledClientId: UUID?
    private var lastPinAction: PinAction?
    private enum PinAction {
        case added
        case removed
    }
    
    init() {
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
                    email: old.email,
                    phoneNumber: old.phoneNumber,
                    linkedinURL: old.linkedinURL,
                    memo: old.memo,
                    action: old.action,
                    favorite: old.favorite,
                    pin: old.pin,
                    notes: latestNotes
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
    
    var availableFilters: [NotesFilterItem] {
        let allFilter = NotesFilterItem(filter: .all, isEnabled: true)
        let companyFilters = companyNamesWithNotes.map {
            NotesFilterItem(filter: .company($0), isEnabled: true)
        }
        return [allFilter] + companyFilters
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
                    email: old.email,
                    phoneNumber: old.phoneNumber,
                    linkedinURL: old.linkedinURL,
                    memo: old.memo,
                    action: old.action,
                    favorite: old.favorite,
                    pin: old.pin,
                    notes: latestNotes
                )
            }
        }
    }
    
    // MARK: - Private actions
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



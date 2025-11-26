//
//  ContactsViewModel.swift
//  APEX
//
//  Created by Assistant on 11/18/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ContactsViewModel: ViewModelable {
    enum Action {
        case onPlusTap
        case toggleFavorite(Client)
        case undoFavorite
        case showDelete(Client)
        case deleteConfirmed(Client)
        case dismissDelete
    }
    
    private let store: ClientsStore = .shared
    
    // MARK: - UI State
    @Published var isFavoritesExpanded: Bool = true
    @Published var isAllExpanded: Bool = true
    
    @Published var showToast: Bool = false
    @Published var toastText: String = "즐겨찾기를 추가했습니다"
    @Published var isProfileAddPresented: Bool = false
    
    @Published var showDeleteDialog: Bool = false
    @Published var isDeleteConfirmed: Bool = false
    @Published var clientToDelete: Client?
    
    // Undo state
    private var lastToggledClient: Client?
    private var lastFavoriteAction: FavoriteAction?
    private enum FavoriteAction {
        case added
        case removed
    }
    
    // MARK: - Derived
    var myProfileClient: Client? {
        store.clients.first
    }
    
    var favorites: [Client] {
        Array(store.clients.dropFirst()).filter { $0.favorite }
    }
    
    var allUngrouped: [Client] {
        Array(store.clients.dropFirst())
    }
    
    // MARK: - ViewModelable
    func send(_ action: Action) {
        switch action {
        case .onPlusTap:
            isProfileAddPresented = true
        case .toggleFavorite(let client):
            toggleFavorite(client)
        case .undoFavorite:
            undoFavoriteAction()
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
        }
    }
    
    // MARK: - Private actions
    private func toggleFavorite(_ client: Client) {
        lastToggledClient = client
        guard let idx = store.clients.firstIndex(where: { $0.id == client.id }) else { return }
        withAnimation(nil) {
            var updated = store.clients[idx]
            updated.favorite.toggle()
            store.clients[idx] = updated
        }
        let nowFavorite = store.clients[idx].favorite
        lastFavoriteAction = nowFavorite ? .added : .removed
        toastText = nowFavorite ? "즐겨찾기를 추가했습니다" : "즐겨찾기를 해제했습니다"
        retriggerToast()
    }
    
    private func deleteClient(_ client: Client) {
        ClientsStore.shared.remove(client.id)
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
    
    private func undoFavoriteAction() {
        guard let client = lastToggledClient,
              let action = lastFavoriteAction else {
            return
        }
        
        guard let idx = store.clients.firstIndex(where: { $0.id == client.id }) else { return }
        withAnimation(nil) {
            var current = store.clients[idx]
            switch action {
            case .added:
                current.favorite = false
            case .removed:
                current.favorite = true
            }
            store.clients[idx] = current
        }
        
        lastToggledClient = nil
        lastFavoriteAction = nil
        showToast = false
    }
}



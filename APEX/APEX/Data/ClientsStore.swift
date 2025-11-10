//
//  ClientsStore.swift
//  APEX
//
//  Shared in-memory clients store to synchronize contacts across views.
//

import Foundation
import SwiftUI
import Combine

final class ClientsStore: ObservableObject {
    static let shared = ClientsStore()

    private let localStore = LocalStore.shared
    private var cancellables: Set<AnyCancellable> = []

    @Published var clients: [Client]

    private init() {
        if let persisted = localStore.loadClients() {
            self.clients = persisted
            // Ensure my profile exists even after loading
            injectMyProfileIfNeeded()
        } else {
            // First run: seed ONLY my profile (no other sample clients)
            let me = ClientsStore.convertToClient(sampleMyProfileClient)
            self.clients = [me]
            // Seed the disk with initial data on first launch
            localStore.saveClients(self.clients)
        }

        // Persist on any change
        $clients
            .dropFirst()
            .sink { [weak self] newValue in
                self?.localStore.saveClients(newValue)
            }
            .store(in: &cancellables)

        // Sync notes changes coming from ChatStore into clients, then persist
        NotificationCenter.default.publisher(for: .apexChatNotesUpdated)
            .sink { [weak self] notification in
                guard
                    let self = self,
                    let userInfo = notification.userInfo,
                    let clientId = userInfo["clientId"] as? UUID
                else { return }
                let updatedNotes = ChatStore.shared.notes(for: clientId)
                if let idx = self.clients.firstIndex(where: { $0.id == clientId }) {
                    var client = self.clients[idx]
                    client.notes = updatedNotes
                    self.clients[idx] = client
                }
            }
            .store(in: &cancellables)
    }

    func add(_ client: Client, atTop: Bool = true) {
        if atTop {
            clients.insert(client, at: 0)
        } else {
            clients.append(client)
        }
    }

    func update(_ client: Client) {
        if let idx = clients.firstIndex(where: { $0.id == client.id }) {
            clients[idx] = client
        }
    }

    func remove(_ clientId: UUID) {
        if let idx = clients.firstIndex(where: { $0.id == clientId }) {
            clients.remove(at: idx)
        }
    }

    // MARK: - Helpers
    private func injectMyProfileIfNeeded() {
        // Use email as a stable key for de-duplication
        let myEmail = sampleMyProfileClient.email
        let exists = clients.contains { ($0.email ?? "") == myEmail }
        if !exists {
            clients.insert(ClientsStore.convertToClient(sampleMyProfileClient), at: 0)
        }
    }

    private static func convertToClient(_ dummy: DummyClient) -> Client {
        Client(
            profile: dummy.profile,
            nameCardFront: dummy.nameCardFront,
            nameCardBack: dummy.nameCardBack,
            surname: dummy.surname,
            name: dummy.name,
            position: dummy.position,
            company: dummy.company,
            email: dummy.email,
            phoneNumber: dummy.phoneNumber,
            linkedinURL: dummy.linkedinURL,
            memo: dummy.memo,
            action: dummy.action,
            favorite: dummy.favorite,
            pin: dummy.pin,
            notes: []
        )
    }
}


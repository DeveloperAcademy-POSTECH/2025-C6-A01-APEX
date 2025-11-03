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

    @Published var clients: [Client]

    private init() {
        self.clients = sampleClients
        // Ensure current user (DummyClient) is also part of clients
        injectMyProfileIfNeeded()
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
            clients.insert(convertToClient(sampleMyProfileClient), at: 0)
        }
    }

    private func convertToClient(_ dummy: DummyClient) -> Client {
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



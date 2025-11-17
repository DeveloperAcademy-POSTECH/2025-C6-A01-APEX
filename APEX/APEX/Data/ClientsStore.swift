//
//  ClientsStore.swift
//  APEX
//
//  Shared in-memory clients store to synchronize contacts across views.
//

import Foundation
import SwiftUI
import UIKit
import Combine

final class ClientsStore: ObservableObject {
    static let shared = ClientsStore()

    private let localStore = LocalStore.shared
    private var cancellables: Set<AnyCancellable> = []

    @Published var clients: [Client]

    private init() {
        if let fromAppGroup = localStore.loadClientsFromAppGroup() {
            self.clients = fromAppGroup
            // Ensure my profile exists even after loading
            injectMyProfileIfNeeded()
            // Persist back to documents and mirror to App Group
            localStore.saveClients(self.clients)
            // Push notes into ChatStore so open chats reflect latest
            syncAllNotesToChatStore()
        } else if let persisted = localStore.loadClients() {
            self.clients = persisted
            // Ensure my profile exists even after loading
            injectMyProfileIfNeeded()
            // Mirror to App Group so Share Extension can read recipients
            localStore.saveClients(self.clients)
            // Push notes into ChatStore so open chats reflect latest
            syncAllNotesToChatStore()
        } else {
            // First run: seed ONLY my profile (no other sample clients)
            let me = ClientsStore.convertToClient(sampleMyProfileClient)
            self.clients = [me]
            // Seed the disk with initial data on first launch
            localStore.saveClients(self.clients)
            // Push notes into ChatStore so open chats reflect latest
            syncAllNotesToChatStore()
        }

        // Persist on any change
        $clients
            .dropFirst()
            .sink { [weak self] newValue in
                guard let self else { return }
                // Avoid persisting when running SwiftUI previews to prevent preview data from leaking into runtime
                let env = ProcessInfo.processInfo.environment
                let isPreview = env["XCODE_RUNNING_FOR_PREVIEWS"] == "1" || env["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
                guard !isPreview else { return }
                self.localStore.saveClients(newValue)
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

        // When app returns to foreground, pull from App Group in case the Share Extension added notes
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                if let fromAppGroup = self.localStore.loadClientsFromAppGroup() {
                    self.clients = fromAppGroup
                    self.injectMyProfileIfNeeded()
                    self.localStore.saveClients(self.clients)
                    self.syncAllNotesToChatStore()
                }
            }
            .store(in: &cancellables)
    }

    private func syncAllNotesToChatStore() {
        for client in clients {
            ChatStore.shared.setNotes(client.notes, for: client.id)
        }
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


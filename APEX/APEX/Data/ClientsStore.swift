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
            // Repair stale file URLs that may still point to Documents
            if repairAttachmentURLsIfNeeded() {
                localStore.saveClients(self.clients)
            }
            // Persist back to documents and mirror to App Group
            localStore.saveClients(self.clients)
            // Push notes into ChatStore so open chats reflect latest
            syncAllNotesToChatStore()
        } else if let persisted = localStore.loadClients() {
            self.clients = persisted
            // Ensure my profile exists even after loading
            injectMyProfileIfNeeded()
            // Repair stale file URLs that may still point to Documents
            if repairAttachmentURLsIfNeeded() {
                localStore.saveClients(self.clients)
            }
            // Mirror to App Group so Share Extension can read recipients
            localStore.saveClients(self.clients)
            // Push notes into ChatStore so open chats reflect latest
            syncAllNotesToChatStore()
        } else {
            // First run: seed ONLY a blank my profile (no sample personal data)
            let me = ClientsStore.makeBlankMyProfile()
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
                    if self.repairAttachmentURLsIfNeeded() {
                        self.localStore.saveClients(self.clients)
                    }
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

    // Attempt to fix attachment URLs that reference old Documents paths by rebinding
    // them to the App Group container if a matching file exists there.
    private func repairAttachmentURLsIfNeeded() -> Bool {
        guard let appGroupBase = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.apex.StashShareExtension") else {
            return false
        }
        let videoDir = appGroupBase.appendingPathComponent("SharedVideos", isDirectory: true)
        let fileDir  = appGroupBase.appendingPathComponent("SharedFiles", isDirectory: true)
        let audioDir = appGroupBase.appendingPathComponent("SharedAudios", isDirectory: true)
        var changed = false

        func rebindURLIfMissing(_ url: URL, in dir: URL) -> URL {
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            let candidate = dir.appendingPathComponent(url.lastPathComponent)
            if FileManager.default.fileExists(atPath: candidate.path) {
                changed = true
                return candidate
            }
            // If exact name not found, try to find same base name with suffix " 2", " 3", etc.
            let base = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            if let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                if let match = items.first(where: { $0.deletingPathExtension().lastPathComponent.hasPrefix(base) && $0.pathExtension == ext }) {
                    changed = true
                    return match
                }
            }
            return url
        }

        for clientIndex in clients.indices {
            var client = clients[clientIndex]
            for noteIndex in client.notes.indices {
                var note = client.notes[noteIndex]
                if var bundle = note.bundle {
                    switch bundle {
                    case .media(let images, let videos):
                        let fixedVideos: [VideoAttachment] = videos.map { item in
                            let rebound = rebindURLIfMissing(item.url, in: videoDir)
                            return VideoAttachment(url: rebound, progress: item.progress, orderIndex: item.orderIndex)
                        }
                        bundle = .media(images: images, videos: fixedVideos)
                        note.bundle = bundle
                    case .files(let files):
                        let fixedFiles: [FileAttachment] = files.map { item in
                            let rebound = rebindURLIfMissing(item.url, in: fileDir)
                            return FileAttachment(url: rebound, contentType: item.contentType, progress: item.progress)
                        }
                        bundle = .files(fixedFiles)
                        note.bundle = bundle
                    case .audio(let audios):
                        let fixedAudios: [AudioAttachment] = audios.map { item in
                            let rebound = rebindURLIfMissing(item.url, in: audioDir)
                            return AudioAttachment(url: rebound, duration: item.duration)
                        }
                        bundle = .audio(fixedAudios)
                        note.bundle = bundle
                    }
                }
                client.notes[noteIndex] = note
            }
            clients[clientIndex] = client
        }
        return changed
    }

    func add(_ client: Client, atTop: Bool = true) {
        if atTop {
            // Keep index 0 reserved for 'my profile'
            let insertIndex = clients.isEmpty ? 0 : 1
            clients.insert(client, at: insertIndex)
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
        // Only inject a sample "my profile" when there are no clients at all
        guard clients.isEmpty else { return }
        clients.insert(ClientsStore.makeBlankMyProfile(), at: 0)
    }

    static func convertToClient(_ dummy: DummyClient) -> Client {
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

    // MARK: - Reset
    func resetToInitial() {
        // Reset in-memory clients to initial "my profile only" state
        let me = ClientsStore.makeBlankMyProfile()
        self.clients = [me]
        // Persist cleared state (also mirrors to App Group)
        localStore.saveClients(self.clients)
        // Clear in-memory chats
        ChatStore.shared.clear()
    }

    // MARK: - Blank my profile
    private static func makeBlankMyProfile() -> Client {
        Client(
            profile: nil,
            nameCardFront: nil,
            nameCardBack: nil,
            surname: "",
            name: "",
            position: nil,
            company: "",
            email: nil,
            phoneNumber: nil,
            linkedinURL: nil,
            memo: nil,
            action: nil,
            favorite: false,
            pin: false,
            notes: []
        )
    }
}


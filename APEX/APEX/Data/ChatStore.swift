//
//  ChatStore.swift
//  APEX
//
//  Simple in-memory store to persist chat notes per client during app session.
//

import Foundation

final class ChatStore {
    static let shared = ChatStore()
    private init() {}

    private var clientIdToNotes: [UUID: [Note]] = [:]
    private let lock = NSLock()

    func notes(for clientId: UUID) -> [Note] {
        lock.lock(); defer { lock.unlock() }
        return clientIdToNotes[clientId] ?? []
    }

    func setNotes(_ notes: [Note], for clientId: UUID) {
        lock.lock()
        clientIdToNotes[clientId] = notes
        lock.unlock()
        NotificationCenter.default.post(name: .apexChatNotesUpdated, object: nil, userInfo: ["clientId": clientId])
    }

    func append(_ note: Note, to clientId: UUID) {
        lock.lock()
        var arr = clientIdToNotes[clientId] ?? []
        arr.append(note)
        clientIdToNotes[clientId] = arr
        lock.unlock()
        NotificationCenter.default.post(name: .apexChatNotesUpdated, object: nil, userInfo: ["clientId": clientId])
    }
}

extension Notification.Name {
    static let apexChatNotesUpdated = Notification.Name("apex.chatNotesUpdated")
}



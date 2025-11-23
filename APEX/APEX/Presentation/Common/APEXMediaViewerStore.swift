//
//  APEXMediaViewerStore.swift
//  APEX
//
//  Created by AI Assistant on 11/12/25.
//

import Foundation

final class APEXMediaViewerStore {
    static let shared = APEXMediaViewerStore()
    private init() {}
    
    private var storage: [UUID: APEXOpenMediaViewerPayload] = [:]
    private let lock = NSLock()
    
    func put(_ payload: APEXOpenMediaViewerPayload) {
        lock.lock()
        storage[payload.id] = payload
        lock.unlock()
    }
    
    func get(_ id: UUID) -> APEXOpenMediaViewerPayload? {
        lock.lock()
        let value = storage[id]
        lock.unlock()
        return value
    }
    
    func remove(_ id: UUID) {
        lock.lock()
        storage.removeValue(forKey: id)
        lock.unlock()
    }
}





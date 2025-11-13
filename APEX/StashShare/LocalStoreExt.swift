//
//  LocalStoreExt.swift
//  StashShare
//
//  Minimal persistence helper for Share Extension to read/write clients.json
//

import Foundation

final class LocalStoreExt {
    static let shared = LocalStoreExt()
    private init() {}
    
    private let fileName = "clients.json"
    private let appGroupId = "group.apex.StashShareExtension"
    
    private func containerDirectory() -> URL {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
            return containerURL
        }
        // Fallback for previews
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func clientsFileURL() -> URL {
        containerDirectory().appendingPathComponent(fileName)
    }
    
    func loadClients() -> [PClient] {
        let url = clientsFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([PClient].self, from: data)
            return decoded
        } catch {
            print("LocalStoreExt load error: \(error)")
            return []
        }
    }
    
    func saveClients(_ clients: [PClient]) {
        let url = clientsFileURL()
        do {
            let data = try JSONEncoder().encode(clients)
            let tmp = url.appendingPathExtension("tmp")
            try data.write(to: tmp, options: .atomic)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.moveItem(at: tmp, to: url)
        } catch {
            print("LocalStoreExt save error: \(error)")
        }
    }
}



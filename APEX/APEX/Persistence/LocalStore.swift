//
//  LocalStore.swift
//  APEX
//
//  Created by Assistant on 11/10/25.
//

import Foundation

final class LocalStore {
    static let shared = LocalStore()
    private init() {}
    
    private let fileName = "clients.json"
    
    // MARK: - Paths
    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func clientsFileURL() -> URL {
        documentsDirectory().appendingPathComponent(fileName)
    }
    
    // MARK: - Load / Save
    func loadClients() -> [Client]? {
        let url = clientsFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([PClient].self, from: data)
            return decoded.map { $0.toRuntime() }
        } catch {
            print("LocalStore load error: \(error)")
            return nil
        }
    }
    
    func saveClients(_ clients: [Client]) {
        let url = clientsFileURL()
        do {
            let persisted = clients.map { PClient(from: $0) }
            let data = try JSONEncoder().encode(persisted)
            let tmp = url.appendingPathExtension("tmp")
            try data.write(to: tmp, options: .atomic)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.moveItem(at: tmp, to: url)
        } catch {
            print("LocalStore save error: \(error)")
        }
    }
}



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
    private let appGroupId = "group.apex.StashShareExtension"
    
    // MARK: - Paths
    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func appGroupContainerDirectory() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
    }
    
    private func clientsFileURL() -> URL {
        documentsDirectory().appendingPathComponent(fileName)
    }
    
    private func clientsFileURLInAppGroup() -> URL? {
        appGroupContainerDirectory()?.appendingPathComponent(fileName)
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
    
    func loadClientsFromAppGroup() -> [Client]? {
        guard let url = clientsFileURLInAppGroup(),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([PClient].self, from: data)
            return decoded.map { $0.toRuntime() }
        } catch {
            print("LocalStore (AppGroup) load error: \(error)")
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
            
            // Mirror to App Group for Share Extension
            if let groupURL = clientsFileURLInAppGroup() {
                let tmpGroup = groupURL.appendingPathExtension("tmp")
                try data.write(to: tmpGroup, options: .atomic)
                if FileManager.default.fileExists(atPath: groupURL.path) {
                    try FileManager.default.removeItem(at: groupURL)
                }
                try FileManager.default.moveItem(at: tmpGroup, to: groupURL)
            }
        } catch {
            print("LocalStore save error: \(error)")
        }
    }
}



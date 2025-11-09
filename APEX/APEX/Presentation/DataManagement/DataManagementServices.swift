import Foundation
import UIKit

// MARK: - Models

struct DMContactUsage: Identifiable, Equatable {
    let id: UUID
    let name: String
    let initials: String
    let sizeText: String
    let image: UIImage?
}

// MARK: - Storage Sync

protocol StorageSyncService {
    func isAutoSyncOn() async throws -> Bool
    func setAutoSyncOn(_ on: Bool) async throws
    func refreshNow() async throws -> Date
    func lastSyncDate() async throws -> Date?
}

final class MockStorageSyncService: StorageSyncService {
    private var autoOn: Bool = false
    private var lastSync: Date? = ISO8601DateFormatter().date(from: "2025-10-15T20:30:00+09:00")

    func isAutoSyncOn() async throws -> Bool { autoOn }

    func setAutoSyncOn(_ on: Bool) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        autoOn = on
    }

    func refreshNow() async throws -> Date {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let now = Date()
        lastSync = now
        return now
    }

    func lastSyncDate() async throws -> Date? { lastSync }
}

// MARK: - Data Usage

protocol DataUsageService {
    func totalMediaSizeText() async throws -> String
    func contactUsages() async throws -> [DMContactUsage]
    func deleteAllMedia() async throws
    func deleteMedia(for contactId: UUID) async throws
}

final class MockDataUsageService: DataUsageService {
    private var totalText: String = "5.70 GB"
    private var contacts: [DMContactUsage] = [
        .init(id: UUID(), name: "Gyeong", initials: "G", sizeText: "816.45 MB", image: nil),
        .init(id: UUID(), name: "Daisy", initials: "D", sizeText: "816.45 MB", image: nil)
    ]

    func totalMediaSizeText() async throws -> String {
        try await Task.sleep(nanoseconds: 150_000_000)
        return totalText
    }

    func contactUsages() async throws -> [DMContactUsage] {
        try await Task.sleep(nanoseconds: 150_000_000)
        return contacts
    }

    func deleteAllMedia() async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        totalText = "0 GB"
    }

    func deleteMedia(for contactId: UUID) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        contacts.removeAll { $0.id == contactId }
    }
}

// MARK: - Real DataUsageService (computes from actual notes)
final class RealDataUsageService: DataUsageService {
    func totalMediaSizeText() async throws -> String {
        let allClients = ClientsStore.shared.clients
        var totalBytes: Int64 = 0
        for client in allClients {
            totalBytes &+= mediaBytes(for: client.id, fallbackNotes: client.notes)
        }
        return format(bytes: totalBytes)
    }
    
    func contactUsages() async throws -> [DMContactUsage] {
        let clients = ClientsStore.shared.clients
        var results: [DMContactUsage] = []
        results.reserveCapacity(clients.count)
        for client in clients {
            let bytes = mediaBytes(for: client.id, fallbackNotes: client.notes)
            let sizeText = format(bytes: bytes)
            let initials = makeInitials(surname: client.surname, name: client.name)
            results.append(.init(
                id: client.id,
                name: client.displayName,
                initials: initials,
                sizeText: sizeText,
                image: client.profile
            ))
        }
        // Sort by size desc, then name
        return results.sorted { lhs, rhs in
            bytesValue(from: lhs.sizeText) > bytesValue(from: rhs.sizeText) || (lhs.sizeText == rhs.sizeText && lhs.name < rhs.name)
        }
    }
    
    func deleteAllMedia() async throws {
        // Remove media from all clients: drop media-only notes, strip media from mixed notes
        let clients = ClientsStore.shared.clients
        for client in clients {
            try await deleteMedia(for: client.id)
        }
    }
    
    func deleteMedia(for contactId: UUID) async throws {
        // Update ChatStore notes
        let notes = ChatStore.shared.notes(for: contactId)
        if !notes.isEmpty {
            var updated: [Note] = []
            updated.reserveCapacity(notes.count)
            for var note in notes {
                if isMediaOnly(note) {
                    // drop media-only note entirely (no residual timestamp)
                    continue
                }
                if note.bundle != nil {
                    note.bundle = nil
                }
                updated.append(note)
            }
            ChatStore.shared.setNotes(updated, for: contactId)
        }
        // Update ClientsStore copy
        if let idx = ClientsStore.shared.clients.firstIndex(where: { $0.id == contactId }) {
            var client = ClientsStore.shared.clients[idx]
            if !client.notes.isEmpty {
                client.notes = client.notes.compactMap { n in
                    var m = n
                    if isMediaOnly(m) {
                        return nil
                    }
                    if m.bundle != nil {
                        m.bundle = nil
                    }
                    return m
                }
                ClientsStore.shared.update(client)
            }
        }
    }
}

// MARK: - Helpers
private extension RealDataUsageService {
    func isMediaOnly(_ note: Note) -> Bool {
        guard note.bundle != nil else { return false }
        let text = (note.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty
    }
    func mediaBytes(for clientId: UUID, fallbackNotes: [Note]) -> Int64 {
        let storeNotes = ChatStore.shared.notes(for: clientId)
        // Merge store + fallback, dedupe by id
        var seen = Set<UUID>()
        var merged: [Note] = []
        for n in storeNotes {
            if seen.insert(n.id).inserted { merged.append(n) }
        }
        for n in fallbackNotes {
            if seen.insert(n.id).inserted { merged.append(n) }
        }
        var total: Int64 = 0
        for note in merged {
            guard let bundle = note.bundle else { continue }
            switch bundle {
            case .media(let images, let videos):
                for img in images {
                    total &+= Int64(img.data.count)
                }
                for v in videos {
                    total &+= fileSize(at: v.url)
                }
            case .files(let files):
                for f in files {
                    total &+= fileSize(at: f.url)
                }
            case .audio(let audios):
                for a in audios {
                    total &+= fileSize(at: a.url)
                }
            }
        }
        return total
    }
    
    func fileSize(at url: URL) -> Int64 {
        // Only count local files
        guard url.isFileURL else { return 0 }
        if let values = try? url.resourceValues(forKeys: [.fileSizeKey]), let size = values.fileSize {
            return Int64(size)
        }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? NSNumber {
            return size.int64Value
        }
        return 0
    }
    
    func format(bytes: Int64) -> String {
        // 1024-based; show GB if >= 1 GB else MB
        let oneMB: Double = 1024 * 1024
        let oneGB: Double = oneMB * 1024
        let b = Double(bytes)
        if b >= oneGB {
            let val = (b / oneGB * 100).rounded() / 100
            return String(format: "%.2f GB", val)
        } else {
            let val = (b / oneMB * 100).rounded() / 100
            return String(format: "%.2f MB", val)
        }
    }
    
    // Best-effort parse back into bytes just for sorting purposes
    func bytesValue(from text: String) -> Int64 {
        let parts = text.split(separator: " ")
        guard parts.count == 2, let number = Double(parts[0]) else { return 0 }
        if parts[1].uppercased().hasPrefix("G") {
            return Int64(number * 1024 * 1024 * 1024)
        } else if parts[1].uppercased().hasPrefix("M") {
            return Int64(number * 1024 * 1024)
        } else {
            return 0
        }
    }
    
    func makeInitials(surname: String, name: String) -> String {
        let s = surname.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let sInitial = s.first.map { String($0) } ?? ""
        let nInitial = n.first.map { String($0) } ?? ""
        return sInitial + nInitial
    }
}

import Foundation
import UIKit

// MARK: - Sync Settings
struct SyncSettings {
    private static let autoKey = "apex.sync.auto"
    private static let lastKey = "apex.sync.lastDate"
    
    static var isAutoOn: Bool {
        get {
            // Default to ON when not set yet
            if UserDefaults.standard.object(forKey: autoKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: autoKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: autoKey) }
    }
    
    static var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: lastKey) as? Date }
        set {
            if let newDateValue = newValue {
                UserDefaults.standard.set(newDateValue, forKey: lastKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lastKey)
            }
        }
    }
}

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
    func setAutoSyncOn(_ isOn: Bool) async throws
    func refreshNow() async throws -> Date
    func lastSyncDate() async throws -> Date?
}

final class MockStorageSyncService: StorageSyncService {
    private var autoOn: Bool = false
    private var lastSync: Date? = ISO8601DateFormatter().date(from: "2025-10-15T20:30:00+09:00")

    func isAutoSyncOn() async throws -> Bool { autoOn }

    func setAutoSyncOn(_ isOn: Bool) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        autoOn = isOn
    }

    func refreshNow() async throws -> Date {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let now = Date()
        lastSync = now
        return now
    }

    func lastSyncDate() async throws -> Date? { lastSync }
}

// MARK: - Real Storage Sync
final class RealStorageSyncService: StorageSyncService {
    func isAutoSyncOn() async throws -> Bool {
        SyncSettings.isAutoOn
    }
    
    func setAutoSyncOn(_ isOn: Bool) async throws {
        SyncSettings.isAutoOn = isOn
        // Optionally kick a best-effort sync when enabling
        if isOn {
            _ = try? await refreshNow()
        }
    }
    
    func refreshNow() async throws -> Date {
        // Best-effort ensure subscription for silent pushes
        CloudKitManager.shared.ensureDatabaseSubscription()
        // Push any unsynced notes to CloudKit
        let clients = ClientsStore.shared.clients
        for client in clients {
            // Merge ChatStore + ClientsStore notes to cover open chats and persisted
            let storeNotes = ChatStore.shared.notes(for: client.id)
            var seen = Set<UUID>()
            var merged: [Note] = []
            for noteItem in storeNotes where seen.insert(noteItem.id).inserted { merged.append(noteItem) }
            for noteItem in client.notes where seen.insert(noteItem.id).inserted { merged.append(noteItem) }
            for note in merged {
                // Only create records for notes not yet mapped to CloudKit
                if !CloudKitNotesManager.shared.hasRecord(for: note.id) {
                    CloudKitNotesManager.shared.save(note: note, for: client.id)
                }
            }
        }
        // Pull latest notes from CloudKit and reflect into app immediately (even when auto-sync is off)
        // We update ChatStore only; ClientsStore will mirror via its NotificationCenter subscriber.
        for client in clients {
            CloudKitNotesManager.shared.fetchNotes(for: client.id) { result in
                if case .success(let fetched) = result {
                    DispatchQueue.main.async {
                        // Merge: preserve local STT text if CloudKit is empty
                        let local = ChatStore.shared.notes(for: client.id)
                        var merged = fetched
                        for idx in merged.indices {
                            if let lidx = local.firstIndex(where: { $0.id == merged[idx].id }) {
                                let localText = local[lidx].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                let cloudText = merged[idx].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                if !localText.isEmpty && cloudText.isEmpty {
                                    merged[idx].text = local[lidx].text
                                }
                            }
                        }
                        ChatStore.shared.setNotes(merged, for: client.id)
                    }
                }
            }
        }
        let now = Date()
        SyncSettings.lastSyncDate = now
        return now
    }
    
    func lastSyncDate() async throws -> Date? {
        SyncSettings.lastSyncDate
    }
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
            var removedNoteIds: [UUID] = []
            var changedNoteIds: [UUID] = []
            updated.reserveCapacity(notes.count)
            for var noteItem in notes {
                if isMediaOnly(noteItem) {
                    // drop media-only note entirely (no residual timestamp)
                    removedNoteIds.append(noteItem.id)
                    continue
                }
                if noteItem.bundle != nil {
                    noteItem.bundle = nil
                    changedNoteIds.append(noteItem.id)
                }
                updated.append(noteItem)
            }
            ChatStore.shared.setNotes(updated, for: contactId)
            if SyncSettings.isAutoOn {
                for id in changedNoteIds {
                    if let idx = updated.firstIndex(where: { $0.id == id }) {
                        CloudKitNotesManager.shared.rewriteAssets(noteId: id, bundle: updated[idx].bundle)
                    }
                }
                for id in removedNoteIds {
                    CloudKitNotesManager.shared.delete(noteId: id)
                }
            }
        }
        // Update ClientsStore copy
        if let idx = ClientsStore.shared.clients.firstIndex(where: { $0.id == contactId }) {
            var client = ClientsStore.shared.clients[idx]
            if !client.notes.isEmpty {
                client.notes = client.notes.compactMap { current in
                    var mutable = current
                    if isMediaOnly(mutable) { return nil }
                    if mutable.bundle != nil { mutable.bundle = nil }
                    return mutable
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
        for noteItem in storeNotes where seen.insert(noteItem.id).inserted {
            merged.append(noteItem)
        }
        for noteItem in fallbackNotes where seen.insert(noteItem.id).inserted {
            merged.append(noteItem)
        }
        var total: Int64 = 0
        for note in merged {
            guard let bundle = note.bundle else { continue }
            switch bundle {
            case .media(let images, let videos):
                for img in images {
                    total &+= Int64(img.data.count)
                }
                for videoAttachment in videos {
                    total &+= fileSize(at: videoAttachment.url)
                }
            case .files(let files):
                for fileAttachment in files {
                    total &+= fileSize(at: fileAttachment.url)
                }
            case .audio(let audios):
                for audioAttachment in audios {
                    total &+= fileSize(at: audioAttachment.url)
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
        let bytesDouble = Double(bytes)
        if bytesDouble >= oneGB {
            let val = (bytesDouble / oneGB * 100).rounded() / 100
            return String(format: "%.2f GB", val)
        } else {
            let val = (bytesDouble / oneMB * 100).rounded() / 100
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
        let trimmedSurname = surname.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let surnameInitial = trimmedSurname.first.map { String($0) } ?? ""
        let nameInitial = trimmedName.first.map { String($0) } ?? ""
        return surnameInitial + nameInitial
    }
}

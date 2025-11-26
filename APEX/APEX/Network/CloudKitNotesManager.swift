//
//  CloudKitNotesManager.swift
//  APEX
//
//  Sync Note / NoteAsset with CloudKit.
//

import Foundation
import CloudKit
import UniformTypeIdentifiers
import UIKit
import CryptoKit

final class CloudKitNotesManager {
    static let shared = CloudKitNotesManager()
    private init() {}

    private let noteMapKey = "cloudkit.mapping.noteIdToRecordName"
    
    // Expose read-only mapping existence for sync decisions
    func hasRecord(for noteId: UUID) -> Bool {
        noteRecordID(for: noteId) != nil
    }

    // MARK: - Public API
    /// Fetch notes for a client from CloudKit and reconstruct their assets.
    func fetchNotes(for clientId: UUID, completion: @escaping (Result<[Note], Error>) -> Void) {
        guard !UserDefaults.standard.bool(forKey: "apex.isGuestMode") else {
            completion(.success([])); return
        }
        guard let clientRecordID = ClientsStore.shared.cloudKitRecordIDForClient(clientId) else {
            completion(.success([])); return
        }
        let pred = NSPredicate(format: "clientRef == %@", clientRecordID)
        let sort = NSSortDescriptor(key: "uploadedAt", ascending: true)
        CloudKitManager.shared.query(type: "Note", predicate: pred, sortDescriptors: [sort]) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let records):
                var notes: [Note] = []
                let group = DispatchGroup()
                var buildErrors: [Error] = []
                let lock = NSLock()
                for rec in records {
                    group.enter()
                    let uploadedAt = (rec["uploadedAt"] as? Date) ?? Date()
                    let text = rec["text"] as? String
                    // Reuse existing noteId mapping if available; otherwise create and store
                    let noteId: UUID = self.noteId(for: rec.recordID) ?? {
                        let newId = UUID()
                        self.setNoteRecordID(rec.recordID, for: newId)
                        return newId
                    }()
                    // Fetch assets for this note
                    let apred = NSPredicate(format: "noteRef == %@", rec.recordID)
                    CloudKitManager.shared.query(type: "NoteAsset", predicate: apred) { ar in
                        switch ar {
                        case .failure(let e):
                            lock.lock()
                            buildErrors.append(e)
                            lock.unlock()
                            let n = Note(uploadedAt: uploadedAt, text: text, bundle: nil)
                            lock.lock()
                            notes.append(n)
                            lock.unlock()
                            group.leave()
                        case .success(let assetRecs):
                            var images: [ImageAttachment] = []
                            var videos: [VideoAttachment] = []
                            var files: [FileAttachment] = []
                            var audios: [AudioAttachment] = []
                            // Sort by orderIndex if present
                            let ordered = assetRecs.sorted {
                                let a = ($0["orderIndex"] as? NSNumber)?.intValue ?? 0
                                let b = ($1["orderIndex"] as? NSNumber)?.intValue ?? 0
                                return a < b
                            }
                            for a in ordered {
                                guard let kind = a["kind"] as? String else { continue }
                                let url = (a["asset"] as? CKAsset)?.fileURL
                                let filenameField = a["filename"] as? String
                                switch kind {
                                case "image":
                                    if let url, let data = try? Data(contentsOf: url) {
                                        let order = (a["orderIndex"] as? NSNumber)?.intValue
                                        images.append(ImageAttachment(data: data, progress: nil, orderIndex: order))
                                    }
                                case "video":
                                    if let url {
                                        let cached = self.persistVideoToAppGroup(originalURL: url, preferredFilename: filenameField)
                                        let order = (a["orderIndex"] as? NSNumber)?.intValue
                                        videos.append(VideoAttachment(url: cached, progress: nil, orderIndex: order))
                                    }
                                case "file":
                                    if let url {
                                        let cached = self.persistGenericFileToAppGroup(originalURL: url, preferredFilename: filenameField)
                                        let utid = (a["contentType"] as? String).flatMap { UTType($0) }
                                        files.append(FileAttachment(url: cached, contentType: utid, progress: nil))
                                    }
                                case "audio":
                                    if let url {
                                        let cached = self.persistAudioToAppGroup(originalURL: url, preferredFilename: filenameField)
                                        let dur = (a["duration"] as? NSNumber)?.doubleValue
                                        audios.append(AudioAttachment(url: cached, duration: dur))
                                    }
                                default:
                                    break
                                }
                            }
                            var bundle: AttachmentBundle? = nil
                            if !images.isEmpty || !videos.isEmpty {
                                bundle = .media(images: images, videos: videos)
                            } else if !files.isEmpty {
                                bundle = .files(files)
                            } else if !audios.isEmpty {
                                bundle = .audio(audios)
                            }
                            let n = Note(id: noteId, uploadedAt: uploadedAt, text: text, bundle: bundle)
                            lock.lock()
                            notes.append(n)
                            lock.unlock()
                            group.leave()
                        }
                    }
                }
                group.notify(queue: .main) {
                    if let err = buildErrors.first {
                        completion(.failure(err))
                    } else {
                        // Ensure stable ordering: oldest at top, newest at bottom
                        let sorted = notes.sorted { $0.uploadedAt < $1.uploadedAt }
                        completion(.success(sorted))
                    }
                }
            }
        }
    }
    func save(note: Note, for clientId: UUID) {
        guard !UserDefaults.standard.bool(forKey: "apex.isGuestMode") else { return }
        guard let clientRecordID = ClientsStore.shared.cloudKitRecordIDForClient(clientId) else { return }

        var fields: [String: CKRecordValueProtocol] = [
            "uploadedAt": note.uploadedAt as NSDate
        ]
        if let text = note.text { fields["text"] = text as NSString }
        fields["clientRef"] = CKRecord.Reference(recordID: clientRecordID, action: .none)

        CloudKitManager.shared.saveRecord(type: "Note", fields: fields) { [weak self] result in
            guard let self else { return }
            if case .success(let saved) = result {
                self.setNoteRecordID(saved.recordID, for: note.id)
                self.createAssetsIfNeeded(for: note, noteRecordID: saved.recordID, clientId: clientId)
            }
        }
    }

    func updateText(noteId: UUID, newText: String?) {
        guard let recordID = noteRecordID(for: noteId) else { return }
        var fields: [String: CKRecordValueProtocol] = [:]
        var clear: [String] = []
        if let t = newText, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields["text"] = t as NSString
        } else {
            clear.append("text")
        }
        CloudKitManager.shared.updateRecord(recordID: recordID, fields: fields, clearKeys: clear, completion: nil)
    }

    func delete(noteId: UUID) {
        guard let recordID = noteRecordID(for: noteId) else { return }
        CloudKitManager.shared.deleteRecord(recordID: recordID) { [weak self] _ in
            self?.removeNoteRecordID(for: noteId)
        }
    }

    // MARK: - Assets
    private func createAssetsIfNeeded(for note: Note, noteRecordID: CKRecord.ID, clientId: UUID) {
        guard let bundle = note.bundle else { return }
        var remaining = 0
        func onOneSaved() {
            remaining -= 1
            if remaining == 0 {
                // After all assets saved, refresh from CloudKit and apply to ChatStore
                self.fetchNotes(for: clientId) { result in
                    if case .success(let fetched) = result {
                        DispatchQueue.main.async {
                            // Merge fetched notes with current local notes to avoid dropping
                            // just-uploaded items due to CloudKit eventual consistency.
                            let local = ChatStore.shared.notes(for: clientId)
                            var merged = fetched
                            // Preserve local STT text if CloudKit text is empty
                            // Preserve local bundle if CloudKit bundle is nil/empty (assets not yet visible)
                            for idx in merged.indices {
                                if let lidx = local.firstIndex(where: { $0.id == merged[idx].id }) {
                                    let localText = local[lidx].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                    let cloudText = merged[idx].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                    if !localText.isEmpty && cloudText.isEmpty {
                                        merged[idx].text = local[lidx].text
                                    }
                                    if merged[idx].bundle.isNilOrEmpty, let localBundle = local[lidx].bundle, !localBundle.isEmpty {
                                        merged[idx].bundle = localBundle
                                    }
                                }
                            }
                            // Include local-only notes that are not yet visible from CloudKit
                            for localNote in local where !merged.contains(where: { $0.id == localNote.id }) {
                                merged.append(localNote)
                            }
                            let sorted = merged.sorted { $0.uploadedAt < $1.uploadedAt }
                            ChatStore.shared.setNotes(sorted, for: clientId)
                        }
                    }
                }
            }
        }
        switch bundle {
        case .media(let images, let videos):
            remaining += images.count + videos.count
            for (idx, img) in images.enumerated() {
                if let ui = UIImage(data: img.data),
                   let asset = CloudKitManager.shared.makeAsset(from: ui, compressionQuality: 1.0) {
                    var fields: [String: CKRecordValueProtocol] = [:]
                    fields["kind"] = "image" as NSString
                    fields["asset"] = asset
                    fields["orderIndex"] = NSNumber(value: img.orderIndex ?? idx)
                    fields["imageKey"] = (self.makeImageKey(from: img.data) as NSString)
                    fields["noteRef"] = CKRecord.Reference(recordID: noteRecordID, action: .none)
                    CloudKitManager.shared.saveRecord(type: "NoteAsset", fields: fields) { _ in
                        onOneSaved()
                    }
                } else {
                    onOneSaved()
                }
            }
            for (idx, vid) in videos.enumerated() {
                var fields: [String: CKRecordValueProtocol] = [:]
                fields["kind"] = "video" as NSString
                fields["orderIndex"] = NSNumber(value: vid.orderIndex ?? idx)
                if let asset = assetFromFileURL(vid.url) { fields["asset"] = asset }
                fields["filename"] = (vid.url.lastPathComponent as NSString)
                fields["noteRef"] = CKRecord.Reference(recordID: noteRecordID, action: .none)
                CloudKitManager.shared.saveRecord(type: "NoteAsset", fields: fields) { _ in
                    onOneSaved()
                }
            }
        case .files(let files):
            remaining += files.count
            for f in files {
                var fields: [String: CKRecordValueProtocol] = [:]
                fields["kind"] = "file" as NSString
                if let asset = assetFromFileURL(f.url) { fields["asset"] = asset }
                if let ut = f.contentType { fields["contentType"] = (ut.identifier as NSString) }
                fields["filename"] = (f.url.lastPathComponent as NSString)
                fields["noteRef"] = CKRecord.Reference(recordID: noteRecordID, action: .none)
                CloudKitManager.shared.saveRecord(type: "NoteAsset", fields: fields) { _ in
                    onOneSaved()
                }
            }
        case .audio(let audios):
            remaining += audios.count
            for a in audios {
                var fields: [String: CKRecordValueProtocol] = [:]
                fields["kind"] = "audio" as NSString
                if let asset = assetFromFileURL(a.url) { fields["asset"] = asset }
                if let dur = a.duration { fields["duration"] = NSNumber(value: dur) }
                fields["filename"] = (a.url.lastPathComponent as NSString)
                fields["noteRef"] = CKRecord.Reference(recordID: noteRecordID, action: .none)
                CloudKitManager.shared.saveRecord(type: "NoteAsset", fields: fields) { _ in
                    onOneSaved()
                }
            }
        }
    }

    private func assetFromFileURL(_ url: URL) -> CKAsset? {
        return CKAsset(fileURL: url)
    }

    // Persist CKAsset file URLs into App Group for stable availability across launches.
    private func persistVideoToAppGroup(originalURL: URL, preferredFilename: String?) -> URL {
        persistToAppGroup(originalURL: originalURL, folder: "SharedVideos", preferredFilename: preferredFilename)
    }
    private func persistGenericFileToAppGroup(originalURL: URL, preferredFilename: String?) -> URL {
        persistToAppGroup(originalURL: originalURL, folder: "SharedFiles", preferredFilename: preferredFilename)
    }
    private func persistAudioToAppGroup(originalURL: URL, preferredFilename: String?) -> URL {
        persistToAppGroup(originalURL: originalURL, folder: "SharedAudios", preferredFilename: preferredFilename)
    }
    private func persistToAppGroup(originalURL: URL, folder: String, preferredFilename: String?) -> URL {
        let fm = FileManager.default
        guard let base = fm.containerURL(forSecurityApplicationGroupIdentifier: "group.apex.StashShareExtension") else {
            return originalURL
        }
        let dir = base.appendingPathComponent(folder, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        // Prefer provided filename (from CloudKit record) to avoid random temp names
        let preferredBase = preferredFilename.flatMap { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
        let preferredExt = preferredFilename.flatMap { URL(fileURLWithPath: $0).pathExtension }
        let baseCandidate = (preferredBase?.isEmpty == false ? preferredBase! : originalURL.deletingPathExtension().lastPathComponent)
        let extCandidate = (preferredExt?.isEmpty == false ? preferredExt! : (originalURL.pathExtension.isEmpty ? "bin" : originalURL.pathExtension))
        var target = dir.appendingPathComponent(baseCandidate).appendingPathExtension(extCandidate)
        // If exact target already exists, reuse it to avoid suffix inflation (-1, -2, ...)
        if fm.fileExists(atPath: target.path) {
            return target
        }
        var suffix = 1
        while fm.fileExists(atPath: target.path) {
            let candidateName = "\(baseCandidate)-\(suffix)"
            target = dir.appendingPathComponent(candidateName).appendingPathExtension(extCandidate)
            suffix += 1
        }
        if originalURL.path.hasPrefix(dir.path) {
            return originalURL
        }
        do {
            try fm.copyItem(at: originalURL, to: target)
            return target
        } catch {
            if let data = try? Data(contentsOf: originalURL) {
                try? data.write(to: target, options: .atomic)
                return target
            }
            return originalURL
        }
    }

    /// Rewrite assets of a note to match the given bundle by:
    /// - Deleting removed assets
    /// - Updating orderIndex of retained assets (without touching creation date)
    /// - Creating new assets when needed
    func rewriteAssets(noteId: UUID, bundle: AttachmentBundle?) {
        guard let noteRecordID = noteRecordID(for: noteId) else { return }
        // Fetch all existing assets for this note
        let pred = NSPredicate(format: "noteRef == %@", noteRecordID)
        CloudKitManager.shared.query(type: "NoteAsset", predicate: pred) { result in
            switch result {
            case .failure:
                break
            case .success(let records):
                guard let bundle else {
                    // No bundle means remove all assets
                    for rec in records {
                        CloudKitManager.shared.deleteRecord(recordID: rec.recordID, completion: nil)
                    }
                    return
                }
                // Build maps of existing assets by stable key
                // - image: imageKey (hash of data at creation time)
                // - video/file/audio: filename (lastPathComponent)
                struct Existing {
                    let record: CKRecord
                    let kind: String
                }
                var existingByKey: [String: Existing] = [:]
                for rec in records {
                    let kind = rec["kind"] as? String ?? ""
                    if kind == "image", let key = rec["imageKey"] as? String {
                        existingByKey[key] = Existing(record: rec, kind: kind)
                    } else if let filename = rec["filename"] as? String {
                        existingByKey["\(kind)|\(filename)"] = Existing(record: rec, kind: kind)
                    }
                }
                // Build desired list with keys and orders
                struct Desired {
                    let key: String
                    let kind: String
                    let order: Int
                    let imgData: Data?
                    let fileURL: URL?
                    let duration: Double?
                    let contentType: UTType?
                }
                var desired: [Desired] = []
                switch bundle {
                case .media(let images, let videos):
                    for (i, img) in images.enumerated() {
                        let order = img.orderIndex ?? i
                        let key = self.makeImageKey(from: img.data)
                        desired.append(Desired(key: key, kind: "image", order: order, imgData: img.data, fileURL: nil, duration: nil, contentType: nil))
                    }
                    for (i, vid) in videos.enumerated() {
                        let order = vid.orderIndex ?? (images.count + i)
                        let filename = vid.url.lastPathComponent
                        desired.append(Desired(key: "video|\(filename)", kind: "video", order: order, imgData: nil, fileURL: vid.url, duration: nil, contentType: nil))
                    }
                case .files(let files):
                    for (i, f) in files.enumerated() {
                        let filename = f.url.lastPathComponent
                        desired.append(Desired(key: "file|\(filename)", kind: "file", order: i, imgData: nil, fileURL: f.url, duration: nil, contentType: f.contentType))
                    }
                case .audio(let audios):
                    for (i, a) in audios.enumerated() {
                        let filename = a.url.lastPathComponent
                        desired.append(Desired(key: "audio|\(filename)", kind: "audio", order: i, imgData: nil, fileURL: a.url, duration: a.duration, contentType: nil))
                    }
                }
                // Update existing (only orderIndex), create missing, delete stale
                var seenKeys: Set<String> = []
                for item in desired {
                    seenKeys.insert(item.key)
                    if let ex = existingByKey[item.key] {
                        // Update only orderIndex if changed
                        let rec = ex.record
                        let currentOrder = (rec["orderIndex"] as? NSNumber)?.intValue
                        if currentOrder != item.order {
                            CloudKitManager.shared.updateRecord(recordID: rec.recordID, fields: ["orderIndex": NSNumber(value: item.order)], clearKeys: [], completion: nil)
                        }
                    } else {
                        // Create new
                        var fields: [String: CKRecordValueProtocol] = [:]
                        fields["kind"] = item.kind as NSString
                        fields["orderIndex"] = NSNumber(value: item.order)
                        if item.kind == "image", let data = item.imgData, let ui = UIImage(data: data), let asset = CloudKitManager.shared.makeAsset(from: ui, compressionQuality: 1.0) {
                            fields["asset"] = asset
                            fields["imageKey"] = (self.makeImageKey(from: data) as NSString)
                        }
                        if item.kind != "image", let url = item.fileURL, let asset = self.assetFromFileURL(url) {
                            fields["asset"] = asset
                            fields["filename"] = (url.lastPathComponent as NSString)
                        }
                        if item.kind == "file", let ut = item.contentType {
                            fields["contentType"] = (ut.identifier as NSString)
                        }
                        if item.kind == "audio", let dur = item.duration {
                            fields["duration"] = NSNumber(value: dur)
                        }
                        fields["noteRef"] = CKRecord.Reference(recordID: noteRecordID, action: .none)
                        CloudKitManager.shared.saveRecord(type: "NoteAsset", fields: fields, completion: nil)
                    }
                }
                // Delete stale
                for (key, ex) in existingByKey where !seenKeys.contains(key) {
                    CloudKitManager.shared.deleteRecord(recordID: ex.record.recordID, completion: nil)
                }
            }
        }
    }

    // MARK: - Mapping
    private func loadNoteMap() -> [String: String] {
        (UserDefaults.standard.dictionary(forKey: noteMapKey) as? [String: String]) ?? [:]
    }
    private func saveNoteMap(_ map: [String: String]) {
        UserDefaults.standard.set(map, forKey: noteMapKey)
    }
    private func noteRecordID(for noteId: UUID) -> CKRecord.ID? {
        let map = loadNoteMap()
        guard let name = map[noteId.uuidString] else { return nil }
        return CKRecord.ID(recordName: name)
    }
    /// Reverse lookup: find existing noteId for a given CloudKit recordID if mapped
    private func noteId(for recordID: CKRecord.ID) -> UUID? {
        let map = loadNoteMap() // [noteIdString: recordName]
        let recordName = recordID.recordName
        if let pair = map.first(where: { $0.value == recordName }) {
            return UUID(uuidString: pair.key)
        }
        return nil
    }
    private func setNoteRecordID(_ id: CKRecord.ID, for noteId: UUID) {
        var map = loadNoteMap()
        map[noteId.uuidString] = id.recordName
        saveNoteMap(map)
    }
    private func removeNoteRecordID(for noteId: UUID) {
        var map = loadNoteMap()
        map.removeValue(forKey: noteId.uuidString)
        saveNoteMap(map)
    }
    
    // Remove local App Group copies after successful CloudKit upload to free device storage.
    private func deleteLocalIfInAppGroup(_ url: URL) {
        guard url.isFileURL else { return }
        guard let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.apex.StashShareExtension") else { return }
        let prefixes = [
            base.appendingPathComponent("SharedVideos", isDirectory: true).path,
            base.appendingPathComponent("SharedFiles", isDirectory: true).path,
            base.appendingPathComponent("SharedAudios", isDirectory: true).path
        ]
        if prefixes.contains(where: { url.path.hasPrefix($0) }) {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    // MARK: - Keys
    private func makeImageKey(from data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}







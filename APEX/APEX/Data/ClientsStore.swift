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
import CloudKit

@MainActor
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
                if SyncSettings.isAutoOn {
                    self.pullAllClientNotesFromCloudKit()
                }
            }
            .store(in: &cancellables)

        // React to CloudKit DB change notifications by pulling latest minimal client list.
        NotificationCenter.default.publisher(for: .cloudKitDatabaseDidChange)
            .sink { [weak self] _ in
                guard SyncSettings.isAutoOn else { return }
                self?.pullClientsFromCloudKit()
                self?.pullUserFromCloudKit()
                self?.pullAllClientNotesFromCloudKit()
            }
            .store(in: &cancellables)

        // Attempt a lightweight initial pull so UI can reflect server state quickly.
        if SyncSettings.isAutoOn {
            DispatchQueue.main.async {
                self.pullClientsFromCloudKit()
                self.pullUserFromCloudKit()
                self.pullAllClientNotesFromCloudKit()
            }
        }
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

    // MARK: - CloudKit lightweight sync (Clients only)
    /// Pull clients from CloudKit and replace in-memory list except index 0 ("my profile") which is preserved.
    private func pullClientsFromCloudKit() {
        // Respect guest mode: skip CloudKit access
        if UserDefaults.standard.bool(forKey: "apex.isGuestMode") {
            return
        }
        let sort = NSSortDescriptor(key: "surname", ascending: true)
        CloudKitManager.shared.query(type: "Client", predicate: NSPredicate(value: true), sortDescriptors: [sort]) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                print("[ClientsStore] CloudKit pull failed: \(error)")
            case .success(let records):
                // Build (Client, RecordID) pairs so we can store mapping for update/delete later.
                // Preserve stable client IDs by reusing existing ID mapped to the record or matching by identity
                let idMap = self.loadIdMap()               // clientId.uuidString -> recordName
                let reverseMap: [String: UUID] = {
                    var r: [String: UUID] = [:]
                    for (k, v) in idMap {
                        if let u = UUID(uuidString: k) { r[v] = u }
                    }
                    return r
                }()
                let existing = self.clients
                let pairs: [(Client, CKRecord.ID)] = records.map { rec in
                    let surname = rec["surname"] as? String ?? ""
                    let name = rec["name"] as? String ?? ""
                    let position = rec["position"] as? String
                    let company = rec["company"] as? String ?? ""
                    let department = rec["department"] as? String
                    let email = rec["email"] as? String
                    let phoneNumber = rec["phoneNumber"] as? String
                    let linkedinURL = rec["linkedinURL"] as? String
                    let memo = rec["memo"] as? String
                    let action = rec["action"] as? String
                    // Optional business fields
                    let industry = rec["industry"] as? String
                    let address = rec["address"] as? String
                    let faxNumber = rec["faxNumber"] as? String
                    let revenue = rec["revenue"] as? String
                    let employees = rec["employees"] as? String
                    // Lists (may come as [String] or [NSString])
                    let additionalEmails: [String] = (rec["additionalEmails"] as? [String])
                        ?? (rec["additionalEmails"] as? [NSString])?.map { $0 as String } ?? []
                    let additionalPhones: [String] = (rec["additionalPhones"] as? [String])
                        ?? (rec["additionalPhones"] as? [NSString])?.map { $0 as String } ?? []
                    let additionalURLs: [String] = (rec["additionalURLs"] as? [String])
                        ?? (rec["additionalURLs"] as? [NSString])?.map { $0 as String } ?? []
                    let favoriteInt = (rec["favorite"] as? NSNumber)?.intValue ?? 0
                    let pinInt = (rec["pin"] as? NSNumber)?.intValue ?? 0
                    var profileImage: UIImage? = nil
                    if let asset = rec["profileAsset"] as? CKAsset, let url = asset.fileURL, let data = try? Data(contentsOf: url) {
                        profileImage = UIImage(data: data)
                    }
                    var nameCardFrontImage: Image? = nil
                    if let asset = rec["nameCardFrontAsset"] as? CKAsset, let url = asset.fileURL, let data = try? Data(contentsOf: url), let ui = UIImage(data: data) {
                        nameCardFrontImage = Image(uiImage: ui)
                    }
                    var nameCardBackImage: Image? = nil
                    if let asset = rec["nameCardBackAsset"] as? CKAsset, let url = asset.fileURL, let data = try? Data(contentsOf: url), let ui = UIImage(data: data) {
                        nameCardBackImage = Image(uiImage: ui)
                    }
                    // Determine stable ID:
                    // 1) If we already mapped this recordName, reuse that UUID
                    // 2) Else try to find an existing client with same identity (email or name+surname+company)
                    // 3) Else generate new UUID (initializer default)
                    let recordName = rec.recordID.recordName
                    let preservedId: UUID? = reverseMap[recordName] ?? {
                        let meEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        if let meEmail, !meEmail.isEmpty,
                           let match = existing.first(where: { ($0.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) == meEmail }) {
                            return match.id
                        }
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedSurname = surname.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedCompany = company.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let match = existing.first(where: {
                            $0.name.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedName &&
                            $0.surname.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedSurname &&
                            $0.company.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedCompany
                        }) {
                            return match.id
                        }
                        return nil
                    }()
                    let c = Client(
                        id: preservedId ?? UUID(),
                        profile: profileImage,
                        nameCardFront: nameCardFrontImage,
                        nameCardBack: nameCardBackImage,
                        surname: surname,
                        name: name,
                        position: position,
                        company: company,
                        department: department,
                        email: email,
                        phoneNumber: phoneNumber,
                        linkedinURL: linkedinURL,
                        memo: memo,
                        action: action,
                        favorite: favoriteInt != 0,
                        pin: pinInt != 0,
                        notes: [],
                        industry: industry, address: address, faxNumber: faxNumber, revenue: revenue, employees: employees,
                        additionalEmails: additionalEmails.prefix(5).map { $0 },
                        additionalPhones: additionalPhones.prefix(5).map { $0 },
                        additionalURLs: additionalURLs.prefix(5).map { $0 }
                    )
                    return (c, rec.recordID)
                }
                // Map to Client list
                var mapped = pairs.map { $0.0 }
                // Exclude "my profile" duplicates coming from server-side Client records
                if let myProfile = self.clients.first {
                    let meName = myProfile.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let meSurname = myProfile.surname.trimmingCharacters(in: .whitespacesAndNewlines)
                    let meCompany = myProfile.company.trimmingCharacters(in: .whitespacesAndNewlines)
                    let meEmail = myProfile.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    mapped.removeAll { candidate in
                        let candName = candidate.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let candSurname = candidate.surname.trimmingCharacters(in: .whitespacesAndNewlines)
                        let candCompany = candidate.company.trimmingCharacters(in: .whitespacesAndNewlines)
                        let candEmail = candidate.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        // If email matches, treat as self
                        if let meEmail, let candEmail, !meEmail.isEmpty, meEmail == candEmail { return true }
                        // Otherwise, if name+surname(+company) identical, also treat as self
                        if candName == meName && candSurname == meSurname && candCompany == meCompany { return true }
                        return false
                    }
                }
                DispatchQueue.main.async {
                    var newList = self.clients
                    if newList.indices.contains(0) {
                        // Replace items after index 0 (keep "my profile" entry)
                        let range = (newList.count > 1) ? 1..<newList.count : 1..<1
                        newList.replaceSubrange(range, with: mapped)
                    } else {
                        newList = mapped
                    }
                    self.clients = newList
                    // Persist mapping for later updates/deletes
                    for (client, recordID) in pairs {
                        self.setCloudKitRecordID(recordID, for: client.id)
                    }
                }
            }
        }
    }

    /// Pull current user's profile from Users record type and merge into index 0.
    private func pullUserFromCloudKit() {
        if UserDefaults.standard.bool(forKey: "apex.isGuestMode") { return }
        CloudKitManager.shared.query(type: "AppUser") { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure:
                break
            case .success(let records):
                guard let rec = records.first else { return }
                let surname = rec["surname"] as? String ?? ""
                let name = rec["name"] as? String ?? ""
                let position = rec["position"] as? String
                let company = rec["company"] as? String ?? ""
                let department = rec["department"] as? String
                let email = rec["email"] as? String
                let phoneNumber = rec["phoneNumber"] as? String
                let linkedinURL = rec["linkedinURL"] as? String
                let memo = rec["memo"] as? String
                let industry = rec["industry"] as? String
                let address = rec["address"] as? String
                let faxNumber = rec["faxNumber"] as? String
                let revenue = rec["revenue"] as? String
                let employees = rec["employees"] as? String
                let additionalEmails: [String] = (rec["additionalEmails"] as? [String])
                    ?? (rec["additionalEmails"] as? [NSString])?.map { $0 as String } ?? []
                let additionalPhones: [String] = (rec["additionalPhones"] as? [String])
                    ?? (rec["additionalPhones"] as? [NSString])?.map { $0 as String } ?? []
                let additionalURLs: [String] = (rec["additionalURLs"] as? [String])
                    ?? (rec["additionalURLs"] as? [NSString])?.map { $0 as String } ?? []
                var profileImage: UIImage? = nil
                if let asset = rec["profileAsset"] as? CKAsset, let url = asset.fileURL, let data = try? Data(contentsOf: url) {
                    profileImage = UIImage(data: data)
                }
                var nameCardFrontImage: Image? = nil
                if let asset = rec["nameCardFrontAsset"] as? CKAsset, let url = asset.fileURL, let data = try? Data(contentsOf: url), let ui = UIImage(data: data) {
                    nameCardFrontImage = Image(uiImage: ui)
                }
                var nameCardBackImage: Image? = nil
                if let asset = rec["nameCardBackAsset"] as? CKAsset, let url = asset.fileURL, let data = try? Data(contentsOf: url), let ui = UIImage(data: data) {
                    nameCardBackImage = Image(uiImage: ui)
                }
                DispatchQueue.main.async {
                    if self.clients.isEmpty {
                        self.clients.insert(ClientsStore.makeBlankMyProfile(), at: 0)
                    }
                    var me = self.clients[0]
                    me = Client(
                        id: me.id,
                        profile: profileImage ?? me.profile,
                        nameCardFront: nameCardFrontImage ?? me.nameCardFront,
                        nameCardBack: nameCardBackImage ?? me.nameCardBack,
                        surname: surname,
                        name: name,
                        position: position,
                        company: company,
                        department: department,
                        email: email,
                        phoneNumber: phoneNumber,
                        linkedinURL: linkedinURL,
                        memo: memo,
                        action: me.action,
                        favorite: me.favorite,
                        pin: me.pin,
                        notes: me.notes,
                        industry: industry,
                        address: address,
                        faxNumber: faxNumber,
                        revenue: revenue,
                        employees: employees,
                        additionalEmails: additionalEmails.prefix(5).map { $0 },
                        additionalPhones: additionalPhones.prefix(5).map { $0 },
                        additionalURLs: additionalURLs.prefix(5).map { $0 }
                    )
                    self.clients[0] = me
                    // store mapping for user
                    self.setUserRecordID(rec.recordID)
                }
            }
        }
    }

    func add(_ client: Client, atTop: Bool = true) {
        if atTop {
            // Keep index 0 reserved for 'my profile'
            let insertIndex = clients.isEmpty ? 0 : 1
            clients.insert(client, at: insertIndex)
            // Do not sync "my profile" (index 0) to CloudKit
            if insertIndex != 0, SyncSettings.isAutoOn {
                syncNewClientToCloudKit(client)
            }
        } else {
            clients.append(client)
            if SyncSettings.isAutoOn {
                syncNewClientToCloudKit(client)
            }
        }
    }

    func update(_ client: Client) {
        if let idx = clients.firstIndex(where: { $0.id == client.id }) {
            clients[idx] = client
            // Skip my-profile index 0 mapping to CloudKit
            if SyncSettings.isAutoOn {
                if idx != 0 {
                    syncUpdateClientToCloudKit(client)
                } else {
                    syncUserToCloudKit(client)
                }
            }
        }
    }

    // MARK: - CloudKit writes
    private func syncNewClientToCloudKit(_ client: Client) {
        // Skip when guest mode
        if UserDefaults.standard.bool(forKey: "apex.isGuestMode") {
            return
        }
        // Map booleans to Int64 fields as defined in schema
        var fields: [String: CKRecordValueProtocol] = [
            "surname": (client.surname as NSString),
            "name": (client.name as NSString),
            "company": (client.company as NSString),
            "favorite": NSNumber(value: client.favorite ? 1 : 0),
            "pin": NSNumber(value: client.pin ? 1 : 0)
        ]
        if let position = client.position { fields["position"] = position as NSString }
        if let department = client.department { fields["department"] = department as NSString }
        if let email = client.email { fields["email"] = email as NSString }
        if let phone = client.phoneNumber { fields["phoneNumber"] = phone as NSString }
        if let linkedin = client.linkedinURL { fields["linkedinURL"] = linkedin as NSString }
        if let memo = client.memo { fields["memo"] = memo as NSString }
        if let action = client.action { fields["action"] = action as NSString }
        if let industry = client.industry { fields["industry"] = industry as NSString }
        if let address = client.address { fields["address"] = address as NSString }
        if let fax = client.faxNumber { fields["faxNumber"] = fax as NSString }
        if let revenue = client.revenue { fields["revenue"] = revenue as NSString }
        if let employees = client.employees { fields["employees"] = employees as NSString }
        // Lists: clamp to max 5 and strip empties/whitespace
        let emailList = client.additionalEmails.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.prefix(5)
        if !emailList.isEmpty {
            fields["additionalEmails"] = NSArray(array: emailList.map { $0 as NSString })
        }
        let phoneList = client.additionalPhones.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.prefix(5)
        if !phoneList.isEmpty {
            fields["additionalPhones"] = NSArray(array: phoneList.map { $0 as NSString })
        }
        let urlList = client.additionalURLs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.prefix(5)
        if !urlList.isEmpty {
            fields["additionalURLs"] = NSArray(array: urlList.map { $0 as NSString })
        }
        if let img = client.profile, let asset = CloudKitManager.shared.makeAsset(from: img) {
            fields["profileAsset"] = asset
        }
        if let front = client.nameCardFront?.asUIImage(), let asset = CloudKitManager.shared.makeAsset(from: front) {
            fields["nameCardFrontAsset"] = asset
        }
        if let back = client.nameCardBack?.asUIImage(), let asset = CloudKitManager.shared.makeAsset(from: back) {
            fields["nameCardBackAsset"] = asset
        }
        CloudKitManager.shared.saveRecord(type: "Client", fields: fields) { [weak self] result in
            guard let self else { return }
            if case .success(let saved) = result {
                self.setCloudKitRecordID(saved.recordID, for: client.id)
            }
        }
    }

    private func syncUpdateClientToCloudKit(_ client: Client) {
        if UserDefaults.standard.bool(forKey: "apex.isGuestMode") {
            return
        }
        let recordID = cloudKitRecordID(for: client.id)
        var fields: [String: CKRecordValueProtocol] = [
            "surname": (client.surname as NSString),
            "name": (client.name as NSString),
            "company": (client.company as NSString),
            "favorite": NSNumber(value: client.favorite ? 1 : 0),
            "pin": NSNumber(value: client.pin ? 1 : 0)
        ]
        var clearKeys: [String] = []
        if let position = client.position { fields["position"] = position as NSString } else { clearKeys.append("position") }
        if let department = client.department { fields["department"] = department as NSString } else { clearKeys.append("department") }
        if let email = client.email { fields["email"] = email as NSString } else { clearKeys.append("email") }
        if let phone = client.phoneNumber { fields["phoneNumber"] = phone as NSString } else { clearKeys.append("phoneNumber") }
        if let linkedin = client.linkedinURL { fields["linkedinURL"] = linkedin as NSString } else { clearKeys.append("linkedinURL") }
        if let memo = client.memo { fields["memo"] = memo as NSString } else { clearKeys.append("memo") }
        if let action = client.action { fields["action"] = action as NSString } else { clearKeys.append("action") }
        if let industry = client.industry { fields["industry"] = industry as NSString } else { clearKeys.append("industry") }
        if let address = client.address { fields["address"] = address as NSString } else { clearKeys.append("address") }
        if let fax = client.faxNumber { fields["faxNumber"] = fax as NSString } else { clearKeys.append("faxNumber") }
        if let revenue = client.revenue { fields["revenue"] = revenue as NSString } else { clearKeys.append("revenue") }
        if let employees = client.employees { fields["employees"] = employees as NSString } else { clearKeys.append("employees") }
        let emailList = client.additionalEmails.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.prefix(5)
        fields["additionalEmails"] = NSArray(array: emailList.map { $0 as NSString })
        let phoneList = client.additionalPhones.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.prefix(5)
        fields["additionalPhones"] = NSArray(array: phoneList.map { $0 as NSString })
        let urlList = client.additionalURLs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.prefix(5)
        fields["additionalURLs"] = NSArray(array: urlList.map { $0 as NSString })
        if let img = client.profile, let asset = CloudKitManager.shared.makeAsset(from: img) {
            fields["profileAsset"] = asset
        } else {
            clearKeys.append("profileAsset")
        }
        if let front = client.nameCardFront?.asUIImage(), let asset = CloudKitManager.shared.makeAsset(from: front) {
            fields["nameCardFrontAsset"] = asset
        } else {
            clearKeys.append("nameCardFrontAsset")
        }
        if let back = client.nameCardBack?.asUIImage(), let asset = CloudKitManager.shared.makeAsset(from: back) {
            fields["nameCardBackAsset"] = asset
        } else {
            clearKeys.append("nameCardBackAsset")
        }
        if let recordID {
            CloudKitManager.shared.updateRecord(recordID: recordID, fields: fields, clearKeys: clearKeys, completion: nil)
        } else {
            // No mapping yet; create new and store mapping
            CloudKitManager.shared.saveRecord(type: "Client", fields: fields) { [weak self] result in
                guard let self else { return }
                if case .success(let saved) = result {
                    self.setCloudKitRecordID(saved.recordID, for: client.id)
                }
            }
        }
    }

    private func deleteClientFromCloudKit(_ clientId: UUID) {
        if UserDefaults.standard.bool(forKey: "apex.isGuestMode") { return }
        guard let recordID = cloudKitRecordID(for: clientId) else { return }
        CloudKitManager.shared.deleteRecord(recordID: recordID) { [weak self] _ in
            self?.removeCloudKitRecordID(for: clientId)
        }
    }

    private func syncUserToCloudKit(_ me: Client) {
        if UserDefaults.standard.bool(forKey: "apex.isGuestMode") { return }
        var fields: [String: CKRecordValueProtocol] = [
            "surname": me.surname as NSString,
            "name": me.name as NSString,
            "company": me.company as NSString
        ]
        if let position = me.position { fields["position"] = position as NSString }
        if let department = me.department { fields["department"] = department as NSString }
        if let email = me.email { fields["email"] = email as NSString }
        if let phone = me.phoneNumber { fields["phoneNumber"] = phone as NSString }
        if let linkedin = me.linkedinURL { fields["linkedinURL"] = linkedin as NSString }
        if let memo = me.memo { fields["memo"] = memo as NSString }
        if let industry = me.industry { fields["industry"] = industry as NSString }
        if let address = me.address { fields["address"] = address as NSString }
        if let fax = me.faxNumber { fields["faxNumber"] = fax as NSString }
        if let revenue = me.revenue { fields["revenue"] = revenue as NSString }
        if let employees = me.employees { fields["employees"] = employees as NSString }
        let emailList = me.additionalEmails.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.prefix(5)
        fields["additionalEmails"] = NSArray(array: emailList.map { $0 as NSString })
        let phoneList = me.additionalPhones.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.prefix(5)
        fields["additionalPhones"] = NSArray(array: phoneList.map { $0 as NSString })
        let urlList = me.additionalURLs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.prefix(5)
        fields["additionalURLs"] = NSArray(array: urlList.map { $0 as NSString })
        var clearKeys: [String] = []
        if let img = me.profile, let asset = CloudKitManager.shared.makeAsset(from: img) {
            fields["profileAsset"] = asset
        } else { clearKeys.append("profileAsset") }
        if let front = me.nameCardFront?.asUIImage(), let asset = CloudKitManager.shared.makeAsset(from: front) {
            fields["nameCardFrontAsset"] = asset
        } else { clearKeys.append("nameCardFrontAsset") }
        if let back = me.nameCardBack?.asUIImage(), let asset = CloudKitManager.shared.makeAsset(from: back) {
            fields["nameCardBackAsset"] = asset
        } else { clearKeys.append("nameCardBackAsset") }

        if let existing = userRecordID() {
            CloudKitManager.shared.updateRecord(recordID: existing, fields: fields, clearKeys: clearKeys, completion: nil)
        } else {
            CloudKitManager.shared.saveRecord(type: "AppUser", fields: fields) { [weak self] result in
                if case .success(let saved) = result { self?.setUserRecordID(saved.recordID) }
            }
        }
    }

    // MARK: - Mapping Client.id <-> CKRecord.ID
    private let ckClientIdMapKey = "cloudkit.mapping.clientIdToRecordName"
    private func loadIdMap() -> [String: String] {
        (UserDefaults.standard.dictionary(forKey: ckClientIdMapKey) as? [String: String]) ?? [:]
    }
    private func saveIdMap(_ map: [String: String]) {
        UserDefaults.standard.set(map, forKey: ckClientIdMapKey)
    }
    private func cloudKitRecordID(for clientId: UUID) -> CKRecord.ID? {
        let map = loadIdMap()
        guard let name = map[clientId.uuidString] else { return nil }
        return CKRecord.ID(recordName: name)
    }
    private func setCloudKitRecordID(_ recordID: CKRecord.ID, for clientId: UUID) {
        var map = loadIdMap()
        map[clientId.uuidString] = recordID.recordName
        saveIdMap(map)
    }
    private func removeCloudKitRecordID(for clientId: UUID) {
        var map = loadIdMap()
        map.removeValue(forKey: clientId.uuidString)
        saveIdMap(map)
    }
    
    // Expose recordID for notes sync:
    // - For 일반 클라이언트: Client 레코드 ID 반환
    // - 내 프로필(인덱스 0): AppUser 레코드 ID를 반환하여 채팅 노트도 클라우드 연동
    func cloudKitRecordIDForClient(_ clientId: UUID) -> CKRecord.ID? {
        if let first = clients.first, first.id == clientId, let userId = userRecordID() {
            return userId
        }
        return cloudKitRecordID(for: clientId)
    }

    // MARK: - User record mapping
    private let ckUserRecordNameKey = "cloudkit.mapping.userRecordName"
    private func userRecordID() -> CKRecord.ID? {
        guard let name = UserDefaults.standard.string(forKey: ckUserRecordNameKey) else { return nil }
        return CKRecord.ID(recordName: name)
    }
    private func setUserRecordID(_ id: CKRecord.ID) {
        UserDefaults.standard.set(id.recordName, forKey: ckUserRecordNameKey)
    }
    func remove(_ clientId: UUID) {
        if let idx = clients.firstIndex(where: { $0.id == clientId }) {
            // Delete all notes for this client locally and in CloudKit (if enabled)
            let notesToDelete = ChatStore.shared.notes(for: clientId)
            ChatStore.shared.setNotes([], for: clientId)
            if SyncSettings.isAutoOn {
                for note in notesToDelete {
                    CloudKitNotesManager.shared.delete(noteId: note.id)
                }
            }
            // Remove client entry
            clients.remove(at: idx)
            if idx != 0, SyncSettings.isAutoOn {
                deleteClientFromCloudKit(clientId)
            }
        }
    }

    // MARK: - Helpers
    private func injectMyProfileIfNeeded() {
        // Only inject a sample "my profile" when there are no clients at all
        guard clients.isEmpty else { return }
        clients.insert(ClientsStore.makeBlankMyProfile(), at: 0)
    }

    // MARK: - Notes prefetch for all clients (to avoid entering chat to sync)
    private func pullAllClientNotesFromCloudKit() {
        if UserDefaults.standard.bool(forKey: "apex.isGuestMode") { return }
        let snapshot = clients
        for client in snapshot {
            CloudKitNotesManager.shared.fetchNotes(for: client.id) { result in
                if case .success(let fetched) = result {
                    DispatchQueue.main.async {
                        // Preserve local STT if Cloud text is empty
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
                        let sorted = merged.sorted { $0.uploadedAt < $1.uploadedAt }
                        ChatStore.shared.setNotes(sorted, for: client.id)
                    }
                }
            }
        }
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



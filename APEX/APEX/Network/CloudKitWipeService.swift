//
//  CloudKitWipeService.swift
//  APEX
//
//  Deletes all user data stored in the app's private CloudKit database.
//

import Foundation
import CloudKit

final class CloudKitWipeService {
    static let shared = CloudKitWipeService()
    private init() {}

    private var database: CKDatabase { CloudKitManager.shared.privateDB }

    /// Delete user data in CloudKit except AppUser (NoteAsset -> Note -> Client), then clear local CloudKit mirrors.
    func wipeAllUserCloudKitData(completion: @escaping (Result<Void, Error>) -> Void) {
        if UserDefaults.standard.bool(forKey: "apex.isGuestMode") {
            completion(.success(()))
            return
        }
        deleteAll(ofType: "NoteAsset") { [weak self] err in
            if let err { completion(.failure(err)); return }
            self?.deleteAll(ofType: "Note") { err in
                if let err { completion(.failure(err)); return }
                self?.deleteAll(ofType: "Client") { err in
                    if let err { completion(.failure(err)); return }
                    // Intentionally KEEP AppUser for future re-login, but prune sensitive fields
                    self?.pruneAppUserKeepingNameSurnameEmail { _ in
                        // Regardless of prune result, proceed to clear local mirrors so app returns to a clean state
                        self?.clearLocalCloudKitMirrors()
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .cloudKitDatabaseDidChange, object: nil)
                        }
                        completion(.success(()))
                    }
                }
            }
        }
    }

    // MARK: - Internals

    /// Keep only surname, name, email in AppUser. Clear all other known fields.
    private func pruneAppUserKeepingNameSurnameEmail(completion: @escaping (Result<Void, Error>) -> Void) {
        CloudKitManager.shared.query(type: "AppUser") { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let records):
                guard let rec = records.first else {
                    // No AppUser present; nothing to prune
                    completion(.success(()))
                    return
                }
                // Preserve existing surname/name/email values (do not modify them)
                var fields: [String: CKRecordValueProtocol] = [:]
                if let surname = rec["surname"] as? String { fields["surname"] = surname as NSString }
                if let name = rec["name"] as? String { fields["name"] = name as NSString }
                if let email = rec["email"] as? String { fields["email"] = email as NSString }
                // Clear everything else we know about
                let clearKeys: [String] = [
                    "company",
                    "position",
                    "department",
                    "phoneNumber",
                    "linkedinURL",
                    "memo",
                    "industry",
                    "address",
                    "faxNumber",
                    "revenue",
                    "employees",
                    "additionalEmails",
                    "additionalPhones",
                    "additionalURLs",
                    "profileAsset",
                    "nameCardFrontAsset",
                    "nameCardBackAsset"
                ]
                CloudKitManager.shared.updateRecord(recordID: rec.recordID, fields: fields, clearKeys: clearKeys) { updateResult in
                    switch updateResult {
                    case .failure(let updateError): completion(.failure(updateError))
                    case .success: completion(.success(()))
                    }
                }
            }
        }
    }

    private func deleteAll(ofType type: String, completion: @escaping (Error?) -> Void) {
        fetchAllRecordIDs(ofType: type) { [weak self] result in
            guard let self else { completion(nil); return }
            switch result {
            case .failure(let error):
                completion(error)
            case .success(let ids):
                guard !ids.isEmpty else { completion(nil); return }
                self.deleteRecordIDsInBatches(ids, batchSize: 200, completion: completion)
            }
        }
    }

    private func fetchAllRecordIDs(ofType type: String,
                                   predicate: NSPredicate = NSPredicate(value: true),
                                   completion: @escaping (Result<[CKRecord.ID], Error>) -> Void) {
        var all: [CKRecord.ID] = []
        func run(cursor: CKQueryOperation.Cursor?) {
            let operation: CKQueryOperation
            if let cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                let query = CKQuery(recordType: type, predicate: predicate)
                operation = CKQueryOperation(query: query)
            }
            operation.resultsLimit = CKQueryOperation.maximumResults
            operation.recordMatchedBlock = { _, result in
                if case .success(let rec) = result {
                    all.append(rec.recordID)
                }
            }
            operation.queryResultBlock = { result in
                switch result {
                case .success(let nextCursor):
                    if let nextCursor {
                        run(cursor: nextCursor)
                    } else {
                        completion(.success(all))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            database.add(operation)
        }
        run(cursor: nil)
    }

    private func deleteRecordIDsInBatches(_ ids: [CKRecord.ID],
                                          batchSize: Int,
                                          completion: @escaping (Error?) -> Void) {
        let chunks: [[CKRecord.ID]] = stride(from: 0, to: ids.count, by: batchSize).map {
            Array(ids[$0..<min($0 + batchSize, ids.count)])
        }
        let group = DispatchGroup()
        var firstError: Error?

        for chunk in chunks {
            group.enter()
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: chunk)
            modifyOperation.isAtomic = false
            modifyOperation.modifyRecordsResultBlock = { result in
                if case .failure(let e) = result, firstError == nil {
                    firstError = e
                }
                group.leave()
            }
            database.add(modifyOperation)
        }
        group.notify(queue: .global()) {
            completion(firstError)
        }
    }

    private func clearLocalCloudKitMirrors() {
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: "cloudkit.mapping.clientIdToRecordName")
        userDefaults.removeObject(forKey: "cloudkit.mapping.userRecordName")
        userDefaults.removeObject(forKey: "cloudkit.mapping.noteIdToRecordName")
        userDefaults.removeObject(forKey: "cloudkit.token.private")
        userDefaults.synchronize()
    }
}


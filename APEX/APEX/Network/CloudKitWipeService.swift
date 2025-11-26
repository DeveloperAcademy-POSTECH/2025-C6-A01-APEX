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
                    // Intentionally KEEP AppUser for future re-login
                    self?.clearLocalCloudKitMirrors()
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .cloudKitDatabaseDidChange, object: nil)
                    }
                    completion(.success(()))
                }
            }
        }
    }

    // MARK: - Internals

    private func deleteAll(ofType type: String, completion: @escaping (Error?) -> Void) {
        fetchAllRecordIDs(ofType: type) { [weak self] result in
            guard let self else { completion(nil); return }
            switch result {
            case .failure(let e):
                completion(e)
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
            let op: CKQueryOperation
            if let cursor {
                op = CKQueryOperation(cursor: cursor)
            } else {
                let q = CKQuery(recordType: type, predicate: predicate)
                op = CKQueryOperation(query: q)
            }
            op.resultsLimit = CKQueryOperation.maximumResults
            op.recordMatchedBlock = { _, result in
                if case .success(let rec) = result {
                    all.append(rec.recordID)
                }
            }
            op.queryResultBlock = { result in
                switch result {
                case .success(let nextCursor):
                    if let nextCursor {
                        run(cursor: nextCursor)
                    } else {
                        completion(.success(all))
                    }
                case .failure(let e):
                    completion(.failure(e))
                }
            }
            database.add(op)
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
            let op = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: chunk)
            op.isAtomic = false
            op.modifyRecordsResultBlock = { result in
                if case .failure(let e) = result, firstError == nil {
                    firstError = e
                }
                group.leave()
            }
            database.add(op)
        }
        group.notify(queue: .global()) {
            completion(firstError)
        }
    }

    private func clearLocalCloudKitMirrors() {
        let ud = UserDefaults.standard
        ud.removeObject(forKey: "cloudkit.mapping.clientIdToRecordName")
        ud.removeObject(forKey: "cloudkit.mapping.userRecordName")
        ud.removeObject(forKey: "cloudkit.mapping.noteIdToRecordName")
        ud.removeObject(forKey: "cloudkit.token.private")
        ud.synchronize()
    }
}



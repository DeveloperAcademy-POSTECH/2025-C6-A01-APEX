//
//  CloudKitManager.swift
//  APEX
//
//  Centralized CloudKit helper focused on the app's Private database.
//

import Foundation
import UIKit
import CloudKit

final class CloudKitManager {
    static let shared = CloudKitManager()
    private init() {}

    // MARK: - Retry Policy
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0
    
    private func retryDelay(for error: CKError, attempt: Int) -> TimeInterval? {
        if let after = error.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
            return after
        }
        switch error.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy, .resultsTruncated, .serverRejectedRequest:
            // Exponential backoff
            return min(8.0, baseRetryDelay * pow(2.0, Double(attempt - 1)))
        default:
            return nil
        }
    }
    
    private func isRetryable(_ error: CKError) -> Bool {
        switch error.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy, .resultsTruncated, .serverRejectedRequest, .limitExceeded:
            return true
        default:
            return false
        }
    }
    
    // Central configuration for all operations
    private func configure(_ operation: CKOperation) {
        operation.qualityOfService = .userInitiated
        if let cfg = operation.configuration {
            cfg.allowsCellularAccess = true
            cfg.timeoutIntervalForRequest = 30
            cfg.timeoutIntervalForResource = 300
            operation.configuration = cfg
        }
    }

    // MARK: - Container / Database
    // Use the default container declared in entitlements (iCloud.$(PRODUCT_BUNDLE_IDENTIFIER))
    // to avoid mismatches with hard-coded identifiers across schemes/configs.
    var container: CKContainer { CKContainer.default() }
    var privateDB: CKDatabase { container.privateCloudDatabase }

    // MARK: - Database Subscription
    private let databaseSubscriptionID = "apex.private.all"

    /// Idempotently install a database-wide subscription to receive silent pushes for any change.
    func ensureDatabaseSubscription() {
        privateDB.fetch(withSubscriptionID: databaseSubscriptionID) { [weak self] existing, _ in
            guard let self, existing == nil else { return }
            let sub = CKDatabaseSubscription(subscriptionID: self.databaseSubscriptionID)
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true
            sub.notificationInfo = info
            let modifyOperation = CKModifySubscriptionsOperation(subscriptionsToSave: [sub], subscriptionIDsToDelete: [])
            modifyOperation.modifySubscriptionsCompletionBlock = { _, _, error in
                if let error { print("[CloudKit] ensureDatabaseSubscription error: \(error)") }
            }
            self.configure(modifyOperation)
            self.privateDB.add(modifyOperation)
        }
    }

    // MARK: - Change Tokens
    private let tokenKeyPrivateDB = "cloudkit.token.private"
    private var privateDBChangeToken: CKServerChangeToken? {
        get {
            guard let data = UserDefaults.standard.data(forKey: tokenKeyPrivateDB) else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
        }
        set {
            if let token = newValue, let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
                UserDefaults.standard.set(data, forKey: tokenKeyPrivateDB)
            } else {
                UserDefaults.standard.removeObject(forKey: tokenKeyPrivateDB)
            }
        }
    }

    // MARK: - Notification Handling
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any], completion: @escaping (UIBackgroundFetchResult) -> Void) {
        _ = CKNotification(fromRemoteNotificationDictionary: userInfo)
        fetchDatabaseChanges(completion: completion)
    }

    func fetchDatabaseChanges(completion: @escaping (UIBackgroundFetchResult) -> Void) {
        func run(attempt: Int) {
            let fetchOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: privateDBChangeToken)
        var hasChanges = false
            fetchOperation.recordZoneWithIDChangedBlock = { _ in hasChanges = true }
            fetchOperation.changeTokenUpdatedBlock = { [weak self] token in
                self?.privateDBChangeToken = token
            }
            fetchOperation.fetchDatabaseChangesCompletionBlock = { [weak self] token, moreComing, error in
            if let error {
                    if let ck = error as? CKError {
                        let shouldRetry = (attempt < (self?.maxRetryAttempts ?? 0)) && (self?.isRetryable(ck) == true)
                        let delay = self?.retryDelay(for: ck, attempt: attempt + 1)
                        if shouldRetry, let delay {
                            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                                run(attempt: attempt + 1)
                            }
                        } else {
                print("[CloudKit] fetchDatabaseChanges error: \(error)")
                completion(.failed)
                        }
                    } else {
                        print("[CloudKit] fetchDatabaseChanges non-CKError: \(error)")
                        completion(.failed)
                    }
                return
            }
            if let token { self?.privateDBChangeToken = token }
            if hasChanges || moreComing {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .cloudKitDatabaseDidChange, object: nil)
                }
                completion(.newData)
            } else {
                completion(.noData)
            }
        }
            configure(fetchOperation)
            privateDB.add(fetchOperation)
        }
        run(attempt: 1)
    }

    // MARK: - Assets
    func makeAsset(from image: UIImage, compressionQuality: CGFloat = 0.9) -> CKAsset? {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else { return nil }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".jpg")
        do {
            try data.write(to: url, options: .atomic)
            return CKAsset(fileURL: url)
        } catch {
            print("[CloudKit] makeAsset error: \(error)")
            return nil
        }
    }

    // MARK: - CRUD helpers
    func saveRecord(type: String, recordID: CKRecord.ID? = nil, fields: [String: CKRecordValueProtocol], completion: ((Result<CKRecord, Error>) -> Void)? = nil) {
        func run(attempt: Int) {
        let record = recordID.map { CKRecord(recordType: type, recordID: $0) } ?? CKRecord(recordType: type)
        fields.forEach { record[$0.key] = $0.value }
        privateDB.save(record) { rec, err in
                if let err {
                    if let ck = err as? CKError, attempt < self.maxRetryAttempts, self.isRetryable(ck), let delay = self.retryDelay(for: ck, attempt: attempt + 1) {
                        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { run(attempt: attempt + 1) }
                    } else {
                        completion?(.failure(err))
                    }
                } else if let rec {
                    completion?(.success(rec))
                }
            }
        }
        run(attempt: 1)
    }

    func query(type: String, predicate: NSPredicate = NSPredicate(value: true), sortDescriptors: [NSSortDescriptor]? = nil, resultsLimit: Int = CKQueryOperation.maximumResults, completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        var collected: [CKRecord] = []
        
        func run(cursor: CKQueryOperation.Cursor?, attempt: Int) {
            let queryOperation: CKQueryOperation
            if let cursor {
                queryOperation = CKQueryOperation(cursor: cursor)
            } else {
                let query = CKQuery(recordType: type, predicate: predicate)
                query.sortDescriptors = sortDescriptors
                queryOperation = CKQueryOperation(query: query)
                queryOperation.resultsLimit = resultsLimit
            }
            queryOperation.recordMatchedBlock = { _, result in
                if case .success(let matchedRecord) = result {
                    collected.append(matchedRecord)
                }
            }
            queryOperation.queryResultBlock = { result in
            switch result {
                case .success(let nextCursor):
                    if let next = nextCursor {
                        run(cursor: next, attempt: 1)
                    } else {
                        completion(.success(collected))
                    }
                case .failure(let error):
                    if let ck = error as? CKError,
                       attempt < self.maxRetryAttempts,
                       self.isRetryable(ck),
                       let delay = self.retryDelay(for: ck, attempt: attempt + 1) {
                        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                            run(cursor: cursor, attempt: attempt + 1)
                        }
                    } else {
                        completion(.failure(error))
            }
        }
            }
            configure(queryOperation)
            privateDB.add(queryOperation)
        }
        run(cursor: nil, attempt: 1)
    }

    func deleteRecord(recordID: CKRecord.ID, completion: ((Result<CKRecord.ID, Error>) -> Void)? = nil) {
        func run(attempt: Int) {
        privateDB.delete(withRecordID: recordID) { id, err in
                if let err {
                    if let ck = err as? CKError, attempt < self.maxRetryAttempts, self.isRetryable(ck), let delay = self.retryDelay(for: ck, attempt: attempt + 1) {
                        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { run(attempt: attempt + 1) }
                    } else {
                        completion?(.failure(err))
                    }
                } else if let id {
                    completion?(.success(id))
                }
            }
        }
        run(attempt: 1)
    }

    /// Safely update an existing record by fetching it first, applying fields and clearing specified keys.
    func updateRecord(recordID: CKRecord.ID,
                      fields: [String: CKRecordValueProtocol],
                      clearKeys: [String] = [],
                      completion: ((Result<CKRecord, Error>) -> Void)? = nil) {
        func fetchThenSave(attempt: Int) {
        privateDB.fetch(withRecordID: recordID) { [weak self] rec, err in
            guard let self else { return }
                if let err {
                    if let ck = err as? CKError, attempt < self.maxRetryAttempts, self.isRetryable(ck), let delay = self.retryDelay(for: ck, attempt: attempt + 1) {
                        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { fetchThenSave(attempt: attempt + 1) }
                    } else {
                        completion?(.failure(err))
                    }
                    return
                }
            guard let rec else {
                completion?(.failure(NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Record not found"]))); return
            }
            fields.forEach { rec[$0.key] = $0.value }
            clearKeys.forEach { rec[$0] = nil }
            self.privateDB.save(rec) { saved, err in
                    if let err {
                        if let ck = err as? CKError, attempt < self.maxRetryAttempts, self.isRetryable(ck), let delay = self.retryDelay(for: ck, attempt: attempt + 1) {
                            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { fetchThenSave(attempt: attempt + 1) }
                        } else {
                            completion?(.failure(err))
                        }
                    } else if let saved {
                        completion?(.success(saved))
                    }
                }
            }
        }
        fetchThenSave(attempt: 1)
    }
}

extension Notification.Name {
    static let cloudKitDatabaseDidChange = Notification.Name("cloudkit.database.didChange")
}

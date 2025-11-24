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
            let op = CKModifySubscriptionsOperation(subscriptionsToSave: [sub], subscriptionIDsToDelete: [])
            op.modifySubscriptionsCompletionBlock = { _, _, error in
                if let error { print("[CloudKit] ensureDatabaseSubscription error: \(error)") }
            }
            self.privateDB.add(op)
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
        let op = CKFetchDatabaseChangesOperation(previousServerChangeToken: privateDBChangeToken)
        var hasChanges = false
        op.recordZoneWithIDChangedBlock = { _ in hasChanges = true }
        op.changeTokenUpdatedBlock = { [weak self] token in self?.privateDBChangeToken = token }
        op.fetchDatabaseChangesCompletionBlock = { [weak self] token, moreComing, error in
            if let error {
                print("[CloudKit] fetchDatabaseChanges error: \(error)")
                completion(.failed)
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
        privateDB.add(op)
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
        let record = recordID.map { CKRecord(recordType: type, recordID: $0) } ?? CKRecord(recordType: type)
        fields.forEach { record[$0.key] = $0.value }
        privateDB.save(record) { rec, err in
            if let err { completion?(.failure(err)) }
            else if let rec { completion?(.success(rec)) }
        }
    }

    func query(type: String, predicate: NSPredicate = NSPredicate(value: true), sortDescriptors: [NSSortDescriptor]? = nil, resultsLimit: Int = CKQueryOperation.maximumResults, completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        let q = CKQuery(recordType: type, predicate: predicate)
        q.sortDescriptors = sortDescriptors
        let op = CKQueryOperation(query: q)
        op.resultsLimit = resultsLimit
        var results: [CKRecord] = []
        op.recordMatchedBlock = { _, result in if case .success(let r) = result { results.append(r) } }
        op.queryResultBlock = { result in
            switch result {
            case .success: completion(.success(results))
            case .failure(let e): completion(.failure(e))
            }
        }
        privateDB.add(op)
    }

    func deleteRecord(recordID: CKRecord.ID, completion: ((Result<CKRecord.ID, Error>) -> Void)? = nil) {
        privateDB.delete(withRecordID: recordID) { id, err in
            if let err { completion?(.failure(err)) }
            else if let id { completion?(.success(id)) }
        }
    }

    /// Safely update an existing record by fetching it first, applying fields and clearing specified keys.
    func updateRecord(recordID: CKRecord.ID,
                      fields: [String: CKRecordValueProtocol],
                      clearKeys: [String] = [],
                      completion: ((Result<CKRecord, Error>) -> Void)? = nil) {
        privateDB.fetch(withRecordID: recordID) { [weak self] rec, err in
            guard let self else { return }
            if let err { completion?(.failure(err)); return }
            guard let rec else {
                completion?(.failure(NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Record not found"]))); return
            }
            fields.forEach { rec[$0.key] = $0.value }
            clearKeys.forEach { rec[$0] = nil }
            self.privateDB.save(rec) { saved, err in
                if let err { completion?(.failure(err)) }
                else if let saved { completion?(.success(saved)) }
            }
        }
    }
}

extension Notification.Name {
    static let cloudKitDatabaseDidChange = Notification.Name("cloudkit.database.didChange")
}

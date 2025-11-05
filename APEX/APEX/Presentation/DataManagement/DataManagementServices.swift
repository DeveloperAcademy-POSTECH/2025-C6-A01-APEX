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

//
//  PersistedModelsExt.swift
//  StashShare
//
//  Copy of persisted models for use inside the Share Extension.
//

import Foundation
import SwiftUI

struct PImageAttachment: Codable {
    var data: Data
    var progress: Double?
    var orderIndex: Int?
}

struct PVideoAttachment: Codable {
    var url: String
    var progress: Double?
    var orderIndex: Int?
}

struct PFileAttachment: Codable {
    var url: String
    var progress: Double?
}

struct PAudioAttachment: Codable {
    var url: String
    var duration: Double?
}

enum PAttachmentBundle: Codable {
    case media(images: [PImageAttachment], videos: [PVideoAttachment])
    case files([PFileAttachment])
    case audio([PAudioAttachment])
    private enum CodingKeys: String, CodingKey {
        case type, images, videos, files, audios
    }
    private enum Kind: String, Codable {
        case media, files, audio
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)
        switch kind {
        case .media:
            let images = try container.decode([PImageAttachment].self, forKey: .images)
            let videos = try container.decode([PVideoAttachment].self, forKey: .videos)
            self = .media(images: images, videos: videos)
        case .files:
            let files = try container.decode([PFileAttachment].self, forKey: .files)
            self = .files(files)
        case .audio:
            let audios = try container.decode([PAudioAttachment].self, forKey: .audios)
            self = .audio(audios)
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .media(let images, let videos):
            try container.encode(Kind.media, forKey: .type)
            try container.encode(images, forKey: .images)
            try container.encode(videos, forKey: .videos)
        case .files(let files):
            try container.encode(Kind.files, forKey: .type)
            try container.encode(files, forKey: .files)
        case .audio(let audios):
            try container.encode(Kind.audio, forKey: .type)
            try container.encode(audios, forKey: .audios)
        }
    }
}

struct PNote: Codable, Identifiable {
    var id: UUID
    var uploadedAt: Date
    var text: String?
    var bundle: PAttachmentBundle?
}

struct PClient: Codable, Identifiable {
    var id: UUID
    var profileImageData: Data?
    var nameCardFrontData: Data?
    var nameCardBackData: Data?
    var surname: String
    var name: String
    var position: String?
    var company: String
    var email: String?
    var phoneNumber: String?
    var linkedinURL: String?
    var memo: String?
    var action: String?
    var favorite: Bool
    var pin: Bool
    var notes: [PNote]
}

// MARK: - Text Formatting (mirror NotesRow behavior in main app)
enum NotesTextFormatterExt {
    static func latestSummary(from notes: [PNote]) -> String? {
        guard let latest = notes.max(by: { $0.uploadedAt < $1.uploadedAt }) else { return nil }

        if let text = latest.text?
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return text
        }

        let id = videoIdPlaceholder()
        switch latest.bundle {
        case .media(let images, let videos):
            if !videos.isEmpty { return "Video [\(id)]" }
            if !images.isEmpty { return "Photo [\(id)]" }
            return nil
        case .files(let files):
            return files.isEmpty ? nil : "File [\(id)]"
        case .audio(let audios):
            return audios.isEmpty ? nil : "Audio [\(id)]"
        case .none:
            return nil
        }
    }

    private static func videoIdPlaceholder() -> String {
        "94128942198382"
    }
}



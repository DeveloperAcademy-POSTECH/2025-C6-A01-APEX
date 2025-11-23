//
//  PersistedModels.swift
//  APEX
//
//  Created by Assistant on 11/10/25.
//

import Foundation
import UIKit
import SwiftUI

// MARK: - Persisted Attachments

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

// MARK: - Persisted Note

struct PNote: Codable {
    var id: UUID
    var uploadedAt: Date
    var text: String?
    var bundle: PAttachmentBundle?
}

// MARK: - Persisted Client
// Only persist codable-safe properties; media previews (UIImage/Image/UTType) are excluded

struct PClient: Codable {
    var id: UUID
    // Persist profile image as Data to restore UIImage on launch
    var profileImageData: Data?
    // Persist name card previews as Data as well
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

// MARK: - Mapping to/from Runtime Models

extension PAttachmentBundle {
    init(from bundle: AttachmentBundle) {
        switch bundle {
        case .media(let images, let videos):
            let pImages = images.map { PImageAttachment(data: $0.data, progress: $0.progress, orderIndex: $0.orderIndex) }
            let pVideos = videos.map { PVideoAttachment(url: $0.url.absoluteString, progress: $0.progress, orderIndex: $0.orderIndex) }
            self = .media(images: pImages, videos: pVideos)
        case .files(let files):
            let pFiles = files.map { PFileAttachment(url: $0.url.absoluteString, progress: $0.progress) }
            self = .files(pFiles)
        case .audio(let audios):
            let pAudios = audios.map { PAudioAttachment(url: $0.url.absoluteString, duration: $0.duration) }
            self = .audio(pAudios)
        }
    }
    
    func toRuntime() -> AttachmentBundle {
        switch self {
        case .media(let pImages, let pVideos):
            let images = pImages.map { ImageAttachment(data: $0.data, progress: $0.progress, orderIndex: $0.orderIndex) }
            let videos: [VideoAttachment] = pVideos.compactMap { item in
                guard let url = URL(string: item.url) else { return nil }
                return VideoAttachment(url: url, progress: item.progress, orderIndex: item.orderIndex)
            }
            return .media(images: images, videos: videos)
        case .files(let pFiles):
            let files: [FileAttachment] = pFiles.compactMap { item in
                guard let url = URL(string: item.url) else { return nil }
                return FileAttachment(url: url, contentType: nil, progress: item.progress)
            }
            return .files(files)
        case .audio(let pAudios):
            let audios: [AudioAttachment] = pAudios.compactMap { item in
                guard let url = URL(string: item.url) else { return nil }
                return AudioAttachment(url: url, duration: item.duration)
            }
            return .audio(audios)
        }
    }
}

extension PNote {
    init(from note: Note) {
        self.id = note.id
        self.uploadedAt = note.uploadedAt
        self.text = note.text
        if let bundle = note.bundle {
            self.bundle = PAttachmentBundle(from: bundle)
        } else {
            self.bundle = nil
        }
    }
    
    func toRuntime() -> Note {
        let runtimeBundle: AttachmentBundle?
        if let persistedBundle = self.bundle {
            runtimeBundle = persistedBundle.toRuntime()
        } else {
            runtimeBundle = nil
        }
        return Note(id: id, uploadedAt: uploadedAt, text: text, bundle: runtimeBundle)
    }
}

extension PClient {
    init(from client: Client) {
        self.id = client.id
        if let image = client.profile {
            // Prefer JPEG for smaller size; fallback to PNG
            self.profileImageData = image.jpegData(compressionQuality: 0.9) ?? image.pngData()
        } else {
            self.profileImageData = nil
        }
        // Render SwiftUI Images to Data for persistence
        self.nameCardFrontData = Self.renderImageData(from: client.nameCardFront)
        self.nameCardBackData  = Self.renderImageData(from: client.nameCardBack)
        self.surname = client.surname
        self.name = client.name
        self.position = client.position
        self.company = client.company
        self.email = client.email
        self.phoneNumber = client.phoneNumber
        self.linkedinURL = client.linkedinURL
        self.memo = client.memo
        self.action = client.action
        self.favorite = client.favorite
        self.pin = client.pin
        self.notes = client.notes.map { PNote(from: $0) }
    }
    
    func toRuntime() -> Client {
        var runtimeNotes: [Note] = notes.map { $0.toRuntime() }
        let restoredProfile: UIImage? = profileImageData.flatMap { UIImage(data: $0) }
        let restoredFront: Image? = nameCardFrontData.flatMap { data in
            guard let ui = UIImage(data: data) else { return nil }
            return Image(uiImage: ui)
        }
        let restoredBack: Image? = nameCardBackData.flatMap { data in
            guard let ui = UIImage(data: data) else { return nil }
            return Image(uiImage: ui)
        }
        let client = Client(
            id: id,
            profile: restoredProfile,
            nameCardFront: restoredFront,
            nameCardBack: restoredBack,
            surname: surname,
            name: name,
            position: position,
            company: company,
            email: email,
            phoneNumber: phoneNumber,
            linkedinURL: linkedinURL,
            memo: memo,
            action: action,
            favorite: favorite,
            pin: pin,
            notes: runtimeNotes
        )
        return client
    }
}

// MARK: - Helpers
private extension PClient {
    static func renderImageData(from swiftUIImage: Image?) -> Data? {
        guard let image = swiftUIImage else { return nil }
        // Render to a reasonable preview size; keep scale for sharpness
        let targetSize = CGSize(width: 358, height: 214)
        let renderer = ImageRenderer(
            content: image
                .resizable()
                .scaledToFit()
                .frame(width: targetSize.width, height: targetSize.height)
        )
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage?.jpegData(compressionQuality: 0.9)
    }
}



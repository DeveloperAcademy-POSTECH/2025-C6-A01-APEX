//
//  ShareViewController.swift
//  StashShare
//
//  Created by 조운경 on 11/13/25.
//

import UIKit
import Social
import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import CoreText

class ShareViewController: UIViewController {
    private var hostingController: UIHostingController<ShareSheetView>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        registerCustomFonts()
        
        // Build attachments from the incoming extension context
        loadAttachments { [weak self] items in
            guard let self else { return }
            let root = ShareSheetView(attachments: items) { [weak self] in
                self?.complete()
            }
            let hostController = UIHostingController(rootView: root)
            self.addChild(hostController)
            hostController.view.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(hostController.view)
            NSLayoutConstraint.activate([
                hostController.view.topAnchor.constraint(equalTo: self.view.topAnchor),
                hostController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
                hostController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                hostController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
            ])
            hostController.didMove(toParent: self)
            self.hostingController = hostController
        }
    }
    
    private func complete() {
        let url = URL(string: "apex://open?dest=notes")!
        extensionContext?.completeRequest(returningItems: nil, completionHandler: { [weak self] _ in
            // Give the system a beat to dismiss the extension UI before opening the host app.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.extensionContext?.open(url, completionHandler: nil)
            }
        })
    }
}

// MARK: - Input parsing
extension ShareViewController {
    private func registerCustomFonts() {
        guard let url = Bundle.main.url(forResource: "PretendardVariable", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
    
    private func loadAttachments(completion: @escaping ([ShareAttachmentItem]) -> Void) {
        guard
            let items = extensionContext?.inputItems as? [NSExtensionItem],
            !items.isEmpty
        else {
            completion([])
            return
        }
        var results: [ShareAttachmentItem] = []
        let group = DispatchGroup()
        
        for item in items {
            guard let providers = item.attachments else { continue }
            for provider in providers {
                process(provider: provider, group: group) { item in
                    results.append(item)
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(results)
        }
    }
}

// MARK: - Provider processing
private extension ShareViewController {
    func process(provider: NSItemProvider, group: DispatchGroup, append: @escaping (ShareAttachmentItem) -> Void) {
        // Images
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { object, _ in
                defer { group.leave() }
                if let image = object as? UIImage {
                    append(ShareAttachmentItem(id: UUID(), kind: .image(image)))
                } else if let url = object as? URL, let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                    append(ShareAttachmentItem(id: UUID(), kind: .image(img)))
                } else if let data = object as? Data, let img = UIImage(data: data) {
                    // Some providers (e.g., screenshot share) deliver raw image data (HEIC/PNG/JPEG)
                    append(ShareAttachmentItem(id: UUID(), kind: .image(img)))
                }
            }
            return
        }
        // Movies / videos
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { object, _ in
                defer { group.leave() }
                if let url = object as? URL {
                    append(ShareAttachmentItem(id: UUID(), kind: .video(url, thumbnail: nil)))
                }
            }
            return
        }
        // File URL (must be treated as file, not link)
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { object, _ in
                defer { group.leave() }
                if let url = object as? URL {
                    append(ShareAttachmentItem(id: UUID(), kind: .file(url)))
                }
            }
            return
        }
        // Plain text
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { object, _ in
                defer { group.leave() }
                if let text = object as? String {
                    append(ShareAttachmentItem(id: UUID(), kind: .text(text)))
                }
            }
            return
        }
        // URL (treat as text link so it renders with link preview in app)
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { object, _ in
                defer { group.leave() }
                if let url = object as? URL {
                    if url.isFileURL || url.scheme?.lowercased() == "file" {
                        append(ShareAttachmentItem(id: UUID(), kind: .file(url)))
                    } else if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                        append(ShareAttachmentItem(id: UUID(), kind: .text(url.absoluteString)))
                    } else {
                        // Fallback: keep as text to preserve value
                        append(ShareAttachmentItem(id: UUID(), kind: .text(url.absoluteString)))
                    }
                }
            }
            return
        }
        // Generic file URLs
        if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.data.identifier, options: nil) { object, _ in
                defer { group.leave() }
                if let url = object as? URL {
                    append(ShareAttachmentItem(id: UUID(), kind: .file(url)))
                }
            }
            return
        }
        // Audio
        if provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.audio.identifier, options: nil) { object, _ in
                defer { group.leave() }
                if let url = object as? URL {
                    append(ShareAttachmentItem(id: UUID(), kind: .audio(url)))
                }
            }
            return
        }
    }
}

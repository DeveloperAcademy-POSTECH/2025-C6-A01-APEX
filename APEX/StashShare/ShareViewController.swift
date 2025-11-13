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

class ShareViewController: UIViewController {
    private var hostingController: UIHostingController<ShareSheetView>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Build attachments from the incoming extension context
        loadAttachments { [weak self] items in
            guard let self else { return }
            let root = ShareSheetView(attachments: items) { [weak self] in
                self?.complete()
            }
            let hc = UIHostingController(rootView: root)
            self.addChild(hc)
            hc.view.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(hc.view)
            NSLayoutConstraint.activate([
                hc.view.topAnchor.constraint(equalTo: self.view.topAnchor),
                hc.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
                hc.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                hc.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            ])
            hc.didMove(toParent: self)
            self.hostingController = hc
        }
    }
    
    private func complete() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

// MARK: - Input parsing
extension ShareViewController {
    private func loadAttachments(completion: @escaping ([ShareAttachmentItem]) -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem], !items.isEmpty else {
            completion([])
            return
        }
        var results: [ShareAttachmentItem] = []
        let group = DispatchGroup()
        
        for item in items {
            guard let providers = item.attachments else { continue }
            for provider in providers {
                // Images
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { object, _ in
                        defer { group.leave() }
                        if let image = object as? UIImage {
                            results.append(ShareAttachmentItem(id: UUID(), kind: .image(image)))
                        } else if let url = object as? URL, let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                            results.append(ShareAttachmentItem(id: UUID(), kind: .image(img)))
                        }
                    }
                    continue
                }
                // Movies / videos
                if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { object, _ in
                        defer { group.leave() }
                        if let url = object as? URL {
                            results.append(ShareAttachmentItem(id: UUID(), kind: .video(url, thumbnail: nil)))
                        }
                    }
                    continue
                }
                // File URL (must be treated as file, not link)
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { object, _ in
                        defer { group.leave() }
                        if let url = object as? URL {
                            results.append(ShareAttachmentItem(id: UUID(), kind: .file(url)))
                        }
                    }
                    continue
                }
                // Plain text
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { object, _ in
                        defer { group.leave() }
                        if let text = object as? String {
                            results.append(ShareAttachmentItem(id: UUID(), kind: .text(text)))
                        }
                    }
                    continue
                }
                // URL (treat as text link so it renders with link preview in app)
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { object, _ in
                        defer { group.leave() }
                        if let url = object as? URL {
                            if url.isFileURL || url.scheme?.lowercased() == "file" {
                                results.append(ShareAttachmentItem(id: UUID(), kind: .file(url)))
                            } else if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                                results.append(ShareAttachmentItem(id: UUID(), kind: .text(url.absoluteString)))
                            } else {
                                // Fallback: keep as text to preserve value
                                results.append(ShareAttachmentItem(id: UUID(), kind: .text(url.absoluteString)))
                            }
                        }
                    }
                    continue
                }
                // Generic file URLs
                if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.data.identifier, options: nil) { object, _ in
                        defer { group.leave() }
                        if let url = object as? URL {
                            results.append(ShareAttachmentItem(id: UUID(), kind: .file(url)))
                        }
                    }
                    continue
                }
                // Audio
                if provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.audio.identifier, options: nil) { object, _ in
                        defer { group.leave() }
                        if let url = object as? URL {
                            results.append(ShareAttachmentItem(id: UUID(), kind: .audio(url)))
                        }
                    }
                    continue
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(results)
        }
    }
}

//
//  RootView.swift
//  APEX
//
//  Created by 조운경 on 10/18/25.
//

import SwiftUI

struct RootView: View {
    enum Tabs { case contacts, notes, search }
    
    @EnvironmentObject private var router: NavigationRouter
    @ObservedObject private var sync = ClientsStore.shared
    @State private var selection: Tabs = .contacts
    @State private var lastNonSearchSelection: Tabs = .contacts
    
    @State private var contactsQuery: String = ""
    @State private var notesQuery: String = ""
    
    var body: some View {
        APEXMediaViewerHost {
            NavigationStack(path: $router.path) {
                TabView(selection: $selection) {
                    
                    Tab("Contacts", systemImage: "person.crop.circle.fill", value: Tabs.contacts) {
                        ContactsView()
                    }

                    Tab("Notes", systemImage: "note.text", value: Tabs.notes) {
                        NotesView()
                    }

                    Tab("Search", systemImage: "magnifyingglass", value: Tabs.search, role: .search) {
                        SearchView(onClose: { selection = lastNonSearchSelection })
                    }
                }
                .tint(Color("Primary"))
                .onChange(of: selection) { newValue in
                    if newValue != .search {
                        lastNonSearchSelection = newValue
                    }
                }
                .navigationDestination(for: NavigationDestination.self) { route in
                    destination(for: route)
                }
            }
        }
        .apexSwipeBack()
        .overlay(alignment: .center) {
            if sync.isCloudSyncInProgress {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color("Primary"))
                        .scaleEffect(1.2)
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
                        )
                }
            }
        }
    }
}

private extension RootView {
    @ViewBuilder
    func destination(for route: NavigationDestination) -> some View {
        switch route {
        case .chat(let id):
            if let client = ClientsStore.shared.clients.first(where: { $0.id == id }) {
                ChattingView(clientId: id, chatTitle: client.autoFormattedName, initialNotes: client.notes)
                    .toolbar(.hidden, for: .navigationBar)
                    .toolbar(.hidden, for: .tabBar)
            } else {
                ChattingView(clientId: id, chatTitle: "채팅", initialNotes: [])
                    .toolbar(.hidden, for: .navigationBar)
                    .toolbar(.hidden, for: .tabBar)
            }
        case .chatArchive(let id):
            let client = ClientsStore.shared.clients.first(where: { $0.id == id })
            ChattingArchiveView(
                client: client,
                onDeletedContact: { router.pop() }
            )
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
        case .chatDetail(let id):
            let client = ClientsStore.shared.clients.first(where: { $0.id == id })
            ChattingArchiveView(client: client)
                .toolbar(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
        case .profileDetail(let id):
            ProfileDetailScreen(clientId: id)
                .toolbar(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
        case .myProfile:
            MyProfileScreen()
                .toolbar(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
        case .archiveSection(let clientId, let section):
            let builtView: AnyView = {
                let client = ClientsStore.shared.clients.first(where: { $0.id == clientId })
                var notes = ChatStore.shared.notes(for: clientId)
                if notes.isEmpty {
                    notes = client?.notes ?? []
                }
                let media = computeMediaItems(from: notes)
                let files = computeFileItems(from: notes)
                let audios = computeAudioItems(from: notes)
                let links = computeLinkItems(from: notes)
                let archiveView = ArchiveListView(
                    section: convert(section),
                    media: media,
                    files: files,
                    links: links,
                    audios: audios,
                    viewerTitle: client.map { $0.autoFormattedName } ?? "Shared Media",
                    excludedClientIds: [clientId],
                    onClose: { router.pop() }
                )
                .toolbar(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
                return AnyView(archiveView)
            }()
            builtView
        case .mediaViewer(let id):
            if let payload = APEXMediaViewerStore.shared.get(id) {
                MediaView(
                    items: payload.items,
                    selectedIndex: payload.index,
                    title: payload.title,
                    uploadedAt: payload.uploadedAt,
                    excludedClientIds: payload.excludedClientIds,
                    onSave: payload.onSave,
                    onDelete: payload.onDelete,
                    onTitleTap: payload.onTitleTap
                )
                .onDisappear {
                    APEXMediaViewerStore.shared.remove(id)
                }
                .toolbar(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
            } else {
                // Fallback if payload missing
                Color.clear
            }
        case .unsubscribe:
            UnsubscribeView()
                .toolbar(.hidden, for: .navigationBar)
        case .dataManagement:
            DataManagementView()
                .toolbar(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
        case .notesManagement:
            NotesManagementView()
                .toolbar(.hidden, for: .navigationBar)
        case .onboarding:
            OnBoardingView()
                .toolbar(.hidden, for: .navigationBar)
        case .profileAdd:
            ProfileAddView()
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Route Screens (wrappers to adapt bindings)
private struct MyProfileScreen: View {
    @ObservedObject private var store = ClientsStore.shared
    @State private var client: DummyClient = DummyClient(
        profile: nil,
        nameCardFront: nil,
        nameCardBack: nil,
        surname: "",
        name: "",
        position: nil,
        company: "",
        department: nil,
        email: nil,
        phoneNumber: nil,
        linkedinURL: nil,
        memo: nil,
        action: nil,
        favorite: false,
        pin: false,
        notes: [],
        industry: nil,
        address: nil,
        faxNumber: nil,
        revenue: nil,
        employees: nil,
        additionalEmails: [],
        additionalPhones: [],
        additionalURLs: []
    )
    var body: some View {
        MyProfileView(client: $client)
            .onAppear { syncFromStore() }
            .onChange(of: store.clients) { _ in
                syncFromStore()
            }
    }
    
    private func syncFromStore() {
        // Always treat index 0 as the reserved "my profile"
        if let first = store.clients.first {
            client = DummyClient(
                profile: first.profile,
                nameCardFront: first.nameCardFront,
                nameCardBack: first.nameCardBack,
                surname: first.surname,
                name: first.name,
                position: first.position,
                company: first.company,
                department: first.department,
                email: first.email,
                phoneNumber: first.phoneNumber,
                linkedinURL: first.linkedinURL,
                memo: first.memo,
                action: first.action,
                favorite: first.favorite,
                pin: first.pin,
                notes: [],
                industry: first.industry,
                address: first.address,
                faxNumber: first.faxNumber,
                revenue: first.revenue,
                employees: first.employees,
                additionalEmails: first.additionalEmails,
                additionalPhones: first.additionalPhones,
                additionalURLs: first.additionalURLs
            )
        }
    }
}

// MARK: - Helpers for archive route
private extension RootView {
    func convert(_ nav: NavigationArchiveSection) -> ArchiveSection {
        switch nav {
        case .media: return .media
        case .files: return .files
        case .links: return .links
        case .audio: return .audio
        }
    }
    
    func computeMediaItems(from notes: [Note]) -> [FlattenedMediaItem] {
        var result: [FlattenedMediaItem] = []
        for note in notes {
            guard case let .media(images, videos)? = note.bundle else { continue }
            struct LocalEntry { let isImage: Bool; let index: Int; let order: Int }
            var merged: [LocalEntry] = []
            for (imageIndex, img) in images.enumerated() {
                let order = img.orderIndex ?? imageIndex
                merged.append(LocalEntry(isImage: true, index: imageIndex, order: order))
            }
            for (videoIndex, vid) in videos.enumerated() {
                let order = vid.orderIndex ?? (images.count + videoIndex)
                merged.append(LocalEntry(isImage: false, index: videoIndex, order: order))
            }
            merged.sort { $0.order < $1.order }
            for entry in merged {
                if entry.isImage {
                    result.append(
                        .init(
                            id: "\(note.id.uuidString)-i-\(entry.index)",
                            isVideo: false,
                            imageData: images[entry.index].data,
                            videoURL: nil,
                            uploadedAt: note.uploadedAt,
                            localOrder: entry.order
                        )
                    )
                } else {
                    result.append(
                        .init(
                            id: "\(note.id.uuidString)-v-\(entry.index)",
                            isVideo: true,
                            imageData: nil,
                            videoURL: videos[entry.index].url,
                            uploadedAt: note.uploadedAt,
                            localOrder: entry.order
                        )
                    )
                }
            }
        }
        return result.sorted {
            if $0.uploadedAt != $1.uploadedAt { return $0.uploadedAt > $1.uploadedAt }
            if $0.id.prefix(36) == $1.id.prefix(36) { return $0.localOrder > $1.localOrder }
            return $0.id > $1.id
        }
    }
    
    func computeFileItems(from notes: [Note]) -> [FlattenedFileItem] {
        var result: [FlattenedFileItem] = []
        for note in notes {
            if case let .files(fileSet)? = note.bundle {
                for (index, fileAttachment) in fileSet.enumerated() {
                    result.append(.init(id: "\(note.id.uuidString)-f-\(index)", url: fileAttachment.url, contentType: fileAttachment.contentType, uploadedAt: note.uploadedAt, localIndex: index))
                }
            }
        }
        return result.sorted {
            if $0.uploadedAt != $1.uploadedAt { return $0.uploadedAt > $1.uploadedAt }
            if $0.id.prefix(36) == $1.id.prefix(36) { return $0.localIndex < $1.localIndex }
            return $0.id > $1.id
        }
    }
    
    func computeAudioItems(from notes: [Note]) -> [FlattenedAudioItem] {
        var result: [FlattenedAudioItem] = []
        for note in notes {
            if case let .audio(audioSet)? = note.bundle {
                for (index, audioAttachment) in audioSet.enumerated() {
                    result.append(.init(id: "\(note.id.uuidString)-a-\(index)", url: audioAttachment.url, duration: audioAttachment.duration, uploadedAt: note.uploadedAt, localIndex: index))
                }
            }
        }
        return result.sorted {
            if $0.uploadedAt != $1.uploadedAt { return $0.uploadedAt > $1.uploadedAt }
            if $0.id.prefix(36) == $1.id.prefix(36) { return $0.localIndex < $1.localIndex }
            return $0.id > $1.id
        }
    }
    
    func computeLinkItems(from notes: [Note]) -> [FlattenedLinkItem] {
        var all: [FlattenedLinkItem] = []
        for note in notes {
            guard let text = note.text else { continue }
            let found = urls(in: text, limit: Int.max)
            for foundURL in found {
                all.append(.init(id: "\(note.id.uuidString)-l-\(foundURL.absoluteString)", url: foundURL, uploadedAt: note.uploadedAt))
            }
        }
        let sorted = all.sorted { $0.uploadedAt == $1.uploadedAt ? $0.id > $1.id : $0.uploadedAt > $1.uploadedAt }
        var seen = Set<String>()
        var dedup: [FlattenedLinkItem] = []
        for item in sorted where seen.insert(item.url.absoluteString).inserted {
            dedup.append(item)
        }
        return dedup
    }
    
    func urls(in text: String, limit: Int = 3) -> [URL] {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let textAsNSString = text as NSString
        let fullRange = NSRange(location: 0, length: textAsNSString.length)
        let matches = detector?.matches(in: text, options: [], range: fullRange) ?? []
        var seen = Set<String>()
        var extractedURLs: [URL] = []
        for match in matches {
            guard let url = match.url else { continue }
            if seen.insert(url.absoluteString).inserted {
                extractedURLs.append(url)
                if extractedURLs.count >= limit { break }
            }
        }
        return extractedURLs
    }
}

private struct ProfileDetailScreen: View {
    let clientId: UUID
    @State private var dummy: DummyClient = DummyClient(
        profile: nil,
        nameCardFront: nil,
        nameCardBack: nil,
        surname: "",
        name: "",
        position: nil,
        company: "",
        department: nil,
        email: nil,
        phoneNumber: nil,
        linkedinURL: nil,
        memo: nil,
        action: nil,
        favorite: false,
        pin: false,
        notes: [],
        industry: nil,
        address: nil,
        faxNumber: nil,
        revenue: nil,
        employees: nil,
        additionalEmails: [],
        additionalPhones: [],
        additionalURLs: []
    )
    
    init(clientId: UUID) {
        self.clientId = clientId
        if let client = ClientsStore.shared.clients.first(where: { $0.id == clientId }) {
            _dummy = State(initialValue: ProfileDetailScreen.convertToDummy(client))
        }
    }
    var body: some View {
        ProfileDetailView(clientId: clientId, client: $dummy)
    }
    
    private static func convertToDummy(_ client: Client) -> DummyClient {
        DummyClient(
            profile: client.profile,
            nameCardFront: client.nameCardFront ?? Image("CardL"),
            nameCardBack: client.nameCardBack ?? Image("CardL"),
            surname: client.surname,
            name: client.name,
            position: client.position,
            company: client.company,
            department: client.department,
            email: client.email,
            phoneNumber: client.phoneNumber,
            linkedinURL: client.linkedinURL,
            memo: client.memo,
            action: client.action,
            favorite: client.favorite,
            pin: client.pin,
            notes: [],
            industry: client.industry,
            address: client.address,
            faxNumber: client.faxNumber,
            revenue: client.revenue,
            employees: client.employees,
            additionalEmails: client.additionalEmails,
            additionalPhones: client.additionalPhones,
            additionalURLs: client.additionalURLs
        )
    }
}

#Preview {
    RootView()
        .environmentObject(NavigationRouter())
}

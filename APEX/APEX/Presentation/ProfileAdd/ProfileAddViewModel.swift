//
//  ProfileAddViewModel.swift
//  APEX
//
//  Created by 조운경 on 10/21/25.
//

import Foundation
import SwiftUI

@MainActor
final class ProfileAddViewModel: ViewModelable {
    enum Action {
        case onAppear
        case tapPhoto(PhotoAddView.PhotoType)
        case setProfileImage(UIImage)
        case setCardImage(UIImage, isFront: Bool)
        case presentAddItems(Bool)
    }
    
    // MARK: - UI State
    @Published var profileUIImage: UIImage? = nil
    @Published var cardFrontUIImage: UIImage? = nil
    @Published var cardBackUIImage: UIImage? = nil
    
    @Published var presentedPhotoType: PhotoAddView.PhotoType?
    @Published var isAddItemPresented: Bool = false
    @Published var addItemConfig: AddItemConfig = .default {
        didSet { ensureFieldArrays() }
    }
    
    // Text fields
    @Published var surname: String = ""
    @Published var name: String = ""
    @Published var company: String = ""
    @Published var department: String = ""
    @Published var position: String = ""
    
    // Dynamic fields
    @Published var emails: [String] = []
    @Published var contacts: [String] = []
    @Published var urls: [String] = []
    
    // Optional fields
    @Published var linkedinLink: String = ""
    @Published var industry: String = ""
    @Published var address: String = ""
    @Published var faxNumber: String = ""
    @Published var revenue: String = ""
    @Published var employees: String = ""
    @Published var memo: String = ""
    
    // MARK: - Derived
    var isDoneEnabled: Bool {
        // Keep behavior consistent with previous implementation (enabled if either has value)
        !surname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Actions
    func send(_ action: Action) {
        switch action {
        case .onAppear:
            ensureFieldArrays()
        case .tapPhoto(let type):
            presentedPhotoType = type
        case .setProfileImage(let image):
            profileUIImage = image
        case .setCardImage(let image, let isFront):
            if isFront { cardFrontUIImage = image } else { cardBackUIImage = image }
        case .presentAddItems(let presented):
            isAddItemPresented = presented
        }
    }
    
    // MARK: - Public
    func makeClient() -> Client {
        Client(
            profile: profileUIImage,
            nameCardFront: cardFrontUIImage.map { Image(uiImage: $0) },
            nameCardBack: cardBackUIImage.map { Image(uiImage: $0) },
            surname: surname,
            name: name,
            position: position.isEmpty ? nil : position,
            company: company,
            email: emails.first,
            phoneNumber: contacts.first,
            linkedinURL: linkedinLink.isEmpty ? nil : linkedinLink,
            memo: memo.isEmpty ? nil : memo,
            action: nil,
            favorite: false,
            pin: false,
            notes: []
        )
    }
    
    // MARK: - Helpers
    func ensureFieldArrays() {
        resize(&emails, to: addItemConfig.emailCount)
        resize(&contacts, to: addItemConfig.phoneCount)
        resize(&urls, to: addItemConfig.urlCount)
    }
    
    private func resize(_ array: inout [String], to newCount: Int) {
        if newCount < 0 { return }
        if array.count < newCount {
            array.append(contentsOf: Array(repeating: "", count: max(0, newCount - array.count)))
        } else if array.count > newCount {
            array = Array(array.prefix(newCount))
        }
    }
}

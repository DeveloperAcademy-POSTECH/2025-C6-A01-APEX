//
//  ProfileDetailViewModel.swift
//  APEX
//
//  Created by Assistant on 11/23/25.
//

import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
final class ProfileDetailViewModel: ViewModelable {
    enum Action {
        case setPage(Int)
        case presentEdit(Bool)
        case showCardViewer(Bool)
        case setAlert(String?)
        case setContactAction(ProfileContactAction?)
    }
    
    // MARK: - Inputs
    private var clientBinding: Binding<DummyClient>
    private let clientId: UUID
    
    // MARK: - UI State
    @Published var isPresentingEdit: Bool = false
    @Published var showingContactAction: ProfileContactAction? = nil
    @Published var isShowingCardViewer: Bool = false
    @Published var alertMessage: String? = nil
    @Published var currentPageIndex: Int = 0
    
    // MARK: - Init
    init(clientId: UUID, client: Binding<DummyClient>) {
        self.clientId = clientId
        self.clientBinding = client
    }
    
    // MARK: - Derived
    var client: DummyClient { clientBinding.wrappedValue }
    
    var adaptedClient: Client {
        ClientsStore.convertToClient(clientBinding.wrappedValue)
    }
    
    var contactDialogTitle: String {
        switch showingContactAction {
        case .email: return "이메일"
        case .phone: return "전화번호"
        case .link:  return "링크"
        case .none:  return ""
        }
    }
    
    // MARK: - ViewModelable
    func send(_ action: Action) {
        switch action {
        case .setPage(let idx):
            currentPageIndex = idx
        case .presentEdit(let presented):
            isPresentingEdit = presented
        case .showCardViewer(let show):
            isShowingCardViewer = show
        case .setAlert(let msg):
            alertMessage = msg
        case .setContactAction(let action):
            showingContactAction = action
        }
    }
}

// MARK: - Public Methods for View Hooks
extension ProfileDetailViewModel {
    func openExternal(_ url: URL?) {
        guard let url else { alertMessage = "잘못된 주소입니다."; return }
        UIApplication.shared.open(url, options: [:]) { [weak self] success in
            guard let self else { return }
            if !success { self.alertMessage = "열 수 없습니다." }
        }
    }
    
    func copyToPasteboard(_ text: String) {
        UIPasteboard.general.string = text
    }
    
    func persistClientUpdate(_ updated: DummyClient, previousEmail: String?) {
        // Push edit result to the bound client
        clientBinding.wrappedValue = updated
        
        // Update the exact existing client by id to keep action/favorite/pin/notes
        guard let existing = ClientsStore.shared.clients.first(where: { $0.id == clientId }) else { return }
        let newClient = Client(
            id: existing.id,
            profile: updated.profile,
            nameCardFront: updated.nameCardFront,
            nameCardBack: updated.nameCardBack,
            surname: updated.surname,
            name: updated.name,
            position: updated.position,
            company: updated.company,
            department: updated.department,
            email: updated.email,
            phoneNumber: updated.phoneNumber,
            linkedinURL: updated.linkedinURL,
            memo: updated.memo,
            action: existing.action,
            favorite: existing.favorite,
            pin: existing.pin,
            notes: existing.notes,
            industry: updated.industry,
            address: updated.address,
            faxNumber: updated.faxNumber,
            revenue: updated.revenue,
            employees: updated.employees,
            additionalEmails: updated.additionalEmails,
            additionalPhones: updated.additionalPhones,
            additionalURLs: updated.additionalURLs
        )
        ClientsStore.shared.update(newClient)
    }
    
    func deleteClient() {
        ClientsStore.shared.remove(clientId)
    }
    
    func updateMemo(_ memo: String?) {
        // 실시간으로 메모 업데이트
        guard let existing = ClientsStore.shared.clients.first(where: { $0.id == clientId }) else { return }
        let updatedClient = Client(
            id: existing.id,
            profile: existing.profile,
            nameCardFront: existing.nameCardFront,
            nameCardBack: existing.nameCardBack,
            surname: existing.surname,
            name: existing.name,
            position: existing.position,
            company: existing.company,
            department: existing.department,
            email: existing.email,
            phoneNumber: existing.phoneNumber,
            linkedinURL: existing.linkedinURL,
            memo: memo,
            action: existing.action,
            favorite: existing.favorite,
            pin: existing.pin,
            notes: existing.notes,
            industry: existing.industry,
            address: existing.address,
            faxNumber: existing.faxNumber,
            revenue: existing.revenue,
            employees: existing.employees,
            additionalEmails: existing.additionalEmails,
            additionalPhones: existing.additionalPhones,
            additionalURLs: existing.additionalURLs
        )
        ClientsStore.shared.update(updatedClient)
    }
}

// MARK: - Types
enum ProfileContactAction: Equatable {
    case email(String)
    case phone(String)
    case link(String)
}



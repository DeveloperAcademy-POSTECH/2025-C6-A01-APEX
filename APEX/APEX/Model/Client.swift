//
//  Client.swift
//  APEX
//
//  Created by 조운경 on 10/7/25.
//
import Foundation
import SwiftUI

struct Client: Identifiable, Hashable {
    let id: UUID
    let profile: UIImage? // 샘플데이터용 타입
    let nameCardFront: Image? // 샘플데이터용 타입
    let nameCardBack: Image?
    let surname: String
    let name: String
    let position: String?
    let company: String
    let email: String?
    let phoneNumber: String?
    let linkedinURL: String?
    let memo: String?
    let action: String?
    let favorite: Bool
    let pin: Bool
    var notes: [Note]

    init(
        id: UUID = UUID(),
        profile: UIImage?,
        nameCardFront: Image?,
        nameCardBack: Image?,
        surname: String,
        name: String,
        position: String?,
        company: String,
        email: String?,
        phoneNumber: String?,
        linkedinURL: String?,
        memo: String?,
        action: String?,
        favorite: Bool,
        pin: Bool,
        notes: [Note]
    ) {
        self.id = id
        self.profile = profile
        self.nameCardFront = nameCardFront
        self.nameCardBack = nameCardBack
        self.surname = surname
        self.name = name
        self.position = position
        self.company = company
        self.email = email
        self.phoneNumber = phoneNumber
        self.linkedinURL = linkedinURL
        self.memo = memo
        self.action = action
        self.favorite = favorite
        self.pin = pin
        self.notes = notes
    }
}

extension Client {
    static func == (lhs: Client, rhs: Client) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

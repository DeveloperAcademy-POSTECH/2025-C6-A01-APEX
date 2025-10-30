//
//  Client.swift
//  APEX
//
//  Created by 조운경 on 10/7/25.
//
import Foundation
import SwiftUI

struct Client: Identifiable, Hashable {
    let id = UUID()
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
    let notes: [Note]
}

extension Client {
    static func == (lhs: Client, rhs: Client) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

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
    let department: String? // 추가
    let email: String?
    let phoneNumber: String?
    let linkedinURL: String?
    let memo: String?
    let action: String?
    var favorite: Bool
    var pin: Bool
    var notes: [Note]
    
    // 추가 필드들
    let industry: String?
    let address: String?
    let faxNumber: String?
    let revenue: String?
    let employees: String?
    let additionalEmails: [String]
    let additionalPhones: [String]
    let additionalURLs: [String]
    // 기본 초기화 함수 (새 UUID 생성)
    init(profile: UIImage? = nil, nameCardFront: Image? = nil, nameCardBack: Image? = nil,
         surname: String, name: String, position: String? = nil, company: String,
         department: String? = nil, email: String? = nil, phoneNumber: String? = nil, linkedinURL: String? = nil,
         memo: String? = nil, action: String? = nil, favorite: Bool = false,
         pin: Bool = false, notes: [Note] = [],
         industry: String? = nil, address: String? = nil, faxNumber: String? = nil,
         revenue: String? = nil, employees: String? = nil, additionalEmails: [String] = [],
         additionalPhones: [String] = [], additionalURLs: [String] = []) {
        self.id = UUID()
        self.profile = profile
        self.nameCardFront = nameCardFront
        self.nameCardBack = nameCardBack
        self.surname = surname
        self.name = name
        self.position = position
        self.company = company
        self.department = department
        self.email = email
        self.phoneNumber = phoneNumber
        self.linkedinURL = linkedinURL
        self.memo = memo
        self.action = action
        self.favorite = favorite
        self.pin = pin
        self.notes = notes
        self.industry = industry
        self.address = address
        self.faxNumber = faxNumber
        self.revenue = revenue
        self.employees = employees
        self.additionalEmails = additionalEmails
        self.additionalPhones = additionalPhones
        self.additionalURLs = additionalURLs
    }
    // ID를 유지하는 초기화 함수
    init(id: UUID, profile: UIImage? = nil, nameCardFront: Image? = nil, nameCardBack: Image? = nil,
         surname: String, name: String, position: String? = nil, company: String,
         department: String? = nil, email: String? = nil, phoneNumber: String? = nil, linkedinURL: String? = nil,
         memo: String? = nil, action: String? = nil, favorite: Bool = false,
         pin: Bool = false, notes: [Note] = [],
         industry: String? = nil, address: String? = nil, faxNumber: String? = nil,
         revenue: String? = nil, employees: String? = nil, additionalEmails: [String] = [],
         additionalPhones: [String] = [], additionalURLs: [String] = []) {
        self.id = id
        self.profile = profile
        self.nameCardFront = nameCardFront
        self.nameCardBack = nameCardBack
        self.surname = surname
        self.name = name
        self.position = position
        self.company = company
        self.department = department
        self.email = email
        self.phoneNumber = phoneNumber
        self.linkedinURL = linkedinURL
        self.memo = memo
        self.action = action
        self.favorite = favorite
        self.pin = pin
        self.notes = notes
        self.industry = industry
        self.address = address
        self.faxNumber = faxNumber
        self.revenue = revenue
        self.employees = employees
        self.additionalEmails = additionalEmails
        self.additionalPhones = additionalPhones
        self.additionalURLs = additionalURLs
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

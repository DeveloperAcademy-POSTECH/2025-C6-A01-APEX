//
//  DummyData.swift
//  APEX
//
//  Created by 조운경 on 10/7/25.
//

import Foundation

let sampleClients: [Client] = [
    Client(
        profile: nil,
        nameCard: nil,
        surname: "Kim",
        name: "Minjun",
        position: "Software Engineer",
        company: "TechWave",
        email: "minjun.kim@techwave.com",
        phoneNumber: "010-1234-5678",
        linkedinURL: "https://linkedin.com/in/minjunkim",
        memo: "백엔드 아키텍처 담당",
        action: "Follow up for API review",
        favorite: true,
        pin: false,
        notes: []
    ),
    Client(
        profile: nil,
        nameCard: nil,
        surname: "Lee",
        name: "Sujin",
        position: "Product Manager",
        company: "InnoSoft",
        email: "sujin.lee@innosoft.com",
        phoneNumber: "010-8765-4321",
        linkedinURL: nil,
        memo: "신규 프로젝트 기획 리드",
        action: nil,
        favorite: false,
        pin: true,
        notes: []
    ),
    Client(
        profile: nil,
        nameCard: nil,
        surname: "Park",
        name: "Jihun",
        position: "Designer",
        company: "CreativeLab",
        email: "jihun.park@creativelab.com",
        phoneNumber: nil,
        linkedinURL: nil,
        memo: "UI/UX 전문가",
        action: "Send design references",
        favorite: true,
        pin: true,
        notes: []
    )
]

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
        nameCardFront: nil,
        nameCardBack: nil,
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
        notes: [
            Note(
                uploadedAt: Date().addingTimeInterval(-3600),
                text: nil,
                bundle: .media(images: [], videos: [VideoAttachment(url: URL(fileURLWithPath: "/tmp/meeting.mp4"), progress: nil, orderIndex: nil)])
            ),
            Note(
                uploadedAt: Date().addingTimeInterval(-7200),
                text: "API 설계 회의 내용",
                bundle: nil
            )
        ]
    ),
    Client(
        profile: nil,
        nameCardFront: nil,
        nameCardBack: nil,
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
        notes: [
            Note(
                uploadedAt: Date().addingTimeInterval(-1800),
                text: nil,

                bundle: .media(images: [], videos: [VideoAttachment(url: URL(fileURLWithPath: "/tmp/presentation.mp4"), progress: nil, orderIndex: nil)])
            ),
            Note(
                uploadedAt: Date().addingTimeInterval(-5400),
                text: nil,
                bundle: .media(images: [ImageAttachment(data: Data(), progress: nil, orderIndex: nil)], videos: [])
            )
        ]
    ),
    Client(
        profile: nil,
        nameCardFront: nil,
        nameCardBack: nil,
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
        notes: [
            Note(
                uploadedAt: Date().addingTimeInterval(-900),
                text: nil,
                bundle: .media(images: [], videos: [VideoAttachment(url: URL(fileURLWithPath: "/tmp/design_review.mp4"), progress: nil, orderIndex: nil)])
            )
        ]
    ),
    // 추가 샘플 데이터
    Client(
        profile: nil,
        nameCardFront: nil,
        nameCardBack: nil,
        surname: "Choi",
        name: "Eunji",
        position: "Marketing Director",
        company: "APEX",
        email: "eunji.choi@apex.com",
        phoneNumber: "010-5555-7777",
        linkedinURL: "https://linkedin.com/in/eunjichoi",
        memo: "마케팅 전략 수립",
        action: nil,
        favorite: false,
        pin: false,
        notes: [
            Note(
                uploadedAt: Date().addingTimeInterval(-2700),
                text: nil,
                bundle: .media(images: [], videos: [VideoAttachment(url: URL(fileURLWithPath: "/tmp/campaign.mp4"), progress: nil, orderIndex: nil)])
            )
        ]
    ),
    Client(
        profile: nil,
        nameCardFront: nil,
        nameCardBack: nil,
        surname: "Jung",
        name: "Taehyun",
        position: "iOS Developer",
        company: "Apple",
        email: "taehyun.jung@apple.com",
        phoneNumber: "010-3333-9999",
        linkedinURL: nil,
        memo: "SwiftUI 전문가",
        action: "Code review scheduled",
        favorite: true,
        pin: false,
        notes: [
            Note(
                uploadedAt: Date().addingTimeInterval(-4500),
                text: nil,
                bundle: .media(images: [], videos: [VideoAttachment(url: URL(fileURLWithPath: "/tmp/code_review.mp4"), progress: nil, orderIndex: nil)])
            )
        ]
    ),
    // 노트가 없는 클라이언트 (비활성화 필터 테스트용)
    Client(
        profile: nil,
        nameCardFront: nil,
        nameCardBack: nil,
        surname: "Smith",
        name: "John",
        position: "Product Manager",
        company: "Google",
        email: "john.smith@google.com",
        phoneNumber: "010-1111-2222",
        linkedinURL: nil,
        memo: "Google 제품 관리",
        action: nil,
        favorite: false,
        pin: false,
        notes: []  // 노트 없음 - 필터에서 비활성화됨
    )
]

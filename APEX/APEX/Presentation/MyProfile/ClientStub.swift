//
//  ClientStub.swift
//  APEX
//
//  Created by Temporary on 10/27/25.
//

import SwiftUI

// 전역 임시 모델: 실제 백엔드/도메인 모델이 준비되면 이 파일을 교체하거나 삭제하고
// 동일한 프로퍼티 이름/타입에 맞춰 마이그레이션하면 됩니다.
struct DummyClient: Identifiable, Equatable {
    let id: UUID = UUID()

    // 미디어
    var profile: UIImage?                 // 프로필 사진(앨범/카메라 원본)
    var nameCardFront: Image?             // 명함 앞면(미리보기용 Image)
    var nameCardBack: Image?              // 명함 뒷면(미리보기용 Image)

    // 기본 정보
    var surname: String                   // 성
    var name: String                      // 이름
    var position: String?                 // 직책
    var company: String                   // 회사

    // 연락처
    var email: String?
    var phoneNumber: String?
    var linkedinURL: String?

    // 메모
    var memo: String?

    // 기타(임시)
    // action: 실제 액션 모델이 생기면 여기 타입을 교체하세요.
    var action: String? = nil

    var favorite: Bool
    var pin: Bool

    // notes: 실제 구조가 생기면 요소 타입을 교체하세요.
    var notes: [String]
}

// MARK: - Sample Data for MyProfile

let sampleMyProfileClient = DummyClient(
    profile: nil,
    nameCardFront: Image("CardL"),
    nameCardBack: Image("CardL"),
    surname: "김",
    name: "하경",
    position: "크리에이티브 디렉터",
    company: "전략기획 마케팅부",
    email: "karynkim@postech.ac.kr",
    phoneNumber: "+82 010-2360-6221",
    linkedinURL: "https://www.linkedin.com/in/karyn",
    memo: "태국 박람회에서 만남...",
    action: nil,
    favorite: false,
    pin: false,
    notes: []
)

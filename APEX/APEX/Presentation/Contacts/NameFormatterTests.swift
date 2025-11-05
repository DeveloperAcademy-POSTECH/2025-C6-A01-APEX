//
//  NameFormatterTests.swift
//  APEX
//
//  NameFormatter의 다양한 케이스를 테스트하는 PreviewProvider
//

import SwiftUI

struct NameFormatterTestView: View {
    // 다양한 테스트 케이스
    let testCases: [(name: String, surname: String, description: String)] = [
        // 한글 케이스
        ("철수", "김", "한글 이름 + 한글 성"),
        ("하경", "김", "한글 이름 + 한글 성 (여성)"),
        ("민준", "박", "한글 이름 + 한글 성 (남성)"),
        
        // 영어 케이스
        ("John", "Doe", "영어 이름 + 영어 성"),
        ("Sarah", "Smith", "영어 이름 + 영어 성 (여성)"),
        ("Michael", "Johnson", "영어 이름 + 영어 성 (남성)"),
        
        // 혼합 케이스 1: 한글 성 + 영어 이름
        ("John", "김", "영어 이름 + 한글 성"),
        ("Sarah", "박", "영어 이름 + 한글 성 (여성)"),
        ("Michael", "이", "영어 이름 + 한글 성 (남성)"),
        
        // 혼합 케이스 2: 영어 성 + 한글 이름
        ("철수", "Kim", "한글 이름 + 영어 성"),
        ("하경", "Park", "한글 이름 + 영어 성 (여성)"),
        ("민준", "Lee", "한글 이름 + 영어 성 (남성)"),
        
        // 복잡한 혼합 케이스 (여러 언어가 섞인 경우)
        ("김ha경", "박", "혼합 이름 + 한글 성 (첫 글자 기준)"),
        ("John김", "이", "혼합 이름 + 한글 성 (첫 글자 기준)"),
        ("박", "Smithる", "한글 이름 + 혼합 성 (첫 글자 기준)"),
        ("김", "るSmith", "한글 이름 + 혼합 성 (첫 글자 기준)"),
        
        // 다른 언어 케이스 (일본어, 중국어 등)
        ("る美", "田中", "일본어 이름 + 일본어 성"),
        ("美子", "김", "일본어 이름 + 한글 성"),
        ("철수", "田中", "한글 이름 + 일본어 성"),
        ("张", "李", "중국어 이름 + 중국어 성"),
        
        // 특수 케이스
        ("", "김", "이름 없음"),
        ("John", "", "성 없음"),
        ("", "", "둘 다 없음"),
        ("   ", "박", "이름이 공백"),
        ("Jane", "   ", "성이 공백"),
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("자동 이름 포맷팅 규칙")
                            .font(.headline)
                        
                        Text("언어 판단: 첫 번째 문자 기준 (한글/비한글)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("한글 + 한글")
                                Spacer()
                                Text("→ 성+이름 (김철수)")
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                                Text("비한글 + 비한글")
                                Spacer()
                                Text("→ 이름 성 (John Doe)")
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 8, height: 8)
                                Text("혼합")
                                Spacer()
                                Text("→ 성 이름 (김 John)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 8)
                }
                
                Section("테스트 케이스") {
                    ForEach(Array(testCases.enumerated()), id: \.offset) { index, testCase in
                        let formattedName = NameFormatter.autoFormat(name: testCase.name, surname: testCase.surname)
                        let format = NameFormatter.determineFormat(name: testCase.name, surname: testCase.surname)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(testCase.description)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(formatDescription(format))
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(formatColor(format))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            
                            HStack {
                                Text("입력:")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text("이름='\(testCase.name)', 성='\(testCase.surname)'")
                                    .font(.system(.caption, design: .monospaced))
                                Spacer()
                            }
                            
                            HStack {
                                Text("결과:")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text("'\(formattedName)'")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("이름 포맷팅 테스트")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func formatDescription(_ format: NameDisplayFormat) -> String {
        switch format {
        case .korean:
            return "성+이름"
        case .western:
            return "이름 성"
        case .koreanWithSpace:
            return "성 이름"
        case .westernWithSpace:
            return "이름 성"
        }
    }
    
    private func formatColor(_ format: NameDisplayFormat) -> Color {
        switch format {
        case .korean:
            return .green
        case .western, .westernWithSpace:
            return .blue
        case .koreanWithSpace:
            return .orange
        }
    }
}

#Preview("이름 포맷팅 테스트") {
    NameFormatterTestView()
}

// MARK: - ContactsView에 테스트 케이스 추가를 위한 샘플 데이터

extension NameFormatterTestView {
    /// ContactsView에서 테스트할 수 있는 샘플 클라이언트들
    static var sampleTestClients: [Client] {
        let testCases: [(name: String, surname: String, company: String)] = [
            ("철수", "김", "한국 회사"),
            ("John", "Doe", "American Company"),
            ("John", "김", "글로벌 코리아"),
            ("하경", "Smith", "Korea Smith Inc."),
            ("Sarah", "박", "박씨 기업"),
            ("민준", "Johnson", "Johnson Korea"),
        ]
        
        return testCases.enumerated().map { index, testCase in
            Client(
                profile: nil,
                nameCardFront: nil,
                nameCardBack: nil,
                surname: testCase.surname,
                name: testCase.name,
                position: "테스트 직책",
                company: testCase.company,
                email: "test\(index)@example.com",
                phoneNumber: "010-1234-567\(index)",
                linkedinURL: nil,
                memo: "테스트 메모",
                action: nil,
                favorite: index % 2 == 0,
                pin: false,
                notes: []
            )
        }
    }
}
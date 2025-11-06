//
//  NameFormatter.swift
//  APEX
//
//  이름 표기 방식을 통일하기 위한 유틸리티
//

import Foundation

enum NameDisplayFormat {
    case korean      // 성 + 이름 (김철수)
    case western     // 이름 + 성 (John Doe)
    case koreanWithSpace  // 성 + 이름 (김 철수)
    case westernWithSpace // 이름 + 성 (John Doe)
}

struct NameFormatter {
    /// 앱 전체에서 사용할 기본 이름 표기 방식
    /// 한국 앱의 특성상 한국식(성+이름)을 기본으로 제안
    static let defaultFormat: NameDisplayFormat = .korean
    
    /// 이름과 성을 지정된 형식으로 포맷팅
    /// - Parameters:
    ///   - name: 이름 (예: "철수", "John")
    ///   - surname: 성 (예: "김", "Doe")
    ///   - format: 표기 형식 (기본값: defaultFormat)
    /// - Returns: 포맷팅된 전체 이름
    static func format(name: String, surname: String, format: NameDisplayFormat = defaultFormat) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSurname = surname.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 빈 값 처리
        let nameComponents = [trimmedName, trimmedSurname].filter { !$0.isEmpty }
        guard !nameComponents.isEmpty else { return "" }
        
        if nameComponents.count == 1 {
            return nameComponents[0]
        }
        
        switch format {
        case .korean:
            return "\(trimmedSurname)\(trimmedName)"
        case .western:
            return "\(trimmedName) \(trimmedSurname)"
        case .koreanWithSpace:
            return "\(trimmedSurname) \(trimmedName)"
        case .westernWithSpace:
            return "\(trimmedName) \(trimmedSurname)"
        }
    }
    
    /// 텍스트의 주요 언어를 첫 번째 문자로 판단하는 함수
    /// - Parameter text: 확인할 텍스트
    /// - Returns: 한글이면 true, 그 외(영어, 일본어, 중국어 등)는 false
    static func isKoreanBased(_ text: String) -> Bool {
        guard let firstChar = text.first else { return false }
        let koreanRange = "\u{AC00}"..."\u{D7A3}" // 한글 유니코드 범위
        return koreanRange.contains(String(firstChar))
    }
    
    /// 이름 표기 형식을 자동으로 결정하는 함수
    /// - Parameters:
    ///   - name: 이름
    ///   - surname: 성
    /// - Returns: 적절한 표기 형식
    static func determineFormat(name: String, surname: String) -> NameDisplayFormat {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSurname = surname.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 빈 문자열 처리
        guard !trimmedName.isEmpty || !trimmedSurname.isEmpty else {
            return .korean // 기본값
        }
        
        // 첫 번째 문자로 언어 판단 (빈 문자열이 아닌 경우에만)
        let nameIsKorean = !trimmedName.isEmpty ? isKoreanBased(trimmedName) : false
        let surnameIsKorean = !trimmedSurname.isEmpty ? isKoreanBased(trimmedSurname) : false
        
        // 하나만 있는 경우
        if trimmedName.isEmpty {
            return surnameIsKorean ? .korean : .western
        }
        if trimmedSurname.isEmpty {
            return nameIsKorean ? .korean : .western
        }
        
        // 둘 다 있는 경우
        if nameIsKorean && surnameIsKorean {
            // 모두 한글: 성+이름 (공백 없음)
            return .korean
        } else if !nameIsKorean && !surnameIsKorean {
            // 모두 비한글(영어/기타): 이름 성 (공백 있음)
            return .western
        } else {
            // 혼합: 성 이름 (공백 있음)
            return .koreanWithSpace
        }
    }
    
    /// 자동으로 적절한 형식을 선택하여 포맷팅
    /// - Parameters:
    ///   - name: 이름
    ///   - surname: 성
    /// - Returns: 자동으로 선택된 형식으로 포맷팅된 이름
    static func autoFormat(name: String, surname: String) -> String {
        let selectedFormat = determineFormat(name: name, surname: surname)
        return format(name: name, surname: surname, format: selectedFormat)
    }
}

// MARK: - Client 확장

extension Client {
    /// 통일된 형식의 전체 이름
    var displayName: String {
        return NameFormatter.format(name: name, surname: surname)
    }
    
    /// 자동 형식의 전체 이름
    var autoFormattedName: String {
        return NameFormatter.autoFormat(name: name, surname: surname)
    }
}

// MARK: - DummyClient 확장 (기존 코드와의 호환성)

extension DummyClient {
    /// 통일된 형식의 전체 이름
    var displayName: String {
        return NameFormatter.format(name: name, surname: surname)
    }
    
    /// 자동 형식의 전체 이름
    var autoFormattedName: String {
        return NameFormatter.autoFormat(name: name, surname: surname)
    }
}
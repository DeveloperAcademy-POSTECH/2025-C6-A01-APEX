//
//  Date+Extension.swift
//  APEX
//
//  Created by 조운경 on 10/28/25.
//

import Foundation

extension Date {
    var formattedHeaderDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR") // 한국어 날짜/AM/PM 유지
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"

        // 시스템 설정에 따라 12/24시간 자동 결정
        if DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current)?.contains("a") == true {
            // 12시간제: 공백 있는 패턴 사용
            formatter.dateFormat = "yyyy.MM.dd h:mm a"
        } else {
            // 24시간제: AM/PM 없는 패턴 사용
            formatter.dateFormat = "yyyy.MM.dd H:mm"
        }

        return formatter.string(from: self)
    }

    private var isInCurrentYear: Bool {
        let cal = Calendar.current
        return cal.component(.year, from: self) == cal.component(.year, from: Date())
    }

    var formattedChatDayHeader: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = isInCurrentYear ? "M월 d일 EEEE" : "yyyy년 M월 d일 EEEE"
        return formatter.string(from: self)
    }
    
    var formattedChatTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR") // 한국어 AM/PM 유지
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"

        // 시스템 설정에 따라 12/24시간 자동 결정하되, 12시간제일 때 공백 추가
        if DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current)?.contains("a") == true {
            // 12시간제: 공백 있는 패턴 사용
            formatter.dateFormat = "h:mm a"
        } else {
            // 24시간제: AM/PM 없는 패턴 사용
            formatter.dateFormat = "H:mm"
        }

        return formatter.string(from: self)
    }

    // 채팅 스크롤 인디케이터용: "yyyy.M.d E" (올해면 연도 생략), 요일은 한 글자
    var formattedScrollIndicator: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = isInCurrentYear ? "M.d E" : "yyyy.M.d E"
        return formatter.string(from: self)
    }
}

// Shared helper: same calendar day comparison
func isSameCalendarDay(_ lhs: Date, _ rhs: Date?) -> Bool {
    guard let rhs else { return false }
    return Calendar.current.isDate(lhs, inSameDayAs: rhs)
}

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
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        formatter.dateFormat = "yyyy.MM.dd h:mm a"
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
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        formatter.dateFormat = "h:mm a" // 예: 오후 3:27
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

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
}

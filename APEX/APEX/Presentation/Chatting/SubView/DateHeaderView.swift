//
//  DateHeaderView.swift
//  APEX
//
//  Extracted date header view and related helpers from ChattingView.
//

import SwiftUI

extension ChattingView {
    @ViewBuilder
    func dateHeaderView(_ date: Date) -> some View {
        Text(date.formattedChatDayHeader)
            .font(.caption2)
            .foregroundColor(isSameCalendarDay(date, highlightedDate) ? Color("Primary") : .gray)
            .offset(y: isSameCalendarDay(date, highlightedDate) ? dateHighlightOffsetY : 0)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: DateHeaderPositionsKey.self,
                        value: [date: geo.frame(in: .named("chatScroll")).minY]
                    )
                }
            )
            .id(dateHeaderId(date))
    }

    func dateHeaderId(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = comps.year ?? 0
        let month = (comps.month ?? 0)
        let day = (comps.day ?? 0)
        return String(format: "date-%04d%02d%02d", year, month, day)
    }
    
    func triggerDateBounce() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) {
            dateHighlightOffsetY = -4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) {
                dateHighlightOffsetY = 3
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                dateHighlightOffsetY = -2
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.7)) {
                dateHighlightOffsetY = 0
            }
        }
    }
}


import SwiftUI

struct ChatDatePickerSheet: View {
    @Binding var date: Date
    var hasMemoDays: Set<Date> = [] // normalized to startOfDay
    var onClose: () -> Void
    var onSelect: (Date) -> Void

    @GestureState private var dragOffset: CGFloat = 0

    private func adjustDate(by days: Int) {
        // Move in the swipe direction until we hit a day that has memos; if none, keep current
        guard days != 0 else { return }
        let step = days > 0 ? 1 : -1
        let cal = Calendar.current
        var candidate = date
        var attempts = 0
        while attempts < 62 { // roughly two months safety bound
            attempts += 1
            guard let next = cal.date(byAdding: .day, value: step, to: candidate) else { break }
            candidate = next
            if hasMemoDays.contains(startOfDay(candidate)) { date = candidate; break }
        }
    }

    private var startOfDisplayedMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }

    private var daysInMonth: [Date] {
        let cal = Calendar.current
        let start = startOfDisplayedMonth
        guard let range = cal.range(of: .day, in: .month, for: start) else { return [] }
        let firstWeekdayIndex = (cal.component(.weekday, from: start) + 6) % 7 // make Monday=0
        var days: [Date] = []
        // Leading placeholders from previous month
        if firstWeekdayIndex > 0 {
            for i in stride(from: firstWeekdayIndex - 1, through: 0, by: -1) {
                if let d = cal.date(byAdding: .day, value: -i - 1, to: start) { days.append(d) }
            }
        }
        // Current month days
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: start) { days.append(d) }
        }
        // Trailing placeholders to fill to 6 rows
        while days.count % 7 != 0 { if let last = days.last, let d = cal.date(byAdding: .day, value: 1, to: last) { days.append(d) } else { break } }
        while days.count < 42 { if let last = days.last, let d = cal.date(byAdding: .day, value: 1, to: last) { days.append(d) } else { break } }
        return days
    }

    private func isSameDay(_ a: Date, _ b: Date) -> Bool { Calendar.current.isDate(a, inSameDayAs: b) }
    private func isSameMonth(_ a: Date, _ b: Date) -> Bool { Calendar.current.component(.month, from: a) == Calendar.current.component(.month, from: b) && Calendar.current.component(.year, from: a) == Calendar.current.component(.year, from: b) }
    private func startOfDay(_ d: Date) -> Date { Calendar.current.startOfDay(for: d) }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 36, height: 36)
                        .glassEffect()
                }
            }

            // Custom month grid with per-day styling
            VStack(spacing: 8) {
                // Month header
                Text(monthHeader(for: date))
                    .font(.headline)
                // Weekday symbols (Mon..Sun)
                let symbols = Calendar.current.shortStandaloneWeekdaySymbols
                let shifted = Array(symbols[1...6] + symbols[0...0])
                HStack(spacing: 0) {
                    ForEach(shifted, id: \.self) { s in
                        Text(s)
                            .font(.caption2)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(Color.gray)
                    }
                }
                // Days grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                    ForEach(daysInMonth, id: \.self) { d in
                        let inMonth = isSameMonth(d, date)
                        let isSelected = isSameDay(d, date)
                        let hasMemo = hasMemoDays.contains(startOfDay(d))
                        let isEnabled = inMonth && hasMemo
                        Button {
                            date = d
                            onSelect(d)
                        } label: {
                            Text("\(Calendar.current.component(.day, from: d))")
                                .font(.caption)
                                .frame(width: 36, height: 36)
                                .background(isSelected ? Color("Primary") : Color.clear)
                                .foregroundStyle(
                                    isSelected ? Color.white : (
                                        hasMemo && inMonth ? Color.primary : Color("BackgroundDisabled")
                                    )
                                )
                                .clipShape(Circle())
                        }
                        .disabled(!isEnabled)
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 40
                        if value.translation.width > threshold {
                            adjustDate(by: -1) // swipe right -> previous day
                        } else if value.translation.width < -threshold {
                            adjustDate(by: 1) // swipe left -> next day
                        }
                    }
            )
        }
        .padding(16)
        .background(Color("Background"))
        .presentationDetents([.medium, .large])
        .environment(\.locale, Locale(identifier: "ko_KR"))
    }

    private func monthHeader(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "YYYY년 M월"
        return f.string(from: date)
    }
}



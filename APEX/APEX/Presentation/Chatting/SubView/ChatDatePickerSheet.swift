import SwiftUI
// swiftlint:disable identifier_name line_length vertical_whitespace trailing_newline

struct ChatDatePickerSheet: View {
    @Binding var date: Date
    var hasMemoDays: Set<Date> = [] // normalized to startOfDay
    var onClose: () -> Void
    var onSelect: (Date) -> Void

    @State private var monthIndex: Int = 0 // 0 = month of current selected date
    @State private var isShowingMonthYearPicker: Bool = false
    @State private var pickerYear: Int = Calendar.current.component(.year, from: Date())
    @State private var pickerMonth: Int = Calendar.current.component(.month, from: Date())

    private var startOfDisplayedMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }

    private var displayedMonth: Date {
        Calendar.current.date(byAdding: .month, value: monthIndex, to: startOfDisplayedMonth) ?? startOfDisplayedMonth
    }

    private func daysInMonth(for monthStart: Date) -> [Date] {
        let cal = Calendar.current
        let start = monthStart
        guard let range = cal.range(of: .day, in: .month, for: start) else { return [] }
        let firstWeekdayIndex = (cal.component(.weekday, from: start) + 6) % 7 // Monday=0
        var days: [Date] = []
        if firstWeekdayIndex > 0 {
            for i in stride(from: firstWeekdayIndex - 1, through: 0, by: -1) {
                if let d = cal.date(byAdding: .day, value: -i - 1, to: start) { days.append(d) }
            }
        }
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: start) { days.append(d) }
        }
        while days.count % 7 != 0 { if let last = days.last, let d = cal.date(byAdding: .day, value: 1, to: last) { days.append(d) } else { break } }
        while days.count < 42 { if let last = days.last, let d = cal.date(byAdding: .day, value: 1, to: last) { days.append(d) } else { break } }
        return days
    }

    private func isSameDay(_ a: Date, _ b: Date) -> Bool { Calendar.current.isDate(a, inSameDayAs: b) }
    private func isSameMonth(_ a: Date, _ b: Date) -> Bool { Calendar.current.component(.month, from: a) == Calendar.current.component(.month, from: b) && Calendar.current.component(.year, from: a) == Calendar.current.component(.year, from: b) }
    private func startOfDay(_ d: Date) -> Date { Calendar.current.startOfDay(for: d) }

    var body: some View {
        VStack(spacing: 16) {
            // Header row: left-aligned year/month, right chevrons to change month
            HStack {
                HStack(spacing: 6) {
                    Text(monthHeader(for: displayedMonth))
                        .font(.system(size: 17, weight: .semibold))
                    Button {
                        let comps = Calendar.current.dateComponents([.year, .month], from: displayedMonth)
                        pickerYear = comps.year ?? pickerYear
                        pickerMonth = comps.month ?? pickerMonth
                        isShowingMonthYearPicker = true
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .bold))
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut) { monthIndex = max(monthIndex - 1, -120) }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 36, height: 36)
                    }
                    Button {
                        withAnimation(.easeInOut) { monthIndex = min(monthIndex + 1, 120) }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 36, height: 36)
                    }
                }
            }

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

            // Swipeable month pager
            TabView(selection: $monthIndex) {
                ForEach(-120...120, id: \.self) { idx in
                    let monthStart = Calendar.current.date(byAdding: .month, value: idx, to: startOfDisplayedMonth) ?? startOfDisplayedMonth
                    // Days grid for this month
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                        ForEach(daysInMonth(for: monthStart), id: \.self) { d in
                            let inMonth = isSameMonth(d, monthStart)
                            let isToday = isSameDay(d, Date())
                            let hasMemo = hasMemoDays.contains(startOfDay(d))
                            let isEnabled = inMonth && hasMemo
                            Button {
                                date = d
                                onSelect(d)
                            } label: {
                                Text("\(Calendar.current.component(.day, from: d))")
                                    .font(.caption)
                                    .frame(width: 36, height: 36)
                                    .background(isToday ? Color("Primary").opacity(0.12) : Color.clear)
                                    .foregroundStyle(
                                        isToday ? Color("Primary") : (
                                            hasMemo && inMonth ? Color.primary : Color("BackgroundDisabled")
                                        )
                                    )
                                    .clipShape(Circle())
                            }
                            .disabled(!isEnabled)
                            .buttonStyle(.plain)
                        }
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: monthIndex)
            .sheet(isPresented: $isShowingMonthYearPicker) {
                MonthYearPickerSheet(year: $pickerYear, month: $pickerMonth) {
                    // 완료: 선택된 연/월로 페이지 이동
                    if let selectedStart = Calendar.current.date(from: DateComponents(year: pickerYear, month: pickerMonth, day: 1)) {
                        let diff = Calendar.current.dateComponents([.month], from: startOfDisplayedMonth, to: selectedStart).month ?? 0
                        withAnimation(.easeInOut) { monthIndex = diff }
                    }
                    isShowingMonthYearPicker = false
                } onCancel: {
                    isShowingMonthYearPicker = false
                }
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .presentationDetents([.height(280)])
            }
        }
        .padding(16)
        .background(Color("Background"))
        .presentationDetents([.medium, .large])
        .presentationBackground(Color("Background"))
        .environment(\.locale, Locale(identifier: "ko_KR"))
    }

    private func monthHeader(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "YYYY년 M월"
        return f.string(from: date)
    }
}

// MARK: - Month/Year Picker Sheet
private struct MonthYearPickerSheet: View {
    @Binding var year: Int
    @Binding var month: Int
    var onDone: () -> Void
    var onCancel: () -> Void

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }
    private var currentMonth: Int { Calendar.current.component(.month, from: Date()) }
    private var yearRange: [Int] { Array((currentYear - 5)...currentYear) }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("취소") { onCancel() }
                Spacer()
                Button("완료") { onDone() }
            }
            .font(.system(size: 16, weight: .medium))

            HStack(spacing: 0) {
                Picker("연도", selection: $year) {
                    ForEach(yearRange, id: \.self) { y in
                        HStack(spacing: 0) {
                            Text(y, format: .number.grouping(.never))
                            Text("년")
                        }
                        .tag(y)
                    }
                }
                .pickerStyle(.wheel)

                Picker("월", selection: $month) {
                    ForEach(1...(year == currentYear ? currentMonth : 12), id: \.self) { m in
                        HStack(spacing: 0) {
                            Text(m, format: .number.grouping(.never))
                            Text("월")
                        }
                        .tag(m)
                    }
                }
                .pickerStyle(.wheel)
            }
            .frame(height: 180)
            .onChange(of: year) { newYear in
                if newYear == currentYear && month > currentMonth { month = currentMonth }
            }
        }
        .padding(16)
        .background(Color("Background"))
    }
}



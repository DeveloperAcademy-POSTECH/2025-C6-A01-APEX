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
        return range.compactMap { day in
            Calendar.current.date(byAdding: .day, value: day - 1, to: start)
        }
    }

    private func isSameDay(_ a: Date, _ b: Date) -> Bool { Calendar.current.isDate(a, inSameDayAs: b) }
    private func isSameMonth(_ a: Date, _ b: Date) -> Bool { Calendar.current.component(.month, from: a) == Calendar.current.component(.month, from: b) && Calendar.current.component(.year, from: a) == Calendar.current.component(.year, from: b) }
    private func startOfDay(_ d: Date) -> Date { Calendar.current.startOfDay(for: d) }

    var body: some View {
        VStack(spacing: 0) {
            // Header row: left-aligned year/month, right chevrons to change month
            HStack {
                HStack(spacing: 6) {
                    Text(monthHeader(for: displayedMonth))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color("BlackLabel"))
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
                .padding(.horizontal, 16)
                Spacer()
                HStack(spacing: 28) {
                    Button {
                        withAnimation(.easeInOut) { monthIndex = max(monthIndex - 1, -120) }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 24, height: 24)
                    }
                    Button {
                        withAnimation(.easeInOut) { monthIndex = min(monthIndex + 1, 120) }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .padding(.vertical, 8)

            // Weekday symbols (Sun..Sat)
            let symbols = weekdaySymbolsKR()
            HStack(spacing: 0) {
                ForEach(symbols, id: \.self) { s in
                    Text(s)
                        .font(.caption1)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color.gray)
                }
            }

            // Swipeable month pager
            TabView(selection: $monthIndex) {
                ForEach(-120...120, id: \.self) { idx in
                    let monthStart = Calendar.current.date(byAdding: .month, value: idx, to: startOfDisplayedMonth) ?? startOfDisplayedMonth
                    // Days grid for this month
                    VStack(spacing: 0) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                            let cal = Calendar.current
                            // Sunday-first alignment for leading placeholders
                            let weekday = cal.component(.weekday, from: monthStart) // 1=Sun ... 7=Sat
                            let firstWeekdayIndex = weekday - 1 // 0..6, Sunday=0
                            let inMonthDays = daysInMonth(for: monthStart)
                            let totalSlots = 42 // Always 6 rows
                            let leading = firstWeekdayIndex
                            let middle = inMonthDays.count
                            ForEach(0..<totalSlots, id: \.self) { slot in
                                if slot < leading || slot >= leading + middle {
                                    Color.clear
                                        .frame(width: 44, height: 44)
                                } else {
                                    let d = inMonthDays[slot - leading]
                                    let isToday = isSameDay(d, Date())
                                    let hasMemo = hasMemoDays.contains(startOfDay(d))
                                    let isEnabled = hasMemo
                                    Button {
                                        date = d
                                        onSelect(d)
                                    } label: {
                                        Text("\(Calendar.current.component(.day, from: d))")
                                            .font(.title6)
                                            .frame(width: 44, height: 44)
                                            .background(isToday ? Color("Primary").opacity(0.12) : Color.clear)
                                            .foregroundStyle(
                                                isToday ? Color("Primary") : (
                                                    hasMemo ? Color("BlackLabel") : Color("BackgroundDisabled")
                                                )
                                            )
                                            .clipShape(Circle())
                                    }
                                    .disabled(!isEnabled)
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        .presentationBackground(Color("Background"))
        .environment(\.locale, Locale(identifier: "ko_KR"))
    }

    private func monthHeader(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "YYYY년 M월"
        return f.string(from: date)
    }

    private func weekdaySymbolsKR() -> [String] {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ko_KR")
        return cal.shortStandaloneWeekdaySymbols
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



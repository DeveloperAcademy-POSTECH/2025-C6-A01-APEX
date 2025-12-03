//
//  ChattingView+ScrollSupport.swift
//  APEX
//
//  Scrolling helpers extracted from ChattingView.
//

import SwiftUI

extension ChattingView {
    func updateScrollDateIndicator(with positions: [Date: CGFloat]) {
        // Compute and store the visible date regardless of current canScroll,
        // because ScrollMetrics (that sets canScroll) may arrive after header positions.
        guard !positions.isEmpty else {
            // Keep the last visible date when headers are temporarily not realized (e.g., LazyVStack virtualization).
            // Do not forcibly clear, so the indicator can still show the last known date while scrolling.
            return
        }

        // Choose the nearest header to the top: prioritize smallest positive Y (>= 0),
        // fallback to the largest negative (just above the top).
        let positives = positions.filter { $0.value >= 0 }
        let candidate = positives.min(by: { $0.value < $1.value }) ?? positions.max(by: { $0.value < $1.value })
        let newDate = candidate?.key

        if newDate != visibleDateForIndicator {
            visibleDateForIndicator = newDate
        }

        // Show now and schedule hide after idle
        // 실제로 사용자가 스크롤하는 중일 때만 표시
        if isUserScrolling && visibleDateForIndicator != nil {
            isShowingDateIndicator = true
            hideIndicatorWork?.cancel()
            let work = DispatchWorkItem { self.isShowingDateIndicator = false }
            hideIndicatorWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
        } else if !isUserScrolling {
            // 스크롤이 멈추면 빠르게 숨김
            hideIndicatorWork?.cancel()
            let work = DispatchWorkItem { self.isShowingDateIndicator = false }
            hideIndicatorWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
        }
    }

    // Retry a few times to ensure we land at bottom after first appear/layout/data updates
    func ensureInitialScrollToBottom(_ proxy: ScrollViewProxy) {
        guard initialBottomScrollAttemptsRemaining > 0 else { return }
        initialBottomScrollAttemptsRemaining -= 1
        let attemptScroll = {
            guard !suppressAutoScroll else { return }
            guard !showScrollToBottom else { return }
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(bottomSentinelId, anchor: .bottom) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: attemptScroll)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20, execute: attemptScroll)
    }
}


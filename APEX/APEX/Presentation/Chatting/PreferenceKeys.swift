//
//  ChattingView+PreferenceKeys.swift
//  APEX
//
//  PreferenceKeys and lightweight structs used by ChattingView.
//

import SwiftUI

struct DateHeaderPositionsKey: PreferenceKey {
    static var defaultValue: [Date: CGFloat] = [:]
    static func reduce(value: inout [Date: CGFloat], nextValue: () -> [Date: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct ScrollMetrics: Equatable {
    var topY: CGFloat?
    var bottomY: CGFloat?
    var viewportHeight: CGFloat?
}

struct ScrollMetricsKey: PreferenceKey {
    static var defaultValue: ScrollMetrics = .init(topY: nil, bottomY: nil, viewportHeight: nil)
    static func reduce(value: inout ScrollMetrics, nextValue: () -> ScrollMetrics) {
        let next = nextValue()
        if let top = next.topY { value.topY = top }
        if let bottom = next.bottomY { value.bottomY = bottom }
        if let viewport = next.viewportHeight { value.viewportHeight = viewport }
    }
}

struct ChipHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        value = max(value, next)
    }
}

struct BottomInsetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ViewportHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}


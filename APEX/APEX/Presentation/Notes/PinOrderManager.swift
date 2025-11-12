//
//  PinOrderManager.swift
//  APEX
//
//  Created by Assistant on 11/12/25.
//

import Foundation
import SwiftUI

class PinOrderManager: ObservableObject {
    @Published private var pinOrder: [UUID] = []
    
    static let shared = PinOrderManager()
    
    private init() {
        loadPinOrder()
    }
    
    // MARK: - Public Methods
    
    func pinClient(_ clientId: UUID) {
        // 이미 핀되어 있으면 순서만 최상단으로 변경
        if let index = pinOrder.firstIndex(of: clientId) {
            pinOrder.remove(at: index)
        }
        pinOrder.insert(clientId, at: 0) // 맨 앞에 추가 (최신이 위)
        savePinOrder()
        
        print("📌 핀 추가: \(clientId)")
        print("📌 현재 핀 순서: \(pinOrder)")
    }
    
    func unpinClient(_ clientId: UUID) {
        pinOrder.removeAll { $0 == clientId }
        savePinOrder()
        
        print("📌 핀 제거: \(clientId)")
        print("📌 현재 핀 순서: \(pinOrder)")
    }
    
    func getPinIndex(for clientId: UUID) -> Int? {
        pinOrder.firstIndex(of: clientId)
    }
    
    func reorderPins(_ newOrder: [UUID]) {
        pinOrder = newOrder
        savePinOrder()
        
        print("📌 핀 순서 재정렬: \(pinOrder)")
    }
    
    // MARK: - Persistence
    
    private func savePinOrder() {
        let data = pinOrder.map { $0.uuidString }
        UserDefaults.standard.set(data, forKey: "PinOrder")
    }
    
    private func loadPinOrder() {
        guard let data = UserDefaults.standard.array(forKey: "PinOrder") as? [String] else { return }
        pinOrder = data.compactMap { UUID(uuidString: $0) }
        
        print("📌 핀 순서 로드: \(pinOrder)")
    }
    
    // MARK: - Debug Helpers
    
    func printCurrentOrder() {
        print("📌 현재 핀 순서:")
        for (index, id) in pinOrder.enumerated() {
            print("  \(index + 1). \(id)")
        }
    }
}
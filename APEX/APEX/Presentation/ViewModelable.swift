//
//  File.swift
//  APEX
//
//  Created by 조운경 on 10/15/25.
//

import Foundation

@MainActor
protocol ViewModelable: ObservableObject {
    associatedtype Action
    
    func send(_ action: Action)
}

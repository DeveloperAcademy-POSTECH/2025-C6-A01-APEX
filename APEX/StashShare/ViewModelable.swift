//
//  ViewModelable.swift
//  StashShare
//
//  Duplicated protocol for the Share Extension target.
//

import Foundation
import Combine

@MainActor
protocol ViewModelable: ObservableObject {
    associatedtype Action
    
    func send(_ action: Action)
}



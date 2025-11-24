//
//  View+GlassEffectExt.swift
//  StashShare
//
//  No-op glassEffect to keep call sites compiling in the extension.
//

import SwiftUI

extension View {
    @ViewBuilder
    func glassEffect() -> some View {
        self
    }
    
    @ViewBuilder
    func glassEffect<S: Shape>(in shape: S) -> some View {
        self.clipShape(shape)
    }
}



//
//  UIApplication+Ex.swift
//  APEX
//
//  Shared helpers for UIApplication.
//

import UIKit

extension UIApplication {
    /// Dismiss the keyboard using the same animation as tapping outside to resign first responder.
    static func apexDismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}







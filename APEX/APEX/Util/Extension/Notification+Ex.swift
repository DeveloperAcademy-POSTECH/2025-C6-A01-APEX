//
//  Notification+Ex.swift
//  APEX
//
//  Centralized Notification.Name keys used across the app.
//

import Foundation

extension Notification.Name {
    static let apexInputFocused = Notification.Name("apex.inputFocused")
    static let apexInputBlurred = Notification.Name("apex.inputBlurred")
    static let apexNavigateToNote = Notification.Name("apex.navigateToNote")
    static let apexNavigateToDate = Notification.Name("apex.navigateToDate")
    static let apexAudioRenamed = Notification.Name("apex.audioRenamed")
    static let apexAudioDeleted = Notification.Name("apex.audioDeleted")
    static let apexOpenDocumentPicker = Notification.Name("apex.openDocumentPicker")
    static let apexOpenCamera = Notification.Name("apex.openCamera")
    static let apexOpenPhotoPicker = Notification.Name("apex.openPhotoPicker")
    static let apexSendSelectedAttachments = Notification.Name("apex.sendSelectedAttachments")
    static let apexStopAllAudioPlayback = Notification.Name("apex.stopAllAudioPlayback")
    static let apexMediaSheetVisibilityChanged = Notification.Name("apex.mediaSheetVisibilityChanged")
}


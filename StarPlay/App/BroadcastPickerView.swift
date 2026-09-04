import ReplayKit
import SwiftUI
import UIKit

struct BroadcastPickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: .zero)
        picker.preferredExtension = AppConstants.broadcastExtensionBundleIdentifier
        picker.showsMicrophoneButton = false
        picker.backgroundColor = .clear
        picker.tintColor = .clear
        picker.isAccessibilityElement = true
        picker.accessibilityLabel = "Start screen broadcast"
        return picker
    }

    func updateUIView(_ picker: RPSystemBroadcastPickerView, context: Context) {
        picker.preferredExtension = AppConstants.broadcastExtensionBundleIdentifier
        picker.showsMicrophoneButton = false
    }
}

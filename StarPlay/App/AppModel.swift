import Combine
import Foundation
import UIKit

final class AppModel: ObservableObject {
    @Published private(set) var streamState = SharedStateStore.snapshot()
    @Published private(set) var network = NetworkStatusSnapshot()
    @Published private(set) var discoveredReceivers: [ReceiverDevice] = []
    @Published private(set) var isSearchingForReceivers = false
    @Published private(set) var receiverSearchError: String?
    @Published var hasCompletedOnboarding: Bool

    let networkMonitor = NetworkMonitor()
    let receiverDiscovery = ReceiverDiscovery()

    #if canImport(ScreenCaptureKit)
    @available(iOS 27.0, *)
    private var modernCaptureController: ModernScreenCaptureController?
    #endif

    private var refreshTimer: Timer?
    private let onboardingKey = "hasCompletedOnboarding"

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
        #if canImport(ScreenCaptureKit)
        if #available(iOS 27.0, *) {
            modernCaptureController = ModernScreenCaptureController(deviceName: UIDevice.current.name)
        } else {
            modernCaptureController = nil
        }
        #endif
        networkMonitor.start()
        receiverDiscovery.start()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    deinit {
        refreshTimer?.invalidate()
        receiverDiscovery.stop()
        #if canImport(ScreenCaptureKit)
        if #available(iOS 27.0, *) {
            modernCaptureController?.stop()
        }
        #endif
    }

    var usesModernCapture: Bool {
        #if canImport(ScreenCaptureKit)
        if #available(iOS 27.0, *) {
            return modernCaptureController != nil
        }
        #endif
        return false
    }

    var activeReceiverName: String? {
        let name = streamState.receiverName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? discoveredReceivers.first?.name : name
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: onboardingKey)
        hasCompletedOnboarding = true
    }

    func prepareForBroadcast() {
        SharedStateStore.resetForNewSession(UUID().uuidString)
        refresh()
    }

    func startMirroring() {
        #if canImport(ScreenCaptureKit)
        if #available(iOS 27.0, *), let modernCaptureController {
            modernCaptureController.presentPicker()
            return
        }
        #endif
        prepareForBroadcast()
    }

    func stopMirroring() {
        SharedStateStore.update(status: .stopping, message: "Stopping the system broadcast")
        #if canImport(ScreenCaptureKit)
        if #available(iOS 27.0, *), let modernCaptureController {
            modernCaptureController.stop()
            refresh()
            return
        }
        #endif
        SharedStateStore.requestStop()
        BroadcastControlChannel.postStop()
        refresh()
    }

    func updateProfile(_ profile: StreamProfile) {
        SharedStateStore.writeProfile(profile)
    }

    func refresh() {
        let state = SharedStateStore.snapshot()
        if state.status != .idle,
           state.status != .waitingForReceiver,
           state.status != .failed,
           state.lastUpdated != .distantPast,
           Date().timeIntervalSince(state.lastUpdated) > AppConstants.stateExpirationInterval {
            var reset = state
            reset.status = .idle
            reset.message = "Ready to mirror"
            SharedStateStore.write(reset)
            streamState = reset
        } else {
            streamState = state
        }
        network = networkMonitor.snapshot
        discoveredReceivers = receiverDiscovery.devices
        isSearchingForReceivers = receiverDiscovery.isSearching
        receiverSearchError = receiverDiscovery.lastError
    }
}

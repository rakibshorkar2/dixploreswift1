import Foundation
import AVFoundation
import CoreLocation
import UIKit

@MainActor
final class BackgroundAudioService {
    static let shared = BackgroundAudioService()

    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var isActive = false

    func start() {
        guard !isActive else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192)!
            buffer.frameLength = buffer.frameCapacity
            let channelData = buffer.floatChannelData![0]
            memset(channelData, 0, Int(buffer.frameLength) * MemoryLayout<Float>.size)

            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            try engine.start()
            player.play()

            self.engine = engine
            self.player = player
            isActive = true
        } catch {
            AppLogger.error("Failed to start background audio: \(error)")
        }
    }

    func stop() {
        guard isActive else { return }
        player?.stop()
        engine?.stop()
        if let p = player { engine?.detach(p) }
        player = nil
        engine = nil
        isActive = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

@MainActor
final class BackgroundLocationService: NSObject, CLLocationManagerDelegate {
    static let shared = BackgroundLocationService()

    private let manager = CLLocationManager()
    private var isUpdating = false

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 500
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        if #available(iOS 14.5, *) {
            manager.showsBackgroundLocationIndicator = true
        }
    }

    func start() {
        guard !isUpdating else { return }
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestAlwaysAuthorization()
        } else if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
            isUpdating = true
        }
    }

    func stop() {
        guard isUpdating else { return }
        manager.stopUpdatingLocation()
        isUpdating = false
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
                if isUpdating { manager.startUpdatingLocation() }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            AppLogger.error("BackgroundLocation error: \(error.localizedDescription)")
        }
    }
}

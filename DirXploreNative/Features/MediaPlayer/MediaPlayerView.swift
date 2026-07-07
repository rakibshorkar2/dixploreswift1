import SwiftUI
import AVKit
import AVFoundation

@Observable
@MainActor
final class MediaPlayerViewModel {
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var volume: Float = 1.0
    var brightness: CGFloat = UIScreen.main.brightness
    var playbackSpeed: Float = 1.0
    var isLocked = false
    var showControls = true
    var aspectRatio: AspectRatioMode = .fit
    var abRepeatMode: ABRepeatMode = .off
    var abStartTime: TimeInterval = 0
    var abEndTime: TimeInterval = 0
    var isHWSwitchable = false
    var useHardwareDecoder = true

    var player: AVPlayer?
    private var timeObserver: Any?
    private var currentURL: URL?

    enum AspectRatioMode: String, CaseIterable {
        case fit = "contain"
        case fill = "cover"
        case stretch = "fill"
    }

    enum ABRepeatMode {
        case off, setStart, setEnd, active
    }

    func load(url: URL) {
        currentURL = url
        player = AVPlayer(url: url)
        player?.rate = playbackSpeed
        player?.volume = volume

        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
            }
        }

        Task {
            guard let duration = try? await player?.currentItem?.asset.load(.duration) else { return }
            self.duration = duration.seconds
        }
    }

    func play() {
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
    }

    func skipForward(_ seconds: TimeInterval = 10) {
        seek(to: min(currentTime + seconds, duration))
    }

    func skipBackward(_ seconds: TimeInterval = 10) {
        seek(to: max(currentTime - seconds, 0))
    }

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        player?.rate = speed
    }

    func setVolume(_ vol: Float) {
        volume = vol
        player?.volume = vol
    }

    func toggleAspectRatio() {
        let all = AspectRatioMode.allCases
        let idx = all.firstIndex(of: aspectRatio) ?? 0
        aspectRatio = all[(idx + 1) % all.count]
    }

    func toggleABRepeat() {
        switch abRepeatMode {
        case .off:
            abStartTime = currentTime
            abRepeatMode = .setStart
        case .setStart:
            abEndTime = currentTime
            abRepeatMode = .setEnd
        case .setEnd:
            if abEndTime > abStartTime {
                abRepeatMode = .active
            } else {
                abRepeatMode = .off
            }
        case .active:
            abRepeatMode = .off
        }
    }

    func toggleLock() {
        isLocked.toggle()
        showControls = !isLocked
    }

    deinit {
        Task { @MainActor in
            if let observer = timeObserver {
                player?.removeTimeObserver(observer)
            }
        }
    }
}

struct MediaPlayerView: View {
    @State private var vm = MediaPlayerViewModel()
    let url: URL
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                VideoPlayer(player: vm.player)
                    .ignoresSafeArea()
                    .aspectRatio(contentMode: aspectRatioContentMode)
                    .overlay(controlsOverlay(geometry: geometry))
                    .onTapGesture { toggleControls() }
                    .gesture(dragGesture(geometry: geometry))

                VStack {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.body)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        Spacer()
                        if !vm.isLocked {
                            Button { vm.toggleLock() } label: {
                                Image(systemName: "lock.open")
                                    .padding(12)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding()
                    Spacer()
                }
                .opacity(vm.showControls ? 1 : 0)
            }
        }
        .onAppear { vm.load(url: url) }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func controlsOverlay(geometry: GeometryProxy) -> some View {
        if vm.showControls && !vm.isLocked {
            VStack {
                Spacer()

                timeSlider

                HStack {
                    Text(vm.currentTime.asDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(vm.duration.asDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                HStack(spacing: 24) {
                    controlButton("gobackward.10") { vm.skipBackward() }
                    controlButton("play.fill") { vm.togglePlayPause() }
                        .font(.title)
                    controlButton("goforward.10") { vm.skipForward() }
                }
                .padding(.vertical)

                HStack(spacing: 16) {
                    speedMenu
                    aspectRatioButton
                    abRepeatButton
                }
                .padding(.bottom, 40)
            }
            .background(LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom))
        }
    }

    private var timeSlider: some View {
        Slider(
            value: Binding(
                get: { vm.currentTime },
                set: { vm.seek(to: $0) }
            ),
            in: 0...max(vm.duration, 1)
        )
        .padding(.horizontal)
        .tint(.white)
    }

    private func controlButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .padding(12)
        }
    }

    private var speedMenu: some View {
        Menu {
            ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                Button("\(speed, specifier: "%.2f")x") {
                    vm.setSpeed(Float(speed))
                }
            }
        } label: {
            Label("\(vm.playbackSpeed, specifier: "%.1f")x", systemImage: "speedometer")
                .font(.caption)
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var aspectRatioButton: some View {
        Button { vm.toggleAspectRatio() } label: {
            Image(systemName: aspectRatioIcon)
                .font(.caption)
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var aspectRatioIcon: String {
        switch vm.aspectRatio {
        case .fit: return "rectangle.arrowtriangle.2.outward"
        case .fill: return "rectangle.fill"
        case .stretch: return "rectangle.arrowtriangle.2.inward"
        }
    }

    private var aspectRatioContentMode: ContentMode {
        switch vm.aspectRatio {
        case .fit: return .fit
        case .fill: return .fill
        case .stretch: return .fill
        }
    }

    private var abRepeatButton: some View {
        Button { vm.toggleABRepeat() } label: {
            Image(systemName: "repeat")
                .font(.caption)
                .foregroundColor(vm.abRepeatMode == .active ? .accent : .white)
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func toggleControls() {
        withAnimation { vm.showControls.toggle() }
    }

    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let vertical = value.translation.height / geometry.size.height
                let horizontal = value.translation.width / geometry.size.width

                if value.startLocation.x < geometry.size.width / 2 {
                    vm.brightness = max(0, min(1, vm.brightness - CGFloat(vertical)))
                    UIScreen.main.brightness = vm.brightness
                } else {
                    vm.volume = max(0, min(1, vm.volume - Float(vertical)))
                }

                if abs(horizontal) > 0.02 {
                    let seekTime = vm.currentTime + TimeInterval(horizontal * vm.duration * 0.3)
                    vm.seek(to: seekTime)
                }
            }
    }
}

private extension TimeInterval {
    var asDuration: String {
        guard !isNaN && !isInfinite else { return "--:--" }
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

import SwiftUI

struct DeepCrawlerView: View {
    @State private var crawler = DeepCrawler.shared
    @State private var startURL = ""
    @State private var maxDepth: Double = 3
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !crawler.isRunning && crawler.discoveredCount == 0 {
                    setupPanel
                } else {
                    progressPanel
                }
            }
            .navigationTitle("Deep Crawler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !crawler.isRunning {
                        Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                CrawlerSettingsView()
            }
        }
    }

    private var setupPanel: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sensor.tag.radiowaves.forward")
                .font(.system(size: 60))
                .foregroundColor(.accent)
            Text("Deep Directory Crawler")
                .font(.title2).fontWeight(.bold)
            Text("Recursively explore directory listings to discover files")
                .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 4) {
                Text("Start URL")
                    .font(.caption).foregroundColor(.secondary)
                TextField("https://example.com/dir/", text: $startURL)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 4) {
                Text("Max Depth: \(Int(maxDepth))")
                    .font(.caption).foregroundColor(.secondary)
                Slider(value: $maxDepth, in: 1...10, step: 1)
            }
            .padding(.horizontal)

            Button {
                crawler.start(from: startURL, maxDepth: Int(maxDepth))
            } label: {
                Label("Start Crawling", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accent)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(startURL.isEmpty)
            .padding(.horizontal)

            Spacer()
        }
    }

    private var progressPanel: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    ProgressView(value: crawler.progress)
                        .tint(.accent)
                    Text("\(Int(crawler.progress * 100))%")
                        .font(.title).fontWeight(.bold)
                }
                .padding()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard("Discovered", "\(crawler.discoveredCount)", "magnifyingglass")
                    statCard("Queued", "\(crawler.queueSize)", "clock")
                    statCard("Visited", "\(crawler.visitedURLs.count)", "checkmark.circle")
                }
                .padding(.horizontal)

                if !crawler.currentURL.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current URL")
                            .font(.caption).foregroundColor(.secondary)
                        Text(crawler.currentURL)
                            .font(.caption).lineLimit(2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }

                if !crawler.pendingQueue.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Pending Queue")
                            .font(.headline).padding(.horizontal)
                        ForEach(crawler.pendingQueue) { task in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.url).font(.caption).lineLimit(1)
                                    Text("Depth: \(task.depth)").font(.caption2).foregroundColor(.secondary)
                                }
                                Spacer()
                                Button { crawler.removeFromQueue(task) } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal).padding(.vertical, 4)
                        }
                    }
                }

                HStack(spacing: 16) {
                    if crawler.isPaused {
                        Button { crawler.resume() } label: {
                            Label("Resume", systemImage: "play.fill")
                                .frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(10)
                        }
                    } else if crawler.isRunning {
                        Button { crawler.pause() } label: {
                            Label("Pause", systemImage: "pause.fill")
                                .frame(maxWidth: .infinity).padding().background(Color.orange).foregroundColor(.white).cornerRadius(10)
                        }
                    }
                    Button(role: .destructive) { crawler.stop() } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity).padding().background(Color.red).foregroundColor(.white).cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }

    private func statCard(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3)
            Text(value).font(.title2).fontWeight(.bold)
            Text(title).font(.caption2).foregroundColor(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.appSecondaryBackground)
        .cornerRadius(8)
    }
}

struct CrawlerSettingsView: View {
    @State private var crawler = DeepCrawler.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Concurrency") {
                    Stepper("Max Concurrent: \(crawler.concurrencyLimit)", value: $crawler.concurrencyLimit, in: 1...16)
                    Text("Higher values scan faster but may overwhelm servers")
                        .font(.caption).foregroundColor(.secondary)
                }
                Section("Retry") {
                    Stepper("Max Retries: \(crawler.maxRetries)", value: $crawler.maxRetries, in: 0...10)
                }
            }
            .navigationTitle("Crawler Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

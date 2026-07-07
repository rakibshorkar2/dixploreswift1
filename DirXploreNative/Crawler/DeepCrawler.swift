import Foundation

@Observable
@MainActor
final class DeepCrawler {
    static let shared = DeepCrawler()

    var isRunning = false
    var isPaused = false
    var progress: Double = 0
    var discoveredCount = 0
    var queueSize = 0
    var currentURL: String = ""
    var visitedURLs: Set<String> = []
    var concurrencyLimit = 4
    var maxRetries = 3
    var pendingQueue: [CrawlTask] = []

    private var queue: [CrawlTask] = []
    private var activeTasks: Set<String> = []
    private var retryCounts: [String: Int] = [:]
    private let httpClient = HTTPClient.shared
    private let parser = HtmlParser.shared
    private var maxDepth = 10
    private var shouldStop = false
    private var pausedContinuation: CheckedContinuation<Void, Never>?

    struct CrawlTask: Identifiable, Sendable {
        let id: UUID
        let url: String
        let depth: Int
        let parentURL: String

        init(url: String, depth: Int, parentURL: String) {
            self.id = UUID()
            self.url = url
            self.depth = depth
            self.parentURL = parentURL
        }
    }

    private init() {}

    func start(from url: String, maxDepth: Int = 10) {
        guard !isRunning else { return }
        isRunning = true
        isPaused = false
        shouldStop = false
        self.maxDepth = maxDepth
        progress = 0
        discoveredCount = 0
        visitedURLs.removeAll()
        queue.removeAll()
        activeTasks.removeAll()
        retryCounts.removeAll()
        pendingQueue.removeAll()

        let baseURL = url.hasSuffix("/") ? url : url + "/"
        queue.append(CrawlTask(url: baseURL, depth: 0, parentURL: ""))
        queueSize = queue.count
        currentURL = baseURL
        updatePendingQueue()

        Task {
            await processQueue()
        }
    }

    func pause() {
        isPaused = true
    }

    func resume() {
        isPaused = false
        pausedContinuation?.resume()
        pausedContinuation = nil
        Task {
            await processQueue()
        }
    }

    func stop() {
        shouldStop = true
        isRunning = false
        isPaused = false
        if let continuation = pausedContinuation {
            continuation.resume()
            pausedContinuation = nil
        }
        queue.removeAll()
        activeTasks.removeAll()
        pendingQueue.removeAll()
    }

    func removeFromQueue(_ task: CrawlTask) {
        queue.removeAll { $0.id == task.id }
        pendingQueue.removeAll { $0.id == task.id }
        queueSize = queue.count
    }

    private func updatePendingQueue() {
        pendingQueue = Array(queue.prefix(50))
    }

    private func processQueue() async {
        while !queue.isEmpty && !shouldStop {
            if isPaused {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    pausedContinuation = continuation
                }
                if shouldStop { break }
            }

            guard activeTasks.count < concurrencyLimit else {
                try? await Task.sleep(nanoseconds: 500_000_000)
                continue
            }

            let tasksToProcess = queue.prefix(concurrencyLimit - activeTasks.count)
            queue.removeFirst(min(tasksToProcess.count, queue.count))

            for task in tasksToProcess {
                guard !shouldStop else { break }
                activeTasks.insert(task.url)
                currentURL = task.url

                Task {
                    await crawl(task: task)
                }
            }

            queueSize = queue.count
            updatePendingQueue()
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        if !shouldStop {
            isRunning = false
            progress = 1.0
        }
    }

    private func crawl(task: CrawlTask) async {
        defer {
            activeTasks.remove(task.url)
        }

        guard !visitedURLs.contains(task.url), task.depth <= maxDepth else { return }
        visitedURLs.insert(task.url)

        do {
            let html = try await httpClient.getString(task.url)
            let entries = await parser.parseDirectoryListing(html: html, baseURL: task.url)

            for entry in entries {
                guard !shouldStop else { return }
                discoveredCount += 1

                if entry.isDirectory && task.depth < maxDepth {
                    let childURL = entry.href.hasSuffix("/") ? entry.href : entry.href + "/"
                    guard !visitedURLs.contains(childURL) else { continue }
                    queue.append(CrawlTask(url: childURL, depth: task.depth + 1, parentURL: task.url))
                    queueSize = queue.count
                }
            }

            progress = calculateProgress()

        } catch {
            let retries = retryCounts[task.url, default: 0]
            if retries < maxRetries {
                retryCounts[task.url] = retries + 1
                queue.append(task)
                queueSize = queue.count
                AppLogger.info("Retry \(retries + 1)/\(maxRetries) for \(task.url)", category: AppLogger.crawler)
            } else {
                AppLogger.error("Crawl failed after \(maxRetries) retries at \(task.url): \(error)", category: AppLogger.crawler)
            }
        }
    }

    private func calculateProgress() -> Double {
        guard maxDepth > 0 else { return 0 }
        guard !queue.isEmpty || !activeTasks.isEmpty else { return 1.0 }
        let maxExpected = min(Int(pow(Double(50), Double(min(maxDepth, 3)))), 10000)
        let visitedWeight = min(Double(visitedURLs.count) / Double(maxExpected), 0.7)
        let depthWeight = queue.isEmpty ? 0.3 : 0.3 * (1.0 - Double(queue.count) / Double(max(queue.count, 1) + visitedURLs.count))
        return min(visitedWeight + depthWeight, 1.0)
    }
}

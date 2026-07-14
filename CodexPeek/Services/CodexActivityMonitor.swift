import CoreServices
import Foundation

final class CodexActivityMonitor {
    private let callback: @Sendable () -> Void
    private let overriddenCodexHomeURL: URL?
    private let latency: CFTimeInterval
    private var stream: FSEventStreamRef?

    init(
        codexHomeURL: URL? = nil,
        latency: CFTimeInterval = 3,
        callback: @escaping @Sendable () -> Void
    ) {
        self.overriddenCodexHomeURL = codexHomeURL
        self.latency = latency
        self.callback = callback
    }

    func start() {
        stop()

        let path = codexHomeURL.path
        guard FileManager.default.fileExists(atPath: path) else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, contextInfo, _, _, _, _ in
                guard let contextInfo else { return }
                let monitor = Unmanaged<CodexActivityMonitor>
                    .fromOpaque(contextInfo)
                    .takeUnretainedValue()
                monitor.callback()
            },
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
                | FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes)
        )

        guard let stream else { return }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        stop()
    }

    private var codexHomeURL: URL {
        if let overriddenCodexHomeURL {
            return overriddenCodexHomeURL
        }
        let env = ProcessInfo.processInfo.environment
        if let codexHome = env["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines), !codexHome.isEmpty {
            return URL(fileURLWithPath: codexHome, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
    }
}

import Foundation

/// Safe, asynchronous wrapper around Foundation.Process with deadlock-free pipe reading via readabilityHandler,
/// timeout supervision, and cancellation support.
public final class ProcessRunner: @unchecked Sendable {
    private let state = ProcessState()

    public init() {}

    /// Runs an executable process with arguments, environment, working directory, and timeout.
    public func run(
        executableURL: URL,
        arguments: [String],
        workingDirectory: String? = nil,
        environment: [String: String] = [:],
        timeoutSeconds: TimeInterval? = nil
    ) async throws -> ExecutionResult {
        let startTime = Date()

        let proc = Process()
        proc.executableURL = executableURL
        proc.arguments = arguments

        if let workDir = workingDirectory, !workDir.isEmpty {
            proc.currentDirectoryURL = URL(fileURLWithPath: (workDir as NSString).expandingTildeInPath)
        }

        var env = ProcessInfo.processInfo.environment
        for (k, v) in environment {
            env[k] = v
        }
        proc.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        let stdoutAccumulator = ThreadSafeAccumulator()
        let stderrAccumulator = ThreadSafeAccumulator()

        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                outPipe.fileHandleForReading.readabilityHandler = nil
            } else {
                stdoutAccumulator.append(chunk)
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                errPipe.fileHandleForReading.readabilityHandler = nil
            } else {
                stderrAccumulator.append(chunk)
            }
        }

        try await state.setProcess(proc)

        do {
            try proc.run()
        } catch {
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            _ = await state.clearProcess()
            throw ExecutionError.processLaunchFailed(error.localizedDescription)
        }

        // Timeout supervisor
        let timeoutRef = TimeoutRef()
        var timeoutTimer: DispatchSourceTimer?

        if let timeout = timeoutSeconds, timeout > 0 {
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
            timer.schedule(deadline: .now() + timeout)
            timer.setEventHandler { [weak proc] in
                timeoutRef.markTimedOut()
                proc?.terminate()
                
                // Force kill if still unresponsive after 500ms
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                    if let pid = proc?.processIdentifier, proc?.isRunning == true {
                        kill(pid, SIGKILL)
                    }
                }
            }
            timer.resume()
            timeoutTimer = timer
        }

        // Wait for process exit asynchronously on a global queue
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                proc.waitUntilExit()
                continuation.resume()
            }
        }

        timeoutTimer?.cancel()
        timeoutTimer = nil

        // Clean up readability handlers
        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil

        // Drain any remaining buffered data
        let remainingOut = outPipe.fileHandleForReading.readDataToEndOfFile()
        stdoutAccumulator.append(remainingOut)

        let remainingErr = errPipe.fileHandleForReading.readDataToEndOfFile()
        stderrAccumulator.append(remainingErr)

        let duration = Date().timeIntervalSince(startTime)
        let stdoutString = String(data: stdoutAccumulator.getData(), encoding: .utf8) ?? ""
        let stderrString = String(data: stderrAccumulator.getData(), encoding: .utf8) ?? ""

        let wasCancelled = await state.clearProcess()

        if wasCancelled {
            throw ExecutionError.cancelled
        }

        if timeoutRef.isTimedOut {
            throw ExecutionError.timeout(timeoutSeconds ?? 0)
        }

        let exitCode = Int(proc.terminationStatus)
        if exitCode != 0 {
            let combined = stdoutString + (stderrString.isEmpty ? "" : "\n" + stderrString)
            throw ExecutionError.nonZeroExitStatus(exitCode, output: combined)
        }

        return ExecutionResult(
            exitCode: exitCode,
            stdout: stdoutString,
            stderr: stderrString,
            duration: duration
        )
    }

    /// Cancels the running process immediately.
    public func cancel() {
        Task {
            let proc = await state.cancel()
            if let proc = proc, proc.isRunning {
                proc.terminate()
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                    if proc.isRunning {
                        kill(proc.processIdentifier, SIGKILL)
                    }
                }
            }
        }
    }
}

// MARK: - Helper Types

private actor ProcessState {
    private var process: Process?
    private var isCancelled = false

    func setProcess(_ proc: Process) throws {
        if isCancelled {
            throw ExecutionError.cancelled
        }
        self.process = proc
    }

    func cancel() -> Process? {
        isCancelled = true
        let proc = self.process
        self.process = nil
        return proc
    }

    func clearProcess() -> Bool {
        let wasCancelled = self.isCancelled
        self.process = nil
        return wasCancelled
    }
}

private final class ThreadSafeAccumulator: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func append(_ newChunk: Data) {
        guard !newChunk.isEmpty else { return }
        lock.lock()
        data.append(newChunk)
        lock.unlock()
    }

    func getData() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

private final class TimeoutRef: @unchecked Sendable {
    private var timedOut = false
    private let lock = NSLock()

    var isTimedOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return timedOut
    }

    func markTimedOut() {
        lock.lock()
        timedOut = true
        lock.unlock()
    }
}

import Foundation

/// Runs blocking work (a program, a walk of `/proc`) on a thread of
/// its own, so it never holds one of Swift concurrency's threads,
/// which are as few as the CPU's cores, while it waits. A thread
/// per call, not a Dispatch queue: Linux's Dispatch pool is just
/// as small, and the calls are few and slow (a program each).
public enum BlockingWork {
    public static func run<Value: Sendable>(
        _ work: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            startThread {
                continuation.resume(with: Result { try work() })
            }
        }
    }

    public static func perform<Value: Sendable>(
        _ work: @escaping @Sendable () -> Value
    ) async -> Value {
        await withCheckedContinuation { continuation in
            startThread { continuation.resume(returning: work()) }
        }
    }

    static func startThread(_ body: @escaping @Sendable () -> Void) {
        let thread = Thread(block: body)
        thread.qualityOfService = .utility
        thread.start()
    }
}

extension CommandRunner {
    /// The same command, awaited without blocking a thread of the
    /// cooperative pool.
    public func runInBackground(
        _ command: Command
    ) async throws -> String {
        try await BlockingWork.run { try run(command) }
    }
}

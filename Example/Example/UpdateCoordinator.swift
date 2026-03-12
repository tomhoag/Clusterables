//
//  UpdateCoordinator.swift
//  Example
//
//  Created by Tom Hoag on 3/28/25.
//

/// Actor that coordinates debounced map updates with automatic cancellation.
///
/// This actor ensures thread-safe management of update tasks and provides
/// automatic cancellation of in-flight updates when new ones are scheduled.
actor UpdateCoordinator {
    private var currentTask: Task<Void, Never>?
    
    /// Schedules an update with debouncing, canceling any previous pending update.
    ///
    /// - Parameters:
    ///   - delay: Delay in milliseconds before executing the work
    ///   - work: The async work to perform after the delay
    func scheduleUpdate(
        delay: UInt64,
        work: @escaping @Sendable () async -> Void
    ) {
        currentTask?.cancel()
        currentTask = Task {
            try? await Task.sleep(for: .milliseconds(delay))
            guard !Task.isCancelled else { return }
            await work()
        }
    }
    
    /// Cancels all pending updates.
    func cancelAll() {
        currentTask?.cancel()
    }
}

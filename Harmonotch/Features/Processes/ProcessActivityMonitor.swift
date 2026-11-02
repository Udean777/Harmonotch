import Combine
import Foundation

/// Demand-driven sampler. It only runs between `start()` and `stop()`, which the
/// dashboard ties to the panel being open. Call both from the main thread.
final class ProcessActivityMonitor: ObservableObject {
  @Published private(set) var state: DashboardDataState<ProcessActivitySnapshot> = .idle

  private let sampler: ProcessCounterSampling
  private let interval: TimeInterval
  private var task: Task<Void, Never>?
  private var generation = 0

  var isRunning: Bool { task != nil }

  init(sampler: ProcessCounterSampling, interval: TimeInterval = 3) {
    self.sampler = sampler
    self.interval = interval
  }

  func start() {
    guard task == nil else { return }
    generation += 1
    let current = generation
    if case .loaded = state {
      // Retain existing loaded snapshot to avoid flashing loading UI on tab switches.
    } else {
      state = .loading
    }
    let sampler = sampler
    let interval = interval
    task = Task { [weak self] in
      var previous: ProcessCounterSample
      do {
        previous = try await Task.detached(priority: .utility) { try sampler.sample() }.value
      } catch {
        await self?.publish(.failed(Self.message(for: error)), generation: current)
        return
      }
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        if Task.isCancelled { return }
        do {
          let sample = try await Task.detached(priority: .utility) { try sampler.sample() }.value
          if Task.isCancelled { return }
          let result = Self.makeState(previous: previous, current: sample)
          previous = sample
          await self?.publish(result, generation: current)
        } catch {
          await self?.publish(.failed(Self.message(for: error)), generation: current)
        }
      }
    }
  }

  func stop(keepCache: Bool = false) {
    task?.cancel()
    task = nil
    generation += 1
    if !keepCache {
      state = .idle
    }
  }

  /// Discards the current baseline and measures again.
  func refresh() {
    stop()
    start()
  }

  @MainActor
  private func publish(_ newState: DashboardDataState<ProcessActivitySnapshot>, generation: Int) {
    guard generation == self.generation else { return }
    state = newState
  }

  private static func makeState(
    previous: ProcessCounterSample,
    current: ProcessCounterSample
  ) -> DashboardDataState<ProcessActivitySnapshot> {
    if current.counters.isEmpty {
      return .unavailable(ProcessActivityError.noReadableProcesses.description)
    }
    let entries = ProcessActivityRanking.rank(previous: previous, current: current)
    if entries.isEmpty { return .empty }
    return .loaded(
      ProcessActivitySnapshot(
        entries: entries,
        samplingInterval: current.takenAt - previous.takenAt,
        isPartial: current.unreadableCount > 0,
        refreshedAt: Date()
      ),
      refreshedAt: Date()
    )
  }

  private static func message(for error: Error) -> String {
    (error as? ProcessActivityError)?.description ?? ProcessActivityError.sampleFailed.description
  }
}

extension ProcessActivityError: CustomStringConvertible {
  /// Technical text only; the UI shows localized copy for each case.
  var description: String {
    switch self {
    case .noReadableProcesses: return "noReadableProcesses"
    case .sampleFailed: return "sampleFailed"
    }
  }
}

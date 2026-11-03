import Combine
import Foundation
import SwiftUI

/// Demand-driven manager that coordinates AI Agent usage and quota telemetry across multiple providers.
/// Only polls when active (e.g. when Notch drawer or MenuBar dashboard is visible).
@MainActor
final class AIUsageManager: ObservableObject {
    static let shared = AIUsageManager()

    @Published private(set) var snapshots: [AIProviderType: AIAgentQuotaSnapshot] = [:]
    @Published private(set) var availableProviders: [AIProviderType] = [.antigravity]
    @Published var selectedProvider: AIProviderType = .antigravity

    // Maintained for backward compatibility
    @Published private(set) var antigravityState: DashboardDataState<AIAgentQuotaSnapshot> = .idle
    @Published private(set) var isMonitoring: Bool = false

    private let services: [any AIProviderService]
    private var monitoringTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval

    init(
        services: [any AIProviderService]? = nil,
        refreshInterval: TimeInterval = 30.0
    ) {
        self.services = services ?? [
            AntigravityQuotaService.shared,
            ClaudeCodeQuotaService.shared,
            OllamaQuotaService.shared,
            CursorQuotaService.shared,
            CopilotQuotaService.shared
        ]
        self.refreshInterval = refreshInterval
    }

    /// Current snapshot for the actively selected provider tab.
    var currentSnapshot: AIAgentQuotaSnapshot? {
        snapshots[selectedProvider]
    }

    /// Starts polling in the background (call when Notch is opened or hover state triggers).
    func startMonitoring() {
        guard monitoringTask == nil else { return }
        isMonitoring = true

        if case .loaded = antigravityState {
            // Keep cached snapshot to avoid UI flickering
        } else {
            antigravityState = .loading
        }

        monitoringTask = Task { [weak self] in
            guard let self = self else { return }

            // Initial fetch
            await self.fetchOnce()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.refreshInterval * 1_000_000_000))
                if Task.isCancelled { break }
                await self.fetchOnce()
            }
        }
    }

    /// Stops polling to conserve battery and CPU when UI is closed.
    func stopMonitoring(keepCache: Bool = true) {
        monitoringTask?.cancel()
        monitoringTask = nil
        isMonitoring = false

        if !keepCache {
            antigravityState = .idle
            snapshots.removeAll()
        }
    }

    /// Manually refreshes all provider snapshots immediately.
    func refresh() async {
        if case .loaded = antigravityState {
            // Retain snapshot while reloading
        } else {
            antigravityState = .loading
        }
        await fetchOnce()
    }

    private func fetchOnce() async {
        var results: [AIProviderType: AIAgentQuotaSnapshot] = [:]

        await withTaskGroup(of: (AIProviderType, AIAgentQuotaSnapshot?).self) { group in
            for service in services {
                let provider = service.provider
                group.addTask {
                    let snapshot = await service.fetchSnapshot()
                    return (provider, snapshot)
                }
            }

            for await (provider, snapshot) in group {
                if let snapshot = snapshot {
                    results[provider] = snapshot
                }
            }
        }

        self.snapshots = results

        // Update list of available providers (detected on system)
        var detected = AIProviderType.allCases.filter { results[$0] != nil }
        if detected.isEmpty {
            detected = [.antigravity]
        }
        self.availableProviders = detected

        // If current provider is not among detected, pick the first connected or available one
        if !detected.contains(selectedProvider) {
            if let firstConnected = detected.first(where: { results[$0]?.isConnected == true }) {
                self.selectedProvider = firstConnected
            } else if let first = detected.first {
                self.selectedProvider = first
            }
        }

        // Backward compatibility update for antigravityState
        if let antigravitySnap = results[.antigravity] {
            antigravityState = .loaded(antigravitySnap, refreshedAt: Date())
        } else {
            if case .loaded(let previous, _) = antigravityState {
                let offlineSnapshot = AIAgentQuotaSnapshot(
                    provider: previous.provider,
                    userTier: previous.userTier,
                    models: previous.models,
                    isConnected: false,
                    endpointDescription: previous.endpointDescription,
                    lastUpdated: Date()
                )
                antigravityState = .loaded(offlineSnapshot, refreshedAt: Date())
            } else {
                antigravityState = .unavailable("Antigravity process not detected")
            }
        }
    }
}

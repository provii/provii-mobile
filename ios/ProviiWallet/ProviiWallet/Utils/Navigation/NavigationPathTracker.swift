// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Combine

/// Tracks the navigation hierarchy for breadcrumb display, satisfying WCAG 2.2 AAA
/// criterion 2.4.8 (Location). Provides push, pop, replace, and clear operations on
/// the path, an environment key for injection, and a View extension for automatic tracking.
@MainActor
class NavigationPathTracker: ObservableObject {
    static let shared = NavigationPathTracker()

    @Published var currentPath: [String] = []

    private init() {}

    /// Set the current navigation path
    func setPath(_ path: [String]) {
        currentPath = path
    }

    /// Push a new item onto the path
    func push(_ item: String) {
        currentPath.append(item)
    }

    /// Pop the last item from the path
    func pop() {
        if !currentPath.isEmpty {
            currentPath.removeLast()
        }
    }

    /// Replace the current path
    func replacePath(with path: [String]) {
        currentPath = path
    }

    /// Clear the path
    func clear() {
        currentPath = []
    }
}

// MARK: - Environment Key

private struct NavigationPathTrackerKey: EnvironmentKey {
    static let defaultValue = NavigationPathTracker.shared
}

extension EnvironmentValues {
    var navigationPathTracker: NavigationPathTracker {
        get { self[NavigationPathTrackerKey.self] }
        set { self[NavigationPathTrackerKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Track this view in the navigation path
    /// - Parameter name: The name to display in breadcrumbs
    func trackInNavigationPath(_ name: String) -> some View {
        self
            .onAppear {
                NavigationPathTracker.shared.push(name)
            }
            .onDisappear {
                NavigationPathTracker.shared.pop()
            }
    }
}

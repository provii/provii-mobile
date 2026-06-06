// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

/// Network configuration structure
struct NetworkConfiguration {
    let timeout: TimeInterval

    static let `default` = NetworkConfiguration(
        timeout: 30
    )
}

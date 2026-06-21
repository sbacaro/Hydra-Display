//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  Log.swift
//  Hydra Display
//
//  Thin wrapper over the unified logging system (os.Logger). Categories map to
//  the app's subsystems so log lines are easy to filter in Console and in the
//  in-app diagnostics export.
//

import OSLog

enum Log {
    private static let subsystem = AppInfo.bundleIdentifier

    static let app      = Logger(subsystem: subsystem, category: "app")
    static let displays = Logger(subsystem: subsystem, category: "displays")
    static let updater  = Logger(subsystem: subsystem, category: "updater")
    static let capture  = Logger(subsystem: subsystem, category: "capture")
    static let gamma    = Logger(subsystem: subsystem, category: "gamma")
}

//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Hydra Display contributors
//
// This file is part of Hydra Display, free software released under the terms of
// the GNU General Public License v3.0 or later. See the LICENSE file at the
// repository root for the full text. Distributed WITHOUT ANY WARRANTY.
//

//
//  HotKeyCenter.swift
//  Hydra Display
//
//  Minimal global hot-key registration via Carbon's RegisterEventHotKey. A
//  single Carbon event handler routes presses back to the registered closures
//  on the main actor.
//

import Carbon.HIToolbox

@MainActor
final class HotKeyCenter {

    static let shared = HotKeyCenter()

    private struct Entry {
        let ref: EventHotKeyRef
        let action: @MainActor () -> Void
    }

    private var entries: [UInt32: Entry] = [:]
    private var nextID: UInt32 = 1
    private var handlerInstalled = false

    private init() {}

    /// Register a system-wide hot key. `keyCode` is a `kVK_*` virtual key and
    /// `modifiers` a Carbon mask (e.g. `cmdKey | optionKey | controlKey`).
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping @MainActor () -> Void) {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1
        let hotKeyID = EventHotKeyID(signature: OSType(0x48594452), id: id) // "HYDR"
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetEventDispatcherTarget(), 0, &ref)
        if status == noErr, let ref {
            entries[id] = Entry(ref: ref, action: action)
        }
    }

    func unregisterAll() {
        for entry in entries.values { UnregisterEventHotKey(entry.ref) }
        entries.removeAll()
    }

    fileprivate func fire(id: UInt32) {
        entries[id]?.action()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), hydraHotKeyHandler, 1, &spec, nil, nil)
    }
}

/// Carbon C callback. Reads the hot-key id and hops to the main actor to fire.
private func hydraHotKeyHandler(_ next: EventHandlerCallRef?,
                                _ event: EventRef?,
                                _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event,
                                   EventParamName(kEventParamDirectObject),
                                   EventParamType(typeEventHotKeyID),
                                   nil,
                                   MemoryLayout<EventHotKeyID>.size,
                                   nil,
                                   &hotKeyID)
    if status == noErr {
        let id = hotKeyID.id
        Task { @MainActor in HotKeyCenter.shared.fire(id: id) }
    }
    return noErr
}

// Portions adapted from SubFlow's hotkey handling
// Copyright (c) 2025 Jinsong Zhou, MIT License (see NOTICE.md); modified 2026.
import AppKit
import Carbon.HIToolbox

/// System-wide shortcuts through Carbon RegisterEventHotKey, which needs no
/// Accessibility permission (unlike NSEvent global monitors).
@MainActor
final class GlobalHotkeys {
  private var refs: [String: EventHotKeyRef] = [:]
  private var ids: [UInt32: String] = [:]
  private var nextId: UInt32 = 1
  private var handler: EventHandlerRef?
  var onPressed: ((String) -> Void)?

  private static let keyCodes: [Character: Int] = [
    "A": kVK_ANSI_A, "B": kVK_ANSI_B, "C": kVK_ANSI_C, "D": kVK_ANSI_D, "E": kVK_ANSI_E,
    "F": kVK_ANSI_F, "G": kVK_ANSI_G, "H": kVK_ANSI_H, "I": kVK_ANSI_I, "J": kVK_ANSI_J,
    "K": kVK_ANSI_K, "L": kVK_ANSI_L, "M": kVK_ANSI_M, "N": kVK_ANSI_N, "O": kVK_ANSI_O,
    "P": kVK_ANSI_P, "Q": kVK_ANSI_Q, "R": kVK_ANSI_R, "S": kVK_ANSI_S, "T": kVK_ANSI_T,
    "U": kVK_ANSI_U, "V": kVK_ANSI_V, "W": kVK_ANSI_W, "X": kVK_ANSI_X, "Y": kVK_ANSI_Y,
    "Z": kVK_ANSI_Z,
  ]

  func register(id: String, key: String, command: Bool, shift: Bool, option: Bool, control: Bool) -> Bool {
    unregister(id: id)
    guard let char = key.uppercased().first, let code = Self.keyCodes[char] else { return false }
    installHandlerIfNeeded()
    var modifiers: UInt32 = 0
    if command { modifiers |= UInt32(cmdKey) }
    if shift { modifiers |= UInt32(shiftKey) }
    if option { modifiers |= UInt32(optionKey) }
    if control { modifiers |= UInt32(controlKey) }
    let number = nextId
    nextId += 1
    var ref: EventHotKeyRef?
    let status = RegisterEventHotKey(
      UInt32(code), modifiers, EventHotKeyID(signature: OSType(0x53_59_4C_4D), id: number),
      GetApplicationEventTarget(), 0, &ref)
    guard status == noErr, let ref else { return false }
    refs[id] = ref
    ids[number] = id
    return true
  }

  func unregister(id: String) {
    if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
    ids = ids.filter { $0.value != id }
  }

  private func installHandlerIfNeeded() {
    guard handler == nil else { return }
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let context = Unmanaged.passUnretained(self).toOpaque()
    InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
      guard let event, let context else { return noErr }
      var hotKey = EventHotKeyID()
      GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
        MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
      let manager = Unmanaged<GlobalHotkeys>.fromOpaque(context).takeUnretainedValue()
      MainActor.assumeIsolated {
        if let id = manager.ids[hotKey.id] { manager.onPressed?(id) }
      }
      return noErr
    }, 1, &spec, context, &handler)
  }
}

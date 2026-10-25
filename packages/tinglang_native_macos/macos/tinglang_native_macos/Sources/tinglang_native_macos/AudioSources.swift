import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation
@preconcurrency import ScreenCaptureKit

/// A capture backend that delivers PCM buffers on its own serial context.
/// Buffers are only valid during the callback; consumers convert immediately.
protocol LiveAudioSource: AnyObject {
  var name: String { get }
  func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) throws
  func stop()
}

enum AudioSourceError: LocalizedError {
  case coreAudio(String, OSStatus)
  case noOutputDevice
  case unsupportedFormat
  case noDisplay

  var errorDescription: String? {
    switch self {
    case .coreAudio(let call, let status): return "\(call) failed (\(status))"
    case .noOutputDevice: return "No audio output device"
    case .unsupportedFormat: return "Unsupported audio format"
    case .noDisplay: return "No display available for ScreenCaptureKit audio"
    }
  }
}

private func check(_ status: OSStatus, _ call: String) throws {
  if status != noErr { throw AudioSourceError.coreAudio(call, status) }
}

private func readProperty<T>(
  _ object: AudioObjectID, _ selector: AudioObjectPropertySelector, default value: T,
  qualifier: inout pid_t
) -> T? {
  var address = AudioObjectPropertyAddress(
    mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain)
  var result = value
  var size = UInt32(MemoryLayout<T>.size)
  let status = AudioObjectGetPropertyData(
    object, &address, UInt32(MemoryLayout<pid_t>.size), &qualifier, &size, &result)
  return status == noErr ? result : nil
}

private func readProperty<T>(
  _ object: AudioObjectID, _ selector: AudioObjectPropertySelector, default value: T
) -> T? {
  var address = AudioObjectPropertyAddress(
    mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain)
  var result = value
  var size = UInt32(MemoryLayout<T>.size)
  let status = AudioObjectGetPropertyData(object, &address, 0, nil, &size, &result)
  return status == noErr ? result : nil
}

/// System audio through a Core Audio process tap (macOS 14.2+). Needs only
/// "System Audio Recording" permission, which macOS asks for on the first
/// AudioDeviceStart. Without `NSAudioCaptureUsageDescription` in Info.plist
/// the tap silently delivers zeros, which LiveCaptionEngine detects.
final class SystemAudioTap: LiveAudioSource {
  let name = "coreaudio_tap"
  private var tapID = AudioObjectID(kAudioObjectUnknown)
  private var aggregateID = AudioObjectID(kAudioObjectUnknown)
  private var procID: AudioDeviceIOProcID?
  private let queue = DispatchQueue(label: "dev.eeeease.tinglang.tap", qos: .userInitiated)

  func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) throws {
    var pid = getpid()
    // Our own process object exists only once we have opened audio; if it
    // does not, there is nothing of ours to exclude.
    let own = readProperty(
      AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyTranslatePIDToProcessObject,
      default: AudioObjectID(kAudioObjectUnknown), qualifier: &pid)
    let excluded = (own.map { $0 == kAudioObjectUnknown ? [] : [$0] }) ?? []
    let description = CATapDescription(stereoGlobalTapButExcludeProcesses: excluded)
    description.uuid = UUID()
    description.name = "Tinglang live captions"
    description.isPrivate = true
    description.muteBehavior = .unmuted
    try check(AudioHardwareCreateProcessTap(description, &tapID), "AudioHardwareCreateProcessTap")

    guard
      var asbd = readProperty(tapID, kAudioTapPropertyFormat, default: AudioStreamBasicDescription()),
      let format = AVAudioFormat(streamDescription: &asbd)
    else { throw AudioSourceError.unsupportedFormat }

    guard
      let output = readProperty(
        AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultSystemOutputDevice,
        default: AudioObjectID(kAudioObjectUnknown)),
      output != kAudioObjectUnknown,
      let outputUID = readProperty(output, kAudioDevicePropertyDeviceUID, default: "" as CFString)
    else { throw AudioSourceError.noOutputDevice }

    let aggregate: [String: Any] = [
      kAudioAggregateDeviceNameKey: "Tinglang Tap",
      kAudioAggregateDeviceUIDKey: UUID().uuidString,
      kAudioAggregateDeviceMainSubDeviceKey: outputUID as String,
      kAudioAggregateDeviceIsPrivateKey: true,
      kAudioAggregateDeviceIsStackedKey: false,
      kAudioAggregateDeviceTapAutoStartKey: true,
      kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID as String]],
      kAudioAggregateDeviceTapListKey: [
        [kAudioSubTapDriftCompensationKey: true, kAudioSubTapUIDKey: description.uuid.uuidString]
      ],
    ]
    try check(
      AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID),
      "AudioHardwareCreateAggregateDevice")
    try check(
      AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { _, input, _, _, _ in
        guard
          let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: input, deallocator: nil)
        else { return }
        onBuffer(buffer)
      }, "AudioDeviceCreateIOProcIDWithBlock")
    liveLog.info("tap created (excluded \(excluded.count) process objects); starting device")
    try check(AudioDeviceStart(aggregateID, procID), "AudioDeviceStart")
    liveLog.info("tap device started")
  }

  func stop() {
    if aggregateID != kAudioObjectUnknown {
      AudioDeviceStop(aggregateID, procID)
      if let procID { AudioDeviceDestroyIOProcID(aggregateID, procID) }
      AudioHardwareDestroyAggregateDevice(aggregateID)
    }
    if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
    procID = nil
    aggregateID = AudioObjectID(kAudioObjectUnknown)
    tapID = AudioObjectID(kAudioObjectUnknown)
  }

  /// Whether any process is currently playing to the default output, used to
  /// tell "silence" from "tap denied" (all-zero buffers while audio plays).
  static func outputIsPlaying() -> Bool {
    guard
      let output = readProperty(
        AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultSystemOutputDevice,
        default: AudioObjectID(kAudioObjectUnknown)),
      let running = readProperty(
        output, kAudioDevicePropertyDeviceIsRunningSomewhere, default: UInt32(0))
    else { return false }
    return running != 0
  }
}

/// Microphone through AVAudioEngine.
final class MicrophoneSource: LiveAudioSource {
  let name = "avaudioengine_mic"
  private let engine = AVAudioEngine()

  func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) throws {
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0 else { throw AudioSourceError.unsupportedFormat }
    input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in onBuffer(buffer) }
    engine.prepare()
    try engine.start()
  }

  func stop() {
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
  }
}

// Portions adapted from SubFlow AudioCaptureService.swift
// Copyright (c) 2025 Jinsong Zhou, MIT License; modified 2026.
/// ScreenCaptureKit audio fallback (needs Screen Recording permission). Video
/// frames are throttled to 1 fps at 2×2 so only audio costs anything.
final class ScreenCaptureAudioSource: NSObject, LiveAudioSource, SCStreamOutput, SCStreamDelegate,
  @unchecked Sendable
{
  let name = "screencapturekit"
  private var stream: SCStream?
  private var onBuffer: ((AVAudioPCMBuffer) -> Void)?
  private let queue = DispatchQueue(label: "dev.eeeease.tinglang.sck", qos: .userInitiated)

  func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) throws {
    self.onBuffer = onBuffer
    let semaphore = DispatchSemaphore(value: 0)
    var failure: Error?
    Task {
      do {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else { throw AudioSourceError.noDisplay }
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.channelCount = 1
        config.sampleRate = 16000
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.queueDepth = 3
        config.showsCursor = false
        let stream = SCStream(
          filter: SCContentFilter(display: display, excludingWindows: []), configuration: config,
          delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: self.queue)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: self.queue)
        try await stream.startCapture()
        self.stream = stream
      } catch { failure = error }
      semaphore.signal()
    }
    semaphore.wait()
    if let failure { throw failure }
  }

  func stop() {
    let stream = self.stream
    self.stream = nil
    Task { try? await stream?.stopCapture() }
  }

  func stream(
    _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType
  ) {
    guard type == .audio, CMSampleBufferIsValid(sampleBuffer),
      let description = sampleBuffer.formatDescription,
      var asbd = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee,
      let format = AVAudioFormat(streamDescription: &asbd)
    else { return }
    let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
    buffer.frameLength = frames
    let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
      sampleBuffer, at: 0, frameCount: Int32(frames), into: buffer.mutableAudioBufferList)
    if status == noErr { onBuffer?(buffer) }
  }
}

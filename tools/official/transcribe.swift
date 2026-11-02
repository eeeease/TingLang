// Transcribes an English audio file with Apple's SpeechTranscriber (macOS 26+,
// the recogniser the app uses for files) and prints the result as JSON: one
// object per final result, with word timings.
//
//   swift tools/official/transcribe.swift audio.m4a > transcript.json
//
// [{"text": "…", "startMs": 0, "endMs": 4200, "words": [{"w": "So", "s": 0, "e": 180}, …]}, …]
// The English speech model must be installed (the app installs it on first use).
import AVFoundation
import Foundation
import Speech

@available(macOS 26.0, *)
func transcribe(_ path: String) async throws -> [[String: Any]] {
  guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US")) else {
    throw NSError(domain: "transcribe", code: 1, userInfo: [NSLocalizedDescriptionKey: "English is not supported"])
  }
  let transcriber = SpeechTranscriber(
    locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange])
  if try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) != nil {
    throw NSError(domain: "transcribe", code: 2, userInfo: [NSLocalizedDescriptionKey: "The English speech model is not installed"])
  }
  let analyzer = SpeechAnalyzer(modules: [transcriber])
  let collector = Task { () -> [[String: Any]] in
    var out: [[String: Any]] = []
    for try await result in transcriber.results where result.isFinal {
      let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !text.isEmpty else { continue }
      var words: [[String: Any]] = []
      for run in result.text.runs {
        guard let range = run.audioTimeRange else { continue }
        let word = String(result.text[run.range].characters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty, range.start.seconds.isFinite, range.end.seconds.isFinite else { continue }
        words.append(["w": word, "s": Int(range.start.seconds * 1000), "e": Int(range.end.seconds * 1000)])
      }
      out.append([
        "text": text,
        "startMs": Int(result.range.start.seconds * 1000),
        "endMs": Int(result.range.end.seconds * 1000),
        "words": words,
      ])
    }
    return out
  }
  let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
  if let last = try await analyzer.analyzeSequence(from: file) {
    try await analyzer.finalizeAndFinish(through: last)
  } else {
    await analyzer.cancelAndFinishNow()
  }
  return try await collector.value
}

guard CommandLine.arguments.count == 2 else {
  FileHandle.standardError.write("usage: swift transcribe.swift <audio file>\n".data(using: .utf8)!)
  exit(64)
}
guard #available(macOS 26.0, *) else {
  FileHandle.standardError.write("SpeechTranscriber needs macOS 26 or later\n".data(using: .utf8)!)
  exit(1)
}
do {
  let segments = try await transcribe(CommandLine.arguments[1])
  let data = try JSONSerialization.data(withJSONObject: segments)
  FileHandle.standardOutput.write(data)
} catch {
  FileHandle.standardError.write("\(error.localizedDescription)\n".data(using: .utf8)!)
  exit(1)
}

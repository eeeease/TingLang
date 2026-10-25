import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
// The public `initBindings()` resolves the library through the package
// config whenever it can, which would load a second copy next to the one the
// app embeds; binding the process image directly avoids that.
// ignore: implementation_imports
import 'package:sherpa_onnx/src/sherpa_onnx_bindings.dart' show SherpaOnnxBindings;
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

/// Where the sherpa-onnx C library comes from, resolved in the root isolate
/// and handed to every worker ([bindSherpa]).
///
/// - In the app the library is linked into the process (the pub package's
///   xcframework through SwiftPM), so this returns null and workers bind
///   `DynamicLibrary.process()`.
/// - `flutter test` and `dart run` have no such image: the directory comes
///   from `TINGLANG_SHERPA_LIB_DIR` or from the `sherpa_onnx_<os>` entry in
///   the nearest `.dart_tool/package_config.json` (the pub cache), the layout
///   `initBindings(path)` expects (`<package>/macos`, `<package>/windows`,
///   `<package>/linux/<arch>`).
String? sherpaLibraryDir() {
  if (DynamicLibrary.process().providesSymbol('SherpaOnnxCreateOnlineRecognizer')) return null;
  final env = Platform.environment['TINGLANG_SHERPA_LIB_DIR'];
  if (env != null && env.isNotEmpty) return env;
  final os = Platform.isMacOS
      ? 'macos'
      : Platform.isWindows
      ? 'windows'
      : Platform.isLinux
      ? 'linux'
      : null;
  if (os == null) return null;
  final root = _packageRoot('sherpa_onnx_$os');
  if (root == null) return null;
  final dir = '$root${Platform.pathSeparator}$os';
  if (!Platform.isLinux) return dir;
  final arm = Platform.version.contains('arm64') || Platform.version.contains('aarch64');
  return '$dir${Platform.pathSeparator}${arm ? 'aarch64' : 'x64'}';
}

/// Binds the sherpa-onnx FFI functions in the calling isolate (every isolate
/// has its own binding table). [libraryDir] comes from [sherpaLibraryDir].
void bindSherpa(String? libraryDir) {
  if (libraryDir != null) {
    sherpa.initBindings(libraryDir);
  } else {
    SherpaOnnxBindings.init(DynamicLibrary.process());
  }
}

String? _packageRoot(String package) {
  for (final config in _packageConfigs()) {
    try {
      final json = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
      for (final entry in (json['packages']! as List<Object?>).cast<Map<String, Object?>>()) {
        if (entry['name'] != package) continue;
        final root = config.uri.resolve(entry['rootUri']! as String);
        return Directory.fromUri(root).path.replaceFirst(RegExp(r'[/\\]$'), '');
      }
    } on Object {
      continue;
    }
  }
  return null;
}

Iterable<File> _packageConfigs() sync* {
  final explicit = Platform.packageConfig;
  if (explicit != null) yield File.fromUri(Uri.base.resolve(explicit));
  for (final start in [Directory.current, File(Platform.script.toFilePath()).parent]) {
    var dir = start.absolute;
    while (true) {
      final file = File('${dir.path}/.dart_tool/package_config.json');
      if (file.existsSync()) yield file;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  }
}

typedef _ClockGettime = Int32 Function(Int32 clock, Pointer<Int64> timespec);

/// CPU time of the calling OS thread in microseconds, or null where the
/// clock is unavailable (Windows). Valid only for deltas measured around
/// synchronous work, since an isolate may move between threads between
/// events. onnxruntime pool threads (numThreads > 1) are not included.
int? threadCpuMicros() {
  final clock = _threadClock;
  if (clock == null) return null;
  final ts = _timespec ??= calloc<Int64>(2);
  if (clock(Platform.isMacOS ? 16 : 3, ts) != 0) return null; // CLOCK_THREAD_CPUTIME_ID
  return ts[0] * 1000000 + ts[1] ~/ 1000;
}

Pointer<Int64>? _timespec;
final int Function(int, Pointer<Int64>)? _threadClock = () {
  if (!Platform.isMacOS && !Platform.isLinux) return null;
  try {
    return DynamicLibrary.process()
        .lookupFunction<_ClockGettime, int Function(int, Pointer<Int64>)>('clock_gettime');
  } on Object {
    return null;
  }
}();

/// Words from token timings, only when the model reported a time for every
/// token (Tinglang never invents timing).
///
/// Models give token start times only, so a word starts at its first token
/// and ends where the token after its last one starts; the last word ends at
/// [endMs]. SentencePiece tokens beginning with `▁` (or a space) start a new
/// word, each CJK character is a word, and punctuation joins the preceding
/// word without changing its end. [offsetMs] maps token times (seconds) onto
/// the capture or media clock.
List<TimedWord>? wordsFromTokens(
  List<String> tokens,
  List<double> timestamps, {
  required int offsetMs,
  required int endMs,
}) {
  if (tokens.isEmpty || tokens.length != timestamps.length) return null;
  final words = <TimedWord>[];
  final text = StringBuffer();
  var start = 0, end = 0;
  int at(int i) => i < tokens.length ? offsetMs + (timestamps[i] * 1000).round() : endMs;
  void close() {
    final word = text.toString();
    if (word.isNotEmpty) words.add(TimedWord(word, start, math.max(start, end)));
    text.clear();
  }

  for (var i = 0; i < tokens.length; i++) {
    final piece = tokens[i].replaceAll('▁', ' ');
    final token = piece.trim();
    if (token.isEmpty) {
      close();
      continue;
    }
    if (_punctuation.hasMatch(token)) {
      if (text.isNotEmpty) {
        text.write(token);
      } else if (words.isNotEmpty) {
        final last = words.removeLast();
        words.add(TimedWord('${last.text}$token', last.startMs, last.endMs));
      }
      continue;
    }
    final cjk = _cjk.hasMatch(token);
    if (cjk || piece.startsWith(' ')) close();
    if (text.isEmpty) start = at(i);
    text.write(token);
    end = at(i + 1);
    if (cjk) close();
  }
  close();
  return words.isEmpty ? null : words;
}

final _cjk = RegExp(r'^[㐀-鿿豈-﫿]+$');
final _punctuation = RegExp(r'''^[.,!?;:'"%)\]}…，。！？；：、”’）」』》]+$''');

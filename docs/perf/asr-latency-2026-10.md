# Speech model latency and CPU per tier — 2026-10-23

Machine: MacBook Pro, Apple M4 Pro (10P+4E), macOS 27.0.1, on mains power,
with the user's normal apps open (not an idle machine). Audio: the first 20
FLEURS en dev utterances (CC-BY-4.0), 211 s with 1 s of silence between
utterances, fed **in real time** in 100 ms blocks — the way live captions see
audio. The benchmark data stays on the machine (`<bench>` below); the harnesses are in the
repository.

Definitions (same for both harnesses):

- **Partial lag**: when a partial arrives, the audio already fed minus the end
  of the audio the partial covers, plus the wait for the app's next partial
  tick (the tier's coalescing interval). What a viewer sees as "how far the
  words trail the speech".
- **Final after clip end**: wall time from the end of an utterance's clip to
  the final that completes it. FLEURS clips end with a little silence, so a
  line can end before its clip does (negative values).
- **CPU**: CPU seconds per second of audio (100% = one core). For Apple's
  engines this includes the out-of-process `localspeechrecognition` and
  `aned` services, sampled per process every second.
- **WER**: word error rate over the whole run (lower case, punctuation
  removed); Apple Dictation punctuates but the reference comparison ignores
  it.

## Apple (macOS 26+): `tools/bench/apple_latency_bench.swift`

```bash
swiftc -O -parse-as-library tools/bench/apple_latency_bench.swift -o /tmp/apple_bench
/tmp/apple_bench <bench>/prepared/fleurs_en_us/manifest.jsonl 20 appleSpeech balanced
```

The harness builds the recogniser exactly as `SpeechRecognizers.swift` does
for each tier (reporting options, `SpeechAnalyzer.Options` priority, model
retention, `ignoresResourceLimits` on macOS 27, `prepareToAnalyze`).

| Engine | Tier | CPU (app + services) | Partial lag p50 / p90 | Final after clip end p50 / p90 | WER |
|---|---|---|---|---|---|
| SpeechTranscriber | Power saver | 3.4% (1.2 + 2.3) | 0.13 / 0.23 s | −0.20 / 0.44 s | 7.9 |
| SpeechTranscriber | Balanced | 3.1% (1.0 + 2.1) | 0.08 / 0.09 s | −0.19 / 0.43 s | 7.9 |
| SpeechTranscriber | Lowest latency | 3.7% (1.2 + 2.5) | **0.03 / 0.04 s** | −0.20 / 0.44 s | 7.9 |
| DictationTranscriber | Power saver | 10.7% (1.3 + 9.4) | 0.25 / 0.35 s | 1.28 / 9.86 s | 18.3 |
| DictationTranscriber | Balanced | 10.5% (1.2 + 9.3) | 0.18 / 0.23 s | 1.25 / 9.86 s | 18.3 |
| DictationTranscriber | Lowest latency | 11.4% (1.4 + 10.0) | 0.14 / 0.18 s | 1.28 / 9.87 s | 18.3 |

Findings:

1. **SpeechTranscriber's tier changes when words appear, not what it costs.**
   CPU stays at 3–4% on every tier (within run-to-run noise); the partial lag
   falls from 0.13 s to 0.03 s, almost entirely through our coalescing
   interval (250 / 100 / 50 ms) — `fastResults`, priority and model retention
   make little measurable difference on this machine. Finals and accuracy are
   unchanged. Earlier "~2%" figures (asr-bench-2026-10.md) were sampled from
   `top` at 1 s granularity; per-process sampling gives ~3%.
2. **DictationTranscriber is a weaker caption engine**: about 3× the CPU,
   2.3× the WER on read speech, and partials lag more. Without
   `frequentFinalization` its lines ended **~15 s** after the speech (p50;
   p90 31 s) on the power-saver and balanced tiers — so live captions now ask
   for `frequentFinalization` on every tier, which brought that to 1.3 s
   (p90 still 9.9 s). It stays available for its far-field and short-form
   hints.
3. A first pass measured the services' CPU from cumulative `ps` time; one
   service process was replaced mid-run and gave a negative number. The
   numbers above use per-process sampling every second.

## sherpa-onnx (all macOS versions): `packages/tinglang_native/tool/asr_latency_bench.dart`

```bash
cd packages/tinglang_native
fvm dart compile exe tool/asr_latency_bench.dart -o /tmp/asr_bench
/tmp/asr_bench --fleurs <bench>/prepared/fleurs_en_us --vad <bench>/models \
  --model sherpa.xasr_zh_en_480=<extracted pack> --model sherpa.zipformer_en_small=<pack> \
  --model sherpa.zipformer_en_medium=<pack> --minutes 5 --gap 2 [--tiers fastest]
```

`SherpaStreamingAsr` as the app runs it (worker isolate, VAD gate, tier
parameters), in push mode from an AOT executable: 27 FLEURS en utterances,
5.1 min with 2 s pauses, real time in 100 ms blocks. Columns differ slightly
from the Apple table: **word lag** is when a word first appears (partial or
final) minus that word's end from the model's token times; **final after
speech end** is relative to the VAD's end of speech. **CPU** is the whole
process (getrusage); **worker** is the recogniser thread alone. The Apple
bench ran in parallel during part of the 2-thread runs (~3% machine CPU).

| Model | Tier | Threads | Word lag p50 / p90 | Final after speech end p50 / p90 | Final after clip end p50 / p90 | CPU (worker) | WER |
|---|---|---|---|---|---|---|---|
| X-ASR 480 ms | Power saver | 1 | 0.26 / 0.58 s | 1.09 / 1.15 s | 0.97 / 1.59 s | 15.6% (8.7%) | 13.4 |
| X-ASR 480 ms | Balanced | 1 | 0.24 / 0.53 s | 0.90 / 0.98 s | 0.81 / 1.35 s | 15.6% (8.7%) | 13.7 |
| X-ASR 480 ms | Lowest, 2 threads | 2 | 0.21 / 0.50 s | 0.93 / 0.96 s | 0.75 / 1.30 s | 24.3% (6.7%) | 13.6 |
| X-ASR 480 ms | **Lowest (shipped)** | 1 | 0.22 / 0.51 s | 0.94 / 0.97 s | 0.77 / 1.31 s | 15.5% (8.7%) | 13.7 |
| Zipformer EN 20M | Power saver | 1 | 0.26 / 0.54 s | 1.07 / 1.08 s | 0.44 / 1.22 s | 13.1% (5.2%) | 31.0 |
| Zipformer EN 20M | Balanced | 1 | 0.14 / 0.36 s | 0.87 / 0.96 s | 0.33 / 1.02 s | 13.1% (5.3%) | 30.8 |
| Zipformer EN 20M | Lowest, 2 threads | 2 | 0.12 / 0.34 s | 0.59 / 0.63 s | 0.02 / 0.72 s | 23.2% (4.1%) | 31.5 |
| Zipformer EN 20M | **Lowest (shipped)** | 1 | 0.13 / 0.35 s | 0.60 / 0.63 s | 0.03 / 0.72 s | 12.9% (5.2%) | 31.5 |
| Zipformer EN 66M | Power saver | 1 | 0.28 / 0.56 s | 1.08 / 1.11 s | 0.73 / 1.47 s | 14.6% (7.7%) | 24.9 |
| Zipformer EN 66M | Balanced | 1 | 0.20 / 0.44 s | 0.88 / 1.05 s | 0.51 / 1.19 s | 14.6% (7.6%) | 25.6 |
| Zipformer EN 66M | Lowest, 2 threads | 2 | 0.17 / 0.42 s | 0.60 / 0.73 s | 0.12 / 0.87 s | 26.3% (6.1%) | 26.2 |
| Zipformer EN 66M | **Lowest (shipped)** | 1 | 0.18 / 0.42 s | 0.61 / 0.73 s | 0.13 / 0.87 s | 14.5% (7.6%) | 26.2 |

Peak RSS: 0.73–0.78 GB with X-ASR loaded first in the same process; alone the
20M model peaked at 0.20 GB and the 66M at 0.30 GB.

Findings:

1. **More threads do not buy latency.** A second onnxruntime thread added
   9–12 points of process CPU and moved words by 0.01–0.03 s (sherpa-onnx
   1.13.8 has no way to turn off the pool's spinning). The shipped
   lowest-latency tier therefore uses one thread; it differs from balanced by
   50 ms feeds and, for the English zipformers, a 0.5 s end-of-line pause
   (finals 0.6 s instead of 0.9 s after speech). X-ASR keeps 0.8 s: at 0.5 s
   the 480 ms model emits words after the endpoint has fired and the reset
   drops them.
2. **Power saver mostly ends lines later** (1.0 s pause) and updates less
   often; CPU is the same as balanced here because the 2 s pauses keep the
   VAD gate open (it holds for the pause plus 1 s). In long silences the gate
   stops feeding the recogniser entirely (tested), which is where the saving
   is.
3. About 6–7 points of process CPU are outside the recogniser thread (Dart
   runtime, push mode, VAD calls). The M0 benchmark's 7.3% for X-ASR was a
   leaner harness without the VAD gate; profiling the app's own overhead is a
   follow-up.
4. **Accuracy:** X-ASR 13.4–13.7 WER here (a simpler text normalisation than
   the M0 benchmark, which reported 9.7–10.5; a 1.5 min subset gave 8.5). The
   LibriSpeech zipformers are much weaker on FLEURS: 20M ≈ 31, 66M ≈ 25 — after
   the warm-up and gain fixes (≈ 75 before). They are offered for low CPU,
   small downloads and early words, labelled as least accurate.

Not measured here: the ring path from Swift capture (push mode was used; the
worker code after the reader is the same), the file transcribers' CPU (the M0
numbers stand: X-ASR offline 3.4%, Parakeet 22%), Windows, Intel Macs.

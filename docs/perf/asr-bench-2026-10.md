# Local ASR model benchmark — 2026-10-21

Machine: MacBook Pro, Apple M4 Pro (10P+4E cores), macOS 27.0.1. Runtime for
open models: `sherpa_onnx` 1.13.8 (pub.dev, the same package the app will use),
CPU provider, greedy search, plus a small Swift harness for Apple
SpeechTranscriber. The benchmark scripts and data were local to the machine
and are not part of the repository; only the results are kept here.

## Test sets

| Set | What | Size |
|---|---|---|
| FLEURS en dev | read English, one utterance per sentence (CC-BY-4.0) | 150 utts, 24.1 min |
| FLEURS zh dev | read Mandarin (CC-BY-4.0) | 150 utts, 27.4 min |
| Lex #497 | conversational podcast, 6 × 120 s windows from the official RSS MP3, scored against the official transcript with semi-global alignment | 12 min |

The Lex reference is the official *cleaned* transcript (fillers, false starts
removed), so every model shows a ~15% floor there; compare models with each
other, not with the absolute number.

CPU = process CPU seconds per audio second (100% = one core). For Apple
SpeechTranscriber it includes the out-of-process `localspeechrecognition` and
`aned` services, integrated from 1 s `top` samples.

## Results

### Live captions (streaming, 100 ms chunks)

| Engine | Disk | RSS | CPU (fast) | CPU (live, paced) | FLEURS en WER | FLEURS zh CER | Lex WER | Partial lag p50 / p90 | Final after speech end p50 / p90 |
|---|---|---|---|---|---|---|---|---|---|
| **Apple SpeechTranscriber** (progressive preset, macOS 26+) | 0 (system asset) | n/a (system) | 1.5–1.8% | **1.7% en / 2.4% zh** | **8.6** | **8.7** | 17.3 | **0.02 s / 0.03 s** | 0.22 / 0.78 s (en), 0.86 / 1.55 s (zh) |
| **X-ASR zh-en 480 ms int8**, 1 thread | 169 MB | 0.9 GB | 5.7% | 7.3% en / 7.0% zh | 10.5 | 9.7 | 17.1 | 0.51 / 0.69 s | 0.44 / 1.22 s (endpoint 0.8 s) |
| X-ASR 480 ms, 2 threads (no spin) | 169 MB | 0.9 GB | 7.3% | — | — | — | — | — | — |
| Nemotron EN 0.6B 560 ms int8, 1 thread | 662 MB | 1.4 GB | 71% | 73% | 14.8 | — | 17.5 | 0.96 / 1.10 s | — |
| Moonshine Small in SubFlow (before / after hotfix) | 235 MB | — | — | 130% / 31.5% | — | — | — | — | — |

Live WER on the 30 paced utterances: Apple 7.8 (en) / 12.0 CER (zh), X-ASR 9.7 / 13.2.

Silence fed straight into the recognizer (no VAD): X-ASR 5.3%, Nemotron 65%.
The app must gate with VAD before the recognizer.

### File transcription (offline, Silero VAD segments)

| Engine | Disk | CPU | FLEURS en WER | FLEURS zh CER | Lex WER |
|---|---|---|---|---|---|
| Apple SpeechTranscriber (transcription preset) | 0 | 1.3–1.8% | 8.6 | 8.7 | 17.3 |
| **X-ASR offline punct int8** | 175 MB | 3.4% | 9.2 | 9.1 | 17.8 |
| Parakeet TDT 0.6B v2 int8 | 661 MB | 22% | **7.5** | en only | **15.9** |

## Findings

1. **Apple SpeechTranscriber is the best live engine on macOS 26+ by every
   measure except final latency for Chinese**: ~2% CPU (4× below X-ASR, 40×
   below Nemotron, 15× below the hotfixed SubFlow), most accurate on read
   speech, tied on conversation, near-instant volatile partials, no download.
2. **X-ASR is the best open model**: one 169 MB model covers en + zh with
   punctuation at ~6–7% CPU on one thread; more threads only add CPU.
3. **Nemotron EN is not viable in this runtime**: 71% CPU on one thread
   (docs claim RTF 0.16; we measure 0.62–0.71 on M4 Pro, every chunk size and
   feed size), and sherpa's endpoint reset drops words (FLEURS WER 14.8 even
   with endpointing off; several utterances lose whole clauses).
4. **Parakeet TDT v2** is the most accurate English file transcriber (Lex 15.9)
   but costs 22% CPU and 661 MB — an optional "high accuracy English" pack.

## Decision (per the approved selection rule)

| | Live captions | File transcription (+ word timing for dictation) |
|---|---|---|
| macOS 26+ | **Apple SpeechTranscriber** (topology A) | Apple SpeechTranscriber; optional Parakeet v2 pack for English |
| macOS 14.2–15, Windows | **X-ASR 480 ms int8**, 1 thread, Silero VAD gate, endpoint 0.8 s | **X-ASR offline punct int8**; optional Parakeet v2 pack for English |
| ja/ko/es/fr/de | Apple on macOS 26+; Windows TBD at M8 (Nemotron 3.5 must be re-measured first — the EN sibling failed here) | same |

Moonshine and Nemotron are dropped from the app.

## Not covered / caveats

- One machine (M4 Pro). Windows/Intel numbers come at M8.
- FLEURS is read speech; Lex is the only conversational set. NBA/game clips with hand-checked references would strengthen the en decision.
- Final-latency numbers mix sentence-internal and end-of-utterance finals; "final after speech end" is the user-visible one.
- SpeechTranscriber CPU is sampled at 1 s granularity from `top`.

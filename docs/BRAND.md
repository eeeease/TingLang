# TingLang · 听浪

**听浪** (Tīng Làng): listening to the waves — the waves of sound that the app turns into lines you can read, replay and keep. **TingLang** is its pinyin, used wherever the interface is not Chinese.

Tagline: *Every sentence is a wave. Catch it.* · 每一句都是一朵浪，接住它。

No trademark search has been done; this is not a claim of registration or exclusive rights.

## Identity in the product

- Interface names: TingLang (English), 听浪 (Chinese) — window titles, the sidebar, About, licence page. The bundle and file names stay `Tinglang` (`Tinglang.app`).
- Identifiers: bundle id `dev.eeeease.tinglang`, the `Tinglang` data folder, the Keychain service `dev.eeeease.tinglang`, `tinglang_*` packages and JSON keys.

## Palette and type

Paper and ink with one accent (see `packages/tinglang_ui`):

- Ink `#171716`, paper `#F7F7F6`, warm neutral greys between them.
- Orange `#D9642A` (brand), `#BD5520` for text and controls on paper, `#FF8A4C` on dark surfaces with near-black text on it. It marks only what is live or chosen: start/listening, the selected item, progress.
- System fonts only (SF Pro and PingFang SC), fixed sizes 11–28.

## Mark

A thin, sharp sound wave that softens and thickens into a rounded "hi": what you hear becomes what you say. Orange to ink on paper, with an ink dot; orange to paper on dark surfaces, with a paper dot. The mark's ink (`#1C1B19`) and paper (`#F4F2EE`) are its own, slightly warmer than the interface neutrals.

The files in `assets/brand/` are the source of truth. Do not redraw them by hand.

| File | Use |
| --- | --- |
| `svg/tinglang-mark.svg`, `svg/tinglang-mark-dark.svg` | 48 pt and up: README, About, empty states |
| `svg/tinglang-mark-small.svg`, `svg/tinglang-mark-small-dark.svg` | 20–48 pt: sidebar, floating panel (heavier strokes, larger dot) |
| `svg/tinglang-mark-ink.svg`, `svg/tinglang-mark-paper.svg` | One colour |
| `svg/mark-square.svg` | Square tile |
| `svg/app-icon.svg`, `svg/app-icon-dark.svg`, `svg/app-icon-{16,32,64}.svg` | App icon; the small sizes are drawn for their pixel grid |
| `app_icon_{16,32,64,128,256,512,1024}.png` | Dock icon; `scripts/configure_macos.py` copies them into the runner's `AppIcon.appiconset` |
| `icon-composer/` | Background and mark layers (light and dark) for the macOS 26 Liquid Glass icon |

In code, the mark is drawn as vectors. `tools/brand_mark_geometry.py` reads the four mark SVGs (regular and small, light and dark; their geometry must match) and writes `lib/ui/brand_mark_geometry.dart` (Flutter `Path`, arcs kept as `arcToPoint`) and `BrandMarkGeometry.swift` in `packages/tinglang_native_macos` (SwiftUI `Path`, arcs converted to cubic Béziers). Run it after changing an SVG; `tools/tests` fails while the generated code is stale. `BrandMark` (Flutter) takes the mark's width, uses the small drawing below 48 pt and follows the light/dark theme; the panel's SwiftUI `BrandMark` always uses the on-dark colours because the panel is dark glass.

Not done yet: the Liquid Glass icon. Open Icon Composer, build an `.icon` from the `icon-composer/` layers (light and dark), and add it to the runner in `configure_macos.py`; the `.icon` format is not written by hand.

Do not put league, team or creator logos in the app identity without separately checking rights.

## Design principles

- **Who and where.** One learner on their own Mac, learning English (Chinese is their own language, for now). By day the floating panel sits over a video, a meeting or a game: small, legible over anything, out of the way. In the evening the main window is for close listening, dictation and review.
- **Personality.** A quiet studio notebook — paper, ink and one warm signal. Voice: plain, calm, exact.
- **Not like this.** No mint-and-green gamification, mascots, streaks or confetti; no black subtitle box; no Material defaults (tinted surfaces, floating action buttons); no all-caps English labels above Chinese titles; no permanent disclaimers or developer notes in the interface — a notice must be something the reader can act on.
- **Details.** One accent; success, danger and warning keep their own colours and never stand in for orange. Radius tiers 8/12/20/28; cards have a hairline edge and a whisper shadow tinted toward ink. Motion is feedback only (the record button, the listening dot, a new caption line) and stops under Reduce Motion. Light and dark follow the system; the floating panel defaults to smoke-grey glass so captions read over any video.

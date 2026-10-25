import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang_native_macos/tinglang_native_macos.dart';
import 'package:tinglang_native_macos/src/host_api.g.dart';
import 'package:tinglang_native_macos/src/live.dart' show overlayConfig, panelState;
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

void main() {
  test('panel button presses become typed actions; unknown ones are ignored', () {
    final open = overlayEvent(LiveEvent(kind: 'panel', code: 'openSession', message: 's-1'));
    expect(open, isA<OverlayActionRequested>().having((e) => e.value, 'value', 's-1'));
    expect((open! as OverlayActionRequested).action, OverlayAction.openSession);
    expect(overlayEvent(LiveEvent(kind: 'panel', code: 'fromTheFuture')), isNull);
    expect(overlayEvent(LiveEvent(kind: 'level', level: .5)), isNull);
  });

  test('dropped paths arrive one per line', () {
    final drop = overlayEvent(LiveEvent(kind: 'drop', message: '/a/one.m4a\n/b/two.qta\n'));
    expect((drop! as OverlayFilesDropped).paths, ['/a/one.m4a', '/b/two.qta']);
    expect((drop as OverlayFilesDropped).mainWindow, isFalse);
    final onWindow = overlayEvent(LiveEvent(kind: 'drop', code: 'window', message: '/a/one.m4a'));
    expect((onWindow! as OverlayFilesDropped).mainWindow, isTrue);
  });

  test('a look chosen in Swift round-trips into the same style', () {
    const style = CaptionStyle(
      mode: CaptionMode.text,
      background: CaptionBackground.solid,
      backgroundColor: 0xFF3A1F12,
      textColor: 0xFFFFE16B,
      fontSize: 30,
      fontWeight: 700,
      maxLines: 1,
      alignment: CaptionAlignment.leading,
      clickThrough: true,
      layout: CaptionLayout.sideBySide,
      scrollback: 200,
    );
    final config = overlayConfig(style, const {'translating': '…'});
    expect(config.mode, 'text');
    expect(config.background, 'solid');
    expect(config.clickThrough, isTrue);
    expect(config.layout, 'sideBySide');
    expect(config.scrollbackLines, 200);
    // What PanelStyle.json produces in Swift for the same look.
    final json =
        '{"fontSize":30,"backgroundOpacity":${style.backgroundOpacity},"showTranslation":true,'
        '"clickThrough":true,"mode":"text","background":"solid","backgroundColor":${0xFF3A1F12},'
        '"textColor":${0xFFFFE16B},"translationColor":${style.translationColor},'
        '"accentColor":${style.accentColor},"fontWeight":700,"outline":true,"maxLines":1,'
        '"alignment":"leading","layout":"sideBySide","scrollbackLines":200}';
    final event = overlayEvent(LiveEvent(kind: 'panelStyle', message: json));
    expect((event! as OverlayStyleChanged).style, style);
    expect(overlayEvent(LiveEvent(kind: 'panelStyle', message: 'not json')), isNull);
  });

  test('a look from an older panel without layout or scroll-back gets the defaults', () {
    final event = overlayEvent(LiveEvent(kind: 'panelStyle', message: '{"clickThrough":true}'));
    final style = (event! as OverlayStyleChanged).style;
    expect(style.clickThrough, isTrue);
    expect(style.layout, CaptionLayout.stacked);
    expect(style.scrollback, CaptionStyle.defaultScrollback);
  });

  test('panel state carries the phase, source and timer start by name', () {
    final started = DateTime.utc(2026, 10, 22, 12);
    final state = panelState(
      OverlayState(
        phase: OverlayPhase.listening,
        source: AudioSourceKind.microphone,
        startedAt: started,
        dueCount: 3,
      ),
    );
    expect(state.phase, 'listening');
    expect(state.source, 'microphone');
    expect(state.startedAtMs, started.millisecondsSinceEpoch);
    expect(state.dueCount, 3);
  });
}

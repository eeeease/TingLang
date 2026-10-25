import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang_native_macos/src/host_api.g.dart';
import 'package:tinglang_native_macos/src/live.dart' show MacEvents;
import 'package:tinglang_native_macos/tinglang_native_macos.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const prefix = 'dev.flutter.pigeon.tinglang_native_macos.TinglangHostApi.';
  const codec = TinglangHostApi.pigeonChannelCodec;
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final mocked = <String>[];
  tearDown(() {
    for (final channel in mocked) {
      messenger.setMockMessageHandler(channel, null);
    }
    mocked.clear();
  });

  void reply(String method, Object? Function(List<Object?>? args) answer) {
    final channel = '$prefix$method';
    mocked.add(channel);
    messenger.setMockMessageHandler(channel, (message) async {
      final args = codec.decodeMessage(message) as List<Object?>?;
      return codec.encodeMessage([answer(args)]);
    });
  }

  test('files opened in Finder are taken from Swift after a filesOpened nudge', () async {
    final queue = ['/Users/me/Downloads/Talk.tinglang'];
    reply('takeOpenedFiles', (_) {
      final taken = [...queue];
      queue.clear();
      return taken;
    });
    final events = StreamController<LiveEvent>.broadcast();
    addTearDown(events.close);
    final shell = MacDesktopShell(TinglangHostApi(), MacEvents(() => events.stream));
    final nudges = <void>[];
    final subscription = shell.filesOpened.listen(nudges.add);
    addTearDown(subscription.cancel);
    events
      ..add(LiveEvent(kind: 'drop', message: '/a.m4a'))
      ..add(LiveEvent(kind: 'filesOpened'));
    await pumpEventQueue();
    expect(nudges, hasLength(1));
    expect(await shell.takeOpenedFiles(), ['/Users/me/Downloads/Talk.tinglang']);
    expect(await shell.takeOpenedFiles(), isEmpty);
  });

  test('iCloud Drive states map by path; unknown names read as local files', () async {
    late List<Object?> asked;
    reply('cloudItemStates', (args) {
      asked = args!.single! as List<Object?>;
      return ['current', 'notDownloaded', 'outdated', 'missing', 'fromTheFuture'];
    });
    final drive = MacCloudDrive(TinglangHostApi());
    final states = await drive.itemStates(['/a', '/b', '/c', '/d', '/e']);
    expect(asked, ['/a', '/b', '/c', '/d', '/e']);
    expect(states, {
      '/a': CloudItemState.current,
      '/b': CloudItemState.notDownloaded,
      '/c': CloudItemState.outdated,
      '/d': CloudItemState.missing,
      '/e': CloudItemState.local,
    });
    // Nothing to ask: no call at all.
    expect(await drive.itemStates(const []), isEmpty);
  });

  test('downloads are requested by their real paths', () async {
    late List<Object?> asked;
    reply('cloudDownload', (args) {
      asked = args!.single! as List<Object?>;
      return null;
    });
    await MacCloudDrive(TinglangHostApi()).download(['/x/devices/a/state.json']);
    expect(asked, ['/x/devices/a/state.json']);
  });
}

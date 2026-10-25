import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang_native_macos/tinglang_native_macos.dart';
import 'package:tinglang_native_macos/src/host_api.g.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = 'dev.flutter.pigeon.tinglang_native_macos.TinglangHostApi.authenticate';
  const codec = StandardMessageCodec();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMessageHandler(channel, null));

  void reply(List<Object?> Function(List<Object?> args) answer) =>
      messenger.setMockMessageHandler(channel, (message) async {
        final args = codec.decodeMessage(message)! as List<Object?>;
        return codec.encodeMessage(answer(args));
      });

  test('the callback URL comes back as a Uri', () async {
    late List<Object?> sent;
    reply((args) {
      sent = args;
      return ['tinglang://oauth/callback?code=c&state=s'];
    });
    final result = await MacWebAuthenticator(
      TinglangHostApi(),
    ).authenticate(Uri.parse('https://id.example.com/authorize?x=1'), callbackScheme: 'tinglang');
    expect(sent, ['https://id.example.com/authorize?x=1', 'tinglang']);
    expect(result.queryParameters['code'], 'c');
  });

  test('closing the window is a cancellation, other failures stay errors', () async {
    reply((_) => ['canceled', 'The sign-in window was closed', null]);
    await expectLater(
      MacWebAuthenticator(TinglangHostApi())
          .authenticate(Uri.parse('https://id.example.com'), callbackScheme: 'tinglang'),
      throwsA(isA<WebAuthCanceled>()),
    );
    reply((_) => ['failed', 'Sign-in failed', null]);
    await expectLater(
      MacWebAuthenticator(TinglangHostApi())
          .authenticate(Uri.parse('https://id.example.com'), callbackScheme: 'tinglang'),
      throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'failed')),
    );
  });
}

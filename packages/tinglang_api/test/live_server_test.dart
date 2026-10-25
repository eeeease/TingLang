// Talks to the official server, so it runs only when asked:
//
//   TINGLANG_LIVE_API=1 dart test test/live_server_test.dart
//
// It sends no credentials and changes nothing on the server.
import 'dart:io';

import 'package:test/test.dart';
import 'package:tinglang_api/tinglang_api.dart';

void main() {
  final live = Platform.environment['TINGLANG_LIVE_API'] == '1';
  final server = ServerUrl.parse(
    Platform.environment['TINGLANG_SERVER'] ?? 'https://api.tinglang.app',
  );

  test('the official /v1/meta reads with the contract and sign-in can start from it', () async {
    final meta = await TinglangApi(server).getMeta();
    expect(meta.requiresNewerClient('macos', '0.6.0'), isFalse);
    expect(meta.features.accounts, isTrue);
    expect(meta.features.entitlements, isTrue);
    final auth = meta.auth!;
    expect(auth.authorizationEndpoint.scheme, 'https');
    expect(auth.tokenEndpoint.scheme, 'https');
    expect(auth.revocationEndpoint?.scheme, 'https');
    expect(auth.clientId, isNotEmpty);
    expect(auth.redirectUri.toString(), 'tinglang://oauth/callback');
    // The browser page the app would open (PKCE S256, exact redirect).
    final url = authorizationUrl(auth, Pkce.generate(), 'state-for-test');
    expect(url.queryParameters['code_challenge_method'], 'S256');
    expect(url.queryParameters['redirect_uri'], 'tinglang://oauth/callback');
    expect(meta.web?.pricingUrl?.host, 'tinglang.app');
    expect(meta.web?.accountUrl?.host, 'tinglang.app');
    // Unknown fields would be kept; what the app reads writes back the same.
    expect(ApiMeta.fromJson(meta.toJson()).toJson(), meta.toJson());
  }, skip: live ? false : 'set TINGLANG_LIVE_API=1 to talk to the official server');

  test('without a token the account is refused with the contract problem', () async {
    await expectLater(
      TinglangApi(server, tokens: _NoToken()).getAccount(),
      throwsA(isA<ApiProblemException>().having((e) => e.code, 'code', ProblemCode.unauthorized)),
    );
  }, skip: live ? false : 'set TINGLANG_LIVE_API=1 to talk to the official server');
}

/// A token the server cannot know.
final class _NoToken implements TokenSource {
  @override
  Future<String> accessToken({bool force = false}) async => 'not-a-token';
}

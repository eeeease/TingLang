import 'errors.dart';

/// The origin of a Tinglang server, e.g. `https://api.example.com`. Only
/// https is accepted, except for this machine (`localhost`, `127.0.0.1`,
/// `[::1]`) during development.
class ServerUrl {
  ServerUrl._(this.origin);

  /// Accepts what a user would type; a trailing `/` or `/v1` is dropped.
  factory ServerUrl.parse(String input) {
    var text = input.trim();
    if (text.isEmpty) throw const ServerUrlException('Enter a server address');
    if (!text.contains('://')) text = 'https://$text';
    final Uri uri;
    try {
      uri = Uri.parse(text);
    } on FormatException {
      throw const ServerUrlException('Not a valid address');
    }
    if (uri.host.isEmpty) throw const ServerUrlException('Not a valid address');
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      throw const ServerUrlException('Use the server address only');
    }
    final local = isLoopback(uri.host);
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && local)) {
      throw const ServerUrlException('The address must start with https://');
    }
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.endsWith('/v1')) path = path.substring(0, path.length - 3);
    return ServerUrl._(uri.replace(path: path));
  }

  final Uri origin;
  String get host => origin.host;

  /// `{origin}/v1{path}` with optional query parameters.
  Uri api(String path, [Map<String, String>? query]) => origin.replace(
    path: '${origin.path}/v1$path',
    queryParameters: query == null || query.isEmpty ? null : query,
  );

  static bool isLoopback(String host) =>
      host == 'localhost' || host == '127.0.0.1' || host == '::1' || host == '[::1]';

  /// Endpoints from the server's metadata follow the same rule.
  static void checkSecure(Uri uri) {
    if (uri.scheme == 'https') return;
    if (uri.scheme == 'http' && isLoopback(uri.host)) return;
    throw const ServerUrlException('The server announced an insecure address');
  }

  @override
  String toString() => origin.toString();
  @override
  bool operator ==(Object other) => other is ServerUrl && other.origin == origin;
  @override
  int get hashCode => origin.hashCode;
}

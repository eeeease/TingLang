/// Client for the Tinglang Cloud API described in `api/openapi.yaml`.
///
/// Nothing here talks to a server until a method is called; the app decides
/// when (only after the user signs in or turns a cloud feature on).
library;

export 'src/auth.dart';
export 'src/client.dart';
export 'src/errors.dart';
export 'src/models.dart';
export 'src/server_url.dart';

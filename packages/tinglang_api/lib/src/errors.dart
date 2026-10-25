import 'models.dart';

/// Every failure this package reports. Messages never contain tokens, codes
/// or request bodies.
sealed class ApiFailure implements Exception {
  const ApiFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The server answered with a problem (RFC 9457).
class ApiProblemException extends ApiFailure {
  ApiProblemException(this.problem, {this.retryAfter})
    : super(
        '${problem.status} ${problem.code}${problem.title == null ? '' : ': ${problem.title}'}',
      );
  final ApiProblem problem;

  /// From the Retry-After header (429, 503).
  final Duration? retryAfter;
  ProblemCode get code => problem.knownCode;
}

/// The server could not be reached: DNS, connection, TLS or a timeout.
class ApiUnreachable extends ApiFailure {
  const ApiUnreachable(super.message);
}

/// The server answered, but not with something this contract describes.
class ApiBadResponse extends ApiFailure {
  const ApiBadResponse(super.message, {this.status});
  final int? status;
}

/// A server address the client refuses (not https, or not a plain origin).
class ServerUrlException extends ApiFailure {
  const ServerUrlException(super.message);
}

/// Signing in or refreshing failed.
class AuthFailure extends ApiFailure {
  const AuthFailure(super.message, {this.reason = AuthFailureReason.other});
  final AuthFailureReason reason;
}

enum AuthFailureReason {
  /// The user closed the sign-in window or declined.
  canceled,

  /// The callback did not belong to this sign-in (state or address mismatch).
  mismatch,

  /// The refresh token or code is no longer valid; sign in again.
  invalidGrant,

  /// No refresh token is stored.
  signedOut,
  other,
}

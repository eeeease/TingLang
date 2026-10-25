import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tinglang_api/tinglang_api.dart';

typedef _RoundTrip = Map<String, Object?> Function(Object? json);

/// Success bodies, by operation. Error bodies are always [ApiProblem].
final Map<String, _RoundTrip> _responses = {
  'getMeta': (j) => ApiMeta.fromJson(j).toJson(),
  'getAccount': (j) => Account.fromJson(j).toJson(),
  'getEntitlements': (j) => Entitlements.fromJson(j).toJson(),
  'estimateJob': (j) => JobEstimate.fromJson(j).toJson(),
  'createJob': (j) => Job.fromJson(j).toJson(),
  'listJobs': (j) => JobPage.fromJson(j).toJson(),
  'getJob': (j) => Job.fromJson(j).toJson(),
  'startJob': (j) => Job.fromJson(j).toJson(),
  'getJobResult': (j) => JobResult.fromJson(j).toJson(),
  'cancelJob': (j) => Job.fromJson(j).toJson(),
};

final Map<String, _RoundTrip> _requests = {
  'estimateJob': (j) => JobEstimateRequest.fromJson(j).toJson(),
  'createJob': (j) => JobCreateRequest.fromJson(j).toJson(),
};

/// OpenAI-compatible bodies go through the app's existing LLM client, and the
/// revocation form is built by [OAuthClient.revoke] (see auth_test.dart).
const _elsewhere = {'listLlmModels', 'createLlmChatCompletion', 'revokeToken'};

Map<String, Object?> _read(File f) => jsonDecode(f.readAsStringSync()) as Map<String, Object?>;

void main() {
  final examples = Directory('../../api/examples');
  final files = examples.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('every example belongs to a covered operation', () {
    expect(files, isNotEmpty);
    for (final f in files) {
      final op = f.parent.uri.pathSegments.where((s) => s.isNotEmpty).last;
      expect(
        _responses.containsKey(op) || _elsewhere.contains(op),
        isTrue,
        reason: 'no round trip for ${f.path}',
      );
    }
  });

  for (final f in files) {
    final op = f.parent.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final name = f.uri.pathSegments.last;
    if (_elsewhere.contains(op)) continue;
    test('$op/$name parses and writes back unchanged', () {
      final json = _read(f);
      final status = RegExp(r'^response\.(\d{3})').firstMatch(name)?[1];
      final _RoundTrip roundTrip;
      if (name == 'request.json') {
        roundTrip = _requests[op]!;
      } else if (int.parse(status!) >= 400) {
        roundTrip = (j) => ApiProblem.fromJson(j).toJson();
      } else {
        roundTrip = _responses[op]!;
      }
      expect(roundTrip(json), equals(json));
    });
  }

  group('reading is lenient where the contract says so', () {
    test('unknown fields are ignored and unknown values stay unknown', () {
      final job = _read(File('../../api/examples/getJob/response.200.json'))
        ..['status'] = 'paused_for_review'
        ..['kind'] = 'summarize'
        ..['shiny_new_field'] = {'x': 1};
      final parsed = Job.fromJson(job);
      expect(parsed.knownStatus, JobStatus.unknown);
      expect(parsed.knownStatus.finished, isFalse);
      expect(parsed.knownKind, JobKind.unknown);

      final problem = ApiProblem.fromJson({'status': 418, 'code': 'teapot'});
      expect(problem.knownCode, ProblemCode.unknown);
      expect(ProblemCode.parse('idempotency_key_reused'), ProblemCode.idempotencyKeyReused);

      final ent = _read(File('../../api/examples/getEntitlements/response.200.json'))
        ..['status'] = 'on_hold';
      expect(Entitlements.fromJson(ent).knownStatus, EntitlementStatus.unknown);
    });

    test('features that are missing, unknown or not true are off', () {
      final meta = ApiMeta.fromJson(_read(File('../../api/examples/getMeta/response.200.json')));
      expect(meta.features.accounts, isTrue);
      expect(meta.features.job(JobKind.transcribe), isTrue);
      expect(meta.features.job(JobKind.course), isFalse);
      expect(meta.features.isOn('teleport'), isFalse);
      final minimal = ApiMeta.fromJson(
        _read(File('../../api/examples/getMeta/response.200.minimal.json')),
      );
      expect(minimal.auth, isNull);
      expect(minimal.features.accounts, isFalse);
      expect(
        CloudFeatures(const {'accounts': 'yes', 'jobs': true}).isOn('jobs.transcribe'),
        isFalse,
      );
    });

    test('a too-old client is told so per platform', () {
      final meta = ApiMeta.fromJson(_read(File('../../api/examples/getMeta/response.200.json')));
      expect(meta.requiresNewerClient('macos', '0.3.0'), isTrue);
      expect(meta.requiresNewerClient('macos', '0.4.0'), isFalse);
      expect(meta.requiresNewerClient('macos', '0.10.1+3'), isFalse);
      expect(meta.requiresNewerClient('windows', '0.1.0'), isFalse);
    });

    test('required fields and RFC 3339 times are enforced', () {
      expect(() => Account.fromJson({'id': 'a'}), throwsA(isA<ApiBadResponse>()));
      expect(
        () => Account.fromJson({'id': 'a', 'created_at': '2026-10-01T09:30:00'}),
        throwsA(isA<ApiBadResponse>()),
        reason: 'a time without a zone is ambiguous',
      );
      expect(() => JobResult.fromJson({'kind': 'transcribe'}), throwsA(isA<ApiBadResponse>()));
      expect(rfc3339(DateTime.utc(2026, 10, 23, 8, 0, 0, 250)), '2026-10-23T08:00:00.250Z');
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/api_contract.dart';

T _copy<T>(T value) => jsonDecode(jsonEncode(value)) as T;

void main() {
  late ApiContract base;
  setUpAll(() => base = ApiContract.load(Directory('../../api')));

  ApiContract variant({
    void Function(Map<String, Object?> doc)? document,
    void Function(Map<String, Map<String, Object?>> schemas)? schemas,
    void Function(Map<String, Object?> examples)? examples,
  }) {
    final doc = _copy(base.document);
    final s = {for (final e in base.schemas.entries) e.key: _copy(e.value)};
    final x = {for (final e in base.examples.entries) e.key: _copy(e.value)};
    document?.call(doc);
    schemas?.call(s);
    examples?.call(x);
    return ApiContract(
      document: doc,
      schemas: s,
      examples: x,
      openApiSchema: jsonDecode(
        File('tool/oas-3.1-schema-2022-10-07.json').readAsStringSync(),
      ) as Map<String, Object?>,
    );
  }

  Map<String, Object?> op(Map<String, Object?> doc, String path, String method) =>
      ((doc['paths']! as Map<String, Object?>)[path]! as Map<String, Object?>)[method]!
          as Map<String, Object?>;

  test('the contract in api/ is consistent', () {
    expect(base.check(), isEmpty);
    expect(base.operations, hasLength(13));
  });

  test('a document OpenAPI 3.1 rejects is reported', () {
    for (final change in <void Function(Map<String, Object?>)>[
      (d) => d.remove('info'),
      (d) => op(d, '/meta', 'get')['summery'] = 'a typo',
    ]) {
      expect(
        variant(document: change).check(),
        contains(startsWith('openapi.yaml does not match OpenAPI 3.1')),
      );
    }
  });

  test('every operation declares a success response', () {
    final problems = variant(document: (d) => op(d, '/meta', 'get').remove('responses')).check();
    expect(problems, contains('getMeta: no 2xx response'));
  });

  test('dangling references, reused ids and undeclared path parameters are reported', () {
    final problems = variant(
      document: (d) {
        op(d, '/account', 'get')['responses'] = {
          '200': {r'$ref': '#/components/responses/Nope'},
        };
        op(d, '/entitlements', 'get')['operationId'] = 'getMeta';
        final job =
            (d['paths']! as Map<String, Object?>)['/jobs/{job_id}']! as Map<String, Object?>;
        job.remove('parameters');
      },
    ).check();
    expect(problems, contains(contains(r'$ref #/components/responses/Nope does not resolve')));
    expect(problems, contains('getMeta: operationId used twice'));
    expect(problems, contains('getJob: path parameter {job_id} is not declared'));
  });

  test('an example that breaks its schema is reported with its path', () {
    final problems = variant(
      examples: (x) {
        (x['getMeta/response.200.json']! as Map<String, Object?>)['api_version'] = 'one';
        (x['getAccount/response.200.json']! as Map<String, Object?>)['created_at'] = 'yesterday';
      },
    ).check();
    expect(problems, contains(startsWith('examples/getMeta/response.200.json:')));
    expect(problems, contains(startsWith('examples/getAccount/response.200.json:')));
  });

  test('missing, stray and undeclared examples are reported', () {
    final problems = variant(
      examples: (x) {
        x.remove('getAccount/response.200.json');
        x.remove('createJob/request.json');
        x['nope/response.200.json'] = <String, Object?>{};
        x['getMeta/response.418.json'] = <String, Object?>{};
        x['getMeta/sample.json'] = <String, Object?>{};
      },
    ).check();
    expect(problems, contains('examples/getAccount: missing a success response example'));
    expect(problems, contains('examples/createJob: missing request.json'));
    expect(problems, contains('examples/nope: no operation with this id'));
    expect(
      problems,
      contains('examples/getMeta/response.418.json: getMeta declares no 418 response'),
    );
    expect(problems, contains(startsWith('examples/getMeta/sample.json: name it')));
  });

  test('problem examples must use a known code and their own status', () {
    final problems = variant(
      examples: (x) {
        final p = x['getAccount/response.401.json']! as Map<String, Object?>;
        p['code'] = 'made_up';
        p['status'] = 403;
      },
    ).check();
    expect(problems, contains(contains('code made_up is not in x-problem-codes')));
    expect(problems, contains(contains('status 403 differs from 401')));
  });

  test('a schema that does not compile is reported', () {
    final problems = variant(schemas: (s) => s['quota.json']!['type'] = 7).check();
    expect(problems, contains(startsWith('schemas/quota.json: does not compile')));
  });
}

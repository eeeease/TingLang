import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';
import 'package:yaml/yaml.dart';

/// Checks the contract in `api/`:
///
/// - `openapi.yaml` against the official OpenAPI 3.1 schema (vendored next to
///   this file), plus what that schema cannot see: unique operation ids,
///   resolvable `$ref`s, declared path parameters;
/// - every JSON Schema in `schemas/` compiles as draft 2020-12;
/// - every operation has examples, and every example validates (formats
///   included) against the schema of its request or response.
class ApiContract {
  ApiContract({
    required this.document,
    required this.schemas,
    required this.examples,
    required Map<String, Object?> openApiSchema,
  }) : _oas = _loadOas(openApiSchema);

  /// Reads [api] (the repository's `api/` folder).
  factory ApiContract.load(Directory api) {
    final schemas = <String, Map<String, Object?>>{};
    for (final f in Directory('${api.path}/schemas').listSync().whereType<File>()) {
      if (f.path.endsWith('.json')) schemas[_name(f)] = _json(f);
    }
    final examples = <String, Object?>{};
    final root = Directory('${api.path}/examples');
    for (final f in root.listSync(recursive: true).whereType<File>()) {
      final rel = f.path.substring(root.path.length + 1);
      examples[rel] = rel.endsWith('.json') ? _json(f) : f.readAsStringSync();
    }
    return ApiContract(
      document:
          plain(loadYaml(File('${api.path}/openapi.yaml').readAsStringSync()))!
              as Map<String, Object?>,
      schemas: schemas,
      examples: examples,
      openApiSchema: _json(File('${_toolDir()}/oas-3.1-schema-2022-10-07.json')),
    );
  }

  final Map<String, Object?> document;

  /// File name (`job.json`) → schema.
  final Map<String, Map<String, Object?>> schemas;

  /// Path under `examples/` (`getJob/response.200.json`) → decoded JSON.
  final Map<String, Object?> examples;
  final JsonSchema _oas;

  static const _methods = ['get', 'put', 'post', 'delete', 'patch', 'head', 'options', 'trace'];
  static final _exampleName = RegExp(r'^(request|response\.(\d{3})(?:\.[a-z0-9-]+)?)\.json$');

  /// Every operation: `operationId` → its method, path and definition.
  Map<String, ({String method, String path, Map<String, Object?> op})> get operations {
    final out = <String, ({String method, String path, Map<String, Object?> op})>{};
    final paths = document['paths'];
    if (paths is! Map<String, Object?>) return out;
    for (final p in paths.entries) {
      final item = p.value;
      if (item is! Map<String, Object?>) continue;
      for (final m in _methods) {
        final op = item[m];
        if (op is Map<String, Object?> && op['operationId'] is String) {
          out[op['operationId']! as String] = (method: m.toUpperCase(), path: p.key, op: op);
        }
      }
    }
    return out;
  }

  /// All problems found; empty when the contract is consistent.
  List<String> check() {
    final problems = <String>[];
    final result = _oas.validate(document);
    for (final e in result.errors) {
      problems.add('openapi.yaml does not match OpenAPI 3.1: $e');
    }
    _checkRefs(document, '#', problems);
    _checkOperations(problems);
    final compiled = _compileSchemas(problems);
    _checkExamples(compiled, problems);
    return problems;
  }

  void _checkRefs(Object? node, String at, List<String> problems) {
    if (node is Map<String, Object?>) {
      final ref = node[r'$ref'];
      if (ref is String) {
        if (ref.startsWith('#')) {
          if (pointer(document, ref) == null) problems.add('$at: \$ref $ref does not resolve');
        } else {
          final file = ref.startsWith('./schemas/') ? ref.substring('./schemas/'.length) : null;
          if (file == null || !schemas.containsKey(file)) {
            problems.add('$at: \$ref $ref is not a file in api/schemas');
          }
        }
      }
      for (final e in node.entries) {
        _checkRefs(e.value, '$at/${e.key}', problems);
      }
    } else if (node is List<Object?>) {
      for (var i = 0; i < node.length; i++) {
        _checkRefs(node[i], '$at/$i', problems);
      }
    }
  }

  void _checkOperations(List<String> problems) {
    final seen = <String>{};
    final paths = document['paths'] as Map<String, Object?>? ?? const {};
    for (final p in paths.entries) {
      final item = p.value as Map<String, Object?>;
      final templated = RegExp(r'\{([^}]+)\}').allMatches(p.key).map((m) => m[1]!).toSet();
      for (final m in _methods) {
        final op = item[m];
        if (op is! Map<String, Object?>) continue;
        final id = op['operationId'];
        if (id is! String) {
          problems.add('${m.toUpperCase()} ${p.key}: no operationId');
          continue;
        }
        if (!seen.add(id)) problems.add('$id: operationId used twice');
        final responses = op['responses'];
        if (responses is! Map<String, Object?> || !responses.keys.any((k) => k.startsWith('2'))) {
          problems.add('$id: no 2xx response');
        }
        final declared = <String>{
          for (final param in [
            ...(item['parameters'] as List<Object?>? ?? const []),
            ...(op['parameters'] as List<Object?>? ?? const []),
          ])
            if (_deref(param) case {'in': 'path', 'name': final String name}) name,
        };
        for (final name in templated.difference(declared)) {
          problems.add('$id: path parameter {$name} is not declared');
        }
      }
    }
  }

  Map<String, JsonSchema> _compileSchemas(List<String> problems) {
    final provider = RefProvider.sync((String ref) {
      final name = Uri.parse(ref).pathSegments.last;
      final schema = schemas[name];
      return schema == null ? null : _withId(name, schema);
    });
    final out = <String, JsonSchema>{};
    for (final e in schemas.entries) {
      if (e.value[r'$schema'] != 'https://json-schema.org/draft/2020-12/schema') {
        problems.add('schemas/${e.key}: \$schema must be draft 2020-12');
      }
      try {
        out[e.key] = JsonSchema.create(
          _withId(e.key, e.value),
          schemaVersion: SchemaVersion.draft2020_12,
          refProvider: provider,
        );
      } on Object catch (error) {
        problems.add('schemas/${e.key}: does not compile: $error');
      }
    }
    return out;
  }

  void _checkExamples(Map<String, JsonSchema> compiled, List<String> problems) {
    final ops = operations;
    final codes = (document['x-problem-codes'] as Map<String, Object?>? ?? const {}).keys.toSet();
    final byOp = <String, List<String>>{};
    for (final path in examples.keys) {
      final slash = path.indexOf('/');
      if (slash < 0) {
        problems.add('examples/$path: put examples in a folder named after the operationId');
        continue;
      }
      byOp.putIfAbsent(path.substring(0, slash), () => []).add(path.substring(slash + 1));
    }
    for (final op in byOp.keys) {
      if (!ops.containsKey(op)) problems.add('examples/$op: no operation with this id');
    }
    for (final entry in ops.entries) {
      final id = entry.key;
      final op = entry.value.op;
      final files = byOp[id] ?? const <String>[];
      for (final f in files) {
        if (!_exampleName.hasMatch(f)) {
          problems.add(
            'examples/$id/$f: name it request.json or response.<status>[.<variant>].json',
          );
        }
      }
      // Request body.
      final body = _deref(op['requestBody']);
      if (body is Map<String, Object?>) {
        final media = _media(body);
        if (!files.contains('request.json')) {
          problems.add('examples/$id: missing request.json');
        } else if (media != null) {
          final example = examples['$id/request.json'];
          if (media.type == 'application/x-www-form-urlencoded' &&
              (example is! Map<String, Object?> || example.values.any((v) => v is! String))) {
            problems.add('examples/$id/request.json: a form body must be an object of strings');
          }
          _validate(compiled, media.schema, example, 'examples/$id/request.json', problems);
        } else {
          problems.add('$id: request body schema must be a \$ref to api/schemas');
        }
      } else if (files.contains('request.json')) {
        problems.add('examples/$id/request.json: the operation takes no body');
      }
      // Responses.
      final responses = op['responses'] as Map<String, Object?>? ?? const {};
      var successExample = false, successBody = false;
      for (final f in files) {
        final m = _exampleName.firstMatch(f);
        final status = m?[2];
        if (status == null) continue;
        final response = _deref(responses[status]);
        if (response is! Map<String, Object?>) {
          problems.add('examples/$id/$f: $id declares no $status response');
          continue;
        }
        final media = _media(response);
        if (media == null) {
          problems.add('examples/$id/$f: the $status response has no JSON body');
          continue;
        }
        final example = examples['$id/$f'];
        _validate(compiled, media.schema, example, 'examples/$id/$f', problems);
        if (status.startsWith('2')) successExample = true;
        if (media.schema == 'problem.json' && example is Map<String, Object?>) {
          if (example['status'] != int.parse(status)) {
            problems.add('examples/$id/$f: status ${example['status']} differs from $status');
          }
          if (!codes.contains(example['code'])) {
            problems.add('examples/$id/$f: code ${example['code']} is not in x-problem-codes');
          }
        }
      }
      for (final r in responses.entries) {
        if (r.key.startsWith('2') && _media(_deref(r.value)) != null) successBody = true;
      }
      if (successBody && !successExample) {
        problems.add('examples/$id: missing a success response example');
      }
    }
  }

  void _validate(
    Map<String, JsonSchema> compiled,
    String schemaFile,
    Object? instance,
    String where,
    List<String> problems,
  ) {
    final schema = compiled[schemaFile];
    if (schema == null) return; // Reported by _compileSchemas or _checkRefs.
    final result = schema.validate(instance, validateFormats: true);
    for (final e in result.errors) {
      problems.add('$where: $e');
    }
  }

  /// The JSON media type of a request body or response, and its schema file.
  ({String type, String schema})? _media(Object? holder) {
    if (holder is! Map<String, Object?>) return null;
    final content = holder['content'];
    if (content is! Map<String, Object?>) return null;
    for (final type in [
      'application/json',
      'application/problem+json',
      'application/x-www-form-urlencoded',
    ]) {
      final media = content[type];
      if (media is Map<String, Object?>) {
        final ref = (media['schema'] as Map<String, Object?>?)?[r'$ref'];
        if (ref is String && ref.startsWith('./schemas/')) {
          return (type: type, schema: ref.substring('./schemas/'.length));
        }
      }
    }
    return null;
  }

  Object? _deref(Object? node) {
    var current = node;
    for (var i = 0; i < 8 && current is Map<String, Object?>; i++) {
      final ref = current[r'$ref'];
      if (ref is! String || !ref.startsWith('#')) break;
      current = pointer(document, ref);
    }
    return current;
  }

  /// Resolves a local JSON pointer (`#/components/responses/NotFound`).
  static Object? pointer(Map<String, Object?> root, String ref) {
    Object? node = root;
    for (final raw in ref.substring(1).split('/').skip(1)) {
      final key = raw.replaceAll('~1', '/').replaceAll('~0', '~');
      final index = int.tryParse(key);
      if (node is Map<String, Object?> && node.containsKey(key)) {
        node = node[key];
      } else if (node is List<Object?> && index != null && index >= 0 && index < node.length) {
        node = node[index];
      } else {
        return null;
      }
    }
    return node;
  }

  /// Relative `$ref`s between schema files need a base URI; the files carry
  /// none, so each gets one from its name while being checked.
  static Map<String, Object?> _withId(String name, Map<String, Object?> schema) => {
    ...schema,
    r'$id': 'file:///api/schemas/$name',
  };

  /// The vendored OpenAPI 3.1 schema nests `$defs` inside `dependentSchemas`
  /// (parameter and header styles), which package:json_schema cannot address.
  /// Those definitions move to the top-level `$defs`; nothing else changes.
  static JsonSchema _loadOas(Map<String, Object?> schema) {
    final copy = jsonDecode(jsonEncode(schema)) as Map<String, Object?>;
    final defs = copy[r'$defs'] as Map<String, Object?>;
    for (final owner in ['parameter', 'header']) {
      final dependent = (defs[owner] as Map<String, Object?>)['dependentSchemas'];
      final nested = ((dependent as Map<String, Object?>)['schema'] as Map<String, Object?>).remove(
        r'$defs',
      );
      if (nested is Map<String, Object?>) {
        for (final e in nested.entries) {
          defs['$owner--${e.key}'] = e.value;
        }
      }
    }
    final text = jsonEncode(copy).replaceAllMapped(
      RegExp(r'#/\$defs/(parameter|header)/dependentSchemas/schema/\$defs/([A-Za-z0-9_-]+)'),
      (m) => '#/\$defs/${m[1]}--${m[2]}',
    );
    return JsonSchema.create(jsonDecode(text) as Object, schemaVersion: SchemaVersion.draft2020_12);
  }

  static Object? plain(Object? value) => switch (value) {
    YamlMap() => {for (final e in value.entries) '${e.key}': plain(e.value)},
    YamlList() => [for (final v in value) plain(v)],
    _ => value,
  };

  static String _name(File f) => f.uri.pathSegments.last;
  static Map<String, Object?> _json(File f) =>
      jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
  static String _toolDir() {
    final script = Platform.script.toFilePath();
    // Under `dart test` the script is a generated runner; fall back to cwd.
    final dir = File(script).parent.path;
    return File('$dir/oas-3.1-schema-2022-10-07.json').existsSync() ? dir : 'tool';
  }
}

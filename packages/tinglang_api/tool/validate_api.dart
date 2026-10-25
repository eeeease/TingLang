// Checks the contract in api/ (spec, schemas, examples). Run from this
// package: dart run tool/validate_api.dart [path/to/api]
import 'dart:io';

import 'api_contract.dart';

void main(List<String> args) {
  final dir = Directory(args.isEmpty ? '../../api' : args.first);
  if (!dir.existsSync()) {
    stderr.writeln('No api/ folder at ${dir.path}');
    exit(2);
  }
  final contract = ApiContract.load(dir);
  final problems = contract.check();
  if (problems.isEmpty) {
    stdout.writeln(
      'api/ is consistent: ${contract.operations.length} operations, '
      '${contract.schemas.length} schemas, ${contract.examples.length} examples.',
    );
    return;
  }
  problems.forEach(stderr.writeln);
  stderr.writeln('${problems.length} problem(s) in api/.');
  exit(1);
}

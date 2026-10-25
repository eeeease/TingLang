/// 严格读取外部数据；格式异常要告诉用户，不能静默生成空课程。
Map<String, Object?> jsonObject(Object? value, String context) {
  if (value is Map<String, Object?>) return value;
  throw FormatException('$context must be a JSON object.');
}

List<Object?> jsonList(Object? value, String context) {
  if (value is List<Object?>) return value;
  throw FormatException('$context must be a JSON array.');
}

String jsonString(Object? value, String context, {String? fallback}) {
  if (value == null && fallback != null) return fallback;
  if (value is String) return value;
  throw FormatException('$context must be text.');
}

int jsonInt(Object? value, String context, {int? fallback}) {
  if (value == null && fallback != null) return fallback;
  if (value is int) return value;
  throw FormatException('$context must be an integer.');
}

String nonEmpty(Object? value, String context) {
  final text = jsonString(value, context).trim();
  if (text.isEmpty || text.length > 2000) {
    throw FormatException('$context must contain 1–2000 characters.');
  }
  return text;
}

/// 内部关联键不拼路径，避免课程 ID 中的 /、: 或 .. 发生冲突。
String entityKey(String courseId, String clipId) =>
    '${courseId.length}:$courseId${clipId.length}:$clipId';

/// Inverse of [entityKey]; returns null for keys not produced by it.
(String, String)? splitEntityKey(String key) {
  final first = RegExp(r'^(\d+):').firstMatch(key);
  if (first == null) return null;
  final courseLength = int.parse(first.group(1)!);
  final courseStart = first.end;
  if (courseStart + courseLength > key.length) return null;
  final rest = key.substring(courseStart + courseLength);
  final second = RegExp(r'^(\d+):').firstMatch(rest);
  if (second == null || rest.length - second.end != int.parse(second.group(1)!)) return null;
  return (key.substring(courseStart, courseStart + courseLength), rest.substring(second.end));
}

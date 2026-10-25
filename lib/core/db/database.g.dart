// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MediaTable extends Media with TableInfo<$MediaTable, MediaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relPathMeta = const VerificationMeta('relPath');
  @override
  late final GeneratedColumn<String> relPath = GeneratedColumn<String>(
    'rel_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta('sourceUrl');
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    relPath,
    sha256,
    durationMs,
    title,
    sourceUrl,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media';
  @override
  VerificationContext validateIntegrity(Insertable<MediaRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('rel_path')) {
      context.handle(_relPathMeta, relPath.isAcceptableOrUnknown(data['rel_path']!, _relPathMeta));
    }
    if (data.containsKey('sha256')) {
      context.handle(_sha256Meta, sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta));
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MediaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      relPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rel_path'],
      ),
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MediaTable createAlias(String alias) {
    return $MediaTable(attachedDatabase, alias);
  }
}

class MediaRow extends DataClass implements Insertable<MediaRow> {
  final String id;

  /// `audio` or `video`.
  final String kind;

  /// Relative to the library root; null for not-yet-downloaded remote media.
  final String? relPath;
  final String? sha256;
  final int? durationMs;
  final String title;
  final String? sourceUrl;
  final DateTime createdAt;
  const MediaRow({
    required this.id,
    required this.kind,
    this.relPath,
    this.sha256,
    this.durationMs,
    required this.title,
    this.sourceUrl,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || relPath != null) {
      map['rel_path'] = Variable<String>(relPath);
    }
    if (!nullToAbsent || sha256 != null) {
      map['sha256'] = Variable<String>(sha256);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MediaCompanion toCompanion(bool nullToAbsent) {
    return MediaCompanion(
      id: Value(id),
      kind: Value(kind),
      relPath: relPath == null && nullToAbsent ? const Value.absent() : Value(relPath),
      sha256: sha256 == null && nullToAbsent ? const Value.absent() : Value(sha256),
      durationMs: durationMs == null && nullToAbsent ? const Value.absent() : Value(durationMs),
      title: Value(title),
      sourceUrl: sourceUrl == null && nullToAbsent ? const Value.absent() : Value(sourceUrl),
      createdAt: Value(createdAt),
    );
  }

  factory MediaRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      relPath: serializer.fromJson<String?>(json['relPath']),
      sha256: serializer.fromJson<String?>(json['sha256']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      title: serializer.fromJson<String>(json['title']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'relPath': serializer.toJson<String?>(relPath),
      'sha256': serializer.toJson<String?>(sha256),
      'durationMs': serializer.toJson<int?>(durationMs),
      'title': serializer.toJson<String>(title),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MediaRow copyWith({
    String? id,
    String? kind,
    Value<String?> relPath = const Value.absent(),
    Value<String?> sha256 = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    String? title,
    Value<String?> sourceUrl = const Value.absent(),
    DateTime? createdAt,
  }) => MediaRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    relPath: relPath.present ? relPath.value : this.relPath,
    sha256: sha256.present ? sha256.value : this.sha256,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    title: title ?? this.title,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    createdAt: createdAt ?? this.createdAt,
  );
  MediaRow copyWithCompanion(MediaCompanion data) {
    return MediaRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      relPath: data.relPath.present ? data.relPath.value : this.relPath,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      durationMs: data.durationMs.present ? data.durationMs.value : this.durationMs,
      title: data.title.present ? data.title.value : this.title,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('relPath: $relPath, ')
          ..write('sha256: $sha256, ')
          ..write('durationMs: $durationMs, ')
          ..write('title: $title, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, kind, relPath, sha256, durationMs, title, sourceUrl, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.relPath == this.relPath &&
          other.sha256 == this.sha256 &&
          other.durationMs == this.durationMs &&
          other.title == this.title &&
          other.sourceUrl == this.sourceUrl &&
          other.createdAt == this.createdAt);
}

class MediaCompanion extends UpdateCompanion<MediaRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String?> relPath;
  final Value<String?> sha256;
  final Value<int?> durationMs;
  final Value<String> title;
  final Value<String?> sourceUrl;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MediaCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.relPath = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.title = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaCompanion.insert({
    required String id,
    required String kind,
    this.relPath = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.title = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       createdAt = Value(createdAt);
  static Insertable<MediaRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? relPath,
    Expression<String>? sha256,
    Expression<int>? durationMs,
    Expression<String>? title,
    Expression<String>? sourceUrl,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (relPath != null) 'rel_path': relPath,
      if (sha256 != null) 'sha256': sha256,
      if (durationMs != null) 'duration_ms': durationMs,
      if (title != null) 'title': title,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String?>? relPath,
    Value<String?>? sha256,
    Value<int?>? durationMs,
    Value<String>? title,
    Value<String?>? sourceUrl,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return MediaCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      relPath: relPath ?? this.relPath,
      sha256: sha256 ?? this.sha256,
      durationMs: durationMs ?? this.durationMs,
      title: title ?? this.title,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (relPath.present) {
      map['rel_path'] = Variable<String>(relPath.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('relPath: $relPath, ')
          ..write('sha256: $sha256, ')
          ..write('durationMs: $durationMs, ')
          ..write('title: $title, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions with TableInfo<$SessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaIdMeta = const VerificationMeta('mediaId');
  @override
  late final GeneratedColumn<String> mediaId = GeneratedColumn<String>(
    'media_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES media (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeBaseMeta = const VerificationMeta('timeBase');
  @override
  late final GeneratedColumn<String> timeBase = GeneratedColumn<String>(
    'time_base',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta('language');
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _sourceRefMeta = const VerificationMeta('sourceRef');
  @override
  late final GeneratedColumn<String> sourceRef = GeneratedColumn<String>(
    'source_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mediaId,
    origin,
    timeBase,
    language,
    title,
    startedAt,
    endedAt,
    status,
    sourceRef,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('media_id')) {
      context.handle(_mediaIdMeta, mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta));
    }
    if (data.containsKey('origin')) {
      context.handle(_originMeta, origin.isAcceptableOrUnknown(data['origin']!, _originMeta));
    } else if (isInserting) {
      context.missing(_originMeta);
    }
    if (data.containsKey('time_base')) {
      context.handle(
        _timeBaseMeta,
        timeBase.isAcceptableOrUnknown(data['time_base']!, _timeBaseMeta),
      );
    } else if (isInserting) {
      context.missing(_timeBaseMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta, endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta, status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('source_ref')) {
      context.handle(
        _sourceRefMeta,
        sourceRef.isAcceptableOrUnknown(data['source_ref']!, _sourceRefMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      mediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_id'],
      ),
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      timeBase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_base'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      sourceRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_ref'],
      ),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final String id;
  final String? mediaId;

  /// `live_system`, `live_mic`, `file`, `voice_memo`, `shared`, `recording`,
  /// `youtube`.
  final String origin;

  /// `media` (offsets into [mediaId]) or `wallclock` (from [startedAt]).
  final String timeBase;
  final String? language;
  final String title;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// `active`, `completed`, `interrupted` (set on next launch after a crash).
  final String status;

  /// What an import came from, so it is not imported twice: `voicememo:<id>`
  /// for Apple Voice Memos. Null for captures and plain files.
  final String? sourceRef;
  const SessionRow({
    required this.id,
    this.mediaId,
    required this.origin,
    required this.timeBase,
    this.language,
    required this.title,
    required this.startedAt,
    this.endedAt,
    required this.status,
    this.sourceRef,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || mediaId != null) {
      map['media_id'] = Variable<String>(mediaId);
    }
    map['origin'] = Variable<String>(origin);
    map['time_base'] = Variable<String>(timeBase);
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    map['title'] = Variable<String>(title);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || sourceRef != null) {
      map['source_ref'] = Variable<String>(sourceRef);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      mediaId: mediaId == null && nullToAbsent ? const Value.absent() : Value(mediaId),
      origin: Value(origin),
      timeBase: Value(timeBase),
      language: language == null && nullToAbsent ? const Value.absent() : Value(language),
      title: Value(title),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent ? const Value.absent() : Value(endedAt),
      status: Value(status),
      sourceRef: sourceRef == null && nullToAbsent ? const Value.absent() : Value(sourceRef),
    );
  }

  factory SessionRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<String>(json['id']),
      mediaId: serializer.fromJson<String?>(json['mediaId']),
      origin: serializer.fromJson<String>(json['origin']),
      timeBase: serializer.fromJson<String>(json['timeBase']),
      language: serializer.fromJson<String?>(json['language']),
      title: serializer.fromJson<String>(json['title']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      status: serializer.fromJson<String>(json['status']),
      sourceRef: serializer.fromJson<String?>(json['sourceRef']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mediaId': serializer.toJson<String?>(mediaId),
      'origin': serializer.toJson<String>(origin),
      'timeBase': serializer.toJson<String>(timeBase),
      'language': serializer.toJson<String?>(language),
      'title': serializer.toJson<String>(title),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'status': serializer.toJson<String>(status),
      'sourceRef': serializer.toJson<String?>(sourceRef),
    };
  }

  SessionRow copyWith({
    String? id,
    Value<String?> mediaId = const Value.absent(),
    String? origin,
    String? timeBase,
    Value<String?> language = const Value.absent(),
    String? title,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    String? status,
    Value<String?> sourceRef = const Value.absent(),
  }) => SessionRow(
    id: id ?? this.id,
    mediaId: mediaId.present ? mediaId.value : this.mediaId,
    origin: origin ?? this.origin,
    timeBase: timeBase ?? this.timeBase,
    language: language.present ? language.value : this.language,
    title: title ?? this.title,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    status: status ?? this.status,
    sourceRef: sourceRef.present ? sourceRef.value : this.sourceRef,
  );
  SessionRow copyWithCompanion(SessionsCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      origin: data.origin.present ? data.origin.value : this.origin,
      timeBase: data.timeBase.present ? data.timeBase.value : this.timeBase,
      language: data.language.present ? data.language.value : this.language,
      title: data.title.present ? data.title.value : this.title,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      status: data.status.present ? data.status.value : this.status,
      sourceRef: data.sourceRef.present ? data.sourceRef.value : this.sourceRef,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('mediaId: $mediaId, ')
          ..write('origin: $origin, ')
          ..write('timeBase: $timeBase, ')
          ..write('language: $language, ')
          ..write('title: $title, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('status: $status, ')
          ..write('sourceRef: $sourceRef')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mediaId,
    origin,
    timeBase,
    language,
    title,
    startedAt,
    endedAt,
    status,
    sourceRef,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.mediaId == this.mediaId &&
          other.origin == this.origin &&
          other.timeBase == this.timeBase &&
          other.language == this.language &&
          other.title == this.title &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.status == this.status &&
          other.sourceRef == this.sourceRef);
}

class SessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<String> id;
  final Value<String?> mediaId;
  final Value<String> origin;
  final Value<String> timeBase;
  final Value<String?> language;
  final Value<String> title;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<String> status;
  final Value<String?> sourceRef;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.origin = const Value.absent(),
    this.timeBase = const Value.absent(),
    this.language = const Value.absent(),
    this.title = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.sourceRef = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    this.mediaId = const Value.absent(),
    required String origin,
    required String timeBase,
    this.language = const Value.absent(),
    this.title = const Value.absent(),
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.sourceRef = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       origin = Value(origin),
       timeBase = Value(timeBase),
       startedAt = Value(startedAt);
  static Insertable<SessionRow> custom({
    Expression<String>? id,
    Expression<String>? mediaId,
    Expression<String>? origin,
    Expression<String>? timeBase,
    Expression<String>? language,
    Expression<String>? title,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<String>? status,
    Expression<String>? sourceRef,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mediaId != null) 'media_id': mediaId,
      if (origin != null) 'origin': origin,
      if (timeBase != null) 'time_base': timeBase,
      if (language != null) 'language': language,
      if (title != null) 'title': title,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (status != null) 'status': status,
      if (sourceRef != null) 'source_ref': sourceRef,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? mediaId,
    Value<String>? origin,
    Value<String>? timeBase,
    Value<String?>? language,
    Value<String>? title,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<String>? status,
    Value<String?>? sourceRef,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      origin: origin ?? this.origin,
      timeBase: timeBase ?? this.timeBase,
      language: language ?? this.language,
      title: title ?? this.title,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      sourceRef: sourceRef ?? this.sourceRef,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mediaId.present) {
      map['media_id'] = Variable<String>(mediaId.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (timeBase.present) {
      map['time_base'] = Variable<String>(timeBase.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (sourceRef.present) {
      map['source_ref'] = Variable<String>(sourceRef.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('mediaId: $mediaId, ')
          ..write('origin: $origin, ')
          ..write('timeBase: $timeBase, ')
          ..write('language: $language, ')
          ..write('title: $title, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('status: $status, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TimeAnchorsTable extends TimeAnchors with TableInfo<$TimeAnchorsTable, TimeAnchorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimeAnchorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES session (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sessionMsMeta = const VerificationMeta('sessionMs');
  @override
  late final GeneratedColumn<int> sessionMs = GeneratedColumn<int>(
    'session_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaMsMeta = const VerificationMeta('mediaMs');
  @override
  late final GeneratedColumn<int> mediaMs = GeneratedColumn<int>(
    'media_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wallclockMeta = const VerificationMeta('wallclock');
  @override
  late final GeneratedColumn<DateTime> wallclock = GeneratedColumn<DateTime>(
    'wallclock',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, sessionId, sessionMs, mediaMs, wallclock];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'time_anchor';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimeAnchorRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('session_ms')) {
      context.handle(
        _sessionMsMeta,
        sessionMs.isAcceptableOrUnknown(data['session_ms']!, _sessionMsMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionMsMeta);
    }
    if (data.containsKey('media_ms')) {
      context.handle(_mediaMsMeta, mediaMs.isAcceptableOrUnknown(data['media_ms']!, _mediaMsMeta));
    }
    if (data.containsKey('wallclock')) {
      context.handle(
        _wallclockMeta,
        wallclock.isAcceptableOrUnknown(data['wallclock']!, _wallclockMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TimeAnchorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimeAnchorRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      sessionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_ms'],
      )!,
      mediaMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_ms'],
      ),
      wallclock: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}wallclock'],
      ),
    );
  }

  @override
  $TimeAnchorsTable createAlias(String alias) {
    return $TimeAnchorsTable(attachedDatabase, alias);
  }
}

class TimeAnchorRow extends DataClass implements Insertable<TimeAnchorRow> {
  final int id;
  final String sessionId;
  final int sessionMs;
  final int? mediaMs;
  final DateTime? wallclock;
  const TimeAnchorRow({
    required this.id,
    required this.sessionId,
    required this.sessionMs,
    this.mediaMs,
    this.wallclock,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['session_ms'] = Variable<int>(sessionMs);
    if (!nullToAbsent || mediaMs != null) {
      map['media_ms'] = Variable<int>(mediaMs);
    }
    if (!nullToAbsent || wallclock != null) {
      map['wallclock'] = Variable<DateTime>(wallclock);
    }
    return map;
  }

  TimeAnchorsCompanion toCompanion(bool nullToAbsent) {
    return TimeAnchorsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      sessionMs: Value(sessionMs),
      mediaMs: mediaMs == null && nullToAbsent ? const Value.absent() : Value(mediaMs),
      wallclock: wallclock == null && nullToAbsent ? const Value.absent() : Value(wallclock),
    );
  }

  factory TimeAnchorRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimeAnchorRow(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      sessionMs: serializer.fromJson<int>(json['sessionMs']),
      mediaMs: serializer.fromJson<int?>(json['mediaMs']),
      wallclock: serializer.fromJson<DateTime?>(json['wallclock']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'sessionMs': serializer.toJson<int>(sessionMs),
      'mediaMs': serializer.toJson<int?>(mediaMs),
      'wallclock': serializer.toJson<DateTime?>(wallclock),
    };
  }

  TimeAnchorRow copyWith({
    int? id,
    String? sessionId,
    int? sessionMs,
    Value<int?> mediaMs = const Value.absent(),
    Value<DateTime?> wallclock = const Value.absent(),
  }) => TimeAnchorRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    sessionMs: sessionMs ?? this.sessionMs,
    mediaMs: mediaMs.present ? mediaMs.value : this.mediaMs,
    wallclock: wallclock.present ? wallclock.value : this.wallclock,
  );
  TimeAnchorRow copyWithCompanion(TimeAnchorsCompanion data) {
    return TimeAnchorRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      sessionMs: data.sessionMs.present ? data.sessionMs.value : this.sessionMs,
      mediaMs: data.mediaMs.present ? data.mediaMs.value : this.mediaMs,
      wallclock: data.wallclock.present ? data.wallclock.value : this.wallclock,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimeAnchorRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('sessionMs: $sessionMs, ')
          ..write('mediaMs: $mediaMs, ')
          ..write('wallclock: $wallclock')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, sessionMs, mediaMs, wallclock);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimeAnchorRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.sessionMs == this.sessionMs &&
          other.mediaMs == this.mediaMs &&
          other.wallclock == this.wallclock);
}

class TimeAnchorsCompanion extends UpdateCompanion<TimeAnchorRow> {
  final Value<int> id;
  final Value<String> sessionId;
  final Value<int> sessionMs;
  final Value<int?> mediaMs;
  final Value<DateTime?> wallclock;
  const TimeAnchorsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.sessionMs = const Value.absent(),
    this.mediaMs = const Value.absent(),
    this.wallclock = const Value.absent(),
  });
  TimeAnchorsCompanion.insert({
    this.id = const Value.absent(),
    required String sessionId,
    required int sessionMs,
    this.mediaMs = const Value.absent(),
    this.wallclock = const Value.absent(),
  }) : sessionId = Value(sessionId),
       sessionMs = Value(sessionMs);
  static Insertable<TimeAnchorRow> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<int>? sessionMs,
    Expression<int>? mediaMs,
    Expression<DateTime>? wallclock,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (sessionMs != null) 'session_ms': sessionMs,
      if (mediaMs != null) 'media_ms': mediaMs,
      if (wallclock != null) 'wallclock': wallclock,
    });
  }

  TimeAnchorsCompanion copyWith({
    Value<int>? id,
    Value<String>? sessionId,
    Value<int>? sessionMs,
    Value<int?>? mediaMs,
    Value<DateTime?>? wallclock,
  }) {
    return TimeAnchorsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      sessionMs: sessionMs ?? this.sessionMs,
      mediaMs: mediaMs ?? this.mediaMs,
      wallclock: wallclock ?? this.wallclock,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (sessionMs.present) {
      map['session_ms'] = Variable<int>(sessionMs.value);
    }
    if (mediaMs.present) {
      map['media_ms'] = Variable<int>(mediaMs.value);
    }
    if (wallclock.present) {
      map['wallclock'] = Variable<DateTime>(wallclock.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimeAnchorsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('sessionMs: $sessionMs, ')
          ..write('mediaMs: $mediaMs, ')
          ..write('wallclock: $wallclock')
          ..write(')'))
        .toString();
  }
}

class $SegmentsTable extends Segments with TableInfo<$SegmentsTable, SegmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES session (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta('startMs');
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta('language');
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wordsJsonMeta = const VerificationMeta('wordsJson');
  @override
  late final GeneratedColumn<String> wordsJson = GeneratedColumn<String>(
    'words_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    seq,
    startMs,
    endMs,
    body,
    language,
    wordsJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'segment';
  @override
  VerificationContext validateIntegrity(
    Insertable<SegmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(_seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(_startMsMeta, startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta));
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('end_ms')) {
      context.handle(_endMsMeta, endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta));
    } else if (isInserting) {
      context.missing(_endMsMeta);
    }
    if (data.containsKey('body')) {
      context.handle(_bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('words_json')) {
      context.handle(
        _wordsJsonMeta,
        wordsJson.isAcceptableOrUnknown(data['words_json']!, _wordsJsonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sessionId, seq},
  ];
  @override
  SegmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SegmentRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      )!,
      endMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}end_ms'])!,
      body: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      wordsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}words_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SegmentsTable createAlias(String alias) {
    return $SegmentsTable(attachedDatabase, alias);
  }
}

class SegmentRow extends DataClass implements Insertable<SegmentRow> {
  final String id;
  final String sessionId;
  final int seq;
  final int startMs;
  final int endMs;
  final String body;
  final String? language;

  /// `[{"w":"word","s":ms,"e":ms}]` only when the backend produced it.
  final String? wordsJson;
  final DateTime createdAt;
  const SegmentRow({
    required this.id,
    required this.sessionId,
    required this.seq,
    required this.startMs,
    required this.endMs,
    required this.body,
    this.language,
    this.wordsJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['seq'] = Variable<int>(seq);
    map['start_ms'] = Variable<int>(startMs);
    map['end_ms'] = Variable<int>(endMs);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    if (!nullToAbsent || wordsJson != null) {
      map['words_json'] = Variable<String>(wordsJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SegmentsCompanion toCompanion(bool nullToAbsent) {
    return SegmentsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      seq: Value(seq),
      startMs: Value(startMs),
      endMs: Value(endMs),
      body: Value(body),
      language: language == null && nullToAbsent ? const Value.absent() : Value(language),
      wordsJson: wordsJson == null && nullToAbsent ? const Value.absent() : Value(wordsJson),
      createdAt: Value(createdAt),
    );
  }

  factory SegmentRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SegmentRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      seq: serializer.fromJson<int>(json['seq']),
      startMs: serializer.fromJson<int>(json['startMs']),
      endMs: serializer.fromJson<int>(json['endMs']),
      body: serializer.fromJson<String>(json['body']),
      language: serializer.fromJson<String?>(json['language']),
      wordsJson: serializer.fromJson<String?>(json['wordsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'seq': serializer.toJson<int>(seq),
      'startMs': serializer.toJson<int>(startMs),
      'endMs': serializer.toJson<int>(endMs),
      'body': serializer.toJson<String>(body),
      'language': serializer.toJson<String?>(language),
      'wordsJson': serializer.toJson<String?>(wordsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SegmentRow copyWith({
    String? id,
    String? sessionId,
    int? seq,
    int? startMs,
    int? endMs,
    String? body,
    Value<String?> language = const Value.absent(),
    Value<String?> wordsJson = const Value.absent(),
    DateTime? createdAt,
  }) => SegmentRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    seq: seq ?? this.seq,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    body: body ?? this.body,
    language: language.present ? language.value : this.language,
    wordsJson: wordsJson.present ? wordsJson.value : this.wordsJson,
    createdAt: createdAt ?? this.createdAt,
  );
  SegmentRow copyWithCompanion(SegmentsCompanion data) {
    return SegmentRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      seq: data.seq.present ? data.seq.value : this.seq,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      body: data.body.present ? data.body.value : this.body,
      language: data.language.present ? data.language.value : this.language,
      wordsJson: data.wordsJson.present ? data.wordsJson.value : this.wordsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SegmentRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('seq: $seq, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('body: $body, ')
          ..write('language: $language, ')
          ..write('wordsJson: $wordsJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, seq, startMs, endMs, body, language, wordsJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SegmentRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.seq == this.seq &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.body == this.body &&
          other.language == this.language &&
          other.wordsJson == this.wordsJson &&
          other.createdAt == this.createdAt);
}

class SegmentsCompanion extends UpdateCompanion<SegmentRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<int> seq;
  final Value<int> startMs;
  final Value<int> endMs;
  final Value<String> body;
  final Value<String?> language;
  final Value<String?> wordsJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SegmentsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.seq = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.body = const Value.absent(),
    this.language = const Value.absent(),
    this.wordsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SegmentsCompanion.insert({
    required String id,
    required String sessionId,
    required int seq,
    required int startMs,
    required int endMs,
    required String body,
    this.language = const Value.absent(),
    this.wordsJson = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       seq = Value(seq),
       startMs = Value(startMs),
       endMs = Value(endMs),
       body = Value(body),
       createdAt = Value(createdAt);
  static Insertable<SegmentRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<int>? seq,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<String>? body,
    Expression<String>? language,
    Expression<String>? wordsJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (seq != null) 'seq': seq,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (body != null) 'body': body,
      if (language != null) 'language': language,
      if (wordsJson != null) 'words_json': wordsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SegmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<int>? seq,
    Value<int>? startMs,
    Value<int>? endMs,
    Value<String>? body,
    Value<String?>? language,
    Value<String?>? wordsJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SegmentsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      seq: seq ?? this.seq,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      body: body ?? this.body,
      language: language ?? this.language,
      wordsJson: wordsJson ?? this.wordsJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (wordsJson.present) {
      map['words_json'] = Variable<String>(wordsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SegmentsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('seq: $seq, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('body: $body, ')
          ..write('language: $language, ')
          ..write('wordsJson: $wordsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TranslationsTable extends Translations with TableInfo<$TranslationsTable, TranslationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranslationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _segmentIdMeta = const VerificationMeta('segmentId');
  @override
  late final GeneratedColumn<String> segmentId = GeneratedColumn<String>(
    'segment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES segment (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _targetLangMeta = const VerificationMeta('targetLang');
  @override
  late final GeneratedColumn<String> targetLang = GeneratedColumn<String>(
    'target_lang',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta('provider');
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qualityMeta = const VerificationMeta('quality');
  @override
  late final GeneratedColumn<String> quality = GeneratedColumn<String>(
    'quality',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    segmentId,
    targetLang,
    body,
    provider,
    quality,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'translation';
  @override
  VerificationContext validateIntegrity(
    Insertable<TranslationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('segment_id')) {
      context.handle(
        _segmentIdMeta,
        segmentId.isAcceptableOrUnknown(data['segment_id']!, _segmentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_segmentIdMeta);
    }
    if (data.containsKey('target_lang')) {
      context.handle(
        _targetLangMeta,
        targetLang.isAcceptableOrUnknown(data['target_lang']!, _targetLangMeta),
      );
    } else if (isInserting) {
      context.missing(_targetLangMeta);
    }
    if (data.containsKey('body')) {
      context.handle(_bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(_qualityMeta, quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta));
    } else if (isInserting) {
      context.missing(_qualityMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {segmentId, targetLang, quality},
  ];
  @override
  TranslationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranslationRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      segmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}segment_id'],
      )!,
      targetLang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_lang'],
      )!,
      body: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quality'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TranslationsTable createAlias(String alias) {
    return $TranslationsTable(attachedDatabase, alias);
  }
}

class TranslationRow extends DataClass implements Insertable<TranslationRow> {
  final int id;
  final String segmentId;
  final String targetLang;
  final String body;
  final String provider;

  /// `preview` (debounced partial context) or `final`.
  final String quality;
  final DateTime createdAt;
  const TranslationRow({
    required this.id,
    required this.segmentId,
    required this.targetLang,
    required this.body,
    required this.provider,
    required this.quality,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['segment_id'] = Variable<String>(segmentId);
    map['target_lang'] = Variable<String>(targetLang);
    map['body'] = Variable<String>(body);
    map['provider'] = Variable<String>(provider);
    map['quality'] = Variable<String>(quality);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TranslationsCompanion toCompanion(bool nullToAbsent) {
    return TranslationsCompanion(
      id: Value(id),
      segmentId: Value(segmentId),
      targetLang: Value(targetLang),
      body: Value(body),
      provider: Value(provider),
      quality: Value(quality),
      createdAt: Value(createdAt),
    );
  }

  factory TranslationRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranslationRow(
      id: serializer.fromJson<int>(json['id']),
      segmentId: serializer.fromJson<String>(json['segmentId']),
      targetLang: serializer.fromJson<String>(json['targetLang']),
      body: serializer.fromJson<String>(json['body']),
      provider: serializer.fromJson<String>(json['provider']),
      quality: serializer.fromJson<String>(json['quality']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'segmentId': serializer.toJson<String>(segmentId),
      'targetLang': serializer.toJson<String>(targetLang),
      'body': serializer.toJson<String>(body),
      'provider': serializer.toJson<String>(provider),
      'quality': serializer.toJson<String>(quality),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TranslationRow copyWith({
    int? id,
    String? segmentId,
    String? targetLang,
    String? body,
    String? provider,
    String? quality,
    DateTime? createdAt,
  }) => TranslationRow(
    id: id ?? this.id,
    segmentId: segmentId ?? this.segmentId,
    targetLang: targetLang ?? this.targetLang,
    body: body ?? this.body,
    provider: provider ?? this.provider,
    quality: quality ?? this.quality,
    createdAt: createdAt ?? this.createdAt,
  );
  TranslationRow copyWithCompanion(TranslationsCompanion data) {
    return TranslationRow(
      id: data.id.present ? data.id.value : this.id,
      segmentId: data.segmentId.present ? data.segmentId.value : this.segmentId,
      targetLang: data.targetLang.present ? data.targetLang.value : this.targetLang,
      body: data.body.present ? data.body.value : this.body,
      provider: data.provider.present ? data.provider.value : this.provider,
      quality: data.quality.present ? data.quality.value : this.quality,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranslationRow(')
          ..write('id: $id, ')
          ..write('segmentId: $segmentId, ')
          ..write('targetLang: $targetLang, ')
          ..write('body: $body, ')
          ..write('provider: $provider, ')
          ..write('quality: $quality, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, segmentId, targetLang, body, provider, quality, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranslationRow &&
          other.id == this.id &&
          other.segmentId == this.segmentId &&
          other.targetLang == this.targetLang &&
          other.body == this.body &&
          other.provider == this.provider &&
          other.quality == this.quality &&
          other.createdAt == this.createdAt);
}

class TranslationsCompanion extends UpdateCompanion<TranslationRow> {
  final Value<int> id;
  final Value<String> segmentId;
  final Value<String> targetLang;
  final Value<String> body;
  final Value<String> provider;
  final Value<String> quality;
  final Value<DateTime> createdAt;
  const TranslationsCompanion({
    this.id = const Value.absent(),
    this.segmentId = const Value.absent(),
    this.targetLang = const Value.absent(),
    this.body = const Value.absent(),
    this.provider = const Value.absent(),
    this.quality = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TranslationsCompanion.insert({
    this.id = const Value.absent(),
    required String segmentId,
    required String targetLang,
    required String body,
    required String provider,
    required String quality,
    required DateTime createdAt,
  }) : segmentId = Value(segmentId),
       targetLang = Value(targetLang),
       body = Value(body),
       provider = Value(provider),
       quality = Value(quality),
       createdAt = Value(createdAt);
  static Insertable<TranslationRow> custom({
    Expression<int>? id,
    Expression<String>? segmentId,
    Expression<String>? targetLang,
    Expression<String>? body,
    Expression<String>? provider,
    Expression<String>? quality,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (segmentId != null) 'segment_id': segmentId,
      if (targetLang != null) 'target_lang': targetLang,
      if (body != null) 'body': body,
      if (provider != null) 'provider': provider,
      if (quality != null) 'quality': quality,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TranslationsCompanion copyWith({
    Value<int>? id,
    Value<String>? segmentId,
    Value<String>? targetLang,
    Value<String>? body,
    Value<String>? provider,
    Value<String>? quality,
    Value<DateTime>? createdAt,
  }) {
    return TranslationsCompanion(
      id: id ?? this.id,
      segmentId: segmentId ?? this.segmentId,
      targetLang: targetLang ?? this.targetLang,
      body: body ?? this.body,
      provider: provider ?? this.provider,
      quality: quality ?? this.quality,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (segmentId.present) {
      map['segment_id'] = Variable<String>(segmentId.value);
    }
    if (targetLang.present) {
      map['target_lang'] = Variable<String>(targetLang.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (quality.present) {
      map['quality'] = Variable<String>(quality.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranslationsCompanion(')
          ..write('id: $id, ')
          ..write('segmentId: $segmentId, ')
          ..write('targetLang: $targetLang, ')
          ..write('body: $body, ')
          ..write('provider: $provider, ')
          ..write('quality: $quality, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CoursesTable extends Courses with TableInfo<$CoursesTable, CourseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoursesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _areaMeta = const VerificationMeta('area');
  @override
  late final GeneratedColumn<String> area = GeneratedColumn<String>(
    'area',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta('rawJson');
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaPathMeta = const VerificationMeta('mediaPath');
  @override
  late final GeneratedColumn<String> mediaPath = GeneratedColumn<String>(
    'media_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceLabelMeta = const VerificationMeta('sourceLabel');
  @override
  late final GeneratedColumn<String> sourceLabel = GeneratedColumn<String>(
    'source_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta('importedAt');
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    area,
    rawJson,
    mediaPath,
    sourceLabel,
    importedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'course';
  @override
  VerificationContext validateIntegrity(
    Insertable<CourseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('area')) {
      context.handle(_areaMeta, area.isAcceptableOrUnknown(data['area']!, _areaMeta));
    } else if (isInserting) {
      context.missing(_areaMeta);
    }
    if (data.containsKey('raw_json')) {
      context.handle(_rawJsonMeta, rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta));
    } else if (isInserting) {
      context.missing(_rawJsonMeta);
    }
    if (data.containsKey('media_path')) {
      context.handle(
        _mediaPathMeta,
        mediaPath.isAcceptableOrUnknown(data['media_path']!, _mediaPathMeta),
      );
    }
    if (data.containsKey('source_label')) {
      context.handle(
        _sourceLabelMeta,
        sourceLabel.isAcceptableOrUnknown(data['source_label']!, _sourceLabelMeta),
      );
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CourseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CourseRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      area: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}area'])!,
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      )!,
      mediaPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_path'],
      ),
      sourceLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_label'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
    );
  }

  @override
  $CoursesTable createAlias(String alias) {
    return $CoursesTable(attachedDatabase, alias);
  }
}

class CourseRow extends DataClass implements Insertable<CourseRow> {
  final String id;
  final String title;
  final String area;
  final String rawJson;
  final String? mediaPath;
  final String sourceLabel;
  final DateTime importedAt;
  const CourseRow({
    required this.id,
    required this.title,
    required this.area,
    required this.rawJson,
    this.mediaPath,
    required this.sourceLabel,
    required this.importedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['area'] = Variable<String>(area);
    map['raw_json'] = Variable<String>(rawJson);
    if (!nullToAbsent || mediaPath != null) {
      map['media_path'] = Variable<String>(mediaPath);
    }
    map['source_label'] = Variable<String>(sourceLabel);
    map['imported_at'] = Variable<DateTime>(importedAt);
    return map;
  }

  CoursesCompanion toCompanion(bool nullToAbsent) {
    return CoursesCompanion(
      id: Value(id),
      title: Value(title),
      area: Value(area),
      rawJson: Value(rawJson),
      mediaPath: mediaPath == null && nullToAbsent ? const Value.absent() : Value(mediaPath),
      sourceLabel: Value(sourceLabel),
      importedAt: Value(importedAt),
    );
  }

  factory CourseRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CourseRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      area: serializer.fromJson<String>(json['area']),
      rawJson: serializer.fromJson<String>(json['rawJson']),
      mediaPath: serializer.fromJson<String?>(json['mediaPath']),
      sourceLabel: serializer.fromJson<String>(json['sourceLabel']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'area': serializer.toJson<String>(area),
      'rawJson': serializer.toJson<String>(rawJson),
      'mediaPath': serializer.toJson<String?>(mediaPath),
      'sourceLabel': serializer.toJson<String>(sourceLabel),
      'importedAt': serializer.toJson<DateTime>(importedAt),
    };
  }

  CourseRow copyWith({
    String? id,
    String? title,
    String? area,
    String? rawJson,
    Value<String?> mediaPath = const Value.absent(),
    String? sourceLabel,
    DateTime? importedAt,
  }) => CourseRow(
    id: id ?? this.id,
    title: title ?? this.title,
    area: area ?? this.area,
    rawJson: rawJson ?? this.rawJson,
    mediaPath: mediaPath.present ? mediaPath.value : this.mediaPath,
    sourceLabel: sourceLabel ?? this.sourceLabel,
    importedAt: importedAt ?? this.importedAt,
  );
  CourseRow copyWithCompanion(CoursesCompanion data) {
    return CourseRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      area: data.area.present ? data.area.value : this.area,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
      mediaPath: data.mediaPath.present ? data.mediaPath.value : this.mediaPath,
      sourceLabel: data.sourceLabel.present ? data.sourceLabel.value : this.sourceLabel,
      importedAt: data.importedAt.present ? data.importedAt.value : this.importedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CourseRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('area: $area, ')
          ..write('rawJson: $rawJson, ')
          ..write('mediaPath: $mediaPath, ')
          ..write('sourceLabel: $sourceLabel, ')
          ..write('importedAt: $importedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, area, rawJson, mediaPath, sourceLabel, importedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CourseRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.area == this.area &&
          other.rawJson == this.rawJson &&
          other.mediaPath == this.mediaPath &&
          other.sourceLabel == this.sourceLabel &&
          other.importedAt == this.importedAt);
}

class CoursesCompanion extends UpdateCompanion<CourseRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> area;
  final Value<String> rawJson;
  final Value<String?> mediaPath;
  final Value<String> sourceLabel;
  final Value<DateTime> importedAt;
  final Value<int> rowid;
  const CoursesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.area = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.mediaPath = const Value.absent(),
    this.sourceLabel = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CoursesCompanion.insert({
    required String id,
    required String title,
    required String area,
    required String rawJson,
    this.mediaPath = const Value.absent(),
    this.sourceLabel = const Value.absent(),
    required DateTime importedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       area = Value(area),
       rawJson = Value(rawJson),
       importedAt = Value(importedAt);
  static Insertable<CourseRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? area,
    Expression<String>? rawJson,
    Expression<String>? mediaPath,
    Expression<String>? sourceLabel,
    Expression<DateTime>? importedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (area != null) 'area': area,
      if (rawJson != null) 'raw_json': rawJson,
      if (mediaPath != null) 'media_path': mediaPath,
      if (sourceLabel != null) 'source_label': sourceLabel,
      if (importedAt != null) 'imported_at': importedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CoursesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? area,
    Value<String>? rawJson,
    Value<String?>? mediaPath,
    Value<String>? sourceLabel,
    Value<DateTime>? importedAt,
    Value<int>? rowid,
  }) {
    return CoursesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      area: area ?? this.area,
      rawJson: rawJson ?? this.rawJson,
      mediaPath: mediaPath ?? this.mediaPath,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      importedAt: importedAt ?? this.importedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (area.present) {
      map['area'] = Variable<String>(area.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (mediaPath.present) {
      map['media_path'] = Variable<String>(mediaPath.value);
    }
    if (sourceLabel.present) {
      map['source_label'] = Variable<String>(sourceLabel.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoursesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('area: $area, ')
          ..write('rawJson: $rawJson, ')
          ..write('mediaPath: $mediaPath, ')
          ..write('sourceLabel: $sourceLabel, ')
          ..write('importedAt: $importedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClipsTable extends Clips with TableInfo<$ClipsTable, ClipRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _courseIdMeta = const VerificationMeta('courseId');
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES course (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordMeta = const VerificationMeta('ord');
  @override
  late final GeneratedColumn<int> ord = GeneratedColumn<int>(
    'ord',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta('startMs');
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transcriptMeta = const VerificationMeta('transcript');
  @override
  late final GeneratedColumn<String> transcript = GeneratedColumn<String>(
    'transcript',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [courseId, id, ord, title, startMs, endMs, transcript];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clip';
  @override
  VerificationContext validateIntegrity(Insertable<ClipRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('ord')) {
      context.handle(_ordMeta, ord.isAcceptableOrUnknown(data['ord']!, _ordMeta));
    } else if (isInserting) {
      context.missing(_ordMeta);
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(_startMsMeta, startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta));
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('end_ms')) {
      context.handle(_endMsMeta, endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta));
    }
    if (data.containsKey('transcript')) {
      context.handle(
        _transcriptMeta,
        transcript.isAcceptableOrUnknown(data['transcript']!, _transcriptMeta),
      );
    } else if (isInserting) {
      context.missing(_transcriptMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {courseId, id};
  @override
  ClipRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClipRow(
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      ord: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}ord'])!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      )!,
      endMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}end_ms']),
      transcript: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript'],
      )!,
    );
  }

  @override
  $ClipsTable createAlias(String alias) {
    return $ClipsTable(attachedDatabase, alias);
  }
}

class ClipRow extends DataClass implements Insertable<ClipRow> {
  final String courseId;
  final String id;
  final int ord;
  final String title;
  final int startMs;
  final int? endMs;
  final String transcript;
  const ClipRow({
    required this.courseId,
    required this.id,
    required this.ord,
    required this.title,
    required this.startMs,
    this.endMs,
    required this.transcript,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['course_id'] = Variable<String>(courseId);
    map['id'] = Variable<String>(id);
    map['ord'] = Variable<int>(ord);
    map['title'] = Variable<String>(title);
    map['start_ms'] = Variable<int>(startMs);
    if (!nullToAbsent || endMs != null) {
      map['end_ms'] = Variable<int>(endMs);
    }
    map['transcript'] = Variable<String>(transcript);
    return map;
  }

  ClipsCompanion toCompanion(bool nullToAbsent) {
    return ClipsCompanion(
      courseId: Value(courseId),
      id: Value(id),
      ord: Value(ord),
      title: Value(title),
      startMs: Value(startMs),
      endMs: endMs == null && nullToAbsent ? const Value.absent() : Value(endMs),
      transcript: Value(transcript),
    );
  }

  factory ClipRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClipRow(
      courseId: serializer.fromJson<String>(json['courseId']),
      id: serializer.fromJson<String>(json['id']),
      ord: serializer.fromJson<int>(json['ord']),
      title: serializer.fromJson<String>(json['title']),
      startMs: serializer.fromJson<int>(json['startMs']),
      endMs: serializer.fromJson<int?>(json['endMs']),
      transcript: serializer.fromJson<String>(json['transcript']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'courseId': serializer.toJson<String>(courseId),
      'id': serializer.toJson<String>(id),
      'ord': serializer.toJson<int>(ord),
      'title': serializer.toJson<String>(title),
      'startMs': serializer.toJson<int>(startMs),
      'endMs': serializer.toJson<int?>(endMs),
      'transcript': serializer.toJson<String>(transcript),
    };
  }

  ClipRow copyWith({
    String? courseId,
    String? id,
    int? ord,
    String? title,
    int? startMs,
    Value<int?> endMs = const Value.absent(),
    String? transcript,
  }) => ClipRow(
    courseId: courseId ?? this.courseId,
    id: id ?? this.id,
    ord: ord ?? this.ord,
    title: title ?? this.title,
    startMs: startMs ?? this.startMs,
    endMs: endMs.present ? endMs.value : this.endMs,
    transcript: transcript ?? this.transcript,
  );
  ClipRow copyWithCompanion(ClipsCompanion data) {
    return ClipRow(
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      id: data.id.present ? data.id.value : this.id,
      ord: data.ord.present ? data.ord.value : this.ord,
      title: data.title.present ? data.title.value : this.title,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      transcript: data.transcript.present ? data.transcript.value : this.transcript,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClipRow(')
          ..write('courseId: $courseId, ')
          ..write('id: $id, ')
          ..write('ord: $ord, ')
          ..write('title: $title, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('transcript: $transcript')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(courseId, id, ord, title, startMs, endMs, transcript);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClipRow &&
          other.courseId == this.courseId &&
          other.id == this.id &&
          other.ord == this.ord &&
          other.title == this.title &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.transcript == this.transcript);
}

class ClipsCompanion extends UpdateCompanion<ClipRow> {
  final Value<String> courseId;
  final Value<String> id;
  final Value<int> ord;
  final Value<String> title;
  final Value<int> startMs;
  final Value<int?> endMs;
  final Value<String> transcript;
  final Value<int> rowid;
  const ClipsCompanion({
    this.courseId = const Value.absent(),
    this.id = const Value.absent(),
    this.ord = const Value.absent(),
    this.title = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.transcript = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClipsCompanion.insert({
    required String courseId,
    required String id,
    required int ord,
    required String title,
    required int startMs,
    this.endMs = const Value.absent(),
    required String transcript,
    this.rowid = const Value.absent(),
  }) : courseId = Value(courseId),
       id = Value(id),
       ord = Value(ord),
       title = Value(title),
       startMs = Value(startMs),
       transcript = Value(transcript);
  static Insertable<ClipRow> custom({
    Expression<String>? courseId,
    Expression<String>? id,
    Expression<int>? ord,
    Expression<String>? title,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<String>? transcript,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (courseId != null) 'course_id': courseId,
      if (id != null) 'id': id,
      if (ord != null) 'ord': ord,
      if (title != null) 'title': title,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (transcript != null) 'transcript': transcript,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClipsCompanion copyWith({
    Value<String>? courseId,
    Value<String>? id,
    Value<int>? ord,
    Value<String>? title,
    Value<int>? startMs,
    Value<int?>? endMs,
    Value<String>? transcript,
    Value<int>? rowid,
  }) {
    return ClipsCompanion(
      courseId: courseId ?? this.courseId,
      id: id ?? this.id,
      ord: ord ?? this.ord,
      title: title ?? this.title,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      transcript: transcript ?? this.transcript,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ord.present) {
      map['ord'] = Variable<int>(ord.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (transcript.present) {
      map['transcript'] = Variable<String>(transcript.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClipsCompanion(')
          ..write('courseId: $courseId, ')
          ..write('id: $id, ')
          ..write('ord: $ord, ')
          ..write('title: $title, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('transcript: $transcript, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemsTable extends Items with TableInfo<$ItemsTable, ItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _courseIdMeta = const VerificationMeta('courseId');
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES course (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _clipIdMeta = const VerificationMeta('clipId');
  @override
  late final GeneratedColumn<String> clipId = GeneratedColumn<String>(
    'clip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meaningMeta = const VerificationMeta('meaning');
  @override
  late final GeneratedColumn<String> meaning = GeneratedColumn<String>(
    'meaning',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [courseId, clipId, id, kind, body, meaning];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item';
  @override
  VerificationContext validateIntegrity(Insertable<ItemRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('clip_id')) {
      context.handle(_clipIdMeta, clipId.isAcceptableOrUnknown(data['clip_id']!, _clipIdMeta));
    } else if (isInserting) {
      context.missing(_clipIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('body')) {
      context.handle(_bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('meaning')) {
      context.handle(_meaningMeta, meaning.isAcceptableOrUnknown(data['meaning']!, _meaningMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {courseId, id};
  @override
  ItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemRow(
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      clipId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clip_id'],
      )!,
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      body: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      meaning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meaning'],
      )!,
    );
  }

  @override
  $ItemsTable createAlias(String alias) {
    return $ItemsTable(attachedDatabase, alias);
  }
}

class ItemRow extends DataClass implements Insertable<ItemRow> {
  final String courseId;
  final String clipId;
  final String id;

  /// `words`, `phrases`, `sentences`.
  final String kind;
  final String body;
  final String meaning;
  const ItemRow({
    required this.courseId,
    required this.clipId,
    required this.id,
    required this.kind,
    required this.body,
    required this.meaning,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['course_id'] = Variable<String>(courseId);
    map['clip_id'] = Variable<String>(clipId);
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['body'] = Variable<String>(body);
    map['meaning'] = Variable<String>(meaning);
    return map;
  }

  ItemsCompanion toCompanion(bool nullToAbsent) {
    return ItemsCompanion(
      courseId: Value(courseId),
      clipId: Value(clipId),
      id: Value(id),
      kind: Value(kind),
      body: Value(body),
      meaning: Value(meaning),
    );
  }

  factory ItemRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemRow(
      courseId: serializer.fromJson<String>(json['courseId']),
      clipId: serializer.fromJson<String>(json['clipId']),
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      body: serializer.fromJson<String>(json['body']),
      meaning: serializer.fromJson<String>(json['meaning']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'courseId': serializer.toJson<String>(courseId),
      'clipId': serializer.toJson<String>(clipId),
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'body': serializer.toJson<String>(body),
      'meaning': serializer.toJson<String>(meaning),
    };
  }

  ItemRow copyWith({
    String? courseId,
    String? clipId,
    String? id,
    String? kind,
    String? body,
    String? meaning,
  }) => ItemRow(
    courseId: courseId ?? this.courseId,
    clipId: clipId ?? this.clipId,
    id: id ?? this.id,
    kind: kind ?? this.kind,
    body: body ?? this.body,
    meaning: meaning ?? this.meaning,
  );
  ItemRow copyWithCompanion(ItemsCompanion data) {
    return ItemRow(
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      clipId: data.clipId.present ? data.clipId.value : this.clipId,
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      body: data.body.present ? data.body.value : this.body,
      meaning: data.meaning.present ? data.meaning.value : this.meaning,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemRow(')
          ..write('courseId: $courseId, ')
          ..write('clipId: $clipId, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('body: $body, ')
          ..write('meaning: $meaning')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(courseId, clipId, id, kind, body, meaning);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemRow &&
          other.courseId == this.courseId &&
          other.clipId == this.clipId &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.body == this.body &&
          other.meaning == this.meaning);
}

class ItemsCompanion extends UpdateCompanion<ItemRow> {
  final Value<String> courseId;
  final Value<String> clipId;
  final Value<String> id;
  final Value<String> kind;
  final Value<String> body;
  final Value<String> meaning;
  final Value<int> rowid;
  const ItemsCompanion({
    this.courseId = const Value.absent(),
    this.clipId = const Value.absent(),
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.body = const Value.absent(),
    this.meaning = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemsCompanion.insert({
    required String courseId,
    required String clipId,
    required String id,
    required String kind,
    required String body,
    this.meaning = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : courseId = Value(courseId),
       clipId = Value(clipId),
       id = Value(id),
       kind = Value(kind),
       body = Value(body);
  static Insertable<ItemRow> custom({
    Expression<String>? courseId,
    Expression<String>? clipId,
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? body,
    Expression<String>? meaning,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (courseId != null) 'course_id': courseId,
      if (clipId != null) 'clip_id': clipId,
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (body != null) 'body': body,
      if (meaning != null) 'meaning': meaning,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemsCompanion copyWith({
    Value<String>? courseId,
    Value<String>? clipId,
    Value<String>? id,
    Value<String>? kind,
    Value<String>? body,
    Value<String>? meaning,
    Value<int>? rowid,
  }) {
    return ItemsCompanion(
      courseId: courseId ?? this.courseId,
      clipId: clipId ?? this.clipId,
      id: id ?? this.id,
      kind: kind ?? this.kind,
      body: body ?? this.body,
      meaning: meaning ?? this.meaning,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (clipId.present) {
      map['clip_id'] = Variable<String>(clipId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (meaning.present) {
      map['meaning'] = Variable<String>(meaning.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemsCompanion(')
          ..write('courseId: $courseId, ')
          ..write('clipId: $clipId, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('body: $body, ')
          ..write('meaning: $meaning, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExercisesTable extends Exercises with TableInfo<$ExercisesTable, ExerciseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta('courseId');
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clipIdMeta = const VerificationMeta('clipId');
  @override
  late final GeneratedColumn<String> clipId = GeneratedColumn<String>(
    'clip_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta('dataJson');
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    courseId,
    clipId,
    sessionId,
    kind,
    dataJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExerciseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    }
    if (data.containsKey('clip_id')) {
      context.handle(_clipIdMeta, clipId.isAcceptableOrUnknown(data['clip_id']!, _clipIdMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExerciseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      ),
      clipId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clip_id'],
      ),
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      ),
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ExercisesTable createAlias(String alias) {
    return $ExercisesTable(attachedDatabase, alias);
  }
}

class ExerciseRow extends DataClass implements Insertable<ExerciseRow> {
  final String id;
  final String? courseId;
  final String? clipId;
  final String? sessionId;
  final String kind;
  final String dataJson;
  final DateTime createdAt;
  const ExerciseRow({
    required this.id,
    this.courseId,
    this.clipId,
    this.sessionId,
    required this.kind,
    required this.dataJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || courseId != null) {
      map['course_id'] = Variable<String>(courseId);
    }
    if (!nullToAbsent || clipId != null) {
      map['clip_id'] = Variable<String>(clipId);
    }
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    map['kind'] = Variable<String>(kind);
    map['data_json'] = Variable<String>(dataJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ExercisesCompanion toCompanion(bool nullToAbsent) {
    return ExercisesCompanion(
      id: Value(id),
      courseId: courseId == null && nullToAbsent ? const Value.absent() : Value(courseId),
      clipId: clipId == null && nullToAbsent ? const Value.absent() : Value(clipId),
      sessionId: sessionId == null && nullToAbsent ? const Value.absent() : Value(sessionId),
      kind: Value(kind),
      dataJson: Value(dataJson),
      createdAt: Value(createdAt),
    );
  }

  factory ExerciseRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseRow(
      id: serializer.fromJson<String>(json['id']),
      courseId: serializer.fromJson<String?>(json['courseId']),
      clipId: serializer.fromJson<String?>(json['clipId']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      kind: serializer.fromJson<String>(json['kind']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'courseId': serializer.toJson<String?>(courseId),
      'clipId': serializer.toJson<String?>(clipId),
      'sessionId': serializer.toJson<String?>(sessionId),
      'kind': serializer.toJson<String>(kind),
      'dataJson': serializer.toJson<String>(dataJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ExerciseRow copyWith({
    String? id,
    Value<String?> courseId = const Value.absent(),
    Value<String?> clipId = const Value.absent(),
    Value<String?> sessionId = const Value.absent(),
    String? kind,
    String? dataJson,
    DateTime? createdAt,
  }) => ExerciseRow(
    id: id ?? this.id,
    courseId: courseId.present ? courseId.value : this.courseId,
    clipId: clipId.present ? clipId.value : this.clipId,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    kind: kind ?? this.kind,
    dataJson: dataJson ?? this.dataJson,
    createdAt: createdAt ?? this.createdAt,
  );
  ExerciseRow copyWithCompanion(ExercisesCompanion data) {
    return ExerciseRow(
      id: data.id.present ? data.id.value : this.id,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      clipId: data.clipId.present ? data.clipId.value : this.clipId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      kind: data.kind.present ? data.kind.value : this.kind,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseRow(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('clipId: $clipId, ')
          ..write('sessionId: $sessionId, ')
          ..write('kind: $kind, ')
          ..write('dataJson: $dataJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, courseId, clipId, sessionId, kind, dataJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseRow &&
          other.id == this.id &&
          other.courseId == this.courseId &&
          other.clipId == this.clipId &&
          other.sessionId == this.sessionId &&
          other.kind == this.kind &&
          other.dataJson == this.dataJson &&
          other.createdAt == this.createdAt);
}

class ExercisesCompanion extends UpdateCompanion<ExerciseRow> {
  final Value<String> id;
  final Value<String?> courseId;
  final Value<String?> clipId;
  final Value<String?> sessionId;
  final Value<String> kind;
  final Value<String> dataJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ExercisesCompanion({
    this.id = const Value.absent(),
    this.courseId = const Value.absent(),
    this.clipId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.kind = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExercisesCompanion.insert({
    required String id,
    this.courseId = const Value.absent(),
    this.clipId = const Value.absent(),
    this.sessionId = const Value.absent(),
    required String kind,
    required String dataJson,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       dataJson = Value(dataJson),
       createdAt = Value(createdAt);
  static Insertable<ExerciseRow> custom({
    Expression<String>? id,
    Expression<String>? courseId,
    Expression<String>? clipId,
    Expression<String>? sessionId,
    Expression<String>? kind,
    Expression<String>? dataJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (courseId != null) 'course_id': courseId,
      if (clipId != null) 'clip_id': clipId,
      if (sessionId != null) 'session_id': sessionId,
      if (kind != null) 'kind': kind,
      if (dataJson != null) 'data_json': dataJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExercisesCompanion copyWith({
    Value<String>? id,
    Value<String?>? courseId,
    Value<String?>? clipId,
    Value<String?>? sessionId,
    Value<String>? kind,
    Value<String>? dataJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ExercisesCompanion(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      clipId: clipId ?? this.clipId,
      sessionId: sessionId ?? this.sessionId,
      kind: kind ?? this.kind,
      dataJson: dataJson ?? this.dataJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (clipId.present) {
      map['clip_id'] = Variable<String>(clipId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesCompanion(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('clipId: $clipId, ')
          ..write('sessionId: $sessionId, ')
          ..write('kind: $kind, ')
          ..write('dataJson: $dataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgressTable extends Progress with TableInfo<$ProgressTable, ProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _courseIdMeta = const VerificationMeta('courseId');
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clipIdMeta = const VerificationMeta('clipId');
  @override
  late final GeneratedColumn<String> clipId = GeneratedColumn<String>(
    'clip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stepMeta = const VerificationMeta('step');
  @override
  late final GeneratedColumn<String> step = GeneratedColumn<String>(
    'step',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [courseId, clipId, step];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('clip_id')) {
      context.handle(_clipIdMeta, clipId.isAcceptableOrUnknown(data['clip_id']!, _clipIdMeta));
    } else if (isInserting) {
      context.missing(_clipIdMeta);
    }
    if (data.containsKey('step')) {
      context.handle(_stepMeta, step.isAcceptableOrUnknown(data['step']!, _stepMeta));
    } else if (isInserting) {
      context.missing(_stepMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {courseId, clipId, step};
  @override
  ProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgressRow(
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      clipId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clip_id'],
      )!,
      step: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}step'])!,
    );
  }

  @override
  $ProgressTable createAlias(String alias) {
    return $ProgressTable(attachedDatabase, alias);
  }
}

class ProgressRow extends DataClass implements Insertable<ProgressRow> {
  final String courseId;
  final String clipId;
  final String step;
  const ProgressRow({required this.courseId, required this.clipId, required this.step});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['course_id'] = Variable<String>(courseId);
    map['clip_id'] = Variable<String>(clipId);
    map['step'] = Variable<String>(step);
    return map;
  }

  ProgressCompanion toCompanion(bool nullToAbsent) {
    return ProgressCompanion(courseId: Value(courseId), clipId: Value(clipId), step: Value(step));
  }

  factory ProgressRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgressRow(
      courseId: serializer.fromJson<String>(json['courseId']),
      clipId: serializer.fromJson<String>(json['clipId']),
      step: serializer.fromJson<String>(json['step']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'courseId': serializer.toJson<String>(courseId),
      'clipId': serializer.toJson<String>(clipId),
      'step': serializer.toJson<String>(step),
    };
  }

  ProgressRow copyWith({String? courseId, String? clipId, String? step}) => ProgressRow(
    courseId: courseId ?? this.courseId,
    clipId: clipId ?? this.clipId,
    step: step ?? this.step,
  );
  ProgressRow copyWithCompanion(ProgressCompanion data) {
    return ProgressRow(
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      clipId: data.clipId.present ? data.clipId.value : this.clipId,
      step: data.step.present ? data.step.value : this.step,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgressRow(')
          ..write('courseId: $courseId, ')
          ..write('clipId: $clipId, ')
          ..write('step: $step')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(courseId, clipId, step);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgressRow &&
          other.courseId == this.courseId &&
          other.clipId == this.clipId &&
          other.step == this.step);
}

class ProgressCompanion extends UpdateCompanion<ProgressRow> {
  final Value<String> courseId;
  final Value<String> clipId;
  final Value<String> step;
  final Value<int> rowid;
  const ProgressCompanion({
    this.courseId = const Value.absent(),
    this.clipId = const Value.absent(),
    this.step = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgressCompanion.insert({
    required String courseId,
    required String clipId,
    required String step,
    this.rowid = const Value.absent(),
  }) : courseId = Value(courseId),
       clipId = Value(clipId),
       step = Value(step);
  static Insertable<ProgressRow> custom({
    Expression<String>? courseId,
    Expression<String>? clipId,
    Expression<String>? step,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (courseId != null) 'course_id': courseId,
      if (clipId != null) 'clip_id': clipId,
      if (step != null) 'step': step,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgressCompanion copyWith({
    Value<String>? courseId,
    Value<String>? clipId,
    Value<String>? step,
    Value<int>? rowid,
  }) {
    return ProgressCompanion(
      courseId: courseId ?? this.courseId,
      clipId: clipId ?? this.clipId,
      step: step ?? this.step,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (clipId.present) {
      map['clip_id'] = Variable<String>(clipId.value);
    }
    if (step.present) {
      map['step'] = Variable<String>(step.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgressCompanion(')
          ..write('courseId: $courseId, ')
          ..write('clipId: $clipId, ')
          ..write('step: $step, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttemptsTable extends Attempts with TableInfo<$AttemptsTable, AttemptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta('courseId');
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clipIdMeta = const VerificationMeta('clipId');
  @override
  late final GeneratedColumn<String> clipId = GeneratedColumn<String>(
    'clip_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordingPathMeta = const VerificationMeta('recordingPath');
  @override
  late final GeneratedColumn<String> recordingPath = GeneratedColumn<String>(
    'recording_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    kind,
    note,
    durationMs,
    courseId,
    clipId,
    recordingPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attempt';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttemptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('note')) {
      context.handle(_noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    } else if (isInserting) {
      context.missing(_noteMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    }
    if (data.containsKey('clip_id')) {
      context.handle(_clipIdMeta, clipId.isAcceptableOrUnknown(data['clip_id']!, _clipIdMeta));
    }
    if (data.containsKey('recording_path')) {
      context.handle(
        _recordingPathMeta,
        recordingPath.isAcceptableOrUnknown(data['recording_path']!, _recordingPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttemptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttemptRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      note: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}note'])!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      ),
      clipId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clip_id'],
      ),
      recordingPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_path'],
      ),
    );
  }

  @override
  $AttemptsTable createAlias(String alias) {
    return $AttemptsTable(attachedDatabase, alias);
  }
}

class AttemptRow extends DataClass implements Insertable<AttemptRow> {
  final String id;
  final DateTime createdAt;
  final String kind;
  final String note;
  final int durationMs;
  final String? courseId;
  final String? clipId;
  final String? recordingPath;
  const AttemptRow({
    required this.id,
    required this.createdAt,
    required this.kind,
    required this.note,
    required this.durationMs,
    this.courseId,
    this.clipId,
    this.recordingPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['kind'] = Variable<String>(kind);
    map['note'] = Variable<String>(note);
    map['duration_ms'] = Variable<int>(durationMs);
    if (!nullToAbsent || courseId != null) {
      map['course_id'] = Variable<String>(courseId);
    }
    if (!nullToAbsent || clipId != null) {
      map['clip_id'] = Variable<String>(clipId);
    }
    if (!nullToAbsent || recordingPath != null) {
      map['recording_path'] = Variable<String>(recordingPath);
    }
    return map;
  }

  AttemptsCompanion toCompanion(bool nullToAbsent) {
    return AttemptsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      kind: Value(kind),
      note: Value(note),
      durationMs: Value(durationMs),
      courseId: courseId == null && nullToAbsent ? const Value.absent() : Value(courseId),
      clipId: clipId == null && nullToAbsent ? const Value.absent() : Value(clipId),
      recordingPath: recordingPath == null && nullToAbsent
          ? const Value.absent()
          : Value(recordingPath),
    );
  }

  factory AttemptRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttemptRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      kind: serializer.fromJson<String>(json['kind']),
      note: serializer.fromJson<String>(json['note']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      courseId: serializer.fromJson<String?>(json['courseId']),
      clipId: serializer.fromJson<String?>(json['clipId']),
      recordingPath: serializer.fromJson<String?>(json['recordingPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'kind': serializer.toJson<String>(kind),
      'note': serializer.toJson<String>(note),
      'durationMs': serializer.toJson<int>(durationMs),
      'courseId': serializer.toJson<String?>(courseId),
      'clipId': serializer.toJson<String?>(clipId),
      'recordingPath': serializer.toJson<String?>(recordingPath),
    };
  }

  AttemptRow copyWith({
    String? id,
    DateTime? createdAt,
    String? kind,
    String? note,
    int? durationMs,
    Value<String?> courseId = const Value.absent(),
    Value<String?> clipId = const Value.absent(),
    Value<String?> recordingPath = const Value.absent(),
  }) => AttemptRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    kind: kind ?? this.kind,
    note: note ?? this.note,
    durationMs: durationMs ?? this.durationMs,
    courseId: courseId.present ? courseId.value : this.courseId,
    clipId: clipId.present ? clipId.value : this.clipId,
    recordingPath: recordingPath.present ? recordingPath.value : this.recordingPath,
  );
  AttemptRow copyWithCompanion(AttemptsCompanion data) {
    return AttemptRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      kind: data.kind.present ? data.kind.value : this.kind,
      note: data.note.present ? data.note.value : this.note,
      durationMs: data.durationMs.present ? data.durationMs.value : this.durationMs,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      clipId: data.clipId.present ? data.clipId.value : this.clipId,
      recordingPath: data.recordingPath.present ? data.recordingPath.value : this.recordingPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttemptRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('kind: $kind, ')
          ..write('note: $note, ')
          ..write('durationMs: $durationMs, ')
          ..write('courseId: $courseId, ')
          ..write('clipId: $clipId, ')
          ..write('recordingPath: $recordingPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, createdAt, kind, note, durationMs, courseId, clipId, recordingPath);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttemptRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.kind == this.kind &&
          other.note == this.note &&
          other.durationMs == this.durationMs &&
          other.courseId == this.courseId &&
          other.clipId == this.clipId &&
          other.recordingPath == this.recordingPath);
}

class AttemptsCompanion extends UpdateCompanion<AttemptRow> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<String> kind;
  final Value<String> note;
  final Value<int> durationMs;
  final Value<String?> courseId;
  final Value<String?> clipId;
  final Value<String?> recordingPath;
  final Value<int> rowid;
  const AttemptsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.kind = const Value.absent(),
    this.note = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.courseId = const Value.absent(),
    this.clipId = const Value.absent(),
    this.recordingPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttemptsCompanion.insert({
    required String id,
    required DateTime createdAt,
    required String kind,
    required String note,
    required int durationMs,
    this.courseId = const Value.absent(),
    this.clipId = const Value.absent(),
    this.recordingPath = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       kind = Value(kind),
       note = Value(note),
       durationMs = Value(durationMs);
  static Insertable<AttemptRow> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<String>? kind,
    Expression<String>? note,
    Expression<int>? durationMs,
    Expression<String>? courseId,
    Expression<String>? clipId,
    Expression<String>? recordingPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (kind != null) 'kind': kind,
      if (note != null) 'note': note,
      if (durationMs != null) 'duration_ms': durationMs,
      if (courseId != null) 'course_id': courseId,
      if (clipId != null) 'clip_id': clipId,
      if (recordingPath != null) 'recording_path': recordingPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttemptsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<String>? kind,
    Value<String>? note,
    Value<int>? durationMs,
    Value<String?>? courseId,
    Value<String?>? clipId,
    Value<String?>? recordingPath,
    Value<int>? rowid,
  }) {
    return AttemptsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      kind: kind ?? this.kind,
      note: note ?? this.note,
      durationMs: durationMs ?? this.durationMs,
      courseId: courseId ?? this.courseId,
      clipId: clipId ?? this.clipId,
      recordingPath: recordingPath ?? this.recordingPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (clipId.present) {
      map['clip_id'] = Variable<String>(clipId.value);
    }
    if (recordingPath.present) {
      map['recording_path'] = Variable<String>(recordingPath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttemptsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('kind: $kind, ')
          ..write('note: $note, ')
          ..write('durationMs: $durationMs, ')
          ..write('courseId: $courseId, ')
          ..write('clipId: $clipId, ')
          ..write('recordingPath: $recordingPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CardsTable extends Cards with TableInfo<$CardsTable, CardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta('courseId');
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clipIdMeta = const VerificationMeta('clipId');
  @override
  late final GeneratedColumn<String> clipId = GeneratedColumn<String>(
    'clip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meaningMeta = const VerificationMeta('meaning');
  @override
  late final GeneratedColumn<String> meaning = GeneratedColumn<String>(
    'meaning',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repetitionsMeta = const VerificationMeta('repetitions');
  @override
  late final GeneratedColumn<int> repetitions = GeneratedColumn<int>(
    'repetitions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _schedulerMeta = const VerificationMeta('scheduler');
  @override
  late final GeneratedColumn<String> scheduler = GeneratedColumn<String>(
    'scheduler',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ladder'),
  );
  static const VerificationMeta _stabilityMeta = const VerificationMeta('stability');
  @override
  late final GeneratedColumn<double> stability = GeneratedColumn<double>(
    'stability',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta('difficulty');
  @override
  late final GeneratedColumn<double> difficulty = GeneratedColumn<double>(
    'difficulty',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    courseId,
    clipId,
    body,
    meaning,
    dueAt,
    repetitions,
    scheduler,
    stability,
    difficulty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card';
  @override
  VerificationContext validateIntegrity(Insertable<CardRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('clip_id')) {
      context.handle(_clipIdMeta, clipId.isAcceptableOrUnknown(data['clip_id']!, _clipIdMeta));
    } else if (isInserting) {
      context.missing(_clipIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(_bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('meaning')) {
      context.handle(_meaningMeta, meaning.isAcceptableOrUnknown(data['meaning']!, _meaningMeta));
    } else if (isInserting) {
      context.missing(_meaningMeta);
    }
    if (data.containsKey('due_at')) {
      context.handle(_dueAtMeta, dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta));
    } else if (isInserting) {
      context.missing(_dueAtMeta);
    }
    if (data.containsKey('repetitions')) {
      context.handle(
        _repetitionsMeta,
        repetitions.isAcceptableOrUnknown(data['repetitions']!, _repetitionsMeta),
      );
    }
    if (data.containsKey('scheduler')) {
      context.handle(
        _schedulerMeta,
        scheduler.isAcceptableOrUnknown(data['scheduler']!, _schedulerMeta),
      );
    }
    if (data.containsKey('stability')) {
      context.handle(
        _stabilityMeta,
        stability.isAcceptableOrUnknown(data['stability']!, _stabilityMeta),
      );
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      clipId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clip_id'],
      )!,
      body: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      meaning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meaning'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      )!,
      repetitions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repetitions'],
      )!,
      scheduler: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduler'],
      )!,
      stability: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stability'],
      ),
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}difficulty'],
      ),
    );
  }

  @override
  $CardsTable createAlias(String alias) {
    return $CardsTable(attachedDatabase, alias);
  }
}

class CardRow extends DataClass implements Insertable<CardRow> {
  final String id;
  final String courseId;
  final String clipId;
  final String body;
  final String meaning;
  final DateTime dueAt;
  final int repetitions;
  final String scheduler;
  final double? stability;
  final double? difficulty;
  const CardRow({
    required this.id,
    required this.courseId,
    required this.clipId,
    required this.body,
    required this.meaning,
    required this.dueAt,
    required this.repetitions,
    required this.scheduler,
    this.stability,
    this.difficulty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['course_id'] = Variable<String>(courseId);
    map['clip_id'] = Variable<String>(clipId);
    map['body'] = Variable<String>(body);
    map['meaning'] = Variable<String>(meaning);
    map['due_at'] = Variable<DateTime>(dueAt);
    map['repetitions'] = Variable<int>(repetitions);
    map['scheduler'] = Variable<String>(scheduler);
    if (!nullToAbsent || stability != null) {
      map['stability'] = Variable<double>(stability);
    }
    if (!nullToAbsent || difficulty != null) {
      map['difficulty'] = Variable<double>(difficulty);
    }
    return map;
  }

  CardsCompanion toCompanion(bool nullToAbsent) {
    return CardsCompanion(
      id: Value(id),
      courseId: Value(courseId),
      clipId: Value(clipId),
      body: Value(body),
      meaning: Value(meaning),
      dueAt: Value(dueAt),
      repetitions: Value(repetitions),
      scheduler: Value(scheduler),
      stability: stability == null && nullToAbsent ? const Value.absent() : Value(stability),
      difficulty: difficulty == null && nullToAbsent ? const Value.absent() : Value(difficulty),
    );
  }

  factory CardRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardRow(
      id: serializer.fromJson<String>(json['id']),
      courseId: serializer.fromJson<String>(json['courseId']),
      clipId: serializer.fromJson<String>(json['clipId']),
      body: serializer.fromJson<String>(json['body']),
      meaning: serializer.fromJson<String>(json['meaning']),
      dueAt: serializer.fromJson<DateTime>(json['dueAt']),
      repetitions: serializer.fromJson<int>(json['repetitions']),
      scheduler: serializer.fromJson<String>(json['scheduler']),
      stability: serializer.fromJson<double?>(json['stability']),
      difficulty: serializer.fromJson<double?>(json['difficulty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'courseId': serializer.toJson<String>(courseId),
      'clipId': serializer.toJson<String>(clipId),
      'body': serializer.toJson<String>(body),
      'meaning': serializer.toJson<String>(meaning),
      'dueAt': serializer.toJson<DateTime>(dueAt),
      'repetitions': serializer.toJson<int>(repetitions),
      'scheduler': serializer.toJson<String>(scheduler),
      'stability': serializer.toJson<double?>(stability),
      'difficulty': serializer.toJson<double?>(difficulty),
    };
  }

  CardRow copyWith({
    String? id,
    String? courseId,
    String? clipId,
    String? body,
    String? meaning,
    DateTime? dueAt,
    int? repetitions,
    String? scheduler,
    Value<double?> stability = const Value.absent(),
    Value<double?> difficulty = const Value.absent(),
  }) => CardRow(
    id: id ?? this.id,
    courseId: courseId ?? this.courseId,
    clipId: clipId ?? this.clipId,
    body: body ?? this.body,
    meaning: meaning ?? this.meaning,
    dueAt: dueAt ?? this.dueAt,
    repetitions: repetitions ?? this.repetitions,
    scheduler: scheduler ?? this.scheduler,
    stability: stability.present ? stability.value : this.stability,
    difficulty: difficulty.present ? difficulty.value : this.difficulty,
  );
  CardRow copyWithCompanion(CardsCompanion data) {
    return CardRow(
      id: data.id.present ? data.id.value : this.id,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      clipId: data.clipId.present ? data.clipId.value : this.clipId,
      body: data.body.present ? data.body.value : this.body,
      meaning: data.meaning.present ? data.meaning.value : this.meaning,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      repetitions: data.repetitions.present ? data.repetitions.value : this.repetitions,
      scheduler: data.scheduler.present ? data.scheduler.value : this.scheduler,
      stability: data.stability.present ? data.stability.value : this.stability,
      difficulty: data.difficulty.present ? data.difficulty.value : this.difficulty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardRow(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('clipId: $clipId, ')
          ..write('body: $body, ')
          ..write('meaning: $meaning, ')
          ..write('dueAt: $dueAt, ')
          ..write('repetitions: $repetitions, ')
          ..write('scheduler: $scheduler, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    courseId,
    clipId,
    body,
    meaning,
    dueAt,
    repetitions,
    scheduler,
    stability,
    difficulty,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardRow &&
          other.id == this.id &&
          other.courseId == this.courseId &&
          other.clipId == this.clipId &&
          other.body == this.body &&
          other.meaning == this.meaning &&
          other.dueAt == this.dueAt &&
          other.repetitions == this.repetitions &&
          other.scheduler == this.scheduler &&
          other.stability == this.stability &&
          other.difficulty == this.difficulty);
}

class CardsCompanion extends UpdateCompanion<CardRow> {
  final Value<String> id;
  final Value<String> courseId;
  final Value<String> clipId;
  final Value<String> body;
  final Value<String> meaning;
  final Value<DateTime> dueAt;
  final Value<int> repetitions;
  final Value<String> scheduler;
  final Value<double?> stability;
  final Value<double?> difficulty;
  final Value<int> rowid;
  const CardsCompanion({
    this.id = const Value.absent(),
    this.courseId = const Value.absent(),
    this.clipId = const Value.absent(),
    this.body = const Value.absent(),
    this.meaning = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.repetitions = const Value.absent(),
    this.scheduler = const Value.absent(),
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardsCompanion.insert({
    required String id,
    required String courseId,
    required String clipId,
    required String body,
    required String meaning,
    required DateTime dueAt,
    this.repetitions = const Value.absent(),
    this.scheduler = const Value.absent(),
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       courseId = Value(courseId),
       clipId = Value(clipId),
       body = Value(body),
       meaning = Value(meaning),
       dueAt = Value(dueAt);
  static Insertable<CardRow> custom({
    Expression<String>? id,
    Expression<String>? courseId,
    Expression<String>? clipId,
    Expression<String>? body,
    Expression<String>? meaning,
    Expression<DateTime>? dueAt,
    Expression<int>? repetitions,
    Expression<String>? scheduler,
    Expression<double>? stability,
    Expression<double>? difficulty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (courseId != null) 'course_id': courseId,
      if (clipId != null) 'clip_id': clipId,
      if (body != null) 'body': body,
      if (meaning != null) 'meaning': meaning,
      if (dueAt != null) 'due_at': dueAt,
      if (repetitions != null) 'repetitions': repetitions,
      if (scheduler != null) 'scheduler': scheduler,
      if (stability != null) 'stability': stability,
      if (difficulty != null) 'difficulty': difficulty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardsCompanion copyWith({
    Value<String>? id,
    Value<String>? courseId,
    Value<String>? clipId,
    Value<String>? body,
    Value<String>? meaning,
    Value<DateTime>? dueAt,
    Value<int>? repetitions,
    Value<String>? scheduler,
    Value<double?>? stability,
    Value<double?>? difficulty,
    Value<int>? rowid,
  }) {
    return CardsCompanion(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      clipId: clipId ?? this.clipId,
      body: body ?? this.body,
      meaning: meaning ?? this.meaning,
      dueAt: dueAt ?? this.dueAt,
      repetitions: repetitions ?? this.repetitions,
      scheduler: scheduler ?? this.scheduler,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (clipId.present) {
      map['clip_id'] = Variable<String>(clipId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (meaning.present) {
      map['meaning'] = Variable<String>(meaning.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (repetitions.present) {
      map['repetitions'] = Variable<int>(repetitions.value);
    }
    if (scheduler.present) {
      map['scheduler'] = Variable<String>(scheduler.value);
    }
    if (stability.present) {
      map['stability'] = Variable<double>(stability.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<double>(difficulty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardsCompanion(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('clipId: $clipId, ')
          ..write('body: $body, ')
          ..write('meaning: $meaning, ')
          ..write('dueAt: $dueAt, ')
          ..write('repetitions: $repetitions, ')
          ..write('scheduler: $scheduler, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewLogsTable extends ReviewLogs with TableInfo<$ReviewLogsTable, ReviewLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<String> cardId = GeneratedColumn<String>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES card (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewedAtMeta = const VerificationMeta('reviewedAt');
  @override
  late final GeneratedColumn<DateTime> reviewedAt = GeneratedColumn<DateTime>(
    'reviewed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<String> rating = GeneratedColumn<String>(
    'rating',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta('dataJson');
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [cardId, seq, reviewedAt, rating, dataJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('card_id')) {
      context.handle(_cardIdMeta, cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta));
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(_seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
        _reviewedAtMeta,
        reviewedAt.isAcceptableOrUnknown(data['reviewed_at']!, _reviewedAtMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta, rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    } else if (isInserting) {
      context.missing(_ratingMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cardId, seq};
  @override
  ReviewLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewLogRow(
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
      reviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reviewed_at'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rating'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
    );
  }

  @override
  $ReviewLogsTable createAlias(String alias) {
    return $ReviewLogsTable(attachedDatabase, alias);
  }
}

class ReviewLogRow extends DataClass implements Insertable<ReviewLogRow> {
  final String cardId;
  final int seq;
  final DateTime? reviewedAt;
  final String rating;

  /// The original history entry, kept verbatim.
  final String dataJson;
  const ReviewLogRow({
    required this.cardId,
    required this.seq,
    this.reviewedAt,
    required this.rating,
    required this.dataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['card_id'] = Variable<String>(cardId);
    map['seq'] = Variable<int>(seq);
    if (!nullToAbsent || reviewedAt != null) {
      map['reviewed_at'] = Variable<DateTime>(reviewedAt);
    }
    map['rating'] = Variable<String>(rating);
    map['data_json'] = Variable<String>(dataJson);
    return map;
  }

  ReviewLogsCompanion toCompanion(bool nullToAbsent) {
    return ReviewLogsCompanion(
      cardId: Value(cardId),
      seq: Value(seq),
      reviewedAt: reviewedAt == null && nullToAbsent ? const Value.absent() : Value(reviewedAt),
      rating: Value(rating),
      dataJson: Value(dataJson),
    );
  }

  factory ReviewLogRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewLogRow(
      cardId: serializer.fromJson<String>(json['cardId']),
      seq: serializer.fromJson<int>(json['seq']),
      reviewedAt: serializer.fromJson<DateTime?>(json['reviewedAt']),
      rating: serializer.fromJson<String>(json['rating']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cardId': serializer.toJson<String>(cardId),
      'seq': serializer.toJson<int>(seq),
      'reviewedAt': serializer.toJson<DateTime?>(reviewedAt),
      'rating': serializer.toJson<String>(rating),
      'dataJson': serializer.toJson<String>(dataJson),
    };
  }

  ReviewLogRow copyWith({
    String? cardId,
    int? seq,
    Value<DateTime?> reviewedAt = const Value.absent(),
    String? rating,
    String? dataJson,
  }) => ReviewLogRow(
    cardId: cardId ?? this.cardId,
    seq: seq ?? this.seq,
    reviewedAt: reviewedAt.present ? reviewedAt.value : this.reviewedAt,
    rating: rating ?? this.rating,
    dataJson: dataJson ?? this.dataJson,
  );
  ReviewLogRow copyWithCompanion(ReviewLogsCompanion data) {
    return ReviewLogRow(
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      seq: data.seq.present ? data.seq.value : this.seq,
      reviewedAt: data.reviewedAt.present ? data.reviewedAt.value : this.reviewedAt,
      rating: data.rating.present ? data.rating.value : this.rating,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLogRow(')
          ..write('cardId: $cardId, ')
          ..write('seq: $seq, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('rating: $rating, ')
          ..write('dataJson: $dataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cardId, seq, reviewedAt, rating, dataJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewLogRow &&
          other.cardId == this.cardId &&
          other.seq == this.seq &&
          other.reviewedAt == this.reviewedAt &&
          other.rating == this.rating &&
          other.dataJson == this.dataJson);
}

class ReviewLogsCompanion extends UpdateCompanion<ReviewLogRow> {
  final Value<String> cardId;
  final Value<int> seq;
  final Value<DateTime?> reviewedAt;
  final Value<String> rating;
  final Value<String> dataJson;
  final Value<int> rowid;
  const ReviewLogsCompanion({
    this.cardId = const Value.absent(),
    this.seq = const Value.absent(),
    this.reviewedAt = const Value.absent(),
    this.rating = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewLogsCompanion.insert({
    required String cardId,
    required int seq,
    this.reviewedAt = const Value.absent(),
    required String rating,
    required String dataJson,
    this.rowid = const Value.absent(),
  }) : cardId = Value(cardId),
       seq = Value(seq),
       rating = Value(rating),
       dataJson = Value(dataJson);
  static Insertable<ReviewLogRow> custom({
    Expression<String>? cardId,
    Expression<int>? seq,
    Expression<DateTime>? reviewedAt,
    Expression<String>? rating,
    Expression<String>? dataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cardId != null) 'card_id': cardId,
      if (seq != null) 'seq': seq,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
      if (rating != null) 'rating': rating,
      if (dataJson != null) 'data_json': dataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewLogsCompanion copyWith({
    Value<String>? cardId,
    Value<int>? seq,
    Value<DateTime?>? reviewedAt,
    Value<String>? rating,
    Value<String>? dataJson,
    Value<int>? rowid,
  }) {
    return ReviewLogsCompanion(
      cardId: cardId ?? this.cardId,
      seq: seq ?? this.seq,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rating: rating ?? this.rating,
      dataJson: dataJson ?? this.dataJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cardId.present) {
      map['card_id'] = Variable<String>(cardId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = Variable<DateTime>(reviewedAt.value);
    }
    if (rating.present) {
      map['rating'] = Variable<String>(rating.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLogsCompanion(')
          ..write('cardId: $cardId, ')
          ..write('seq: $seq, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('rating: $rating, ')
          ..write('dataJson: $dataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProviderConfigsTable extends ProviderConfigs
    with TableInfo<$ProviderConfigsTable, ProviderConfigRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _presetMeta = const VerificationMeta('preset');
  @override
  late final GeneratedColumn<String> preset = GeneratedColumn<String>(
    'preset',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta('baseUrl');
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _secretRefMeta = const VerificationMeta('secretRef');
  @override
  late final GeneratedColumn<String> secretRef = GeneratedColumn<String>(
    'secret_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cloudMeta = const VerificationMeta('cloud');
  @override
  late final GeneratedColumn<bool> cloud = GeneratedColumn<bool>(
    'cloud',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("cloud" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    preset,
    label,
    baseUrl,
    model,
    secretRef,
    cloud,
    enabled,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_config';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderConfigRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('preset')) {
      context.handle(_presetMeta, preset.isAcceptableOrUnknown(data['preset']!, _presetMeta));
    } else if (isInserting) {
      context.missing(_presetMeta);
    }
    if (data.containsKey('label')) {
      context.handle(_labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(_baseUrlMeta, baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta));
    }
    if (data.containsKey('model')) {
      context.handle(_modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    }
    if (data.containsKey('secret_ref')) {
      context.handle(
        _secretRefMeta,
        secretRef.isAcceptableOrUnknown(data['secret_ref']!, _secretRefMeta),
      );
    }
    if (data.containsKey('cloud')) {
      context.handle(_cloudMeta, cloud.isAcceptableOrUnknown(data['cloud']!, _cloudMeta));
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta, enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProviderConfigRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderConfigRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      preset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preset'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      secretRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secret_ref'],
      ),
      cloud: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}cloud'])!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProviderConfigsTable createAlias(String alias) {
    return $ProviderConfigsTable(attachedDatabase, alias);
  }
}

class ProviderConfigRow extends DataClass implements Insertable<ProviderConfigRow> {
  final String id;

  /// `llm`, `asr`, `translation`.
  final String kind;
  final String preset;
  final String label;
  final String? baseUrl;
  final String? model;
  final String? secretRef;
  final bool cloud;

  /// Off until the user explicitly enables it.
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ProviderConfigRow({
    required this.id,
    required this.kind,
    required this.preset,
    required this.label,
    this.baseUrl,
    this.model,
    this.secretRef,
    required this.cloud,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['preset'] = Variable<String>(preset);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || baseUrl != null) {
      map['base_url'] = Variable<String>(baseUrl);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || secretRef != null) {
      map['secret_ref'] = Variable<String>(secretRef);
    }
    map['cloud'] = Variable<bool>(cloud);
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProviderConfigsCompanion toCompanion(bool nullToAbsent) {
    return ProviderConfigsCompanion(
      id: Value(id),
      kind: Value(kind),
      preset: Value(preset),
      label: Value(label),
      baseUrl: baseUrl == null && nullToAbsent ? const Value.absent() : Value(baseUrl),
      model: model == null && nullToAbsent ? const Value.absent() : Value(model),
      secretRef: secretRef == null && nullToAbsent ? const Value.absent() : Value(secretRef),
      cloud: Value(cloud),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProviderConfigRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderConfigRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      preset: serializer.fromJson<String>(json['preset']),
      label: serializer.fromJson<String>(json['label']),
      baseUrl: serializer.fromJson<String?>(json['baseUrl']),
      model: serializer.fromJson<String?>(json['model']),
      secretRef: serializer.fromJson<String?>(json['secretRef']),
      cloud: serializer.fromJson<bool>(json['cloud']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'preset': serializer.toJson<String>(preset),
      'label': serializer.toJson<String>(label),
      'baseUrl': serializer.toJson<String?>(baseUrl),
      'model': serializer.toJson<String?>(model),
      'secretRef': serializer.toJson<String?>(secretRef),
      'cloud': serializer.toJson<bool>(cloud),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProviderConfigRow copyWith({
    String? id,
    String? kind,
    String? preset,
    String? label,
    Value<String?> baseUrl = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<String?> secretRef = const Value.absent(),
    bool? cloud,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ProviderConfigRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    preset: preset ?? this.preset,
    label: label ?? this.label,
    baseUrl: baseUrl.present ? baseUrl.value : this.baseUrl,
    model: model.present ? model.value : this.model,
    secretRef: secretRef.present ? secretRef.value : this.secretRef,
    cloud: cloud ?? this.cloud,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProviderConfigRow copyWithCompanion(ProviderConfigsCompanion data) {
    return ProviderConfigRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      preset: data.preset.present ? data.preset.value : this.preset,
      label: data.label.present ? data.label.value : this.label,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      model: data.model.present ? data.model.value : this.model,
      secretRef: data.secretRef.present ? data.secretRef.value : this.secretRef,
      cloud: data.cloud.present ? data.cloud.value : this.cloud,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderConfigRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('preset: $preset, ')
          ..write('label: $label, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('model: $model, ')
          ..write('secretRef: $secretRef, ')
          ..write('cloud: $cloud, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    preset,
    label,
    baseUrl,
    model,
    secretRef,
    cloud,
    enabled,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderConfigRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.preset == this.preset &&
          other.label == this.label &&
          other.baseUrl == this.baseUrl &&
          other.model == this.model &&
          other.secretRef == this.secretRef &&
          other.cloud == this.cloud &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProviderConfigsCompanion extends UpdateCompanion<ProviderConfigRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> preset;
  final Value<String> label;
  final Value<String?> baseUrl;
  final Value<String?> model;
  final Value<String?> secretRef;
  final Value<bool> cloud;
  final Value<bool> enabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProviderConfigsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.preset = const Value.absent(),
    this.label = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.model = const Value.absent(),
    this.secretRef = const Value.absent(),
    this.cloud = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderConfigsCompanion.insert({
    required String id,
    required String kind,
    required String preset,
    required String label,
    this.baseUrl = const Value.absent(),
    this.model = const Value.absent(),
    this.secretRef = const Value.absent(),
    this.cloud = const Value.absent(),
    this.enabled = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       preset = Value(preset),
       label = Value(label),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ProviderConfigRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? preset,
    Expression<String>? label,
    Expression<String>? baseUrl,
    Expression<String>? model,
    Expression<String>? secretRef,
    Expression<bool>? cloud,
    Expression<bool>? enabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (preset != null) 'preset': preset,
      if (label != null) 'label': label,
      if (baseUrl != null) 'base_url': baseUrl,
      if (model != null) 'model': model,
      if (secretRef != null) 'secret_ref': secretRef,
      if (cloud != null) 'cloud': cloud,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderConfigsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? preset,
    Value<String>? label,
    Value<String?>? baseUrl,
    Value<String?>? model,
    Value<String?>? secretRef,
    Value<bool>? cloud,
    Value<bool>? enabled,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProviderConfigsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      preset: preset ?? this.preset,
      label: label ?? this.label,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      secretRef: secretRef ?? this.secretRef,
      cloud: cloud ?? this.cloud,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (preset.present) {
      map['preset'] = Variable<String>(preset.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (secretRef.present) {
      map['secret_ref'] = Variable<String>(secretRef.value);
    }
    if (cloud.present) {
      map['cloud'] = Variable<bool>(cloud.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderConfigsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('preset: $preset, ')
          ..write('label: $label, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('model: $model, ')
          ..write('secretRef: $secretRef, ')
          ..write('cloud: $cloud, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FeatureRoutesTable extends FeatureRoutes
    with TableInfo<$FeatureRoutesTable, FeatureRouteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeatureRoutesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _featureMeta = const VerificationMeta('feature');
  @override
  late final GeneratedColumn<String> feature = GeneratedColumn<String>(
    'feature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta('providerId');
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES provider_config (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [feature, providerId, enabled];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feature_route';
  @override
  VerificationContext validateIntegrity(
    Insertable<FeatureRouteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('feature')) {
      context.handle(_featureMeta, feature.isAcceptableOrUnknown(data['feature']!, _featureMeta));
    } else if (isInserting) {
      context.missing(_featureMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta, enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {feature};
  @override
  FeatureRouteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FeatureRouteRow(
      feature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feature'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
    );
  }

  @override
  $FeatureRoutesTable createAlias(String alias) {
    return $FeatureRoutesTable(attachedDatabase, alias);
  }
}

class FeatureRouteRow extends DataClass implements Insertable<FeatureRouteRow> {
  final String feature;
  final String? providerId;
  final bool enabled;
  const FeatureRouteRow({required this.feature, this.providerId, required this.enabled});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['feature'] = Variable<String>(feature);
    if (!nullToAbsent || providerId != null) {
      map['provider_id'] = Variable<String>(providerId);
    }
    map['enabled'] = Variable<bool>(enabled);
    return map;
  }

  FeatureRoutesCompanion toCompanion(bool nullToAbsent) {
    return FeatureRoutesCompanion(
      feature: Value(feature),
      providerId: providerId == null && nullToAbsent ? const Value.absent() : Value(providerId),
      enabled: Value(enabled),
    );
  }

  factory FeatureRouteRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FeatureRouteRow(
      feature: serializer.fromJson<String>(json['feature']),
      providerId: serializer.fromJson<String?>(json['providerId']),
      enabled: serializer.fromJson<bool>(json['enabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'feature': serializer.toJson<String>(feature),
      'providerId': serializer.toJson<String?>(providerId),
      'enabled': serializer.toJson<bool>(enabled),
    };
  }

  FeatureRouteRow copyWith({
    String? feature,
    Value<String?> providerId = const Value.absent(),
    bool? enabled,
  }) => FeatureRouteRow(
    feature: feature ?? this.feature,
    providerId: providerId.present ? providerId.value : this.providerId,
    enabled: enabled ?? this.enabled,
  );
  FeatureRouteRow copyWithCompanion(FeatureRoutesCompanion data) {
    return FeatureRouteRow(
      feature: data.feature.present ? data.feature.value : this.feature,
      providerId: data.providerId.present ? data.providerId.value : this.providerId,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FeatureRouteRow(')
          ..write('feature: $feature, ')
          ..write('providerId: $providerId, ')
          ..write('enabled: $enabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(feature, providerId, enabled);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeatureRouteRow &&
          other.feature == this.feature &&
          other.providerId == this.providerId &&
          other.enabled == this.enabled);
}

class FeatureRoutesCompanion extends UpdateCompanion<FeatureRouteRow> {
  final Value<String> feature;
  final Value<String?> providerId;
  final Value<bool> enabled;
  final Value<int> rowid;
  const FeatureRoutesCompanion({
    this.feature = const Value.absent(),
    this.providerId = const Value.absent(),
    this.enabled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FeatureRoutesCompanion.insert({
    required String feature,
    this.providerId = const Value.absent(),
    this.enabled = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : feature = Value(feature);
  static Insertable<FeatureRouteRow> custom({
    Expression<String>? feature,
    Expression<String>? providerId,
    Expression<bool>? enabled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (feature != null) 'feature': feature,
      if (providerId != null) 'provider_id': providerId,
      if (enabled != null) 'enabled': enabled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FeatureRoutesCompanion copyWith({
    Value<String>? feature,
    Value<String?>? providerId,
    Value<bool>? enabled,
    Value<int>? rowid,
  }) {
    return FeatureRoutesCompanion(
      feature: feature ?? this.feature,
      providerId: providerId ?? this.providerId,
      enabled: enabled ?? this.enabled,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (feature.present) {
      map['feature'] = Variable<String>(feature.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeatureRoutesCompanion(')
          ..write('feature: $feature, ')
          ..write('providerId: $providerId, ')
          ..write('enabled: $enabled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LlmCacheTable extends LlmCache with TableInfo<$LlmCacheTable, LlmCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LlmCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta('providerId');
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _responseJsonMeta = const VerificationMeta('responseJson');
  @override
  late final GeneratedColumn<String> responseJson = GeneratedColumn<String>(
    'response_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, providerId, model, responseJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'llm_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<LlmCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('model')) {
      context.handle(_modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('response_json')) {
      context.handle(
        _responseJsonMeta,
        responseJson.isAcceptableOrUnknown(data['response_json']!, _responseJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_responseJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LlmCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LlmCacheRow(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      responseJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LlmCacheTable createAlias(String alias) {
    return $LlmCacheTable(attachedDatabase, alias);
  }
}

class LlmCacheRow extends DataClass implements Insertable<LlmCacheRow> {
  final String key;
  final String providerId;
  final String model;
  final String responseJson;
  final DateTime createdAt;
  const LlmCacheRow({
    required this.key,
    required this.providerId,
    required this.model,
    required this.responseJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['provider_id'] = Variable<String>(providerId);
    map['model'] = Variable<String>(model);
    map['response_json'] = Variable<String>(responseJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LlmCacheCompanion toCompanion(bool nullToAbsent) {
    return LlmCacheCompanion(
      key: Value(key),
      providerId: Value(providerId),
      model: Value(model),
      responseJson: Value(responseJson),
      createdAt: Value(createdAt),
    );
  }

  factory LlmCacheRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LlmCacheRow(
      key: serializer.fromJson<String>(json['key']),
      providerId: serializer.fromJson<String>(json['providerId']),
      model: serializer.fromJson<String>(json['model']),
      responseJson: serializer.fromJson<String>(json['responseJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'providerId': serializer.toJson<String>(providerId),
      'model': serializer.toJson<String>(model),
      'responseJson': serializer.toJson<String>(responseJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LlmCacheRow copyWith({
    String? key,
    String? providerId,
    String? model,
    String? responseJson,
    DateTime? createdAt,
  }) => LlmCacheRow(
    key: key ?? this.key,
    providerId: providerId ?? this.providerId,
    model: model ?? this.model,
    responseJson: responseJson ?? this.responseJson,
    createdAt: createdAt ?? this.createdAt,
  );
  LlmCacheRow copyWithCompanion(LlmCacheCompanion data) {
    return LlmCacheRow(
      key: data.key.present ? data.key.value : this.key,
      providerId: data.providerId.present ? data.providerId.value : this.providerId,
      model: data.model.present ? data.model.value : this.model,
      responseJson: data.responseJson.present ? data.responseJson.value : this.responseJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LlmCacheRow(')
          ..write('key: $key, ')
          ..write('providerId: $providerId, ')
          ..write('model: $model, ')
          ..write('responseJson: $responseJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, providerId, model, responseJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LlmCacheRow &&
          other.key == this.key &&
          other.providerId == this.providerId &&
          other.model == this.model &&
          other.responseJson == this.responseJson &&
          other.createdAt == this.createdAt);
}

class LlmCacheCompanion extends UpdateCompanion<LlmCacheRow> {
  final Value<String> key;
  final Value<String> providerId;
  final Value<String> model;
  final Value<String> responseJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LlmCacheCompanion({
    this.key = const Value.absent(),
    this.providerId = const Value.absent(),
    this.model = const Value.absent(),
    this.responseJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LlmCacheCompanion.insert({
    required String key,
    required String providerId,
    required String model,
    required String responseJson,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       providerId = Value(providerId),
       model = Value(model),
       responseJson = Value(responseJson),
       createdAt = Value(createdAt);
  static Insertable<LlmCacheRow> custom({
    Expression<String>? key,
    Expression<String>? providerId,
    Expression<String>? model,
    Expression<String>? responseJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (providerId != null) 'provider_id': providerId,
      if (model != null) 'model': model,
      if (responseJson != null) 'response_json': responseJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LlmCacheCompanion copyWith({
    Value<String>? key,
    Value<String>? providerId,
    Value<String>? model,
    Value<String>? responseJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LlmCacheCompanion(
      key: key ?? this.key,
      providerId: providerId ?? this.providerId,
      model: model ?? this.model,
      responseJson: responseJson ?? this.responseJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (responseJson.present) {
      map['response_json'] = Variable<String>(responseJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LlmCacheCompanion(')
          ..write('key: $key, ')
          ..write('providerId: $providerId, ')
          ..write('model: $model, ')
          ..write('responseJson: $responseJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PodcastFeedsTable extends PodcastFeeds with TableInfo<$PodcastFeedsTable, PodcastFeedRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PodcastFeedsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastFetchedAtMeta = const VerificationMeta('lastFetchedAt');
  @override
  late final GeneratedColumn<DateTime> lastFetchedAt = GeneratedColumn<DateTime>(
    'last_fetched_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, url, title, imageUrl, etag, lastFetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'podcast_feed';
  @override
  VerificationContext validateIntegrity(
    Insertable<PodcastFeedRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('url')) {
      context.handle(_urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(_etagMeta, etag.isAcceptableOrUnknown(data['etag']!, _etagMeta));
    }
    if (data.containsKey('last_fetched_at')) {
      context.handle(
        _lastFetchedAtMeta,
        lastFetchedAt.isAcceptableOrUnknown(data['last_fetched_at']!, _lastFetchedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PodcastFeedRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PodcastFeedRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      url: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}url'])!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      etag: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}etag']),
      lastFetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_fetched_at'],
      ),
    );
  }

  @override
  $PodcastFeedsTable createAlias(String alias) {
    return $PodcastFeedsTable(attachedDatabase, alias);
  }
}

class PodcastFeedRow extends DataClass implements Insertable<PodcastFeedRow> {
  final String id;
  final String url;
  final String title;
  final String? imageUrl;
  final String? etag;
  final DateTime? lastFetchedAt;
  const PodcastFeedRow({
    required this.id,
    required this.url,
    required this.title,
    this.imageUrl,
    this.etag,
    this.lastFetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['url'] = Variable<String>(url);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || lastFetchedAt != null) {
      map['last_fetched_at'] = Variable<DateTime>(lastFetchedAt);
    }
    return map;
  }

  PodcastFeedsCompanion toCompanion(bool nullToAbsent) {
    return PodcastFeedsCompanion(
      id: Value(id),
      url: Value(url),
      title: Value(title),
      imageUrl: imageUrl == null && nullToAbsent ? const Value.absent() : Value(imageUrl),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      lastFetchedAt: lastFetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastFetchedAt),
    );
  }

  factory PodcastFeedRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PodcastFeedRow(
      id: serializer.fromJson<String>(json['id']),
      url: serializer.fromJson<String>(json['url']),
      title: serializer.fromJson<String>(json['title']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      etag: serializer.fromJson<String?>(json['etag']),
      lastFetchedAt: serializer.fromJson<DateTime?>(json['lastFetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'url': serializer.toJson<String>(url),
      'title': serializer.toJson<String>(title),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'etag': serializer.toJson<String?>(etag),
      'lastFetchedAt': serializer.toJson<DateTime?>(lastFetchedAt),
    };
  }

  PodcastFeedRow copyWith({
    String? id,
    String? url,
    String? title,
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> etag = const Value.absent(),
    Value<DateTime?> lastFetchedAt = const Value.absent(),
  }) => PodcastFeedRow(
    id: id ?? this.id,
    url: url ?? this.url,
    title: title ?? this.title,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    etag: etag.present ? etag.value : this.etag,
    lastFetchedAt: lastFetchedAt.present ? lastFetchedAt.value : this.lastFetchedAt,
  );
  PodcastFeedRow copyWithCompanion(PodcastFeedsCompanion data) {
    return PodcastFeedRow(
      id: data.id.present ? data.id.value : this.id,
      url: data.url.present ? data.url.value : this.url,
      title: data.title.present ? data.title.value : this.title,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      etag: data.etag.present ? data.etag.value : this.etag,
      lastFetchedAt: data.lastFetchedAt.present ? data.lastFetchedAt.value : this.lastFetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PodcastFeedRow(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('etag: $etag, ')
          ..write('lastFetchedAt: $lastFetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, url, title, imageUrl, etag, lastFetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PodcastFeedRow &&
          other.id == this.id &&
          other.url == this.url &&
          other.title == this.title &&
          other.imageUrl == this.imageUrl &&
          other.etag == this.etag &&
          other.lastFetchedAt == this.lastFetchedAt);
}

class PodcastFeedsCompanion extends UpdateCompanion<PodcastFeedRow> {
  final Value<String> id;
  final Value<String> url;
  final Value<String> title;
  final Value<String?> imageUrl;
  final Value<String?> etag;
  final Value<DateTime?> lastFetchedAt;
  final Value<int> rowid;
  const PodcastFeedsCompanion({
    this.id = const Value.absent(),
    this.url = const Value.absent(),
    this.title = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastFetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PodcastFeedsCompanion.insert({
    required String id,
    required String url,
    required String title,
    this.imageUrl = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastFetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       url = Value(url),
       title = Value(title);
  static Insertable<PodcastFeedRow> custom({
    Expression<String>? id,
    Expression<String>? url,
    Expression<String>? title,
    Expression<String>? imageUrl,
    Expression<String>? etag,
    Expression<DateTime>? lastFetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (url != null) 'url': url,
      if (title != null) 'title': title,
      if (imageUrl != null) 'image_url': imageUrl,
      if (etag != null) 'etag': etag,
      if (lastFetchedAt != null) 'last_fetched_at': lastFetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PodcastFeedsCompanion copyWith({
    Value<String>? id,
    Value<String>? url,
    Value<String>? title,
    Value<String?>? imageUrl,
    Value<String?>? etag,
    Value<DateTime?>? lastFetchedAt,
    Value<int>? rowid,
  }) {
    return PodcastFeedsCompanion(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      etag: etag ?? this.etag,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (lastFetchedAt.present) {
      map['last_fetched_at'] = Variable<DateTime>(lastFetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PodcastFeedsCompanion(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('etag: $etag, ')
          ..write('lastFetchedAt: $lastFetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpisodesTable extends Episodes with TableInfo<$EpisodesTable, EpisodeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _feedIdMeta = const VerificationMeta('feedId');
  @override
  late final GeneratedColumn<String> feedId = GeneratedColumn<String>(
    'feed_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES podcast_feed (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _guidMeta = const VerificationMeta('guid');
  @override
  late final GeneratedColumn<String> guid = GeneratedColumn<String>(
    'guid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _audioUrlMeta = const VerificationMeta('audioUrl');
  @override
  late final GeneratedColumn<String> audioUrl = GeneratedColumn<String>(
    'audio_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta('publishedAt');
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
    'published_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaIdMeta = const VerificationMeta('mediaId');
  @override
  late final GeneratedColumn<String> mediaId = GeneratedColumn<String>(
    'media_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES media (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('new'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    feedId,
    guid,
    title,
    audioUrl,
    publishedAt,
    durationMs,
    mediaId,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episode';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpisodeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('feed_id')) {
      context.handle(_feedIdMeta, feedId.isAcceptableOrUnknown(data['feed_id']!, _feedIdMeta));
    } else if (isInserting) {
      context.missing(_feedIdMeta);
    }
    if (data.containsKey('guid')) {
      context.handle(_guidMeta, guid.isAcceptableOrUnknown(data['guid']!, _guidMeta));
    } else if (isInserting) {
      context.missing(_guidMeta);
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('audio_url')) {
      context.handle(
        _audioUrlMeta,
        audioUrl.isAcceptableOrUnknown(data['audio_url']!, _audioUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_audioUrlMeta);
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(data['published_at']!, _publishedAtMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('media_id')) {
      context.handle(_mediaIdMeta, mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta, status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {feedId, guid},
  ];
  @override
  EpisodeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpisodeRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      feedId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feed_id'],
      )!,
      guid: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}guid'])!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      audioUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_url'],
      )!,
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      mediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $EpisodesTable createAlias(String alias) {
    return $EpisodesTable(attachedDatabase, alias);
  }
}

class EpisodeRow extends DataClass implements Insertable<EpisodeRow> {
  final String id;
  final String feedId;
  final String guid;
  final String title;
  final String audioUrl;
  final DateTime? publishedAt;
  final int? durationMs;
  final String? mediaId;

  /// `new`, `downloaded`, `transcribed`, `course`.
  final String status;
  const EpisodeRow({
    required this.id,
    required this.feedId,
    required this.guid,
    required this.title,
    required this.audioUrl,
    this.publishedAt,
    this.durationMs,
    this.mediaId,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['feed_id'] = Variable<String>(feedId);
    map['guid'] = Variable<String>(guid);
    map['title'] = Variable<String>(title);
    map['audio_url'] = Variable<String>(audioUrl);
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<DateTime>(publishedAt);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || mediaId != null) {
      map['media_id'] = Variable<String>(mediaId);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  EpisodesCompanion toCompanion(bool nullToAbsent) {
    return EpisodesCompanion(
      id: Value(id),
      feedId: Value(feedId),
      guid: Value(guid),
      title: Value(title),
      audioUrl: Value(audioUrl),
      publishedAt: publishedAt == null && nullToAbsent ? const Value.absent() : Value(publishedAt),
      durationMs: durationMs == null && nullToAbsent ? const Value.absent() : Value(durationMs),
      mediaId: mediaId == null && nullToAbsent ? const Value.absent() : Value(mediaId),
      status: Value(status),
    );
  }

  factory EpisodeRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpisodeRow(
      id: serializer.fromJson<String>(json['id']),
      feedId: serializer.fromJson<String>(json['feedId']),
      guid: serializer.fromJson<String>(json['guid']),
      title: serializer.fromJson<String>(json['title']),
      audioUrl: serializer.fromJson<String>(json['audioUrl']),
      publishedAt: serializer.fromJson<DateTime?>(json['publishedAt']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      mediaId: serializer.fromJson<String?>(json['mediaId']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'feedId': serializer.toJson<String>(feedId),
      'guid': serializer.toJson<String>(guid),
      'title': serializer.toJson<String>(title),
      'audioUrl': serializer.toJson<String>(audioUrl),
      'publishedAt': serializer.toJson<DateTime?>(publishedAt),
      'durationMs': serializer.toJson<int?>(durationMs),
      'mediaId': serializer.toJson<String?>(mediaId),
      'status': serializer.toJson<String>(status),
    };
  }

  EpisodeRow copyWith({
    String? id,
    String? feedId,
    String? guid,
    String? title,
    String? audioUrl,
    Value<DateTime?> publishedAt = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<String?> mediaId = const Value.absent(),
    String? status,
  }) => EpisodeRow(
    id: id ?? this.id,
    feedId: feedId ?? this.feedId,
    guid: guid ?? this.guid,
    title: title ?? this.title,
    audioUrl: audioUrl ?? this.audioUrl,
    publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    mediaId: mediaId.present ? mediaId.value : this.mediaId,
    status: status ?? this.status,
  );
  EpisodeRow copyWithCompanion(EpisodesCompanion data) {
    return EpisodeRow(
      id: data.id.present ? data.id.value : this.id,
      feedId: data.feedId.present ? data.feedId.value : this.feedId,
      guid: data.guid.present ? data.guid.value : this.guid,
      title: data.title.present ? data.title.value : this.title,
      audioUrl: data.audioUrl.present ? data.audioUrl.value : this.audioUrl,
      publishedAt: data.publishedAt.present ? data.publishedAt.value : this.publishedAt,
      durationMs: data.durationMs.present ? data.durationMs.value : this.durationMs,
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeRow(')
          ..write('id: $id, ')
          ..write('feedId: $feedId, ')
          ..write('guid: $guid, ')
          ..write('title: $title, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('mediaId: $mediaId, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, feedId, guid, title, audioUrl, publishedAt, durationMs, mediaId, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpisodeRow &&
          other.id == this.id &&
          other.feedId == this.feedId &&
          other.guid == this.guid &&
          other.title == this.title &&
          other.audioUrl == this.audioUrl &&
          other.publishedAt == this.publishedAt &&
          other.durationMs == this.durationMs &&
          other.mediaId == this.mediaId &&
          other.status == this.status);
}

class EpisodesCompanion extends UpdateCompanion<EpisodeRow> {
  final Value<String> id;
  final Value<String> feedId;
  final Value<String> guid;
  final Value<String> title;
  final Value<String> audioUrl;
  final Value<DateTime?> publishedAt;
  final Value<int?> durationMs;
  final Value<String?> mediaId;
  final Value<String> status;
  final Value<int> rowid;
  const EpisodesCompanion({
    this.id = const Value.absent(),
    this.feedId = const Value.absent(),
    this.guid = const Value.absent(),
    this.title = const Value.absent(),
    this.audioUrl = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpisodesCompanion.insert({
    required String id,
    required String feedId,
    required String guid,
    required String title,
    required String audioUrl,
    this.publishedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       feedId = Value(feedId),
       guid = Value(guid),
       title = Value(title),
       audioUrl = Value(audioUrl);
  static Insertable<EpisodeRow> custom({
    Expression<String>? id,
    Expression<String>? feedId,
    Expression<String>? guid,
    Expression<String>? title,
    Expression<String>? audioUrl,
    Expression<DateTime>? publishedAt,
    Expression<int>? durationMs,
    Expression<String>? mediaId,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (feedId != null) 'feed_id': feedId,
      if (guid != null) 'guid': guid,
      if (title != null) 'title': title,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (publishedAt != null) 'published_at': publishedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (mediaId != null) 'media_id': mediaId,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpisodesCompanion copyWith({
    Value<String>? id,
    Value<String>? feedId,
    Value<String>? guid,
    Value<String>? title,
    Value<String>? audioUrl,
    Value<DateTime?>? publishedAt,
    Value<int?>? durationMs,
    Value<String?>? mediaId,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return EpisodesCompanion(
      id: id ?? this.id,
      feedId: feedId ?? this.feedId,
      guid: guid ?? this.guid,
      title: title ?? this.title,
      audioUrl: audioUrl ?? this.audioUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      durationMs: durationMs ?? this.durationMs,
      mediaId: mediaId ?? this.mediaId,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (feedId.present) {
      map['feed_id'] = Variable<String>(feedId.value);
    }
    if (guid.present) {
      map['guid'] = Variable<String>(guid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (audioUrl.present) {
      map['audio_url'] = Variable<String>(audioUrl.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (mediaId.present) {
      map['media_id'] = Variable<String>(mediaId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodesCompanion(')
          ..write('id: $id, ')
          ..write('feedId: $feedId, ')
          ..write('guid: $guid, ')
          ..write('title: $title, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('mediaId: $mediaId, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DraftsTable extends Drafts with TableInfo<$DraftsTable, DraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, body];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'draft';
  @override
  VerificationContext validateIntegrity(Insertable<DraftRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('body')) {
      context.handle(_bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  DraftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DraftRow(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      body: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}body'])!,
    );
  }

  @override
  $DraftsTable createAlias(String alias) {
    return $DraftsTable(attachedDatabase, alias);
  }
}

class DraftRow extends DataClass implements Insertable<DraftRow> {
  final String key;
  final String body;
  const DraftRow({required this.key, required this.body});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['body'] = Variable<String>(body);
    return map;
  }

  DraftsCompanion toCompanion(bool nullToAbsent) {
    return DraftsCompanion(key: Value(key), body: Value(body));
  }

  factory DraftRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DraftRow(
      key: serializer.fromJson<String>(json['key']),
      body: serializer.fromJson<String>(json['body']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'body': serializer.toJson<String>(body),
    };
  }

  DraftRow copyWith({String? key, String? body}) =>
      DraftRow(key: key ?? this.key, body: body ?? this.body);
  DraftRow copyWithCompanion(DraftsCompanion data) {
    return DraftRow(
      key: data.key.present ? data.key.value : this.key,
      body: data.body.present ? data.body.value : this.body,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DraftRow(')
          ..write('key: $key, ')
          ..write('body: $body')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, body);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DraftRow && other.key == this.key && other.body == this.body);
}

class DraftsCompanion extends UpdateCompanion<DraftRow> {
  final Value<String> key;
  final Value<String> body;
  final Value<int> rowid;
  const DraftsCompanion({
    this.key = const Value.absent(),
    this.body = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DraftsCompanion.insert({
    required String key,
    required String body,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       body = Value(body);
  static Insertable<DraftRow> custom({
    Expression<String>? key,
    Expression<String>? body,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (body != null) 'body': body,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DraftsCompanion copyWith({Value<String>? key, Value<String>? body, Value<int>? rowid}) {
    return DraftsCompanion(
      key: key ?? this.key,
      body: body ?? this.body,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftsCompanion(')
          ..write('key: $key, ')
          ..write('body: $body, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppMetaTable extends AppMeta with TableInfo<$AppMetaTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_meta';
  @override
  VerificationContext validateIntegrity(Insertable<MetaRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppMetaTable createAlias(String alias) {
    return $AppMetaTable(attachedDatabase, alias);
  }
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  final String key;
  final String value;
  const MetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppMetaCompanion toCompanion(bool nullToAbsent) {
    return AppMetaCompanion(key: Value(key), value: Value(value));
  }

  factory MetaRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaRow copyWith({String? key, String? value}) =>
      MetaRow(key: key ?? this.key, value: value ?? this.value);
  MetaRow copyWithCompanion(AppMetaCompanion data) {
    return MetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaRow && other.key == this.key && other.value == this.value);
}

class AppMetaCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppMetaCompanion copyWith({Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return AppMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DictationAttemptsTable extends DictationAttempts
    with TableInfo<$DictationAttemptsTable, DictationAttemptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DictationAttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES session (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _segmentIdMeta = const VerificationMeta('segmentId');
  @override
  late final GeneratedColumn<String> segmentId = GeneratedColumn<String>(
    'segment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
    'answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _similarityMeta = const VerificationMeta('similarity');
  @override
  late final GeneratedColumn<double> similarity = GeneratedColumn<double>(
    'similarity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    segmentId,
    answer,
    result,
    similarity,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dictation_attempt';
  @override
  VerificationContext validateIntegrity(
    Insertable<DictationAttemptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('segment_id')) {
      context.handle(
        _segmentIdMeta,
        segmentId.isAcceptableOrUnknown(data['segment_id']!, _segmentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_segmentIdMeta);
    }
    if (data.containsKey('answer')) {
      context.handle(_answerMeta, answer.isAcceptableOrUnknown(data['answer']!, _answerMeta));
    } else if (isInserting) {
      context.missing(_answerMeta);
    }
    if (data.containsKey('result')) {
      context.handle(_resultMeta, result.isAcceptableOrUnknown(data['result']!, _resultMeta));
    } else if (isInserting) {
      context.missing(_resultMeta);
    }
    if (data.containsKey('similarity')) {
      context.handle(
        _similarityMeta,
        similarity.isAcceptableOrUnknown(data['similarity']!, _similarityMeta),
      );
    } else if (isInserting) {
      context.missing(_similarityMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DictationAttemptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DictationAttemptRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      segmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}segment_id'],
      )!,
      answer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer'],
      )!,
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      )!,
      similarity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}similarity'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DictationAttemptsTable createAlias(String alias) {
    return $DictationAttemptsTable(attachedDatabase, alias);
  }
}

class DictationAttemptRow extends DataClass implements Insertable<DictationAttemptRow> {
  final String id;
  final String sessionId;
  final String segmentId;
  final String answer;

  /// `correct`, `close` or `incorrect`.
  final String result;
  final double similarity;
  final DateTime createdAt;
  const DictationAttemptRow({
    required this.id,
    required this.sessionId,
    required this.segmentId,
    required this.answer,
    required this.result,
    required this.similarity,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['segment_id'] = Variable<String>(segmentId);
    map['answer'] = Variable<String>(answer);
    map['result'] = Variable<String>(result);
    map['similarity'] = Variable<double>(similarity);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DictationAttemptsCompanion toCompanion(bool nullToAbsent) {
    return DictationAttemptsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      segmentId: Value(segmentId),
      answer: Value(answer),
      result: Value(result),
      similarity: Value(similarity),
      createdAt: Value(createdAt),
    );
  }

  factory DictationAttemptRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DictationAttemptRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      segmentId: serializer.fromJson<String>(json['segmentId']),
      answer: serializer.fromJson<String>(json['answer']),
      result: serializer.fromJson<String>(json['result']),
      similarity: serializer.fromJson<double>(json['similarity']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'segmentId': serializer.toJson<String>(segmentId),
      'answer': serializer.toJson<String>(answer),
      'result': serializer.toJson<String>(result),
      'similarity': serializer.toJson<double>(similarity),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DictationAttemptRow copyWith({
    String? id,
    String? sessionId,
    String? segmentId,
    String? answer,
    String? result,
    double? similarity,
    DateTime? createdAt,
  }) => DictationAttemptRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    segmentId: segmentId ?? this.segmentId,
    answer: answer ?? this.answer,
    result: result ?? this.result,
    similarity: similarity ?? this.similarity,
    createdAt: createdAt ?? this.createdAt,
  );
  DictationAttemptRow copyWithCompanion(DictationAttemptsCompanion data) {
    return DictationAttemptRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      segmentId: data.segmentId.present ? data.segmentId.value : this.segmentId,
      answer: data.answer.present ? data.answer.value : this.answer,
      result: data.result.present ? data.result.value : this.result,
      similarity: data.similarity.present ? data.similarity.value : this.similarity,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictationAttemptRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('segmentId: $segmentId, ')
          ..write('answer: $answer, ')
          ..write('result: $result, ')
          ..write('similarity: $similarity, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, segmentId, answer, result, similarity, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictationAttemptRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.segmentId == this.segmentId &&
          other.answer == this.answer &&
          other.result == this.result &&
          other.similarity == this.similarity &&
          other.createdAt == this.createdAt);
}

class DictationAttemptsCompanion extends UpdateCompanion<DictationAttemptRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> segmentId;
  final Value<String> answer;
  final Value<String> result;
  final Value<double> similarity;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DictationAttemptsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.segmentId = const Value.absent(),
    this.answer = const Value.absent(),
    this.result = const Value.absent(),
    this.similarity = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DictationAttemptsCompanion.insert({
    required String id,
    required String sessionId,
    required String segmentId,
    required String answer,
    required String result,
    required double similarity,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       segmentId = Value(segmentId),
       answer = Value(answer),
       result = Value(result),
       similarity = Value(similarity),
       createdAt = Value(createdAt);
  static Insertable<DictationAttemptRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? segmentId,
    Expression<String>? answer,
    Expression<String>? result,
    Expression<double>? similarity,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (segmentId != null) 'segment_id': segmentId,
      if (answer != null) 'answer': answer,
      if (result != null) 'result': result,
      if (similarity != null) 'similarity': similarity,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DictationAttemptsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? segmentId,
    Value<String>? answer,
    Value<String>? result,
    Value<double>? similarity,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return DictationAttemptsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      segmentId: segmentId ?? this.segmentId,
      answer: answer ?? this.answer,
      result: result ?? this.result,
      similarity: similarity ?? this.similarity,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (segmentId.present) {
      map['segment_id'] = Variable<String>(segmentId.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (similarity.present) {
      map['similarity'] = Variable<double>(similarity.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictationAttemptsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('segmentId: $segmentId, ')
          ..write('answer: $answer, ')
          ..write('result: $result, ')
          ..write('similarity: $similarity, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncRecordsTable extends SyncRecords with TableInfo<$SyncRecordsTable, SyncRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localHashMeta = const VerificationMeta('localHash');
  @override
  late final GeneratedColumn<String> localHash = GeneratedColumn<String>(
    'local_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceMeta = const VerificationMeta('device');
  @override
  late final GeneratedColumn<String> device = GeneratedColumn<String>(
    'device',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [kind, key, localHash, updatedAt, device, deleted, hash];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_record';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('local_hash')) {
      context.handle(
        _localHashMeta,
        localHash.isAcceptableOrUnknown(data['local_hash']!, _localHashMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device')) {
      context.handle(_deviceMeta, device.isAcceptableOrUnknown(data['device']!, _deviceMeta));
    } else if (isInserting) {
      context.missing(_deviceMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta, deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('hash')) {
      context.handle(_hashMeta, hash.isAcceptableOrUnknown(data['hash']!, _hashMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind, key};
  @override
  SyncRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncRecordRow(
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      localHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_hash'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      device: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      hash: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hash']),
    );
  }

  @override
  $SyncRecordsTable createAlias(String alias) {
    return $SyncRecordsTable(attachedDatabase, alias);
  }
}

class SyncRecordRow extends DataClass implements Insertable<SyncRecordRow> {
  /// `course`, `session`, `progress`, `draft`, `card`, `attempt`,
  /// `dictation`.
  final String kind;
  final String key;

  /// Hash of the local copy as it was when it matched this version; null
  /// once deleted. A different hash later means a change made on this Mac.
  final String? localHash;

  /// The version this Mac has: when it was made (ms since the epoch, UTC)
  /// and on which device. Newer (time, then device id) wins.
  final int updatedAt;
  final String device;

  /// The version is a deletion (a tombstone).
  final bool deleted;

  /// Content hash published with the version; packages are checked against it.
  final String? hash;
  const SyncRecordRow({
    required this.kind,
    required this.key,
    this.localHash,
    required this.updatedAt,
    required this.device,
    required this.deleted,
    this.hash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || localHash != null) {
      map['local_hash'] = Variable<String>(localHash);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    map['device'] = Variable<String>(device);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || hash != null) {
      map['hash'] = Variable<String>(hash);
    }
    return map;
  }

  SyncRecordsCompanion toCompanion(bool nullToAbsent) {
    return SyncRecordsCompanion(
      kind: Value(kind),
      key: Value(key),
      localHash: localHash == null && nullToAbsent ? const Value.absent() : Value(localHash),
      updatedAt: Value(updatedAt),
      device: Value(device),
      deleted: Value(deleted),
      hash: hash == null && nullToAbsent ? const Value.absent() : Value(hash),
    );
  }

  factory SyncRecordRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncRecordRow(
      kind: serializer.fromJson<String>(json['kind']),
      key: serializer.fromJson<String>(json['key']),
      localHash: serializer.fromJson<String?>(json['localHash']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      device: serializer.fromJson<String>(json['device']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      hash: serializer.fromJson<String?>(json['hash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'key': serializer.toJson<String>(key),
      'localHash': serializer.toJson<String?>(localHash),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'device': serializer.toJson<String>(device),
      'deleted': serializer.toJson<bool>(deleted),
      'hash': serializer.toJson<String?>(hash),
    };
  }

  SyncRecordRow copyWith({
    String? kind,
    String? key,
    Value<String?> localHash = const Value.absent(),
    int? updatedAt,
    String? device,
    bool? deleted,
    Value<String?> hash = const Value.absent(),
  }) => SyncRecordRow(
    kind: kind ?? this.kind,
    key: key ?? this.key,
    localHash: localHash.present ? localHash.value : this.localHash,
    updatedAt: updatedAt ?? this.updatedAt,
    device: device ?? this.device,
    deleted: deleted ?? this.deleted,
    hash: hash.present ? hash.value : this.hash,
  );
  SyncRecordRow copyWithCompanion(SyncRecordsCompanion data) {
    return SyncRecordRow(
      kind: data.kind.present ? data.kind.value : this.kind,
      key: data.key.present ? data.key.value : this.key,
      localHash: data.localHash.present ? data.localHash.value : this.localHash,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      device: data.device.present ? data.device.value : this.device,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      hash: data.hash.present ? data.hash.value : this.hash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncRecordRow(')
          ..write('kind: $kind, ')
          ..write('key: $key, ')
          ..write('localHash: $localHash, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('device: $device, ')
          ..write('deleted: $deleted, ')
          ..write('hash: $hash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kind, key, localHash, updatedAt, device, deleted, hash);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncRecordRow &&
          other.kind == this.kind &&
          other.key == this.key &&
          other.localHash == this.localHash &&
          other.updatedAt == this.updatedAt &&
          other.device == this.device &&
          other.deleted == this.deleted &&
          other.hash == this.hash);
}

class SyncRecordsCompanion extends UpdateCompanion<SyncRecordRow> {
  final Value<String> kind;
  final Value<String> key;
  final Value<String?> localHash;
  final Value<int> updatedAt;
  final Value<String> device;
  final Value<bool> deleted;
  final Value<String?> hash;
  final Value<int> rowid;
  const SyncRecordsCompanion({
    this.kind = const Value.absent(),
    this.key = const Value.absent(),
    this.localHash = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.device = const Value.absent(),
    this.deleted = const Value.absent(),
    this.hash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncRecordsCompanion.insert({
    required String kind,
    required String key,
    this.localHash = const Value.absent(),
    required int updatedAt,
    required String device,
    this.deleted = const Value.absent(),
    this.hash = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       key = Value(key),
       updatedAt = Value(updatedAt),
       device = Value(device);
  static Insertable<SyncRecordRow> custom({
    Expression<String>? kind,
    Expression<String>? key,
    Expression<String>? localHash,
    Expression<int>? updatedAt,
    Expression<String>? device,
    Expression<bool>? deleted,
    Expression<String>? hash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (key != null) 'key': key,
      if (localHash != null) 'local_hash': localHash,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (device != null) 'device': device,
      if (deleted != null) 'deleted': deleted,
      if (hash != null) 'hash': hash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncRecordsCompanion copyWith({
    Value<String>? kind,
    Value<String>? key,
    Value<String?>? localHash,
    Value<int>? updatedAt,
    Value<String>? device,
    Value<bool>? deleted,
    Value<String?>? hash,
    Value<int>? rowid,
  }) {
    return SyncRecordsCompanion(
      kind: kind ?? this.kind,
      key: key ?? this.key,
      localHash: localHash ?? this.localHash,
      updatedAt: updatedAt ?? this.updatedAt,
      device: device ?? this.device,
      deleted: deleted ?? this.deleted,
      hash: hash ?? this.hash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (localHash.present) {
      map['local_hash'] = Variable<String>(localHash.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (device.present) {
      map['device'] = Variable<String>(device.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncRecordsCompanion(')
          ..write('kind: $kind, ')
          ..write('key: $key, ')
          ..write('localHash: $localHash, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('device: $device, ')
          ..write('deleted: $deleted, ')
          ..write('hash: $hash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$TinglangDatabase extends GeneratedDatabase {
  _$TinglangDatabase(QueryExecutor e) : super(e);
  $TinglangDatabaseManager get managers => $TinglangDatabaseManager(this);
  late final $MediaTable media = $MediaTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $TimeAnchorsTable timeAnchors = $TimeAnchorsTable(this);
  late final $SegmentsTable segments = $SegmentsTable(this);
  late final $TranslationsTable translations = $TranslationsTable(this);
  late final $CoursesTable courses = $CoursesTable(this);
  late final $ClipsTable clips = $ClipsTable(this);
  late final $ItemsTable items = $ItemsTable(this);
  late final $ExercisesTable exercises = $ExercisesTable(this);
  late final $ProgressTable progress = $ProgressTable(this);
  late final $AttemptsTable attempts = $AttemptsTable(this);
  late final $CardsTable cards = $CardsTable(this);
  late final $ReviewLogsTable reviewLogs = $ReviewLogsTable(this);
  late final $ProviderConfigsTable providerConfigs = $ProviderConfigsTable(this);
  late final $FeatureRoutesTable featureRoutes = $FeatureRoutesTable(this);
  late final $LlmCacheTable llmCache = $LlmCacheTable(this);
  late final $PodcastFeedsTable podcastFeeds = $PodcastFeedsTable(this);
  late final $EpisodesTable episodes = $EpisodesTable(this);
  late final $DraftsTable drafts = $DraftsTable(this);
  late final $AppMetaTable appMeta = $AppMetaTable(this);
  late final $DictationAttemptsTable dictationAttempts = $DictationAttemptsTable(this);
  late final $SyncRecordsTable syncRecords = $SyncRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    media,
    sessions,
    timeAnchors,
    segments,
    translations,
    courses,
    clips,
    items,
    exercises,
    progress,
    attempts,
    cards,
    reviewLogs,
    providerConfigs,
    featureRoutes,
    llmCache,
    podcastFeeds,
    episodes,
    drafts,
    appMeta,
    dictationAttempts,
    syncRecords,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName('media', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('session', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('session', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('time_anchor', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('session', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('segment', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('segment', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('translation', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('course', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('clip', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('course', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('item', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('card', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('review_log', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('provider_config', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('feature_route', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('podcast_feed', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('episode', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('media', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('episode', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('session', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('dictation_attempt', kind: UpdateKind.delete)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options => const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$MediaTableCreateCompanionBuilder = MediaCompanion Function({
  required String id,
  required String kind,
  Value<String?> relPath,
  Value<String?> sha256,
  Value<int?> durationMs,
  Value<String> title,
  Value<String?> sourceUrl,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$MediaTableUpdateCompanionBuilder = MediaCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<String?> relPath,
  Value<String?> sha256,
  Value<int?> durationMs,
  Value<String> title,
  Value<String?> sourceUrl,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$MediaTableReferences
    extends BaseReferences<_$TinglangDatabase, $MediaTable, MediaRow> {
  $$MediaTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SessionsTable, List<SessionRow>> _sessionsRefsTable(
    _$TinglangDatabase db,
  ) => MultiTypedResultKey.fromTable(db.sessions, aliasName: 'media__id__session__media_id');

  $$SessionsTableProcessedTableManager get sessionsRefs {
    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.mediaId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sessionsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$EpisodesTable, List<EpisodeRow>> _episodesRefsTable(
    _$TinglangDatabase db,
  ) => MultiTypedResultKey.fromTable(db.episodes, aliasName: 'media__id__episode__media_id');

  $$EpisodesTableProcessedTableManager get episodesRefs {
    final manager = $$EpisodesTableTableManager(
      $_db,
      $_db.episodes,
    ).filter((f) => f.mediaId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_episodesRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$MediaTableFilterComposer extends Composer<_$TinglangDatabase, $MediaTable> {
  $$MediaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs =>
      $composableBuilder(column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> sessionsRefs(Expression<bool> Function($$SessionsTableFilterComposer f) f) {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.mediaId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> episodesRefs(Expression<bool> Function($$EpisodesTableFilterComposer f) f) {
    final $$EpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.mediaId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$EpisodesTableFilterComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MediaTableOrderingComposer extends Composer<_$TinglangDatabase, $MediaTable> {
  $$MediaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs =>
      $composableBuilder(column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$MediaTableAnnotationComposer extends Composer<_$TinglangDatabase, $MediaTable> {
  $$MediaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<int> get durationMs =>
      $composableBuilder(column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> sessionsRefs<T extends Object>(
    Expression<T> Function($$SessionsTableAnnotationComposer a) f,
  ) {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.mediaId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> episodesRefs<T extends Object>(
    Expression<T> Function($$EpisodesTableAnnotationComposer a) f,
  ) {
    final $$EpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.mediaId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$EpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MediaTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $MediaTable,
          MediaRow,
          $$MediaTableFilterComposer,
          $$MediaTableOrderingComposer,
          $$MediaTableAnnotationComposer,
          $$MediaTableCreateCompanionBuilder,
          $$MediaTableUpdateCompanionBuilder,
          (MediaRow, $$MediaTableReferences),
          MediaRow,
          PrefetchHooks Function({bool sessionsRefs, bool episodesRefs})
        > {
  $$MediaTableTableManager(_$TinglangDatabase db, $MediaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$MediaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$MediaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$MediaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> relPath = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaCompanion(
                id: id,
                kind: kind,
                relPath: relPath,
                sha256: sha256,
                durationMs: durationMs,
                title: title,
                sourceUrl: sourceUrl,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                Value<String?> relPath = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MediaCompanion.insert(
                id: id,
                kind: kind,
                relPath: relPath,
                sha256: sha256,
                durationMs: durationMs,
                title: title,
                sourceUrl: sourceUrl,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MediaTable, MediaRow>(table),
                  $$MediaTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionsRefs = false, episodesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (sessionsRefs) db.sessions,
                if (episodesRefs) db.episodes,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionsRefs)
                    await $_getPrefetchedData<MediaRow, $MediaTable, SessionRow>(
                      currentTable: table,
                      referencedTable: $$MediaTableReferences._sessionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MediaTableReferences(db, table, p0).sessionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.mediaId == item.id),
                      typedResults: items,
                    ),
                  if (episodesRefs)
                    await $_getPrefetchedData<MediaRow, $MediaTable, EpisodeRow>(
                      currentTable: table,
                      referencedTable: $$MediaTableReferences._episodesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MediaTableReferences(db, table, p0).episodesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.mediaId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MediaTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $MediaTable,
      MediaRow,
      $$MediaTableFilterComposer,
      $$MediaTableOrderingComposer,
      $$MediaTableAnnotationComposer,
      $$MediaTableCreateCompanionBuilder,
      $$MediaTableUpdateCompanionBuilder,
      (MediaRow, $$MediaTableReferences),
      MediaRow,
      PrefetchHooks Function({bool sessionsRefs, bool episodesRefs})
    >;
typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  required String id,
  Value<String?> mediaId,
  required String origin,
  required String timeBase,
  Value<String?> language,
  Value<String> title,
  required DateTime startedAt,
  Value<DateTime?> endedAt,
  Value<String> status,
  Value<String?> sourceRef,
  Value<int> rowid,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<String> id,
  Value<String?> mediaId,
  Value<String> origin,
  Value<String> timeBase,
  Value<String?> language,
  Value<String> title,
  Value<DateTime> startedAt,
  Value<DateTime?> endedAt,
  Value<String> status,
  Value<String?> sourceRef,
  Value<int> rowid,
});

final class $$SessionsTableReferences
    extends BaseReferences<_$TinglangDatabase, $SessionsTable, SessionRow> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MediaTable _mediaIdTable(_$TinglangDatabase db) =>
      db.media.createAlias('session__media_id__media__id');

  $$MediaTableProcessedTableManager? get mediaId {
    final $_column = $_itemColumn<String>('media_id');
    if ($_column == null) return null;
    final manager = $$MediaTableTableManager(
      $_db,
      $_db.media,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mediaIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$TimeAnchorsTable, List<TimeAnchorRow>> _timeAnchorsRefsTable(
    _$TinglangDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.timeAnchors,
    aliasName: 'session__id__time_anchor__session_id',
  );

  $$TimeAnchorsTableProcessedTableManager get timeAnchorsRefs {
    final manager = $$TimeAnchorsTableTableManager(
      $_db,
      $_db.timeAnchors,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_timeAnchorsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$SegmentsTable, List<SegmentRow>> _segmentsRefsTable(
    _$TinglangDatabase db,
  ) => MultiTypedResultKey.fromTable(db.segments, aliasName: 'session__id__segment__session_id');

  $$SegmentsTableProcessedTableManager get segmentsRefs {
    final manager = $$SegmentsTableTableManager(
      $_db,
      $_db.segments,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_segmentsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$DictationAttemptsTable, List<DictationAttemptRow>>
  _dictationAttemptsRefsTable(_$TinglangDatabase db) => MultiTypedResultKey.fromTable(
    db.dictationAttempts,
    aliasName: 'session__id__dictation_attempt__session_id',
  );

  $$DictationAttemptsTableProcessedTableManager get dictationAttemptsRefs {
    final manager = $$DictationAttemptsTableTableManager(
      $_db,
      $_db.dictationAttempts,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_dictationAttemptsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SessionsTableFilterComposer extends Composer<_$TinglangDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get timeBase =>
      $composableBuilder(column: $table.timeBase, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceRef =>
      $composableBuilder(column: $table.sourceRef, builder: (column) => ColumnFilters(column));

  $$MediaTableFilterComposer get mediaId {
    final $$MediaTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaId,
      referencedTable: $db.media,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MediaTableFilterComposer(
            $db: $db,
            $table: $db.media,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> timeAnchorsRefs(
    Expression<bool> Function($$TimeAnchorsTableFilterComposer f) f,
  ) {
    final $$TimeAnchorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timeAnchors,
      getReferencedColumn: (t) => t.sessionId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$TimeAnchorsTableFilterComposer(
            $db: $db,
            $table: $db.timeAnchors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> segmentsRefs(Expression<bool> Function($$SegmentsTableFilterComposer f) f) {
    final $$SegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.segments,
      getReferencedColumn: (t) => t.sessionId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SegmentsTableFilterComposer(
            $db: $db,
            $table: $db.segments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dictationAttemptsRefs(
    Expression<bool> Function($$DictationAttemptsTableFilterComposer f) f,
  ) {
    final $$DictationAttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dictationAttempts,
      getReferencedColumn: (t) => t.sessionId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$DictationAttemptsTableFilterComposer(
            $db: $db,
            $table: $db.dictationAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer extends Composer<_$TinglangDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get timeBase =>
      $composableBuilder(column: $table.timeBase, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceRef =>
      $composableBuilder(column: $table.sourceRef, builder: (column) => ColumnOrderings(column));

  $$MediaTableOrderingComposer get mediaId {
    final $$MediaTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaId,
      referencedTable: $db.media,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MediaTableOrderingComposer(
            $db: $db,
            $table: $db.media,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionsTableAnnotationComposer extends Composer<_$TinglangDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get timeBase =>
      $composableBuilder(column: $table.timeBase, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get sourceRef =>
      $composableBuilder(column: $table.sourceRef, builder: (column) => column);

  $$MediaTableAnnotationComposer get mediaId {
    final $$MediaTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaId,
      referencedTable: $db.media,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MediaTableAnnotationComposer(
            $db: $db,
            $table: $db.media,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> timeAnchorsRefs<T extends Object>(
    Expression<T> Function($$TimeAnchorsTableAnnotationComposer a) f,
  ) {
    final $$TimeAnchorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timeAnchors,
      getReferencedColumn: (t) => t.sessionId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$TimeAnchorsTableAnnotationComposer(
            $db: $db,
            $table: $db.timeAnchors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> segmentsRefs<T extends Object>(
    Expression<T> Function($$SegmentsTableAnnotationComposer a) f,
  ) {
    final $$SegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.segments,
      getReferencedColumn: (t) => t.sessionId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.segments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dictationAttemptsRefs<T extends Object>(
    Expression<T> Function($$DictationAttemptsTableAnnotationComposer a) f,
  ) {
    final $$DictationAttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dictationAttempts,
      getReferencedColumn: (t) => t.sessionId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$DictationAttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.dictationAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $SessionsTable,
          SessionRow,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (SessionRow, $$SessionsTableReferences),
          SessionRow,
          PrefetchHooks Function({
            bool mediaId,
            bool timeAnchorsRefs,
            bool segmentsRefs,
            bool dictationAttemptsRefs,
          })
        > {
  $$SessionsTableTableManager(_$TinglangDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> mediaId = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<String> timeBase = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> sourceRef = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                mediaId: mediaId,
                origin: origin,
                timeBase: timeBase,
                language: language,
                title: title,
                startedAt: startedAt,
                endedAt: endedAt,
                status: status,
                sourceRef: sourceRef,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> mediaId = const Value.absent(),
                required String origin,
                required String timeBase,
                Value<String?> language = const Value.absent(),
                Value<String> title = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> sourceRef = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                mediaId: mediaId,
                origin: origin,
                timeBase: timeBase,
                language: language,
                title: title,
                startedAt: startedAt,
                endedAt: endedAt,
                status: status,
                sourceRef: sourceRef,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionsTable, SessionRow>(table),
                  $$SessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                mediaId = false,
                timeAnchorsRefs = false,
                segmentsRefs = false,
                dictationAttemptsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (timeAnchorsRefs) db.timeAnchors,
                    if (segmentsRefs) db.segments,
                    if (dictationAttemptsRefs) db.dictationAttempts,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (mediaId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.mediaId,
                            referencedTable: $$SessionsTableReferences._mediaIdTable(db),
                            referencedColumn: $$SessionsTableReferences._mediaIdTable(db).id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (timeAnchorsRefs)
                        await $_getPrefetchedData<SessionRow, $SessionsTable, TimeAnchorRow>(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences._timeAnchorsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(db, table, p0).timeAnchorsRefs,
                          referencedItemsForCurrentItem: (item, referencedItems) =>
                              referencedItems.where((e) => e.sessionId == item.id),
                          typedResults: items,
                        ),
                      if (segmentsRefs)
                        await $_getPrefetchedData<SessionRow, $SessionsTable, SegmentRow>(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences._segmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(db, table, p0).segmentsRefs,
                          referencedItemsForCurrentItem: (item, referencedItems) =>
                              referencedItems.where((e) => e.sessionId == item.id),
                          typedResults: items,
                        ),
                      if (dictationAttemptsRefs)
                        await $_getPrefetchedData<SessionRow, $SessionsTable, DictationAttemptRow>(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences._dictationAttemptsRefsTable(
                            db,
                          ),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(db, table, p0).dictationAttemptsRefs,
                          referencedItemsForCurrentItem: (item, referencedItems) =>
                              referencedItems.where((e) => e.sessionId == item.id),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $SessionsTable,
      SessionRow,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (SessionRow, $$SessionsTableReferences),
      SessionRow,
      PrefetchHooks Function({
        bool mediaId,
        bool timeAnchorsRefs,
        bool segmentsRefs,
        bool dictationAttemptsRefs,
      })
    >;
typedef $$TimeAnchorsTableCreateCompanionBuilder = TimeAnchorsCompanion Function({
  Value<int> id,
  required String sessionId,
  required int sessionMs,
  Value<int?> mediaMs,
  Value<DateTime?> wallclock,
});
typedef $$TimeAnchorsTableUpdateCompanionBuilder = TimeAnchorsCompanion Function({
  Value<int> id,
  Value<String> sessionId,
  Value<int> sessionMs,
  Value<int?> mediaMs,
  Value<DateTime?> wallclock,
});

final class $$TimeAnchorsTableReferences
    extends BaseReferences<_$TinglangDatabase, $TimeAnchorsTable, TimeAnchorRow> {
  $$TimeAnchorsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$TinglangDatabase db) =>
      db.sessions.createAlias('time_anchor__session_id__session__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TimeAnchorsTableFilterComposer extends Composer<_$TinglangDatabase, $TimeAnchorsTable> {
  $$TimeAnchorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sessionMs =>
      $composableBuilder(column: $table.sessionMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get mediaMs =>
      $composableBuilder(column: $table.mediaMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get wallclock =>
      $composableBuilder(column: $table.wallclock, builder: (column) => ColumnFilters(column));

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimeAnchorsTableOrderingComposer extends Composer<_$TinglangDatabase, $TimeAnchorsTable> {
  $$TimeAnchorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sessionMs =>
      $composableBuilder(column: $table.sessionMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get mediaMs =>
      $composableBuilder(column: $table.mediaMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get wallclock =>
      $composableBuilder(column: $table.wallclock, builder: (column) => ColumnOrderings(column));

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimeAnchorsTableAnnotationComposer extends Composer<_$TinglangDatabase, $TimeAnchorsTable> {
  $$TimeAnchorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sessionMs =>
      $composableBuilder(column: $table.sessionMs, builder: (column) => column);

  GeneratedColumn<int> get mediaMs =>
      $composableBuilder(column: $table.mediaMs, builder: (column) => column);

  GeneratedColumn<DateTime> get wallclock =>
      $composableBuilder(column: $table.wallclock, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimeAnchorsTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $TimeAnchorsTable,
          TimeAnchorRow,
          $$TimeAnchorsTableFilterComposer,
          $$TimeAnchorsTableOrderingComposer,
          $$TimeAnchorsTableAnnotationComposer,
          $$TimeAnchorsTableCreateCompanionBuilder,
          $$TimeAnchorsTableUpdateCompanionBuilder,
          (TimeAnchorRow, $$TimeAnchorsTableReferences),
          TimeAnchorRow,
          PrefetchHooks Function({bool sessionId})
        > {
  $$TimeAnchorsTableTableManager(_$TinglangDatabase db, $TimeAnchorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$TimeAnchorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$TimeAnchorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TimeAnchorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> sessionMs = const Value.absent(),
                Value<int?> mediaMs = const Value.absent(),
                Value<DateTime?> wallclock = const Value.absent(),
              }) => TimeAnchorsCompanion(
                id: id,
                sessionId: sessionId,
                sessionMs: sessionMs,
                mediaMs: mediaMs,
                wallclock: wallclock,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sessionId,
                required int sessionMs,
                Value<int?> mediaMs = const Value.absent(),
                Value<DateTime?> wallclock = const Value.absent(),
              }) => TimeAnchorsCompanion.insert(
                id: id,
                sessionId: sessionId,
                sessionMs: sessionMs,
                mediaMs: mediaMs,
                wallclock: wallclock,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TimeAnchorsTable, TimeAnchorRow>(table),
                  $$TimeAnchorsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$TimeAnchorsTableReferences._sessionIdTable(db),
                        referencedColumn: $$TimeAnchorsTableReferences._sessionIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TimeAnchorsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $TimeAnchorsTable,
      TimeAnchorRow,
      $$TimeAnchorsTableFilterComposer,
      $$TimeAnchorsTableOrderingComposer,
      $$TimeAnchorsTableAnnotationComposer,
      $$TimeAnchorsTableCreateCompanionBuilder,
      $$TimeAnchorsTableUpdateCompanionBuilder,
      (TimeAnchorRow, $$TimeAnchorsTableReferences),
      TimeAnchorRow,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$SegmentsTableCreateCompanionBuilder = SegmentsCompanion Function({
  required String id,
  required String sessionId,
  required int seq,
  required int startMs,
  required int endMs,
  required String body,
  Value<String?> language,
  Value<String?> wordsJson,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$SegmentsTableUpdateCompanionBuilder = SegmentsCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<int> seq,
  Value<int> startMs,
  Value<int> endMs,
  Value<String> body,
  Value<String?> language,
  Value<String?> wordsJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$SegmentsTableReferences
    extends BaseReferences<_$TinglangDatabase, $SegmentsTable, SegmentRow> {
  $$SegmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$TinglangDatabase db) =>
      db.sessions.createAlias('segment__session_id__session__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$TranslationsTable, List<TranslationRow>> _translationsRefsTable(
    _$TinglangDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.translations,
    aliasName: 'segment__id__translation__segment_id',
  );

  $$TranslationsTableProcessedTableManager get translationsRefs {
    final manager = $$TranslationsTableTableManager(
      $_db,
      $_db.translations,
    ).filter((f) => f.segmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_translationsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SegmentsTableFilterComposer extends Composer<_$TinglangDatabase, $SegmentsTable> {
  $$SegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get wordsJson =>
      $composableBuilder(column: $table.wordsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> translationsRefs(
    Expression<bool> Function($$TranslationsTableFilterComposer f) f,
  ) {
    final $$TranslationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.translations,
      getReferencedColumn: (t) => t.segmentId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$TranslationsTableFilterComposer(
            $db: $db,
            $table: $db.translations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SegmentsTableOrderingComposer extends Composer<_$TinglangDatabase, $SegmentsTable> {
  $$SegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get wordsJson =>
      $composableBuilder(column: $table.wordsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SegmentsTableAnnotationComposer extends Composer<_$TinglangDatabase, $SegmentsTable> {
  $$SegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get wordsJson =>
      $composableBuilder(column: $table.wordsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> translationsRefs<T extends Object>(
    Expression<T> Function($$TranslationsTableAnnotationComposer a) f,
  ) {
    final $$TranslationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.translations,
      getReferencedColumn: (t) => t.segmentId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$TranslationsTableAnnotationComposer(
            $db: $db,
            $table: $db.translations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SegmentsTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $SegmentsTable,
          SegmentRow,
          $$SegmentsTableFilterComposer,
          $$SegmentsTableOrderingComposer,
          $$SegmentsTableAnnotationComposer,
          $$SegmentsTableCreateCompanionBuilder,
          $$SegmentsTableUpdateCompanionBuilder,
          (SegmentRow, $$SegmentsTableReferences),
          SegmentRow,
          PrefetchHooks Function({bool sessionId, bool translationsRefs})
        > {
  $$SegmentsTableTableManager(_$TinglangDatabase db, $SegmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int> startMs = const Value.absent(),
                Value<int> endMs = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String?> wordsJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SegmentsCompanion(
                id: id,
                sessionId: sessionId,
                seq: seq,
                startMs: startMs,
                endMs: endMs,
                body: body,
                language: language,
                wordsJson: wordsJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required int seq,
                required int startMs,
                required int endMs,
                required String body,
                Value<String?> language = const Value.absent(),
                Value<String?> wordsJson = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SegmentsCompanion.insert(
                id: id,
                sessionId: sessionId,
                seq: seq,
                startMs: startMs,
                endMs: endMs,
                body: body,
                language: language,
                wordsJson: wordsJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SegmentsTable, SegmentRow>(table),
                  $$SegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false, translationsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (translationsRefs) db.translations],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$SegmentsTableReferences._sessionIdTable(db),
                        referencedColumn: $$SegmentsTableReferences._sessionIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (translationsRefs)
                    await $_getPrefetchedData<SegmentRow, $SegmentsTable, TranslationRow>(
                      currentTable: table,
                      referencedTable: $$SegmentsTableReferences._translationsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SegmentsTableReferences(db, table, p0).translationsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.segmentId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $SegmentsTable,
      SegmentRow,
      $$SegmentsTableFilterComposer,
      $$SegmentsTableOrderingComposer,
      $$SegmentsTableAnnotationComposer,
      $$SegmentsTableCreateCompanionBuilder,
      $$SegmentsTableUpdateCompanionBuilder,
      (SegmentRow, $$SegmentsTableReferences),
      SegmentRow,
      PrefetchHooks Function({bool sessionId, bool translationsRefs})
    >;
typedef $$TranslationsTableCreateCompanionBuilder = TranslationsCompanion Function({
  Value<int> id,
  required String segmentId,
  required String targetLang,
  required String body,
  required String provider,
  required String quality,
  required DateTime createdAt,
});
typedef $$TranslationsTableUpdateCompanionBuilder = TranslationsCompanion Function({
  Value<int> id,
  Value<String> segmentId,
  Value<String> targetLang,
  Value<String> body,
  Value<String> provider,
  Value<String> quality,
  Value<DateTime> createdAt,
});

final class $$TranslationsTableReferences
    extends BaseReferences<_$TinglangDatabase, $TranslationsTable, TranslationRow> {
  $$TranslationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SegmentsTable _segmentIdTable(_$TinglangDatabase db) =>
      db.segments.createAlias('translation__segment_id__segment__id');

  $$SegmentsTableProcessedTableManager get segmentId {
    final $_column = $_itemColumn<String>('segment_id')!;

    final manager = $$SegmentsTableTableManager(
      $_db,
      $_db.segments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_segmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TranslationsTableFilterComposer extends Composer<_$TinglangDatabase, $TranslationsTable> {
  $$TranslationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetLang =>
      $composableBuilder(column: $table.targetLang, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$SegmentsTableFilterComposer get segmentId {
    final $$SegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.segmentId,
      referencedTable: $db.segments,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SegmentsTableFilterComposer(
            $db: $db,
            $table: $db.segments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranslationsTableOrderingComposer extends Composer<_$TinglangDatabase, $TranslationsTable> {
  $$TranslationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetLang =>
      $composableBuilder(column: $table.targetLang, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$SegmentsTableOrderingComposer get segmentId {
    final $$SegmentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.segmentId,
      referencedTable: $db.segments,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SegmentsTableOrderingComposer(
            $db: $db,
            $table: $db.segments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranslationsTableAnnotationComposer
    extends Composer<_$TinglangDatabase, $TranslationsTable> {
  $$TranslationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetLang =>
      $composableBuilder(column: $table.targetLang, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SegmentsTableAnnotationComposer get segmentId {
    final $$SegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.segmentId,
      referencedTable: $db.segments,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.segments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranslationsTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $TranslationsTable,
          TranslationRow,
          $$TranslationsTableFilterComposer,
          $$TranslationsTableOrderingComposer,
          $$TranslationsTableAnnotationComposer,
          $$TranslationsTableCreateCompanionBuilder,
          $$TranslationsTableUpdateCompanionBuilder,
          (TranslationRow, $$TranslationsTableReferences),
          TranslationRow,
          PrefetchHooks Function({bool segmentId})
        > {
  $$TranslationsTableTableManager(_$TinglangDatabase db, $TranslationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$TranslationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$TranslationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranslationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> segmentId = const Value.absent(),
                Value<String> targetLang = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> quality = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TranslationsCompanion(
                id: id,
                segmentId: segmentId,
                targetLang: targetLang,
                body: body,
                provider: provider,
                quality: quality,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String segmentId,
                required String targetLang,
                required String body,
                required String provider,
                required String quality,
                required DateTime createdAt,
              }) => TranslationsCompanion.insert(
                id: id,
                segmentId: segmentId,
                targetLang: targetLang,
                body: body,
                provider: provider,
                quality: quality,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TranslationsTable, TranslationRow>(table),
                  $$TranslationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({segmentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (segmentId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.segmentId,
                        referencedTable: $$TranslationsTableReferences._segmentIdTable(db),
                        referencedColumn: $$TranslationsTableReferences._segmentIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TranslationsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $TranslationsTable,
      TranslationRow,
      $$TranslationsTableFilterComposer,
      $$TranslationsTableOrderingComposer,
      $$TranslationsTableAnnotationComposer,
      $$TranslationsTableCreateCompanionBuilder,
      $$TranslationsTableUpdateCompanionBuilder,
      (TranslationRow, $$TranslationsTableReferences),
      TranslationRow,
      PrefetchHooks Function({bool segmentId})
    >;
typedef $$CoursesTableCreateCompanionBuilder = CoursesCompanion Function({
  required String id,
  required String title,
  required String area,
  required String rawJson,
  Value<String?> mediaPath,
  Value<String> sourceLabel,
  required DateTime importedAt,
  Value<int> rowid,
});
typedef $$CoursesTableUpdateCompanionBuilder = CoursesCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> area,
  Value<String> rawJson,
  Value<String?> mediaPath,
  Value<String> sourceLabel,
  Value<DateTime> importedAt,
  Value<int> rowid,
});

final class $$CoursesTableReferences
    extends BaseReferences<_$TinglangDatabase, $CoursesTable, CourseRow> {
  $$CoursesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ClipsTable, List<ClipRow>> _clipsRefsTable(_$TinglangDatabase db) =>
      MultiTypedResultKey.fromTable(db.clips, aliasName: 'course__id__clip__course_id');

  $$ClipsTableProcessedTableManager get clipsRefs {
    final manager = $$ClipsTableTableManager(
      $_db,
      $_db.clips,
    ).filter((f) => f.courseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_clipsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ItemsTable, List<ItemRow>> _itemsRefsTable(_$TinglangDatabase db) =>
      MultiTypedResultKey.fromTable(db.items, aliasName: 'course__id__item__course_id');

  $$ItemsTableProcessedTableManager get itemsRefs {
    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.courseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_itemsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CoursesTableFilterComposer extends Composer<_$TinglangDatabase, $CoursesTable> {
  $$CoursesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get area =>
      $composableBuilder(column: $table.area, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaPath =>
      $composableBuilder(column: $table.mediaPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceLabel =>
      $composableBuilder(column: $table.sourceLabel, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get importedAt =>
      $composableBuilder(column: $table.importedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> clipsRefs(Expression<bool> Function($$ClipsTableFilterComposer f) f) {
    final $$ClipsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.clips,
      getReferencedColumn: (t) => t.courseId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ClipsTableFilterComposer(
            $db: $db,
            $table: $db.clips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> itemsRefs(Expression<bool> Function($$ItemsTableFilterComposer f) f) {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.courseId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CoursesTableOrderingComposer extends Composer<_$TinglangDatabase, $CoursesTable> {
  $$CoursesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get area =>
      $composableBuilder(column: $table.area, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaPath =>
      $composableBuilder(column: $table.mediaPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceLabel =>
      $composableBuilder(column: $table.sourceLabel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get importedAt =>
      $composableBuilder(column: $table.importedAt, builder: (column) => ColumnOrderings(column));
}

class $$CoursesTableAnnotationComposer extends Composer<_$TinglangDatabase, $CoursesTable> {
  $$CoursesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get area =>
      $composableBuilder(column: $table.area, builder: (column) => column);

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  GeneratedColumn<String> get mediaPath =>
      $composableBuilder(column: $table.mediaPath, builder: (column) => column);

  GeneratedColumn<String> get sourceLabel =>
      $composableBuilder(column: $table.sourceLabel, builder: (column) => column);

  GeneratedColumn<DateTime> get importedAt =>
      $composableBuilder(column: $table.importedAt, builder: (column) => column);

  Expression<T> clipsRefs<T extends Object>(
    Expression<T> Function($$ClipsTableAnnotationComposer a) f,
  ) {
    final $$ClipsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.clips,
      getReferencedColumn: (t) => t.courseId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ClipsTableAnnotationComposer(
            $db: $db,
            $table: $db.clips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> itemsRefs<T extends Object>(
    Expression<T> Function($$ItemsTableAnnotationComposer a) f,
  ) {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.courseId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CoursesTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $CoursesTable,
          CourseRow,
          $$CoursesTableFilterComposer,
          $$CoursesTableOrderingComposer,
          $$CoursesTableAnnotationComposer,
          $$CoursesTableCreateCompanionBuilder,
          $$CoursesTableUpdateCompanionBuilder,
          (CourseRow, $$CoursesTableReferences),
          CourseRow,
          PrefetchHooks Function({bool clipsRefs, bool itemsRefs})
        > {
  $$CoursesTableTableManager(_$TinglangDatabase db, $CoursesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CoursesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CoursesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoursesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> area = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<String?> mediaPath = const Value.absent(),
                Value<String> sourceLabel = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoursesCompanion(
                id: id,
                title: title,
                area: area,
                rawJson: rawJson,
                mediaPath: mediaPath,
                sourceLabel: sourceLabel,
                importedAt: importedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String area,
                required String rawJson,
                Value<String?> mediaPath = const Value.absent(),
                Value<String> sourceLabel = const Value.absent(),
                required DateTime importedAt,
                Value<int> rowid = const Value.absent(),
              }) => CoursesCompanion.insert(
                id: id,
                title: title,
                area: area,
                rawJson: rawJson,
                mediaPath: mediaPath,
                sourceLabel: sourceLabel,
                importedAt: importedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CoursesTable, CourseRow>(table),
                  $$CoursesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({clipsRefs = false, itemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (clipsRefs) db.clips, if (itemsRefs) db.items],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (clipsRefs)
                    await $_getPrefetchedData<CourseRow, $CoursesTable, ClipRow>(
                      currentTable: table,
                      referencedTable: $$CoursesTableReferences._clipsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CoursesTableReferences(db, table, p0).clipsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.courseId == item.id),
                      typedResults: items,
                    ),
                  if (itemsRefs)
                    await $_getPrefetchedData<CourseRow, $CoursesTable, ItemRow>(
                      currentTable: table,
                      referencedTable: $$CoursesTableReferences._itemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CoursesTableReferences(db, table, p0).itemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.courseId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CoursesTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $CoursesTable,
      CourseRow,
      $$CoursesTableFilterComposer,
      $$CoursesTableOrderingComposer,
      $$CoursesTableAnnotationComposer,
      $$CoursesTableCreateCompanionBuilder,
      $$CoursesTableUpdateCompanionBuilder,
      (CourseRow, $$CoursesTableReferences),
      CourseRow,
      PrefetchHooks Function({bool clipsRefs, bool itemsRefs})
    >;
typedef $$ClipsTableCreateCompanionBuilder = ClipsCompanion Function({
  required String courseId,
  required String id,
  required int ord,
  required String title,
  required int startMs,
  Value<int?> endMs,
  required String transcript,
  Value<int> rowid,
});
typedef $$ClipsTableUpdateCompanionBuilder = ClipsCompanion Function({
  Value<String> courseId,
  Value<String> id,
  Value<int> ord,
  Value<String> title,
  Value<int> startMs,
  Value<int?> endMs,
  Value<String> transcript,
  Value<int> rowid,
});

final class $$ClipsTableReferences
    extends BaseReferences<_$TinglangDatabase, $ClipsTable, ClipRow> {
  $$ClipsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CoursesTable _courseIdTable(_$TinglangDatabase db) =>
      db.courses.createAlias('clip__course_id__course__id');

  $$CoursesTableProcessedTableManager get courseId {
    final $_column = $_itemColumn<String>('course_id')!;

    final manager = $$CoursesTableTableManager(
      $_db,
      $_db.courses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_courseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ClipsTableFilterComposer extends Composer<_$TinglangDatabase, $ClipsTable> {
  $$ClipsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ord =>
      $composableBuilder(column: $table.ord, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get transcript =>
      $composableBuilder(column: $table.transcript, builder: (column) => ColumnFilters(column));

  $$CoursesTableFilterComposer get courseId {
    final $$CoursesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseId,
      referencedTable: $db.courses,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CoursesTableFilterComposer(
            $db: $db,
            $table: $db.courses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClipsTableOrderingComposer extends Composer<_$TinglangDatabase, $ClipsTable> {
  $$ClipsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ord =>
      $composableBuilder(column: $table.ord, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get transcript =>
      $composableBuilder(column: $table.transcript, builder: (column) => ColumnOrderings(column));

  $$CoursesTableOrderingComposer get courseId {
    final $$CoursesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseId,
      referencedTable: $db.courses,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CoursesTableOrderingComposer(
            $db: $db,
            $table: $db.courses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClipsTableAnnotationComposer extends Composer<_$TinglangDatabase, $ClipsTable> {
  $$ClipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ord =>
      $composableBuilder(column: $table.ord, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<String> get transcript =>
      $composableBuilder(column: $table.transcript, builder: (column) => column);

  $$CoursesTableAnnotationComposer get courseId {
    final $$CoursesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseId,
      referencedTable: $db.courses,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CoursesTableAnnotationComposer(
            $db: $db,
            $table: $db.courses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClipsTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $ClipsTable,
          ClipRow,
          $$ClipsTableFilterComposer,
          $$ClipsTableOrderingComposer,
          $$ClipsTableAnnotationComposer,
          $$ClipsTableCreateCompanionBuilder,
          $$ClipsTableUpdateCompanionBuilder,
          (ClipRow, $$ClipsTableReferences),
          ClipRow,
          PrefetchHooks Function({bool courseId})
        > {
  $$ClipsTableTableManager(_$TinglangDatabase db, $ClipsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ClipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ClipsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ClipsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> courseId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<int> ord = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> startMs = const Value.absent(),
                Value<int?> endMs = const Value.absent(),
                Value<String> transcript = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClipsCompanion(
                courseId: courseId,
                id: id,
                ord: ord,
                title: title,
                startMs: startMs,
                endMs: endMs,
                transcript: transcript,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String courseId,
                required String id,
                required int ord,
                required String title,
                required int startMs,
                Value<int?> endMs = const Value.absent(),
                required String transcript,
                Value<int> rowid = const Value.absent(),
              }) => ClipsCompanion.insert(
                courseId: courseId,
                id: id,
                ord: ord,
                title: title,
                startMs: startMs,
                endMs: endMs,
                transcript: transcript,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ClipsTable, ClipRow>(table),
                  $$ClipsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({courseId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (courseId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.courseId,
                        referencedTable: $$ClipsTableReferences._courseIdTable(db),
                        referencedColumn: $$ClipsTableReferences._courseIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ClipsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $ClipsTable,
      ClipRow,
      $$ClipsTableFilterComposer,
      $$ClipsTableOrderingComposer,
      $$ClipsTableAnnotationComposer,
      $$ClipsTableCreateCompanionBuilder,
      $$ClipsTableUpdateCompanionBuilder,
      (ClipRow, $$ClipsTableReferences),
      ClipRow,
      PrefetchHooks Function({bool courseId})
    >;
typedef $$ItemsTableCreateCompanionBuilder = ItemsCompanion Function({
  required String courseId,
  required String clipId,
  required String id,
  required String kind,
  required String body,
  Value<String> meaning,
  Value<int> rowid,
});
typedef $$ItemsTableUpdateCompanionBuilder = ItemsCompanion Function({
  Value<String> courseId,
  Value<String> clipId,
  Value<String> id,
  Value<String> kind,
  Value<String> body,
  Value<String> meaning,
  Value<int> rowid,
});

final class $$ItemsTableReferences
    extends BaseReferences<_$TinglangDatabase, $ItemsTable, ItemRow> {
  $$ItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CoursesTable _courseIdTable(_$TinglangDatabase db) =>
      db.courses.createAlias('item__course_id__course__id');

  $$CoursesTableProcessedTableManager get courseId {
    final $_column = $_itemColumn<String>('course_id')!;

    final manager = $$CoursesTableTableManager(
      $_db,
      $_db.courses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_courseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ItemsTableFilterComposer extends Composer<_$TinglangDatabase, $ItemsTable> {
  $$ItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clipId =>
      $composableBuilder(column: $table.clipId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get meaning =>
      $composableBuilder(column: $table.meaning, builder: (column) => ColumnFilters(column));

  $$CoursesTableFilterComposer get courseId {
    final $$CoursesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseId,
      referencedTable: $db.courses,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CoursesTableFilterComposer(
            $db: $db,
            $table: $db.courses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemsTableOrderingComposer extends Composer<_$TinglangDatabase, $ItemsTable> {
  $$ItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clipId =>
      $composableBuilder(column: $table.clipId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get meaning =>
      $composableBuilder(column: $table.meaning, builder: (column) => ColumnOrderings(column));

  $$CoursesTableOrderingComposer get courseId {
    final $$CoursesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseId,
      referencedTable: $db.courses,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CoursesTableOrderingComposer(
            $db: $db,
            $table: $db.courses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemsTableAnnotationComposer extends Composer<_$TinglangDatabase, $ItemsTable> {
  $$ItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clipId =>
      $composableBuilder(column: $table.clipId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get meaning =>
      $composableBuilder(column: $table.meaning, builder: (column) => column);

  $$CoursesTableAnnotationComposer get courseId {
    final $$CoursesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseId,
      referencedTable: $db.courses,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CoursesTableAnnotationComposer(
            $db: $db,
            $table: $db.courses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemsTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $ItemsTable,
          ItemRow,
          $$ItemsTableFilterComposer,
          $$ItemsTableOrderingComposer,
          $$ItemsTableAnnotationComposer,
          $$ItemsTableCreateCompanionBuilder,
          $$ItemsTableUpdateCompanionBuilder,
          (ItemRow, $$ItemsTableReferences),
          ItemRow,
          PrefetchHooks Function({bool courseId})
        > {
  $$ItemsTableTableManager(_$TinglangDatabase db, $ItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> courseId = const Value.absent(),
                Value<String> clipId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> meaning = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion(
                courseId: courseId,
                clipId: clipId,
                id: id,
                kind: kind,
                body: body,
                meaning: meaning,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String courseId,
                required String clipId,
                required String id,
                required String kind,
                required String body,
                Value<String> meaning = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion.insert(
                courseId: courseId,
                clipId: clipId,
                id: id,
                kind: kind,
                body: body,
                meaning: meaning,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ItemsTable, ItemRow>(table),
                  $$ItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({courseId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (courseId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.courseId,
                        referencedTable: $$ItemsTableReferences._courseIdTable(db),
                        referencedColumn: $$ItemsTableReferences._courseIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $ItemsTable,
      ItemRow,
      $$ItemsTableFilterComposer,
      $$ItemsTableOrderingComposer,
      $$ItemsTableAnnotationComposer,
      $$ItemsTableCreateCompanionBuilder,
      $$ItemsTableUpdateCompanionBuilder,
      (ItemRow, $$ItemsTableReferences),
      ItemRow,
      PrefetchHooks Function({bool courseId})
    >;
typedef $$ExercisesTableCreateCompanionBuilder = ExercisesCompanion Function({
  required String id,
  Value<String?> courseId,
  Value<String?> clipId,
  Value<String?> sessionId,
  required String kind,
  required String dataJson,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$ExercisesTableUpdateCompanionBuilder = ExercisesCompanion Function({
  Value<String> id,
  Value<String?> courseId,
  Value<String?> clipId,
  Value<String?> sessionId,
  Value<String> kind,
  Value<String> dataJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ExercisesTableFilterComposer extends Composer<_$TinglangDatabase, $ExercisesTable> {
  $$ExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clipId =>
      $composableBuilder(column: $table.clipId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ExercisesTableOrderingComposer extends Composer<_$TinglangDatabase, $ExercisesTable> {
  $$ExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clipId =>
      $composableBuilder(column: $table.clipId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ExercisesTableAnnotationComposer extends Composer<_$TinglangDatabase, $ExercisesTable> {
  $$ExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get clipId =>
      $composableBuilder(column: $table.clipId, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ExercisesTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $ExercisesTable,
          ExerciseRow,
          $$ExercisesTableFilterComposer,
          $$ExercisesTableOrderingComposer,
          $$ExercisesTableAnnotationComposer,
          $$ExercisesTableCreateCompanionBuilder,
          $$ExercisesTableUpdateCompanionBuilder,
          (ExerciseRow, BaseReferences<_$TinglangDatabase, $ExercisesTable, ExerciseRow>),
          ExerciseRow,
          PrefetchHooks Function()
        > {
  $$ExercisesTableTableManager(_$TinglangDatabase db, $ExercisesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> courseId = const Value.absent(),
                Value<String?> clipId = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExercisesCompanion(
                id: id,
                courseId: courseId,
                clipId: clipId,
                sessionId: sessionId,
                kind: kind,
                dataJson: dataJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> courseId = const Value.absent(),
                Value<String?> clipId = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                required String kind,
                required String dataJson,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ExercisesCompanion.insert(
                id: id,
                courseId: courseId,
                clipId: clipId,
                sessionId: sessionId,
                kind: kind,
                dataJson: dataJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExercisesTable, ExerciseRow>(table),
                  BaseReferences<_$TinglangDatabase, $ExercisesTable, ExerciseRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $ExercisesTable,
      ExerciseRow,
      $$ExercisesTableFilterComposer,
      $$ExercisesTableOrderingComposer,
      $$ExercisesTableAnnotationComposer,
      $$ExercisesTableCreateCompanionBuilder,
      $$ExercisesTableUpdateCompanionBuilder,
      (ExerciseRow, BaseReferences<_$TinglangDatabase, $ExercisesTable, ExerciseRow>),
      ExerciseRow,
      PrefetchHooks Function()
    >;
typedef $$ProgressTableCreateCompanionBuilder = ProgressCompanion Function({
  required String courseId,
  required String clipId,
  required String step,
  Value<int> rowid,
});
typedef $$ProgressTableUpdateCompanionBuilder = ProgressCompanion Function({
  Value<String> courseId,
  Value<String> clipId,
  Value<String> step,
  Value<int> rowid,
});

class $$ProgressTableFilterComposer extends Composer<_$TinglangDatabase, $ProgressTable> {
  $$ProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clipId =>
      $composableBuilder(column: $table.clipId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get step =>
      $composableBuilder(column: $table.step, builder: (column) => ColumnFilters(column));
}

class $$ProgressTableOrderingComposer extends Composer<_$TinglangDatabase, $ProgressTable> {
  $$ProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clipId =>
      $composableBuilder(column: $table.clipId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get step =>
      $composableBuilder(column: $table.step, builder: (column) => ColumnOrderings(column));
}

class $$ProgressTableAnnotationComposer extends Composer<_$TinglangDatabase, $ProgressTable> {
  $$ProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get clipId =>
      $composableBuilder(column: $table.clipId, builder: (column) => column);

  GeneratedColumn<String> get step =>
      $composableBuilder(column: $table.step, builder: (column) => column);
}

class $$ProgressTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $ProgressTable,
          ProgressRow,
          $$ProgressTableFilterComposer,
          $$ProgressTableOrderingComposer,
          $$ProgressTableAnnotationComposer,
          $$ProgressTableCreateCompanionBuilder,
          $$ProgressTableUpdateCompanionBuilder,
          (ProgressRow, BaseReferences<_$TinglangDatabase, $ProgressTable, ProgressRow>),
          ProgressRow,
          PrefetchHooks Function()
        > {
  $$ProgressTableTableManager(_$TinglangDatabase db, $ProgressTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> courseId = const Value.absent(),
            Value<String> clipId = const Value.absent(),
            Value<String> step = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => ProgressCompanion(courseId: courseId, clipId: clipId, step: step, rowid: rowid),
          createCompanionCallback:
              ({
                required String courseId,
                required String clipId,
                required String step,
                Value<int> rowid = const Value.absent(),
              }) => ProgressCompanion.insert(
                courseId: courseId,
                clipId: clipId,
                step: step,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProgressTable, ProgressRow>(table),
                  BaseReferences<_$TinglangDatabase, $ProgressTable, ProgressRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $ProgressTable,
      ProgressRow,
      $$ProgressTableFilterComposer,
      $$ProgressTableOrderingComposer,
      $$ProgressTableAnnotationComposer,
      $$ProgressTableCreateCompanionBuilder,
      $$ProgressTableUpdateCompanionBuilder,
      (ProgressRow, BaseReferences<_$TinglangDatabase, $ProgressTable, ProgressRow>),
      ProgressRow,
      PrefetchHooks Function()
    >;
typedef $$AttemptsTableCreateCompanionBuilder = AttemptsCompanion Function({
  required String id,
  required DateTime createdAt,
  required String kind,
  required String note,
  required int durationMs,
  Value<String?> courseId,
  Value<String?> clipId,
  Value<String?> recordingPath,
  Value<int> rowid,
});
typedef $$AttemptsTableUpdateCompanionBuilder = AttemptsCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<String> kind,
  Value<String> note,
  Value<int> durationMs,
  Value<String?> courseId,
  Value<String?> clipId,
  Value<String?> recordingPath,
  Value<int> rowid,
});

class $$AttemptsTableFilterComposer extends Composer<_$TinglangDatabase, $AttemptsTable> {
  $$AttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs =>
      $composableBuilder(column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clipId =>
      $composableBuilder(column: $table.clipId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordingPath =>
      $composableBuilder(column: $table.recordingPath, builder: (column) => ColumnFilters(column));
}

class $$AttemptsTableOrderingComposer extends Composer<_$TinglangDatabase, $AttemptsTable> {
  $$AttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs =>
      $composableBuilder(column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clipId =>
      $composableBuilder(column: $table.clipId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordingPath => $composableBuilder(
    column: $table.recordingPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttemptsTableAnnotationComposer extends Composer<_$TinglangDatabase, $AttemptsTable> {
  $$AttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get durationMs =>
      $composableBuilder(column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get clipId =>
      $composableBuilder(column: $table.clipId, builder: (column) => column);

  GeneratedColumn<String> get recordingPath =>
      $composableBuilder(column: $table.recordingPath, builder: (column) => column);
}

class $$AttemptsTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $AttemptsTable,
          AttemptRow,
          $$AttemptsTableFilterComposer,
          $$AttemptsTableOrderingComposer,
          $$AttemptsTableAnnotationComposer,
          $$AttemptsTableCreateCompanionBuilder,
          $$AttemptsTableUpdateCompanionBuilder,
          (AttemptRow, BaseReferences<_$TinglangDatabase, $AttemptsTable, AttemptRow>),
          AttemptRow,
          PrefetchHooks Function()
        > {
  $$AttemptsTableTableManager(_$TinglangDatabase db, $AttemptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$AttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$AttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String?> courseId = const Value.absent(),
                Value<String?> clipId = const Value.absent(),
                Value<String?> recordingPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttemptsCompanion(
                id: id,
                createdAt: createdAt,
                kind: kind,
                note: note,
                durationMs: durationMs,
                courseId: courseId,
                clipId: clipId,
                recordingPath: recordingPath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required String kind,
                required String note,
                required int durationMs,
                Value<String?> courseId = const Value.absent(),
                Value<String?> clipId = const Value.absent(),
                Value<String?> recordingPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttemptsCompanion.insert(
                id: id,
                createdAt: createdAt,
                kind: kind,
                note: note,
                durationMs: durationMs,
                courseId: courseId,
                clipId: clipId,
                recordingPath: recordingPath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttemptsTable, AttemptRow>(table),
                  BaseReferences<_$TinglangDatabase, $AttemptsTable, AttemptRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $AttemptsTable,
      AttemptRow,
      $$AttemptsTableFilterComposer,
      $$AttemptsTableOrderingComposer,
      $$AttemptsTableAnnotationComposer,
      $$AttemptsTableCreateCompanionBuilder,
      $$AttemptsTableUpdateCompanionBuilder,
      (AttemptRow, BaseReferences<_$TinglangDatabase, $AttemptsTable, AttemptRow>),
      AttemptRow,
      PrefetchHooks Function()
    >;
typedef $$CardsTableCreateCompanionBuilder = CardsCompanion Function({
  required String id,
  required String courseId,
  required String clipId,
  required String body,
  required String meaning,
  required DateTime dueAt,
  Value<int> repetitions,
  Value<String> scheduler,
  Value<double?> stability,
  Value<double?> difficulty,
  Value<int> rowid,
});
typedef $$CardsTableUpdateCompanionBuilder = CardsCompanion Function({
  Value<String> id,
  Value<String> courseId,
  Value<String> clipId,
  Value<String> body,
  Value<String> meaning,
  Value<DateTime> dueAt,
  Value<int> repetitions,
  Value<String> scheduler,
  Value<double?> stability,
  Value<double?> difficulty,
  Value<int> rowid,
});

final class $$CardsTableReferences
    extends BaseReferences<_$TinglangDatabase, $CardsTable, CardRow> {
  $$CardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ReviewLogsTable, List<ReviewLogRow>> _reviewLogsRefsTable(
    _$TinglangDatabase db,
  ) => MultiTypedResultKey.fromTable(db.reviewLogs, aliasName: 'card__id__review_log__card_id');

  $$ReviewLogsTableProcessedTableManager get reviewLogsRefs {
    final manager = $$ReviewLogsTableTableManager(
      $_db,
      $_db.reviewLogs,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_reviewLogsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CardsTableFilterComposer extends Composer<_$TinglangDatabase, $CardsTable> {
  $$CardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clipId =>
      $composableBuilder(column: $table.clipId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get meaning =>
      $composableBuilder(column: $table.meaning, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get repetitions =>
      $composableBuilder(column: $table.repetitions, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scheduler =>
      $composableBuilder(column: $table.scheduler, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get difficulty =>
      $composableBuilder(column: $table.difficulty, builder: (column) => ColumnFilters(column));

  Expression<bool> reviewLogsRefs(Expression<bool> Function($$ReviewLogsTableFilterComposer f) f) {
    final $$ReviewLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewLogs,
      getReferencedColumn: (t) => t.cardId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ReviewLogsTableFilterComposer(
            $db: $db,
            $table: $db.reviewLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardsTableOrderingComposer extends Composer<_$TinglangDatabase, $CardsTable> {
  $$CardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clipId =>
      $composableBuilder(column: $table.clipId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get meaning =>
      $composableBuilder(column: $table.meaning, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get repetitions =>
      $composableBuilder(column: $table.repetitions, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scheduler =>
      $composableBuilder(column: $table.scheduler, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get difficulty =>
      $composableBuilder(column: $table.difficulty, builder: (column) => ColumnOrderings(column));
}

class $$CardsTableAnnotationComposer extends Composer<_$TinglangDatabase, $CardsTable> {
  $$CardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get clipId =>
      $composableBuilder(column: $table.clipId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get meaning =>
      $composableBuilder(column: $table.meaning, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<int> get repetitions =>
      $composableBuilder(column: $table.repetitions, builder: (column) => column);

  GeneratedColumn<String> get scheduler =>
      $composableBuilder(column: $table.scheduler, builder: (column) => column);

  GeneratedColumn<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => column);

  GeneratedColumn<double> get difficulty =>
      $composableBuilder(column: $table.difficulty, builder: (column) => column);

  Expression<T> reviewLogsRefs<T extends Object>(
    Expression<T> Function($$ReviewLogsTableAnnotationComposer a) f,
  ) {
    final $$ReviewLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewLogs,
      getReferencedColumn: (t) => t.cardId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ReviewLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.reviewLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardsTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $CardsTable,
          CardRow,
          $$CardsTableFilterComposer,
          $$CardsTableOrderingComposer,
          $$CardsTableAnnotationComposer,
          $$CardsTableCreateCompanionBuilder,
          $$CardsTableUpdateCompanionBuilder,
          (CardRow, $$CardsTableReferences),
          CardRow,
          PrefetchHooks Function({bool reviewLogsRefs})
        > {
  $$CardsTableTableManager(_$TinglangDatabase db, $CardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String> clipId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> meaning = const Value.absent(),
                Value<DateTime> dueAt = const Value.absent(),
                Value<int> repetitions = const Value.absent(),
                Value<String> scheduler = const Value.absent(),
                Value<double?> stability = const Value.absent(),
                Value<double?> difficulty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion(
                id: id,
                courseId: courseId,
                clipId: clipId,
                body: body,
                meaning: meaning,
                dueAt: dueAt,
                repetitions: repetitions,
                scheduler: scheduler,
                stability: stability,
                difficulty: difficulty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String courseId,
                required String clipId,
                required String body,
                required String meaning,
                required DateTime dueAt,
                Value<int> repetitions = const Value.absent(),
                Value<String> scheduler = const Value.absent(),
                Value<double?> stability = const Value.absent(),
                Value<double?> difficulty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion.insert(
                id: id,
                courseId: courseId,
                clipId: clipId,
                body: body,
                meaning: meaning,
                dueAt: dueAt,
                repetitions: repetitions,
                scheduler: scheduler,
                stability: stability,
                difficulty: difficulty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CardsTable, CardRow>(table),
                  $$CardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({reviewLogsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (reviewLogsRefs) db.reviewLogs],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (reviewLogsRefs)
                    await $_getPrefetchedData<CardRow, $CardsTable, ReviewLogRow>(
                      currentTable: table,
                      referencedTable: $$CardsTableReferences._reviewLogsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CardsTableReferences(db, table, p0).reviewLogsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.cardId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CardsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $CardsTable,
      CardRow,
      $$CardsTableFilterComposer,
      $$CardsTableOrderingComposer,
      $$CardsTableAnnotationComposer,
      $$CardsTableCreateCompanionBuilder,
      $$CardsTableUpdateCompanionBuilder,
      (CardRow, $$CardsTableReferences),
      CardRow,
      PrefetchHooks Function({bool reviewLogsRefs})
    >;
typedef $$ReviewLogsTableCreateCompanionBuilder = ReviewLogsCompanion Function({
  required String cardId,
  required int seq,
  Value<DateTime?> reviewedAt,
  required String rating,
  required String dataJson,
  Value<int> rowid,
});
typedef $$ReviewLogsTableUpdateCompanionBuilder = ReviewLogsCompanion Function({
  Value<String> cardId,
  Value<int> seq,
  Value<DateTime?> reviewedAt,
  Value<String> rating,
  Value<String> dataJson,
  Value<int> rowid,
});

final class $$ReviewLogsTableReferences
    extends BaseReferences<_$TinglangDatabase, $ReviewLogsTable, ReviewLogRow> {
  $$ReviewLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CardsTable _cardIdTable(_$TinglangDatabase db) =>
      db.cards.createAlias('review_log__card_id__card__id');

  $$CardsTableProcessedTableManager get cardId {
    final $_column = $_itemColumn<String>('card_id')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ReviewLogsTableFilterComposer extends Composer<_$TinglangDatabase, $ReviewLogsTable> {
  $$ReviewLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get reviewedAt =>
      $composableBuilder(column: $table.reviewedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => ColumnFilters(column));

  $$CardsTableFilterComposer get cardId {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewLogsTableOrderingComposer extends Composer<_$TinglangDatabase, $ReviewLogsTable> {
  $$ReviewLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get reviewedAt =>
      $composableBuilder(column: $table.reviewedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => ColumnOrderings(column));

  $$CardsTableOrderingComposer get cardId {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewLogsTableAnnotationComposer extends Composer<_$TinglangDatabase, $ReviewLogsTable> {
  $$ReviewLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<DateTime> get reviewedAt =>
      $composableBuilder(column: $table.reviewedAt, builder: (column) => column);

  GeneratedColumn<String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  $$CardsTableAnnotationComposer get cardId {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewLogsTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $ReviewLogsTable,
          ReviewLogRow,
          $$ReviewLogsTableFilterComposer,
          $$ReviewLogsTableOrderingComposer,
          $$ReviewLogsTableAnnotationComposer,
          $$ReviewLogsTableCreateCompanionBuilder,
          $$ReviewLogsTableUpdateCompanionBuilder,
          (ReviewLogRow, $$ReviewLogsTableReferences),
          ReviewLogRow,
          PrefetchHooks Function({bool cardId})
        > {
  $$ReviewLogsTableTableManager(_$TinglangDatabase db, $ReviewLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ReviewLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ReviewLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cardId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<DateTime?> reviewedAt = const Value.absent(),
                Value<String> rating = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewLogsCompanion(
                cardId: cardId,
                seq: seq,
                reviewedAt: reviewedAt,
                rating: rating,
                dataJson: dataJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cardId,
                required int seq,
                Value<DateTime?> reviewedAt = const Value.absent(),
                required String rating,
                required String dataJson,
                Value<int> rowid = const Value.absent(),
              }) => ReviewLogsCompanion.insert(
                cardId: cardId,
                seq: seq,
                reviewedAt: reviewedAt,
                rating: rating,
                dataJson: dataJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReviewLogsTable, ReviewLogRow>(table),
                  $$ReviewLogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (cardId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.cardId,
                        referencedTable: $$ReviewLogsTableReferences._cardIdTable(db),
                        referencedColumn: $$ReviewLogsTableReferences._cardIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReviewLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $ReviewLogsTable,
      ReviewLogRow,
      $$ReviewLogsTableFilterComposer,
      $$ReviewLogsTableOrderingComposer,
      $$ReviewLogsTableAnnotationComposer,
      $$ReviewLogsTableCreateCompanionBuilder,
      $$ReviewLogsTableUpdateCompanionBuilder,
      (ReviewLogRow, $$ReviewLogsTableReferences),
      ReviewLogRow,
      PrefetchHooks Function({bool cardId})
    >;
typedef $$ProviderConfigsTableCreateCompanionBuilder = ProviderConfigsCompanion Function({
  required String id,
  required String kind,
  required String preset,
  required String label,
  Value<String?> baseUrl,
  Value<String?> model,
  Value<String?> secretRef,
  Value<bool> cloud,
  Value<bool> enabled,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ProviderConfigsTableUpdateCompanionBuilder = ProviderConfigsCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<String> preset,
  Value<String> label,
  Value<String?> baseUrl,
  Value<String?> model,
  Value<String?> secretRef,
  Value<bool> cloud,
  Value<bool> enabled,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$ProviderConfigsTableReferences
    extends BaseReferences<_$TinglangDatabase, $ProviderConfigsTable, ProviderConfigRow> {
  $$ProviderConfigsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FeatureRoutesTable, List<FeatureRouteRow>> _featureRoutesRefsTable(
    _$TinglangDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.featureRoutes,
    aliasName: 'provider_config__id__feature_route__provider_id',
  );

  $$FeatureRoutesTableProcessedTableManager get featureRoutesRefs {
    final manager = $$FeatureRoutesTableTableManager(
      $_db,
      $_db.featureRoutes,
    ).filter((f) => f.providerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_featureRoutesRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ProviderConfigsTableFilterComposer
    extends Composer<_$TinglangDatabase, $ProviderConfigsTable> {
  $$ProviderConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get preset =>
      $composableBuilder(column: $table.preset, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get secretRef =>
      $composableBuilder(column: $table.secretRef, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get cloud =>
      $composableBuilder(column: $table.cloud, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> featureRoutesRefs(
    Expression<bool> Function($$FeatureRoutesTableFilterComposer f) f,
  ) {
    final $$FeatureRoutesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.featureRoutes,
      getReferencedColumn: (t) => t.providerId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$FeatureRoutesTableFilterComposer(
            $db: $db,
            $table: $db.featureRoutes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProviderConfigsTableOrderingComposer
    extends Composer<_$TinglangDatabase, $ProviderConfigsTable> {
  $$ProviderConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preset =>
      $composableBuilder(column: $table.preset, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get secretRef =>
      $composableBuilder(column: $table.secretRef, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get cloud =>
      $composableBuilder(column: $table.cloud, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ProviderConfigsTableAnnotationComposer
    extends Composer<_$TinglangDatabase, $ProviderConfigsTable> {
  $$ProviderConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get preset =>
      $composableBuilder(column: $table.preset, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get secretRef =>
      $composableBuilder(column: $table.secretRef, builder: (column) => column);

  GeneratedColumn<bool> get cloud =>
      $composableBuilder(column: $table.cloud, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> featureRoutesRefs<T extends Object>(
    Expression<T> Function($$FeatureRoutesTableAnnotationComposer a) f,
  ) {
    final $$FeatureRoutesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.featureRoutes,
      getReferencedColumn: (t) => t.providerId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$FeatureRoutesTableAnnotationComposer(
            $db: $db,
            $table: $db.featureRoutes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProviderConfigsTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $ProviderConfigsTable,
          ProviderConfigRow,
          $$ProviderConfigsTableFilterComposer,
          $$ProviderConfigsTableOrderingComposer,
          $$ProviderConfigsTableAnnotationComposer,
          $$ProviderConfigsTableCreateCompanionBuilder,
          $$ProviderConfigsTableUpdateCompanionBuilder,
          (ProviderConfigRow, $$ProviderConfigsTableReferences),
          ProviderConfigRow,
          PrefetchHooks Function({bool featureRoutesRefs})
        > {
  $$ProviderConfigsTableTableManager(_$TinglangDatabase db, $ProviderConfigsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProviderConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> preset = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String?> baseUrl = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> secretRef = const Value.absent(),
                Value<bool> cloud = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderConfigsCompanion(
                id: id,
                kind: kind,
                preset: preset,
                label: label,
                baseUrl: baseUrl,
                model: model,
                secretRef: secretRef,
                cloud: cloud,
                enabled: enabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String preset,
                required String label,
                Value<String?> baseUrl = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> secretRef = const Value.absent(),
                Value<bool> cloud = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProviderConfigsCompanion.insert(
                id: id,
                kind: kind,
                preset: preset,
                label: label,
                baseUrl: baseUrl,
                model: model,
                secretRef: secretRef,
                cloud: cloud,
                enabled: enabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProviderConfigsTable, ProviderConfigRow>(table),
                  $$ProviderConfigsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({featureRoutesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (featureRoutesRefs) db.featureRoutes],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (featureRoutesRefs)
                    await $_getPrefetchedData<
                      ProviderConfigRow,
                      $ProviderConfigsTable,
                      FeatureRouteRow
                    >(
                      currentTable: table,
                      referencedTable: $$ProviderConfigsTableReferences._featureRoutesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ProviderConfigsTableReferences(db, table, p0).featureRoutesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.providerId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ProviderConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $ProviderConfigsTable,
      ProviderConfigRow,
      $$ProviderConfigsTableFilterComposer,
      $$ProviderConfigsTableOrderingComposer,
      $$ProviderConfigsTableAnnotationComposer,
      $$ProviderConfigsTableCreateCompanionBuilder,
      $$ProviderConfigsTableUpdateCompanionBuilder,
      (ProviderConfigRow, $$ProviderConfigsTableReferences),
      ProviderConfigRow,
      PrefetchHooks Function({bool featureRoutesRefs})
    >;
typedef $$FeatureRoutesTableCreateCompanionBuilder = FeatureRoutesCompanion Function({
  required String feature,
  Value<String?> providerId,
  Value<bool> enabled,
  Value<int> rowid,
});
typedef $$FeatureRoutesTableUpdateCompanionBuilder = FeatureRoutesCompanion Function({
  Value<String> feature,
  Value<String?> providerId,
  Value<bool> enabled,
  Value<int> rowid,
});

final class $$FeatureRoutesTableReferences
    extends BaseReferences<_$TinglangDatabase, $FeatureRoutesTable, FeatureRouteRow> {
  $$FeatureRoutesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProviderConfigsTable _providerIdTable(_$TinglangDatabase db) =>
      db.providerConfigs.createAlias('feature_route__provider_id__provider_config__id');

  $$ProviderConfigsTableProcessedTableManager? get providerId {
    final $_column = $_itemColumn<String>('provider_id');
    if ($_column == null) return null;
    final manager = $$ProviderConfigsTableTableManager(
      $_db,
      $_db.providerConfigs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_providerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$FeatureRoutesTableFilterComposer extends Composer<_$TinglangDatabase, $FeatureRoutesTable> {
  $$FeatureRoutesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get feature =>
      $composableBuilder(column: $table.feature, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => ColumnFilters(column));

  $$ProviderConfigsTableFilterComposer get providerId {
    final $$ProviderConfigsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.providerConfigs,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ProviderConfigsTableFilterComposer(
            $db: $db,
            $table: $db.providerConfigs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FeatureRoutesTableOrderingComposer
    extends Composer<_$TinglangDatabase, $FeatureRoutesTable> {
  $$FeatureRoutesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get feature =>
      $composableBuilder(column: $table.feature, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => ColumnOrderings(column));

  $$ProviderConfigsTableOrderingComposer get providerId {
    final $$ProviderConfigsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.providerConfigs,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ProviderConfigsTableOrderingComposer(
            $db: $db,
            $table: $db.providerConfigs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FeatureRoutesTableAnnotationComposer
    extends Composer<_$TinglangDatabase, $FeatureRoutesTable> {
  $$FeatureRoutesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get feature =>
      $composableBuilder(column: $table.feature, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  $$ProviderConfigsTableAnnotationComposer get providerId {
    final $$ProviderConfigsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.providerConfigs,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ProviderConfigsTableAnnotationComposer(
            $db: $db,
            $table: $db.providerConfigs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FeatureRoutesTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $FeatureRoutesTable,
          FeatureRouteRow,
          $$FeatureRoutesTableFilterComposer,
          $$FeatureRoutesTableOrderingComposer,
          $$FeatureRoutesTableAnnotationComposer,
          $$FeatureRoutesTableCreateCompanionBuilder,
          $$FeatureRoutesTableUpdateCompanionBuilder,
          (FeatureRouteRow, $$FeatureRoutesTableReferences),
          FeatureRouteRow,
          PrefetchHooks Function({bool providerId})
        > {
  $$FeatureRoutesTableTableManager(_$TinglangDatabase db, $FeatureRoutesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$FeatureRoutesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeatureRoutesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeatureRoutesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> feature = const Value.absent(),
                Value<String?> providerId = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FeatureRoutesCompanion(
                feature: feature,
                providerId: providerId,
                enabled: enabled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String feature,
                Value<String?> providerId = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FeatureRoutesCompanion.insert(
                feature: feature,
                providerId: providerId,
                enabled: enabled,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FeatureRoutesTable, FeatureRouteRow>(table),
                  $$FeatureRoutesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({providerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (providerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.providerId,
                        referencedTable: $$FeatureRoutesTableReferences._providerIdTable(db),
                        referencedColumn: $$FeatureRoutesTableReferences._providerIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FeatureRoutesTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $FeatureRoutesTable,
      FeatureRouteRow,
      $$FeatureRoutesTableFilterComposer,
      $$FeatureRoutesTableOrderingComposer,
      $$FeatureRoutesTableAnnotationComposer,
      $$FeatureRoutesTableCreateCompanionBuilder,
      $$FeatureRoutesTableUpdateCompanionBuilder,
      (FeatureRouteRow, $$FeatureRoutesTableReferences),
      FeatureRouteRow,
      PrefetchHooks Function({bool providerId})
    >;
typedef $$LlmCacheTableCreateCompanionBuilder = LlmCacheCompanion Function({
  required String key,
  required String providerId,
  required String model,
  required String responseJson,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$LlmCacheTableUpdateCompanionBuilder = LlmCacheCompanion Function({
  Value<String> key,
  Value<String> providerId,
  Value<String> model,
  Value<String> responseJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$LlmCacheTableFilterComposer extends Composer<_$TinglangDatabase, $LlmCacheTable> {
  $$LlmCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get providerId =>
      $composableBuilder(column: $table.providerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get responseJson =>
      $composableBuilder(column: $table.responseJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$LlmCacheTableOrderingComposer extends Composer<_$TinglangDatabase, $LlmCacheTable> {
  $$LlmCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get providerId =>
      $composableBuilder(column: $table.providerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get responseJson =>
      $composableBuilder(column: $table.responseJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LlmCacheTableAnnotationComposer extends Composer<_$TinglangDatabase, $LlmCacheTable> {
  $$LlmCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get providerId =>
      $composableBuilder(column: $table.providerId, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get responseJson =>
      $composableBuilder(column: $table.responseJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LlmCacheTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $LlmCacheTable,
          LlmCacheRow,
          $$LlmCacheTableFilterComposer,
          $$LlmCacheTableOrderingComposer,
          $$LlmCacheTableAnnotationComposer,
          $$LlmCacheTableCreateCompanionBuilder,
          $$LlmCacheTableUpdateCompanionBuilder,
          (LlmCacheRow, BaseReferences<_$TinglangDatabase, $LlmCacheTable, LlmCacheRow>),
          LlmCacheRow,
          PrefetchHooks Function()
        > {
  $$LlmCacheTableTableManager(_$TinglangDatabase db, $LlmCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$LlmCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$LlmCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LlmCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String> responseJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LlmCacheCompanion(
                key: key,
                providerId: providerId,
                model: model,
                responseJson: responseJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String providerId,
                required String model,
                required String responseJson,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LlmCacheCompanion.insert(
                key: key,
                providerId: providerId,
                model: model,
                responseJson: responseJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LlmCacheTable, LlmCacheRow>(table),
                  BaseReferences<_$TinglangDatabase, $LlmCacheTable, LlmCacheRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LlmCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $LlmCacheTable,
      LlmCacheRow,
      $$LlmCacheTableFilterComposer,
      $$LlmCacheTableOrderingComposer,
      $$LlmCacheTableAnnotationComposer,
      $$LlmCacheTableCreateCompanionBuilder,
      $$LlmCacheTableUpdateCompanionBuilder,
      (LlmCacheRow, BaseReferences<_$TinglangDatabase, $LlmCacheTable, LlmCacheRow>),
      LlmCacheRow,
      PrefetchHooks Function()
    >;
typedef $$PodcastFeedsTableCreateCompanionBuilder = PodcastFeedsCompanion Function({
  required String id,
  required String url,
  required String title,
  Value<String?> imageUrl,
  Value<String?> etag,
  Value<DateTime?> lastFetchedAt,
  Value<int> rowid,
});
typedef $$PodcastFeedsTableUpdateCompanionBuilder = PodcastFeedsCompanion Function({
  Value<String> id,
  Value<String> url,
  Value<String> title,
  Value<String?> imageUrl,
  Value<String?> etag,
  Value<DateTime?> lastFetchedAt,
  Value<int> rowid,
});

final class $$PodcastFeedsTableReferences
    extends BaseReferences<_$TinglangDatabase, $PodcastFeedsTable, PodcastFeedRow> {
  $$PodcastFeedsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EpisodesTable, List<EpisodeRow>> _episodesRefsTable(
    _$TinglangDatabase db,
  ) => MultiTypedResultKey.fromTable(db.episodes, aliasName: 'podcast_feed__id__episode__feed_id');

  $$EpisodesTableProcessedTableManager get episodesRefs {
    final manager = $$EpisodesTableTableManager(
      $_db,
      $_db.episodes,
    ).filter((f) => f.feedId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_episodesRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$PodcastFeedsTableFilterComposer extends Composer<_$TinglangDatabase, $PodcastFeedsTable> {
  $$PodcastFeedsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastFetchedAt =>
      $composableBuilder(column: $table.lastFetchedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> episodesRefs(Expression<bool> Function($$EpisodesTableFilterComposer f) f) {
    final $$EpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.feedId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$EpisodesTableFilterComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PodcastFeedsTableOrderingComposer extends Composer<_$TinglangDatabase, $PodcastFeedsTable> {
  $$PodcastFeedsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastFetchedAt => $composableBuilder(
    column: $table.lastFetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PodcastFeedsTableAnnotationComposer
    extends Composer<_$TinglangDatabase, $PodcastFeedsTable> {
  $$PodcastFeedsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<DateTime> get lastFetchedAt =>
      $composableBuilder(column: $table.lastFetchedAt, builder: (column) => column);

  Expression<T> episodesRefs<T extends Object>(
    Expression<T> Function($$EpisodesTableAnnotationComposer a) f,
  ) {
    final $$EpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.feedId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$EpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PodcastFeedsTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $PodcastFeedsTable,
          PodcastFeedRow,
          $$PodcastFeedsTableFilterComposer,
          $$PodcastFeedsTableOrderingComposer,
          $$PodcastFeedsTableAnnotationComposer,
          $$PodcastFeedsTableCreateCompanionBuilder,
          $$PodcastFeedsTableUpdateCompanionBuilder,
          (PodcastFeedRow, $$PodcastFeedsTableReferences),
          PodcastFeedRow,
          PrefetchHooks Function({bool episodesRefs})
        > {
  $$PodcastFeedsTableTableManager(_$TinglangDatabase db, $PodcastFeedsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$PodcastFeedsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$PodcastFeedsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PodcastFeedsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<DateTime?> lastFetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PodcastFeedsCompanion(
                id: id,
                url: url,
                title: title,
                imageUrl: imageUrl,
                etag: etag,
                lastFetchedAt: lastFetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String url,
                required String title,
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<DateTime?> lastFetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PodcastFeedsCompanion.insert(
                id: id,
                url: url,
                title: title,
                imageUrl: imageUrl,
                etag: etag,
                lastFetchedAt: lastFetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PodcastFeedsTable, PodcastFeedRow>(table),
                  $$PodcastFeedsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({episodesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (episodesRefs) db.episodes],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (episodesRefs)
                    await $_getPrefetchedData<PodcastFeedRow, $PodcastFeedsTable, EpisodeRow>(
                      currentTable: table,
                      referencedTable: $$PodcastFeedsTableReferences._episodesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PodcastFeedsTableReferences(db, table, p0).episodesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.feedId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PodcastFeedsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $PodcastFeedsTable,
      PodcastFeedRow,
      $$PodcastFeedsTableFilterComposer,
      $$PodcastFeedsTableOrderingComposer,
      $$PodcastFeedsTableAnnotationComposer,
      $$PodcastFeedsTableCreateCompanionBuilder,
      $$PodcastFeedsTableUpdateCompanionBuilder,
      (PodcastFeedRow, $$PodcastFeedsTableReferences),
      PodcastFeedRow,
      PrefetchHooks Function({bool episodesRefs})
    >;
typedef $$EpisodesTableCreateCompanionBuilder = EpisodesCompanion Function({
  required String id,
  required String feedId,
  required String guid,
  required String title,
  required String audioUrl,
  Value<DateTime?> publishedAt,
  Value<int?> durationMs,
  Value<String?> mediaId,
  Value<String> status,
  Value<int> rowid,
});
typedef $$EpisodesTableUpdateCompanionBuilder = EpisodesCompanion Function({
  Value<String> id,
  Value<String> feedId,
  Value<String> guid,
  Value<String> title,
  Value<String> audioUrl,
  Value<DateTime?> publishedAt,
  Value<int?> durationMs,
  Value<String?> mediaId,
  Value<String> status,
  Value<int> rowid,
});

final class $$EpisodesTableReferences
    extends BaseReferences<_$TinglangDatabase, $EpisodesTable, EpisodeRow> {
  $$EpisodesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PodcastFeedsTable _feedIdTable(_$TinglangDatabase db) =>
      db.podcastFeeds.createAlias('episode__feed_id__podcast_feed__id');

  $$PodcastFeedsTableProcessedTableManager get feedId {
    final $_column = $_itemColumn<String>('feed_id')!;

    final manager = $$PodcastFeedsTableTableManager(
      $_db,
      $_db.podcastFeeds,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_feedIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static $MediaTable _mediaIdTable(_$TinglangDatabase db) =>
      db.media.createAlias('episode__media_id__media__id');

  $$MediaTableProcessedTableManager? get mediaId {
    final $_column = $_itemColumn<String>('media_id');
    if ($_column == null) return null;
    final manager = $$MediaTableTableManager(
      $_db,
      $_db.media,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mediaIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$EpisodesTableFilterComposer extends Composer<_$TinglangDatabase, $EpisodesTable> {
  $$EpisodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get guid =>
      $composableBuilder(column: $table.guid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audioUrl =>
      $composableBuilder(column: $table.audioUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get publishedAt =>
      $composableBuilder(column: $table.publishedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs =>
      $composableBuilder(column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnFilters(column));

  $$PodcastFeedsTableFilterComposer get feedId {
    final $$PodcastFeedsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.feedId,
      referencedTable: $db.podcastFeeds,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$PodcastFeedsTableFilterComposer(
            $db: $db,
            $table: $db.podcastFeeds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MediaTableFilterComposer get mediaId {
    final $$MediaTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaId,
      referencedTable: $db.media,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MediaTableFilterComposer(
            $db: $db,
            $table: $db.media,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableOrderingComposer extends Composer<_$TinglangDatabase, $EpisodesTable> {
  $$EpisodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get guid =>
      $composableBuilder(column: $table.guid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audioUrl =>
      $composableBuilder(column: $table.audioUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get publishedAt =>
      $composableBuilder(column: $table.publishedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs =>
      $composableBuilder(column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnOrderings(column));

  $$PodcastFeedsTableOrderingComposer get feedId {
    final $$PodcastFeedsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.feedId,
      referencedTable: $db.podcastFeeds,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$PodcastFeedsTableOrderingComposer(
            $db: $db,
            $table: $db.podcastFeeds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MediaTableOrderingComposer get mediaId {
    final $$MediaTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaId,
      referencedTable: $db.media,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MediaTableOrderingComposer(
            $db: $db,
            $table: $db.media,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableAnnotationComposer extends Composer<_$TinglangDatabase, $EpisodesTable> {
  $$EpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get guid =>
      $composableBuilder(column: $table.guid, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get audioUrl =>
      $composableBuilder(column: $table.audioUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get publishedAt =>
      $composableBuilder(column: $table.publishedAt, builder: (column) => column);

  GeneratedColumn<int> get durationMs =>
      $composableBuilder(column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  $$PodcastFeedsTableAnnotationComposer get feedId {
    final $$PodcastFeedsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.feedId,
      referencedTable: $db.podcastFeeds,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$PodcastFeedsTableAnnotationComposer(
            $db: $db,
            $table: $db.podcastFeeds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MediaTableAnnotationComposer get mediaId {
    final $$MediaTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaId,
      referencedTable: $db.media,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MediaTableAnnotationComposer(
            $db: $db,
            $table: $db.media,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $EpisodesTable,
          EpisodeRow,
          $$EpisodesTableFilterComposer,
          $$EpisodesTableOrderingComposer,
          $$EpisodesTableAnnotationComposer,
          $$EpisodesTableCreateCompanionBuilder,
          $$EpisodesTableUpdateCompanionBuilder,
          (EpisodeRow, $$EpisodesTableReferences),
          EpisodeRow,
          PrefetchHooks Function({bool feedId, bool mediaId})
        > {
  $$EpisodesTableTableManager(_$TinglangDatabase db, $EpisodesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$EpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$EpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> feedId = const Value.absent(),
                Value<String> guid = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> audioUrl = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> mediaId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpisodesCompanion(
                id: id,
                feedId: feedId,
                guid: guid,
                title: title,
                audioUrl: audioUrl,
                publishedAt: publishedAt,
                durationMs: durationMs,
                mediaId: mediaId,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String feedId,
                required String guid,
                required String title,
                required String audioUrl,
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> mediaId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpisodesCompanion.insert(
                id: id,
                feedId: feedId,
                guid: guid,
                title: title,
                audioUrl: audioUrl,
                publishedAt: publishedAt,
                durationMs: durationMs,
                mediaId: mediaId,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpisodesTable, EpisodeRow>(table),
                  $$EpisodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({feedId = false, mediaId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (feedId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.feedId,
                        referencedTable: $$EpisodesTableReferences._feedIdTable(db),
                        referencedColumn: $$EpisodesTableReferences._feedIdTable(db).id,
                      ) as T;
                    }
                    if (mediaId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.mediaId,
                        referencedTable: $$EpisodesTableReferences._mediaIdTable(db),
                        referencedColumn: $$EpisodesTableReferences._mediaIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $EpisodesTable,
      EpisodeRow,
      $$EpisodesTableFilterComposer,
      $$EpisodesTableOrderingComposer,
      $$EpisodesTableAnnotationComposer,
      $$EpisodesTableCreateCompanionBuilder,
      $$EpisodesTableUpdateCompanionBuilder,
      (EpisodeRow, $$EpisodesTableReferences),
      EpisodeRow,
      PrefetchHooks Function({bool feedId, bool mediaId})
    >;
typedef $$DraftsTableCreateCompanionBuilder = DraftsCompanion Function({
  required String key,
  required String body,
  Value<int> rowid,
});
typedef $$DraftsTableUpdateCompanionBuilder = DraftsCompanion Function({
  Value<String> key,
  Value<String> body,
  Value<int> rowid,
});

class $$DraftsTableFilterComposer extends Composer<_$TinglangDatabase, $DraftsTable> {
  $$DraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => ColumnFilters(column));
}

class $$DraftsTableOrderingComposer extends Composer<_$TinglangDatabase, $DraftsTable> {
  $$DraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => ColumnOrderings(column));
}

class $$DraftsTableAnnotationComposer extends Composer<_$TinglangDatabase, $DraftsTable> {
  $$DraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);
}

class $$DraftsTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $DraftsTable,
          DraftRow,
          $$DraftsTableFilterComposer,
          $$DraftsTableOrderingComposer,
          $$DraftsTableAnnotationComposer,
          $$DraftsTableCreateCompanionBuilder,
          $$DraftsTableUpdateCompanionBuilder,
          (DraftRow, BaseReferences<_$TinglangDatabase, $DraftsTable, DraftRow>),
          DraftRow,
          PrefetchHooks Function()
        > {
  $$DraftsTableTableManager(_$TinglangDatabase db, $DraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$DraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$DraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => DraftsCompanion(key: key, body: body, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String body,
            Value<int> rowid = const Value.absent(),
          }) => DraftsCompanion.insert(key: key, body: body, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DraftsTable, DraftRow>(table),
                  BaseReferences<_$TinglangDatabase, $DraftsTable, DraftRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $DraftsTable,
      DraftRow,
      $$DraftsTableFilterComposer,
      $$DraftsTableOrderingComposer,
      $$DraftsTableAnnotationComposer,
      $$DraftsTableCreateCompanionBuilder,
      $$DraftsTableUpdateCompanionBuilder,
      (DraftRow, BaseReferences<_$TinglangDatabase, $DraftsTable, DraftRow>),
      DraftRow,
      PrefetchHooks Function()
    >;
typedef $$AppMetaTableCreateCompanionBuilder = AppMetaCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppMetaTableUpdateCompanionBuilder = AppMetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppMetaTableFilterComposer extends Composer<_$TinglangDatabase, $AppMetaTable> {
  $$AppMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$AppMetaTableOrderingComposer extends Composer<_$TinglangDatabase, $AppMetaTable> {
  $$AppMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$AppMetaTableAnnotationComposer extends Composer<_$TinglangDatabase, $AppMetaTable> {
  $$AppMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppMetaTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $AppMetaTable,
          MetaRow,
          $$AppMetaTableFilterComposer,
          $$AppMetaTableOrderingComposer,
          $$AppMetaTableAnnotationComposer,
          $$AppMetaTableCreateCompanionBuilder,
          $$AppMetaTableUpdateCompanionBuilder,
          (MetaRow, BaseReferences<_$TinglangDatabase, $AppMetaTable, MetaRow>),
          MetaRow,
          PrefetchHooks Function()
        > {
  $$AppMetaTableTableManager(_$TinglangDatabase db, $AppMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$AppMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$AppMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => AppMetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppMetaTable, MetaRow>(table),
                  BaseReferences<_$TinglangDatabase, $AppMetaTable, MetaRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $AppMetaTable,
      MetaRow,
      $$AppMetaTableFilterComposer,
      $$AppMetaTableOrderingComposer,
      $$AppMetaTableAnnotationComposer,
      $$AppMetaTableCreateCompanionBuilder,
      $$AppMetaTableUpdateCompanionBuilder,
      (MetaRow, BaseReferences<_$TinglangDatabase, $AppMetaTable, MetaRow>),
      MetaRow,
      PrefetchHooks Function()
    >;
typedef $$DictationAttemptsTableCreateCompanionBuilder = DictationAttemptsCompanion Function({
  required String id,
  required String sessionId,
  required String segmentId,
  required String answer,
  required String result,
  required double similarity,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$DictationAttemptsTableUpdateCompanionBuilder = DictationAttemptsCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String> segmentId,
  Value<String> answer,
  Value<String> result,
  Value<double> similarity,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$DictationAttemptsTableReferences
    extends BaseReferences<_$TinglangDatabase, $DictationAttemptsTable, DictationAttemptRow> {
  $$DictationAttemptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$TinglangDatabase db) =>
      db.sessions.createAlias('dictation_attempt__session_id__session__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$DictationAttemptsTableFilterComposer
    extends Composer<_$TinglangDatabase, $DictationAttemptsTable> {
  $$DictationAttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get segmentId =>
      $composableBuilder(column: $table.segmentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get similarity =>
      $composableBuilder(column: $table.similarity, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DictationAttemptsTableOrderingComposer
    extends Composer<_$TinglangDatabase, $DictationAttemptsTable> {
  $$DictationAttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get segmentId =>
      $composableBuilder(column: $table.segmentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get similarity =>
      $composableBuilder(column: $table.similarity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DictationAttemptsTableAnnotationComposer
    extends Composer<_$TinglangDatabase, $DictationAttemptsTable> {
  $$DictationAttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get segmentId =>
      $composableBuilder(column: $table.segmentId, builder: (column) => column);

  GeneratedColumn<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<double> get similarity =>
      $composableBuilder(column: $table.similarity, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DictationAttemptsTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $DictationAttemptsTable,
          DictationAttemptRow,
          $$DictationAttemptsTableFilterComposer,
          $$DictationAttemptsTableOrderingComposer,
          $$DictationAttemptsTableAnnotationComposer,
          $$DictationAttemptsTableCreateCompanionBuilder,
          $$DictationAttemptsTableUpdateCompanionBuilder,
          (DictationAttemptRow, $$DictationAttemptsTableReferences),
          DictationAttemptRow,
          PrefetchHooks Function({bool sessionId})
        > {
  $$DictationAttemptsTableTableManager(_$TinglangDatabase db, $DictationAttemptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DictationAttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DictationAttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DictationAttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> segmentId = const Value.absent(),
                Value<String> answer = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<double> similarity = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DictationAttemptsCompanion(
                id: id,
                sessionId: sessionId,
                segmentId: segmentId,
                answer: answer,
                result: result,
                similarity: similarity,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String segmentId,
                required String answer,
                required String result,
                required double similarity,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => DictationAttemptsCompanion.insert(
                id: id,
                sessionId: sessionId,
                segmentId: segmentId,
                answer: answer,
                result: result,
                similarity: similarity,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DictationAttemptsTable, DictationAttemptRow>(table),
                  $$DictationAttemptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$DictationAttemptsTableReferences._sessionIdTable(db),
                        referencedColumn: $$DictationAttemptsTableReferences._sessionIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DictationAttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $DictationAttemptsTable,
      DictationAttemptRow,
      $$DictationAttemptsTableFilterComposer,
      $$DictationAttemptsTableOrderingComposer,
      $$DictationAttemptsTableAnnotationComposer,
      $$DictationAttemptsTableCreateCompanionBuilder,
      $$DictationAttemptsTableUpdateCompanionBuilder,
      (DictationAttemptRow, $$DictationAttemptsTableReferences),
      DictationAttemptRow,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$SyncRecordsTableCreateCompanionBuilder = SyncRecordsCompanion Function({
  required String kind,
  required String key,
  Value<String?> localHash,
  required int updatedAt,
  required String device,
  Value<bool> deleted,
  Value<String?> hash,
  Value<int> rowid,
});
typedef $$SyncRecordsTableUpdateCompanionBuilder = SyncRecordsCompanion Function({
  Value<String> kind,
  Value<String> key,
  Value<String?> localHash,
  Value<int> updatedAt,
  Value<String> device,
  Value<bool> deleted,
  Value<String?> hash,
  Value<int> rowid,
});

class $$SyncRecordsTableFilterComposer extends Composer<_$TinglangDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localHash =>
      $composableBuilder(column: $table.localHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get device =>
      $composableBuilder(column: $table.device, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => ColumnFilters(column));
}

class $$SyncRecordsTableOrderingComposer extends Composer<_$TinglangDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localHash =>
      $composableBuilder(column: $table.localHash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get device =>
      $composableBuilder(column: $table.device, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => ColumnOrderings(column));
}

class $$SyncRecordsTableAnnotationComposer extends Composer<_$TinglangDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get localHash =>
      $composableBuilder(column: $table.localHash, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get device =>
      $composableBuilder(column: $table.device, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);
}

class $$SyncRecordsTableTableManager
    extends
        RootTableManager<
          _$TinglangDatabase,
          $SyncRecordsTable,
          SyncRecordRow,
          $$SyncRecordsTableFilterComposer,
          $$SyncRecordsTableOrderingComposer,
          $$SyncRecordsTableAnnotationComposer,
          $$SyncRecordsTableCreateCompanionBuilder,
          $$SyncRecordsTableUpdateCompanionBuilder,
          (SyncRecordRow, BaseReferences<_$TinglangDatabase, $SyncRecordsTable, SyncRecordRow>),
          SyncRecordRow,
          PrefetchHooks Function()
        > {
  $$SyncRecordsTableTableManager(_$TinglangDatabase db, $SyncRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SyncRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SyncRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> kind = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String?> localHash = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> device = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String?> hash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncRecordsCompanion(
                kind: kind,
                key: key,
                localHash: localHash,
                updatedAt: updatedAt,
                device: device,
                deleted: deleted,
                hash: hash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kind,
                required String key,
                Value<String?> localHash = const Value.absent(),
                required int updatedAt,
                required String device,
                Value<bool> deleted = const Value.absent(),
                Value<String?> hash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncRecordsCompanion.insert(
                kind: kind,
                key: key,
                localHash: localHash,
                updatedAt: updatedAt,
                device: device,
                deleted: deleted,
                hash: hash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncRecordsTable, SyncRecordRow>(table),
                  BaseReferences<_$TinglangDatabase, $SyncRecordsTable, SyncRecordRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$TinglangDatabase,
      $SyncRecordsTable,
      SyncRecordRow,
      $$SyncRecordsTableFilterComposer,
      $$SyncRecordsTableOrderingComposer,
      $$SyncRecordsTableAnnotationComposer,
      $$SyncRecordsTableCreateCompanionBuilder,
      $$SyncRecordsTableUpdateCompanionBuilder,
      (SyncRecordRow, BaseReferences<_$TinglangDatabase, $SyncRecordsTable, SyncRecordRow>),
      SyncRecordRow,
      PrefetchHooks Function()
    >;

class $TinglangDatabaseManager {
  final _$TinglangDatabase _db;
  $TinglangDatabaseManager(this._db);
  $$MediaTableTableManager get media => $$MediaTableTableManager(_db, _db.media);
  $$SessionsTableTableManager get sessions => $$SessionsTableTableManager(_db, _db.sessions);
  $$TimeAnchorsTableTableManager get timeAnchors =>
      $$TimeAnchorsTableTableManager(_db, _db.timeAnchors);
  $$SegmentsTableTableManager get segments => $$SegmentsTableTableManager(_db, _db.segments);
  $$TranslationsTableTableManager get translations =>
      $$TranslationsTableTableManager(_db, _db.translations);
  $$CoursesTableTableManager get courses => $$CoursesTableTableManager(_db, _db.courses);
  $$ClipsTableTableManager get clips => $$ClipsTableTableManager(_db, _db.clips);
  $$ItemsTableTableManager get items => $$ItemsTableTableManager(_db, _db.items);
  $$ExercisesTableTableManager get exercises => $$ExercisesTableTableManager(_db, _db.exercises);
  $$ProgressTableTableManager get progress => $$ProgressTableTableManager(_db, _db.progress);
  $$AttemptsTableTableManager get attempts => $$AttemptsTableTableManager(_db, _db.attempts);
  $$CardsTableTableManager get cards => $$CardsTableTableManager(_db, _db.cards);
  $$ReviewLogsTableTableManager get reviewLogs =>
      $$ReviewLogsTableTableManager(_db, _db.reviewLogs);
  $$ProviderConfigsTableTableManager get providerConfigs =>
      $$ProviderConfigsTableTableManager(_db, _db.providerConfigs);
  $$FeatureRoutesTableTableManager get featureRoutes =>
      $$FeatureRoutesTableTableManager(_db, _db.featureRoutes);
  $$LlmCacheTableTableManager get llmCache => $$LlmCacheTableTableManager(_db, _db.llmCache);
  $$PodcastFeedsTableTableManager get podcastFeeds =>
      $$PodcastFeedsTableTableManager(_db, _db.podcastFeeds);
  $$EpisodesTableTableManager get episodes => $$EpisodesTableTableManager(_db, _db.episodes);
  $$DraftsTableTableManager get drafts => $$DraftsTableTableManager(_db, _db.drafts);
  $$AppMetaTableTableManager get appMeta => $$AppMetaTableTableManager(_db, _db.appMeta);
  $$DictationAttemptsTableTableManager get dictationAttempts =>
      $$DictationAttemptsTableTableManager(_db, _db.dictationAttempts);
  $$SyncRecordsTableTableManager get syncRecords =>
      $$SyncRecordsTableTableManager(_db, _db.syncRecords);
}

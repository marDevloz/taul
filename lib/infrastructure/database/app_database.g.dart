// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $EntriesTable extends Entries with TableInfo<$EntriesTable, Entry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
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
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsColorMeta = const VerificationMeta(
    'tagsColor',
  );
  @override
  late final GeneratedColumn<String> tagsColor = GeneratedColumn<String>(
    'tags_color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _secretMeta = const VerificationMeta('secret');
  @override
  late final GeneratedColumn<String> secret = GeneratedColumn<String>(
    'secret',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requiresAuthMeta = const VerificationMeta(
    'requiresAuth',
  );
  @override
  late final GeneratedColumn<bool> requiresAuth = GeneratedColumn<bool>(
    'requires_auth',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("requires_auth" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _encryptedSecretMeta = const VerificationMeta(
    'encryptedSecret',
  );
  @override
  late final GeneratedColumn<String> encryptedSecret = GeneratedColumn<String>(
    'encrypted_secret',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cipherNonceMeta = const VerificationMeta(
    'cipherNonce',
  );
  @override
  late final GeneratedColumn<String> cipherNonce = GeneratedColumn<String>(
    'cipher_nonce',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cipherTagMeta = const VerificationMeta(
    'cipherTag',
  );
  @override
  late final GeneratedColumn<String> cipherTag = GeneratedColumn<String>(
    'cipher_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    title,
    content,
    metadata,
    tags,
    tagsColor,
    secret,
    requiresAuth,
    encryptedSecret,
    cipherNonce,
    cipherTag,
    createdAt,
    updatedAt,
    version,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Entry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    } else if (isInserting) {
      context.missing(_metadataMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    } else if (isInserting) {
      context.missing(_tagsMeta);
    }
    if (data.containsKey('tags_color')) {
      context.handle(
        _tagsColorMeta,
        tagsColor.isAcceptableOrUnknown(data['tags_color']!, _tagsColorMeta),
      );
    }
    if (data.containsKey('secret')) {
      context.handle(
        _secretMeta,
        secret.isAcceptableOrUnknown(data['secret']!, _secretMeta),
      );
    }
    if (data.containsKey('requires_auth')) {
      context.handle(
        _requiresAuthMeta,
        requiresAuth.isAcceptableOrUnknown(
          data['requires_auth']!,
          _requiresAuthMeta,
        ),
      );
    }
    if (data.containsKey('encrypted_secret')) {
      context.handle(
        _encryptedSecretMeta,
        encryptedSecret.isAcceptableOrUnknown(
          data['encrypted_secret']!,
          _encryptedSecretMeta,
        ),
      );
    }
    if (data.containsKey('cipher_nonce')) {
      context.handle(
        _cipherNonceMeta,
        cipherNonce.isAcceptableOrUnknown(
          data['cipher_nonce']!,
          _cipherNonceMeta,
        ),
      );
    }
    if (data.containsKey('cipher_tag')) {
      context.handle(
        _cipherTagMeta,
        cipherTag.isAcceptableOrUnknown(data['cipher_tag']!, _cipherTagMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Entry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      tagsColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_color'],
      ),
      secret: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secret'],
      ),
      requiresAuth: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requires_auth'],
      )!,
      encryptedSecret: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_secret'],
      ),
      cipherNonce: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cipher_nonce'],
      ),
      cipherTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cipher_tag'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }
}

class Entry extends DataClass implements Insertable<Entry> {
  final String id;
  final String type;
  final String title;
  final String content;
  final String metadata;
  final String tags;
  final String? tagsColor;
  final String? secret;
  final bool requiresAuth;
  final String? encryptedSecret;
  final String? cipherNonce;
  final String? cipherTag;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;
  const Entry({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.metadata,
    required this.tags,
    this.tagsColor,
    this.secret,
    required this.requiresAuth,
    this.encryptedSecret,
    this.cipherNonce,
    this.cipherTag,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    map['metadata'] = Variable<String>(metadata);
    map['tags'] = Variable<String>(tags);
    if (!nullToAbsent || tagsColor != null) {
      map['tags_color'] = Variable<String>(tagsColor);
    }
    if (!nullToAbsent || secret != null) {
      map['secret'] = Variable<String>(secret);
    }
    map['requires_auth'] = Variable<bool>(requiresAuth);
    if (!nullToAbsent || encryptedSecret != null) {
      map['encrypted_secret'] = Variable<String>(encryptedSecret);
    }
    if (!nullToAbsent || cipherNonce != null) {
      map['cipher_nonce'] = Variable<String>(cipherNonce);
    }
    if (!nullToAbsent || cipherTag != null) {
      map['cipher_tag'] = Variable<String>(cipherTag);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      type: Value(type),
      title: Value(title),
      content: Value(content),
      metadata: Value(metadata),
      tags: Value(tags),
      tagsColor: tagsColor == null && nullToAbsent
          ? const Value.absent()
          : Value(tagsColor),
      secret: secret == null && nullToAbsent
          ? const Value.absent()
          : Value(secret),
      requiresAuth: Value(requiresAuth),
      encryptedSecret: encryptedSecret == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedSecret),
      cipherNonce: cipherNonce == null && nullToAbsent
          ? const Value.absent()
          : Value(cipherNonce),
      cipherTag: cipherTag == null && nullToAbsent
          ? const Value.absent()
          : Value(cipherTag),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      version: Value(version),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Entry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entry(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      metadata: serializer.fromJson<String>(json['metadata']),
      tags: serializer.fromJson<String>(json['tags']),
      tagsColor: serializer.fromJson<String?>(json['tagsColor']),
      secret: serializer.fromJson<String?>(json['secret']),
      requiresAuth: serializer.fromJson<bool>(json['requiresAuth']),
      encryptedSecret: serializer.fromJson<String?>(json['encryptedSecret']),
      cipherNonce: serializer.fromJson<String?>(json['cipherNonce']),
      cipherTag: serializer.fromJson<String?>(json['cipherTag']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      version: serializer.fromJson<int>(json['version']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'metadata': serializer.toJson<String>(metadata),
      'tags': serializer.toJson<String>(tags),
      'tagsColor': serializer.toJson<String?>(tagsColor),
      'secret': serializer.toJson<String?>(secret),
      'requiresAuth': serializer.toJson<bool>(requiresAuth),
      'encryptedSecret': serializer.toJson<String?>(encryptedSecret),
      'cipherNonce': serializer.toJson<String?>(cipherNonce),
      'cipherTag': serializer.toJson<String?>(cipherTag),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'version': serializer.toJson<int>(version),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Entry copyWith({
    String? id,
    String? type,
    String? title,
    String? content,
    String? metadata,
    String? tags,
    Value<String?> tagsColor = const Value.absent(),
    Value<String?> secret = const Value.absent(),
    bool? requiresAuth,
    Value<String?> encryptedSecret = const Value.absent(),
    Value<String?> cipherNonce = const Value.absent(),
    Value<String?> cipherTag = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Entry(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title ?? this.title,
    content: content ?? this.content,
    metadata: metadata ?? this.metadata,
    tags: tags ?? this.tags,
    tagsColor: tagsColor.present ? tagsColor.value : this.tagsColor,
    secret: secret.present ? secret.value : this.secret,
    requiresAuth: requiresAuth ?? this.requiresAuth,
    encryptedSecret: encryptedSecret.present
        ? encryptedSecret.value
        : this.encryptedSecret,
    cipherNonce: cipherNonce.present ? cipherNonce.value : this.cipherNonce,
    cipherTag: cipherTag.present ? cipherTag.value : this.cipherTag,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Entry copyWithCompanion(EntriesCompanion data) {
    return Entry(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      tags: data.tags.present ? data.tags.value : this.tags,
      tagsColor: data.tagsColor.present ? data.tagsColor.value : this.tagsColor,
      secret: data.secret.present ? data.secret.value : this.secret,
      requiresAuth: data.requiresAuth.present
          ? data.requiresAuth.value
          : this.requiresAuth,
      encryptedSecret: data.encryptedSecret.present
          ? data.encryptedSecret.value
          : this.encryptedSecret,
      cipherNonce: data.cipherNonce.present
          ? data.cipherNonce.value
          : this.cipherNonce,
      cipherTag: data.cipherTag.present ? data.cipherTag.value : this.cipherTag,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entry(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('metadata: $metadata, ')
          ..write('tags: $tags, ')
          ..write('tagsColor: $tagsColor, ')
          ..write('secret: $secret, ')
          ..write('requiresAuth: $requiresAuth, ')
          ..write('encryptedSecret: $encryptedSecret, ')
          ..write('cipherNonce: $cipherNonce, ')
          ..write('cipherTag: $cipherTag, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    title,
    content,
    metadata,
    tags,
    tagsColor,
    secret,
    requiresAuth,
    encryptedSecret,
    cipherNonce,
    cipherTag,
    createdAt,
    updatedAt,
    version,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entry &&
          other.id == this.id &&
          other.type == this.type &&
          other.title == this.title &&
          other.content == this.content &&
          other.metadata == this.metadata &&
          other.tags == this.tags &&
          other.tagsColor == this.tagsColor &&
          other.secret == this.secret &&
          other.requiresAuth == this.requiresAuth &&
          other.encryptedSecret == this.encryptedSecret &&
          other.cipherNonce == this.cipherNonce &&
          other.cipherTag == this.cipherTag &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.deletedAt == this.deletedAt);
}

class EntriesCompanion extends UpdateCompanion<Entry> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> title;
  final Value<String> content;
  final Value<String> metadata;
  final Value<String> tags;
  final Value<String?> tagsColor;
  final Value<String?> secret;
  final Value<bool> requiresAuth;
  final Value<String?> encryptedSecret;
  final Value<String?> cipherNonce;
  final Value<String?> cipherTag;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> version;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.metadata = const Value.absent(),
    this.tags = const Value.absent(),
    this.tagsColor = const Value.absent(),
    this.secret = const Value.absent(),
    this.requiresAuth = const Value.absent(),
    this.encryptedSecret = const Value.absent(),
    this.cipherNonce = const Value.absent(),
    this.cipherTag = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntriesCompanion.insert({
    required String id,
    required String type,
    required String title,
    required String content,
    required String metadata,
    required String tags,
    this.tagsColor = const Value.absent(),
    this.secret = const Value.absent(),
    this.requiresAuth = const Value.absent(),
    this.encryptedSecret = const Value.absent(),
    this.cipherNonce = const Value.absent(),
    this.cipherTag = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.version = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       title = Value(title),
       content = Value(content),
       metadata = Value(metadata),
       tags = Value(tags),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Entry> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? metadata,
    Expression<String>? tags,
    Expression<String>? tagsColor,
    Expression<String>? secret,
    Expression<bool>? requiresAuth,
    Expression<String>? encryptedSecret,
    Expression<String>? cipherNonce,
    Expression<String>? cipherTag,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? version,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (metadata != null) 'metadata': metadata,
      if (tags != null) 'tags': tags,
      if (tagsColor != null) 'tags_color': tagsColor,
      if (secret != null) 'secret': secret,
      if (requiresAuth != null) 'requires_auth': requiresAuth,
      if (encryptedSecret != null) 'encrypted_secret': encryptedSecret,
      if (cipherNonce != null) 'cipher_nonce': cipherNonce,
      if (cipherTag != null) 'cipher_tag': cipherTag,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? title,
    Value<String>? content,
    Value<String>? metadata,
    Value<String>? tags,
    Value<String?>? tagsColor,
    Value<String?>? secret,
    Value<bool>? requiresAuth,
    Value<String?>? encryptedSecret,
    Value<String?>? cipherNonce,
    Value<String?>? cipherTag,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? version,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
      tags: tags ?? this.tags,
      tagsColor: tagsColor ?? this.tagsColor,
      secret: secret ?? this.secret,
      requiresAuth: requiresAuth ?? this.requiresAuth,
      encryptedSecret: encryptedSecret ?? this.encryptedSecret,
      cipherNonce: cipherNonce ?? this.cipherNonce,
      cipherTag: cipherTag ?? this.cipherTag,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (tagsColor.present) {
      map['tags_color'] = Variable<String>(tagsColor.value);
    }
    if (secret.present) {
      map['secret'] = Variable<String>(secret.value);
    }
    if (requiresAuth.present) {
      map['requires_auth'] = Variable<bool>(requiresAuth.value);
    }
    if (encryptedSecret.present) {
      map['encrypted_secret'] = Variable<String>(encryptedSecret.value);
    }
    if (cipherNonce.present) {
      map['cipher_nonce'] = Variable<String>(cipherNonce.value);
    }
    if (cipherTag.present) {
      map['cipher_tag'] = Variable<String>(cipherTag.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('metadata: $metadata, ')
          ..write('tags: $tags, ')
          ..write('tagsColor: $tagsColor, ')
          ..write('secret: $secret, ')
          ..write('requiresAuth: $requiresAuth, ')
          ..write('encryptedSecret: $encryptedSecret, ')
          ..write('cipherNonce: $cipherNonce, ')
          ..write('cipherTag: $cipherTag, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MasterPasswordConfigTable extends MasterPasswordConfig
    with TableInfo<$MasterPasswordConfigTable, MasterPasswordConfigData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MasterPasswordConfigTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: () => 1,
  );
  static const VerificationMeta _passwordHashArgon2Meta =
      const VerificationMeta('passwordHashArgon2');
  @override
  late final GeneratedColumn<String> passwordHashArgon2 =
      GeneratedColumn<String>(
        'password_hash_argon2',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _saltHexMeta = const VerificationMeta(
    'saltHex',
  );
  @override
  late final GeneratedColumn<String> saltHex = GeneratedColumn<String>(
    'salt_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _passwordHintMeta = const VerificationMeta(
    'passwordHint',
  );
  @override
  late final GeneratedColumn<String> passwordHint = GeneratedColumn<String>(
    'password_hint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backupCodeHashesMeta = const VerificationMeta(
    'backupCodeHashes',
  );
  @override
  late final GeneratedColumn<String> backupCodeHashes = GeneratedColumn<String>(
    'backup_code_hashes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backupCodeDataMeta = const VerificationMeta(
    'backupCodeData',
  );
  @override
  late final GeneratedColumn<String> backupCodeData = GeneratedColumn<String>(
    'backup_code_data',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encryptedStorageKeyMeta =
      const VerificationMeta('encryptedStorageKey');
  @override
  late final GeneratedColumn<String> encryptedStorageKey =
      GeneratedColumn<String>(
        'encrypted_storage_key',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _encryptedStorageKeyNonceMeta =
      const VerificationMeta('encryptedStorageKeyNonce');
  @override
  late final GeneratedColumn<String> encryptedStorageKeyNonce =
      GeneratedColumn<String>(
        'encrypted_storage_key_nonce',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _encryptedStorageKeyTagMeta =
      const VerificationMeta('encryptedStorageKeyTag');
  @override
  late final GeneratedColumn<String> encryptedStorageKeyTag =
      GeneratedColumn<String>(
        'encrypted_storage_key_tag',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
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
    passwordHashArgon2,
    saltHex,
    passwordHint,
    backupCodeHashes,
    backupCodeData,
    encryptedStorageKey,
    encryptedStorageKeyNonce,
    encryptedStorageKeyTag,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'master_password_config';
  @override
  VerificationContext validateIntegrity(
    Insertable<MasterPasswordConfigData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('password_hash_argon2')) {
      context.handle(
        _passwordHashArgon2Meta,
        passwordHashArgon2.isAcceptableOrUnknown(
          data['password_hash_argon2']!,
          _passwordHashArgon2Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_passwordHashArgon2Meta);
    }
    if (data.containsKey('salt_hex')) {
      context.handle(
        _saltHexMeta,
        saltHex.isAcceptableOrUnknown(data['salt_hex']!, _saltHexMeta),
      );
    } else if (isInserting) {
      context.missing(_saltHexMeta);
    }
    if (data.containsKey('password_hint')) {
      context.handle(
        _passwordHintMeta,
        passwordHint.isAcceptableOrUnknown(
          data['password_hint']!,
          _passwordHintMeta,
        ),
      );
    }
    if (data.containsKey('backup_code_hashes')) {
      context.handle(
        _backupCodeHashesMeta,
        backupCodeHashes.isAcceptableOrUnknown(
          data['backup_code_hashes']!,
          _backupCodeHashesMeta,
        ),
      );
    }
    if (data.containsKey('backup_code_data')) {
      context.handle(
        _backupCodeDataMeta,
        backupCodeData.isAcceptableOrUnknown(
          data['backup_code_data']!,
          _backupCodeDataMeta,
        ),
      );
    }
    if (data.containsKey('encrypted_storage_key')) {
      context.handle(
        _encryptedStorageKeyMeta,
        encryptedStorageKey.isAcceptableOrUnknown(
          data['encrypted_storage_key']!,
          _encryptedStorageKeyMeta,
        ),
      );
    }
    if (data.containsKey('encrypted_storage_key_nonce')) {
      context.handle(
        _encryptedStorageKeyNonceMeta,
        encryptedStorageKeyNonce.isAcceptableOrUnknown(
          data['encrypted_storage_key_nonce']!,
          _encryptedStorageKeyNonceMeta,
        ),
      );
    }
    if (data.containsKey('encrypted_storage_key_tag')) {
      context.handle(
        _encryptedStorageKeyTagMeta,
        encryptedStorageKeyTag.isAcceptableOrUnknown(
          data['encrypted_storage_key_tag']!,
          _encryptedStorageKeyTagMeta,
        ),
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
  MasterPasswordConfigData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MasterPasswordConfigData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      passwordHashArgon2: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password_hash_argon2'],
      )!,
      saltHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}salt_hex'],
      )!,
      passwordHint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password_hint'],
      ),
      backupCodeHashes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backup_code_hashes'],
      ),
      backupCodeData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backup_code_data'],
      ),
      encryptedStorageKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_storage_key'],
      ),
      encryptedStorageKeyNonce: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_storage_key_nonce'],
      ),
      encryptedStorageKeyTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_storage_key_tag'],
      ),
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
  $MasterPasswordConfigTable createAlias(String alias) {
    return $MasterPasswordConfigTable(attachedDatabase, alias);
  }
}

class MasterPasswordConfigData extends DataClass
    implements Insertable<MasterPasswordConfigData> {
  final int id;
  final String passwordHashArgon2;
  final String saltHex;
  final String? passwordHint;
  final String? backupCodeHashes;
  final String? backupCodeData;
  final String? encryptedStorageKey;
  final String? encryptedStorageKeyNonce;
  final String? encryptedStorageKeyTag;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MasterPasswordConfigData({
    required this.id,
    required this.passwordHashArgon2,
    required this.saltHex,
    this.passwordHint,
    this.backupCodeHashes,
    this.backupCodeData,
    this.encryptedStorageKey,
    this.encryptedStorageKeyNonce,
    this.encryptedStorageKeyTag,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['password_hash_argon2'] = Variable<String>(passwordHashArgon2);
    map['salt_hex'] = Variable<String>(saltHex);
    if (!nullToAbsent || passwordHint != null) {
      map['password_hint'] = Variable<String>(passwordHint);
    }
    if (!nullToAbsent || backupCodeHashes != null) {
      map['backup_code_hashes'] = Variable<String>(backupCodeHashes);
    }
    if (!nullToAbsent || backupCodeData != null) {
      map['backup_code_data'] = Variable<String>(backupCodeData);
    }
    if (!nullToAbsent || encryptedStorageKey != null) {
      map['encrypted_storage_key'] = Variable<String>(encryptedStorageKey);
    }
    if (!nullToAbsent || encryptedStorageKeyNonce != null) {
      map['encrypted_storage_key_nonce'] = Variable<String>(
        encryptedStorageKeyNonce,
      );
    }
    if (!nullToAbsent || encryptedStorageKeyTag != null) {
      map['encrypted_storage_key_tag'] = Variable<String>(
        encryptedStorageKeyTag,
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MasterPasswordConfigCompanion toCompanion(bool nullToAbsent) {
    return MasterPasswordConfigCompanion(
      id: Value(id),
      passwordHashArgon2: Value(passwordHashArgon2),
      saltHex: Value(saltHex),
      passwordHint: passwordHint == null && nullToAbsent
          ? const Value.absent()
          : Value(passwordHint),
      backupCodeHashes: backupCodeHashes == null && nullToAbsent
          ? const Value.absent()
          : Value(backupCodeHashes),
      backupCodeData: backupCodeData == null && nullToAbsent
          ? const Value.absent()
          : Value(backupCodeData),
      encryptedStorageKey: encryptedStorageKey == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedStorageKey),
      encryptedStorageKeyNonce: encryptedStorageKeyNonce == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedStorageKeyNonce),
      encryptedStorageKeyTag: encryptedStorageKeyTag == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedStorageKeyTag),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MasterPasswordConfigData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MasterPasswordConfigData(
      id: serializer.fromJson<int>(json['id']),
      passwordHashArgon2: serializer.fromJson<String>(
        json['passwordHashArgon2'],
      ),
      saltHex: serializer.fromJson<String>(json['saltHex']),
      passwordHint: serializer.fromJson<String?>(json['passwordHint']),
      backupCodeHashes: serializer.fromJson<String?>(json['backupCodeHashes']),
      backupCodeData: serializer.fromJson<String?>(json['backupCodeData']),
      encryptedStorageKey: serializer.fromJson<String?>(
        json['encryptedStorageKey'],
      ),
      encryptedStorageKeyNonce: serializer.fromJson<String?>(
        json['encryptedStorageKeyNonce'],
      ),
      encryptedStorageKeyTag: serializer.fromJson<String?>(
        json['encryptedStorageKeyTag'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'passwordHashArgon2': serializer.toJson<String>(passwordHashArgon2),
      'saltHex': serializer.toJson<String>(saltHex),
      'passwordHint': serializer.toJson<String?>(passwordHint),
      'backupCodeHashes': serializer.toJson<String?>(backupCodeHashes),
      'backupCodeData': serializer.toJson<String?>(backupCodeData),
      'encryptedStorageKey': serializer.toJson<String?>(encryptedStorageKey),
      'encryptedStorageKeyNonce': serializer.toJson<String?>(
        encryptedStorageKeyNonce,
      ),
      'encryptedStorageKeyTag': serializer.toJson<String?>(
        encryptedStorageKeyTag,
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MasterPasswordConfigData copyWith({
    int? id,
    String? passwordHashArgon2,
    String? saltHex,
    Value<String?> passwordHint = const Value.absent(),
    Value<String?> backupCodeHashes = const Value.absent(),
    Value<String?> backupCodeData = const Value.absent(),
    Value<String?> encryptedStorageKey = const Value.absent(),
    Value<String?> encryptedStorageKeyNonce = const Value.absent(),
    Value<String?> encryptedStorageKeyTag = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MasterPasswordConfigData(
    id: id ?? this.id,
    passwordHashArgon2: passwordHashArgon2 ?? this.passwordHashArgon2,
    saltHex: saltHex ?? this.saltHex,
    passwordHint: passwordHint.present ? passwordHint.value : this.passwordHint,
    backupCodeHashes: backupCodeHashes.present
        ? backupCodeHashes.value
        : this.backupCodeHashes,
    backupCodeData: backupCodeData.present
        ? backupCodeData.value
        : this.backupCodeData,
    encryptedStorageKey: encryptedStorageKey.present
        ? encryptedStorageKey.value
        : this.encryptedStorageKey,
    encryptedStorageKeyNonce: encryptedStorageKeyNonce.present
        ? encryptedStorageKeyNonce.value
        : this.encryptedStorageKeyNonce,
    encryptedStorageKeyTag: encryptedStorageKeyTag.present
        ? encryptedStorageKeyTag.value
        : this.encryptedStorageKeyTag,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MasterPasswordConfigData copyWithCompanion(
    MasterPasswordConfigCompanion data,
  ) {
    return MasterPasswordConfigData(
      id: data.id.present ? data.id.value : this.id,
      passwordHashArgon2: data.passwordHashArgon2.present
          ? data.passwordHashArgon2.value
          : this.passwordHashArgon2,
      saltHex: data.saltHex.present ? data.saltHex.value : this.saltHex,
      passwordHint: data.passwordHint.present
          ? data.passwordHint.value
          : this.passwordHint,
      backupCodeHashes: data.backupCodeHashes.present
          ? data.backupCodeHashes.value
          : this.backupCodeHashes,
      backupCodeData: data.backupCodeData.present
          ? data.backupCodeData.value
          : this.backupCodeData,
      encryptedStorageKey: data.encryptedStorageKey.present
          ? data.encryptedStorageKey.value
          : this.encryptedStorageKey,
      encryptedStorageKeyNonce: data.encryptedStorageKeyNonce.present
          ? data.encryptedStorageKeyNonce.value
          : this.encryptedStorageKeyNonce,
      encryptedStorageKeyTag: data.encryptedStorageKeyTag.present
          ? data.encryptedStorageKeyTag.value
          : this.encryptedStorageKeyTag,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MasterPasswordConfigData(')
          ..write('id: $id, ')
          ..write('passwordHashArgon2: $passwordHashArgon2, ')
          ..write('saltHex: $saltHex, ')
          ..write('passwordHint: $passwordHint, ')
          ..write('backupCodeHashes: $backupCodeHashes, ')
          ..write('backupCodeData: $backupCodeData, ')
          ..write('encryptedStorageKey: $encryptedStorageKey, ')
          ..write('encryptedStorageKeyNonce: $encryptedStorageKeyNonce, ')
          ..write('encryptedStorageKeyTag: $encryptedStorageKeyTag, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    passwordHashArgon2,
    saltHex,
    passwordHint,
    backupCodeHashes,
    backupCodeData,
    encryptedStorageKey,
    encryptedStorageKeyNonce,
    encryptedStorageKeyTag,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MasterPasswordConfigData &&
          other.id == this.id &&
          other.passwordHashArgon2 == this.passwordHashArgon2 &&
          other.saltHex == this.saltHex &&
          other.passwordHint == this.passwordHint &&
          other.backupCodeHashes == this.backupCodeHashes &&
          other.backupCodeData == this.backupCodeData &&
          other.encryptedStorageKey == this.encryptedStorageKey &&
          other.encryptedStorageKeyNonce == this.encryptedStorageKeyNonce &&
          other.encryptedStorageKeyTag == this.encryptedStorageKeyTag &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MasterPasswordConfigCompanion
    extends UpdateCompanion<MasterPasswordConfigData> {
  final Value<int> id;
  final Value<String> passwordHashArgon2;
  final Value<String> saltHex;
  final Value<String?> passwordHint;
  final Value<String?> backupCodeHashes;
  final Value<String?> backupCodeData;
  final Value<String?> encryptedStorageKey;
  final Value<String?> encryptedStorageKeyNonce;
  final Value<String?> encryptedStorageKeyTag;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const MasterPasswordConfigCompanion({
    this.id = const Value.absent(),
    this.passwordHashArgon2 = const Value.absent(),
    this.saltHex = const Value.absent(),
    this.passwordHint = const Value.absent(),
    this.backupCodeHashes = const Value.absent(),
    this.backupCodeData = const Value.absent(),
    this.encryptedStorageKey = const Value.absent(),
    this.encryptedStorageKeyNonce = const Value.absent(),
    this.encryptedStorageKeyTag = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  MasterPasswordConfigCompanion.insert({
    this.id = const Value.absent(),
    required String passwordHashArgon2,
    required String saltHex,
    this.passwordHint = const Value.absent(),
    this.backupCodeHashes = const Value.absent(),
    this.backupCodeData = const Value.absent(),
    this.encryptedStorageKey = const Value.absent(),
    this.encryptedStorageKeyNonce = const Value.absent(),
    this.encryptedStorageKeyTag = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : passwordHashArgon2 = Value(passwordHashArgon2),
       saltHex = Value(saltHex),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MasterPasswordConfigData> custom({
    Expression<int>? id,
    Expression<String>? passwordHashArgon2,
    Expression<String>? saltHex,
    Expression<String>? passwordHint,
    Expression<String>? backupCodeHashes,
    Expression<String>? backupCodeData,
    Expression<String>? encryptedStorageKey,
    Expression<String>? encryptedStorageKeyNonce,
    Expression<String>? encryptedStorageKeyTag,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (passwordHashArgon2 != null)
        'password_hash_argon2': passwordHashArgon2,
      if (saltHex != null) 'salt_hex': saltHex,
      if (passwordHint != null) 'password_hint': passwordHint,
      if (backupCodeHashes != null) 'backup_code_hashes': backupCodeHashes,
      if (backupCodeData != null) 'backup_code_data': backupCodeData,
      if (encryptedStorageKey != null)
        'encrypted_storage_key': encryptedStorageKey,
      if (encryptedStorageKeyNonce != null)
        'encrypted_storage_key_nonce': encryptedStorageKeyNonce,
      if (encryptedStorageKeyTag != null)
        'encrypted_storage_key_tag': encryptedStorageKeyTag,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  MasterPasswordConfigCompanion copyWith({
    Value<int>? id,
    Value<String>? passwordHashArgon2,
    Value<String>? saltHex,
    Value<String?>? passwordHint,
    Value<String?>? backupCodeHashes,
    Value<String?>? backupCodeData,
    Value<String?>? encryptedStorageKey,
    Value<String?>? encryptedStorageKeyNonce,
    Value<String?>? encryptedStorageKeyTag,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return MasterPasswordConfigCompanion(
      id: id ?? this.id,
      passwordHashArgon2: passwordHashArgon2 ?? this.passwordHashArgon2,
      saltHex: saltHex ?? this.saltHex,
      passwordHint: passwordHint ?? this.passwordHint,
      backupCodeHashes: backupCodeHashes ?? this.backupCodeHashes,
      backupCodeData: backupCodeData ?? this.backupCodeData,
      encryptedStorageKey: encryptedStorageKey ?? this.encryptedStorageKey,
      encryptedStorageKeyNonce:
          encryptedStorageKeyNonce ?? this.encryptedStorageKeyNonce,
      encryptedStorageKeyTag:
          encryptedStorageKeyTag ?? this.encryptedStorageKeyTag,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (passwordHashArgon2.present) {
      map['password_hash_argon2'] = Variable<String>(passwordHashArgon2.value);
    }
    if (saltHex.present) {
      map['salt_hex'] = Variable<String>(saltHex.value);
    }
    if (passwordHint.present) {
      map['password_hint'] = Variable<String>(passwordHint.value);
    }
    if (backupCodeHashes.present) {
      map['backup_code_hashes'] = Variable<String>(backupCodeHashes.value);
    }
    if (backupCodeData.present) {
      map['backup_code_data'] = Variable<String>(backupCodeData.value);
    }
    if (encryptedStorageKey.present) {
      map['encrypted_storage_key'] = Variable<String>(
        encryptedStorageKey.value,
      );
    }
    if (encryptedStorageKeyNonce.present) {
      map['encrypted_storage_key_nonce'] = Variable<String>(
        encryptedStorageKeyNonce.value,
      );
    }
    if (encryptedStorageKeyTag.present) {
      map['encrypted_storage_key_tag'] = Variable<String>(
        encryptedStorageKeyTag.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MasterPasswordConfigCompanion(')
          ..write('id: $id, ')
          ..write('passwordHashArgon2: $passwordHashArgon2, ')
          ..write('saltHex: $saltHex, ')
          ..write('passwordHint: $passwordHint, ')
          ..write('backupCodeHashes: $backupCodeHashes, ')
          ..write('backupCodeData: $backupCodeData, ')
          ..write('encryptedStorageKey: $encryptedStorageKey, ')
          ..write('encryptedStorageKeyNonce: $encryptedStorageKeyNonce, ')
          ..write('encryptedStorageKeyTag: $encryptedStorageKeyTag, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $MasterPasswordConfigTable masterPasswordConfig =
      $MasterPasswordConfigTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    entries,
    masterPasswordConfig,
  ];
}

typedef $$EntriesTableCreateCompanionBuilder =
    EntriesCompanion Function({
      required String id,
      required String type,
      required String title,
      required String content,
      required String metadata,
      required String tags,
      Value<String?> tagsColor,
      Value<String?> secret,
      Value<bool> requiresAuth,
      Value<String?> encryptedSecret,
      Value<String?> cipherNonce,
      Value<String?> cipherTag,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> version,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$EntriesTableUpdateCompanionBuilder =
    EntriesCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> title,
      Value<String> content,
      Value<String> metadata,
      Value<String> tags,
      Value<String?> tagsColor,
      Value<String?> secret,
      Value<bool> requiresAuth,
      Value<String?> encryptedSecret,
      Value<String?> cipherNonce,
      Value<String?> cipherTag,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> version,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$EntriesTableFilterComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsColor => $composableBuilder(
    column: $table.tagsColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secret => $composableBuilder(
    column: $table.secret,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiresAuth => $composableBuilder(
    column: $table.requiresAuth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedSecret => $composableBuilder(
    column: $table.encryptedSecret,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cipherNonce => $composableBuilder(
    column: $table.cipherNonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cipherTag => $composableBuilder(
    column: $table.cipherTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsColor => $composableBuilder(
    column: $table.tagsColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secret => $composableBuilder(
    column: $table.secret,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiresAuth => $composableBuilder(
    column: $table.requiresAuth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedSecret => $composableBuilder(
    column: $table.encryptedSecret,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cipherNonce => $composableBuilder(
    column: $table.cipherNonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cipherTag => $composableBuilder(
    column: $table.cipherTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get tagsColor =>
      $composableBuilder(column: $table.tagsColor, builder: (column) => column);

  GeneratedColumn<String> get secret =>
      $composableBuilder(column: $table.secret, builder: (column) => column);

  GeneratedColumn<bool> get requiresAuth => $composableBuilder(
    column: $table.requiresAuth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedSecret => $composableBuilder(
    column: $table.encryptedSecret,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cipherNonce => $composableBuilder(
    column: $table.cipherNonce,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cipherTag =>
      $composableBuilder(column: $table.cipherTag, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntriesTable,
          Entry,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (Entry, BaseReferences<_$AppDatabase, $EntriesTable, Entry>),
          Entry,
          PrefetchHooks Function()
        > {
  $$EntriesTableTableManager(_$AppDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String?> tagsColor = const Value.absent(),
                Value<String?> secret = const Value.absent(),
                Value<bool> requiresAuth = const Value.absent(),
                Value<String?> encryptedSecret = const Value.absent(),
                Value<String?> cipherNonce = const Value.absent(),
                Value<String?> cipherTag = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                type: type,
                title: title,
                content: content,
                metadata: metadata,
                tags: tags,
                tagsColor: tagsColor,
                secret: secret,
                requiresAuth: requiresAuth,
                encryptedSecret: encryptedSecret,
                cipherNonce: cipherNonce,
                cipherTag: cipherTag,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String title,
                required String content,
                required String metadata,
                required String tags,
                Value<String?> tagsColor = const Value.absent(),
                Value<String?> secret = const Value.absent(),
                Value<bool> requiresAuth = const Value.absent(),
                Value<String?> encryptedSecret = const Value.absent(),
                Value<String?> cipherNonce = const Value.absent(),
                Value<String?> cipherTag = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> version = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion.insert(
                id: id,
                type: type,
                title: title,
                content: content,
                metadata: metadata,
                tags: tags,
                tagsColor: tagsColor,
                secret: secret,
                requiresAuth: requiresAuth,
                encryptedSecret: encryptedSecret,
                cipherNonce: cipherNonce,
                cipherTag: cipherTag,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntriesTable,
      Entry,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (Entry, BaseReferences<_$AppDatabase, $EntriesTable, Entry>),
      Entry,
      PrefetchHooks Function()
    >;
typedef $$MasterPasswordConfigTableCreateCompanionBuilder =
    MasterPasswordConfigCompanion Function({
      Value<int> id,
      required String passwordHashArgon2,
      required String saltHex,
      Value<String?> passwordHint,
      Value<String?> backupCodeHashes,
      Value<String?> backupCodeData,
      Value<String?> encryptedStorageKey,
      Value<String?> encryptedStorageKeyNonce,
      Value<String?> encryptedStorageKeyTag,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$MasterPasswordConfigTableUpdateCompanionBuilder =
    MasterPasswordConfigCompanion Function({
      Value<int> id,
      Value<String> passwordHashArgon2,
      Value<String> saltHex,
      Value<String?> passwordHint,
      Value<String?> backupCodeHashes,
      Value<String?> backupCodeData,
      Value<String?> encryptedStorageKey,
      Value<String?> encryptedStorageKeyNonce,
      Value<String?> encryptedStorageKeyTag,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$MasterPasswordConfigTableFilterComposer
    extends Composer<_$AppDatabase, $MasterPasswordConfigTable> {
  $$MasterPasswordConfigTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passwordHashArgon2 => $composableBuilder(
    column: $table.passwordHashArgon2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get saltHex => $composableBuilder(
    column: $table.saltHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passwordHint => $composableBuilder(
    column: $table.passwordHint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backupCodeHashes => $composableBuilder(
    column: $table.backupCodeHashes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backupCodeData => $composableBuilder(
    column: $table.backupCodeData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedStorageKey => $composableBuilder(
    column: $table.encryptedStorageKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedStorageKeyNonce => $composableBuilder(
    column: $table.encryptedStorageKeyNonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedStorageKeyTag => $composableBuilder(
    column: $table.encryptedStorageKeyTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MasterPasswordConfigTableOrderingComposer
    extends Composer<_$AppDatabase, $MasterPasswordConfigTable> {
  $$MasterPasswordConfigTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passwordHashArgon2 => $composableBuilder(
    column: $table.passwordHashArgon2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get saltHex => $composableBuilder(
    column: $table.saltHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passwordHint => $composableBuilder(
    column: $table.passwordHint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backupCodeHashes => $composableBuilder(
    column: $table.backupCodeHashes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backupCodeData => $composableBuilder(
    column: $table.backupCodeData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedStorageKey => $composableBuilder(
    column: $table.encryptedStorageKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedStorageKeyNonce => $composableBuilder(
    column: $table.encryptedStorageKeyNonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedStorageKeyTag => $composableBuilder(
    column: $table.encryptedStorageKeyTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MasterPasswordConfigTableAnnotationComposer
    extends Composer<_$AppDatabase, $MasterPasswordConfigTable> {
  $$MasterPasswordConfigTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get passwordHashArgon2 => $composableBuilder(
    column: $table.passwordHashArgon2,
    builder: (column) => column,
  );

  GeneratedColumn<String> get saltHex =>
      $composableBuilder(column: $table.saltHex, builder: (column) => column);

  GeneratedColumn<String> get passwordHint => $composableBuilder(
    column: $table.passwordHint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backupCodeHashes => $composableBuilder(
    column: $table.backupCodeHashes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backupCodeData => $composableBuilder(
    column: $table.backupCodeData,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedStorageKey => $composableBuilder(
    column: $table.encryptedStorageKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedStorageKeyNonce => $composableBuilder(
    column: $table.encryptedStorageKeyNonce,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedStorageKeyTag => $composableBuilder(
    column: $table.encryptedStorageKeyTag,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MasterPasswordConfigTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MasterPasswordConfigTable,
          MasterPasswordConfigData,
          $$MasterPasswordConfigTableFilterComposer,
          $$MasterPasswordConfigTableOrderingComposer,
          $$MasterPasswordConfigTableAnnotationComposer,
          $$MasterPasswordConfigTableCreateCompanionBuilder,
          $$MasterPasswordConfigTableUpdateCompanionBuilder,
          (
            MasterPasswordConfigData,
            BaseReferences<
              _$AppDatabase,
              $MasterPasswordConfigTable,
              MasterPasswordConfigData
            >,
          ),
          MasterPasswordConfigData,
          PrefetchHooks Function()
        > {
  $$MasterPasswordConfigTableTableManager(
    _$AppDatabase db,
    $MasterPasswordConfigTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MasterPasswordConfigTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MasterPasswordConfigTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MasterPasswordConfigTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> passwordHashArgon2 = const Value.absent(),
                Value<String> saltHex = const Value.absent(),
                Value<String?> passwordHint = const Value.absent(),
                Value<String?> backupCodeHashes = const Value.absent(),
                Value<String?> backupCodeData = const Value.absent(),
                Value<String?> encryptedStorageKey = const Value.absent(),
                Value<String?> encryptedStorageKeyNonce = const Value.absent(),
                Value<String?> encryptedStorageKeyTag = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => MasterPasswordConfigCompanion(
                id: id,
                passwordHashArgon2: passwordHashArgon2,
                saltHex: saltHex,
                passwordHint: passwordHint,
                backupCodeHashes: backupCodeHashes,
                backupCodeData: backupCodeData,
                encryptedStorageKey: encryptedStorageKey,
                encryptedStorageKeyNonce: encryptedStorageKeyNonce,
                encryptedStorageKeyTag: encryptedStorageKeyTag,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String passwordHashArgon2,
                required String saltHex,
                Value<String?> passwordHint = const Value.absent(),
                Value<String?> backupCodeHashes = const Value.absent(),
                Value<String?> backupCodeData = const Value.absent(),
                Value<String?> encryptedStorageKey = const Value.absent(),
                Value<String?> encryptedStorageKeyNonce = const Value.absent(),
                Value<String?> encryptedStorageKeyTag = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => MasterPasswordConfigCompanion.insert(
                id: id,
                passwordHashArgon2: passwordHashArgon2,
                saltHex: saltHex,
                passwordHint: passwordHint,
                backupCodeHashes: backupCodeHashes,
                backupCodeData: backupCodeData,
                encryptedStorageKey: encryptedStorageKey,
                encryptedStorageKeyNonce: encryptedStorageKeyNonce,
                encryptedStorageKeyTag: encryptedStorageKeyTag,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MasterPasswordConfigTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MasterPasswordConfigTable,
      MasterPasswordConfigData,
      $$MasterPasswordConfigTableFilterComposer,
      $$MasterPasswordConfigTableOrderingComposer,
      $$MasterPasswordConfigTableAnnotationComposer,
      $$MasterPasswordConfigTableCreateCompanionBuilder,
      $$MasterPasswordConfigTableUpdateCompanionBuilder,
      (
        MasterPasswordConfigData,
        BaseReferences<
          _$AppDatabase,
          $MasterPasswordConfigTable,
          MasterPasswordConfigData
        >,
      ),
      MasterPasswordConfigData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$MasterPasswordConfigTableTableManager get masterPasswordConfig =>
      $$MasterPasswordConfigTableTableManager(_db, _db.masterPasswordConfig);
}

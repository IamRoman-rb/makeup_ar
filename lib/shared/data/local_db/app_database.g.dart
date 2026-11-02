// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, UserRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _passwordHashMeta = const VerificationMeta(
    'passwordHash',
  );
  @override
  late final GeneratedColumn<String> passwordHash = GeneratedColumn<String>(
    'password_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _passwordSaltMeta = const VerificationMeta(
    'passwordSalt',
  );
  @override
  late final GeneratedColumn<String> passwordSalt = GeneratedColumn<String>(
    'password_salt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _passwordIterationsMeta =
      const VerificationMeta('passwordIterations');
  @override
  late final GeneratedColumn<int> passwordIterations = GeneratedColumn<int>(
    'password_iterations',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _birthDateMeta = const VerificationMeta(
    'birthDate',
  );
  @override
  late final GeneratedColumn<String> birthDate = GeneratedColumn<String>(
    'birth_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ageMeta = const VerificationMeta('age');
  @override
  late final GeneratedColumn<int> age = GeneratedColumn<int>(
    'age',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _skinTypeMeta = const VerificationMeta(
    'skinType',
  );
  @override
  late final GeneratedColumn<String> skinType = GeneratedColumn<String>(
    'skin_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Combined'),
  );
  static const VerificationMeta _skinToneMeta = const VerificationMeta(
    'skinTone',
  );
  @override
  late final GeneratedColumn<String> skinTone = GeneratedColumn<String>(
    'skin_tone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Light'),
  );
  static const VerificationMeta _preferencesMeta = const VerificationMeta(
    'preferences',
  );
  @override
  late final GeneratedColumn<String> preferences = GeneratedColumn<String>(
    'preferences',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isAdminMeta = const VerificationMeta(
    'isAdmin',
  );
  @override
  late final GeneratedColumn<bool> isAdmin = GeneratedColumn<bool>(
    'is_admin',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_admin" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _premiumUntilMeta = const VerificationMeta(
    'premiumUntil',
  );
  @override
  late final GeneratedColumn<int> premiumUntil = GeneratedColumn<int>(
    'premium_until',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deletedAt,
    dirty,
    id,
    email,
    passwordHash,
    passwordSalt,
    passwordIterations,
    name,
    birthDate,
    age,
    skinType,
    skinTone,
    preferences,
    photoPath,
    isAdmin,
    premiumUntil,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('password_hash')) {
      context.handle(
        _passwordHashMeta,
        passwordHash.isAcceptableOrUnknown(
          data['password_hash']!,
          _passwordHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_passwordHashMeta);
    }
    if (data.containsKey('password_salt')) {
      context.handle(
        _passwordSaltMeta,
        passwordSalt.isAcceptableOrUnknown(
          data['password_salt']!,
          _passwordSaltMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_passwordSaltMeta);
    }
    if (data.containsKey('password_iterations')) {
      context.handle(
        _passwordIterationsMeta,
        passwordIterations.isAcceptableOrUnknown(
          data['password_iterations']!,
          _passwordIterationsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_passwordIterationsMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('birth_date')) {
      context.handle(
        _birthDateMeta,
        birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta),
      );
    }
    if (data.containsKey('age')) {
      context.handle(
        _ageMeta,
        age.isAcceptableOrUnknown(data['age']!, _ageMeta),
      );
    }
    if (data.containsKey('skin_type')) {
      context.handle(
        _skinTypeMeta,
        skinType.isAcceptableOrUnknown(data['skin_type']!, _skinTypeMeta),
      );
    }
    if (data.containsKey('skin_tone')) {
      context.handle(
        _skinToneMeta,
        skinTone.isAcceptableOrUnknown(data['skin_tone']!, _skinToneMeta),
      );
    }
    if (data.containsKey('preferences')) {
      context.handle(
        _preferencesMeta,
        preferences.isAcceptableOrUnknown(
          data['preferences']!,
          _preferencesMeta,
        ),
      );
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    if (data.containsKey('is_admin')) {
      context.handle(
        _isAdminMeta,
        isAdmin.isAcceptableOrUnknown(data['is_admin']!, _isAdminMeta),
      );
    }
    if (data.containsKey('premium_until')) {
      context.handle(
        _premiumUntilMeta,
        premiumUntil.isAcceptableOrUnknown(
          data['premium_until']!,
          _premiumUntilMeta,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      passwordHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password_hash'],
      )!,
      passwordSalt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password_salt'],
      )!,
      passwordIterations: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}password_iterations'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      birthDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}birth_date'],
      ),
      age: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age'],
      )!,
      skinType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skin_type'],
      )!,
      skinTone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skin_tone'],
      )!,
      preferences: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferences'],
      )!,
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
      isAdmin: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_admin'],
      )!,
      premiumUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}premium_until'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class UserRow extends DataClass implements Insertable<UserRow> {
  final int updatedAt;
  final int? deletedAt;
  final bool dirty;
  final String id;

  /// En minúsculas y sin espacios.
  final String email;

  /// PBKDF2-HMAC-SHA256 en base64, con su sal y sus iteraciones.
  final String passwordHash;
  final String passwordSalt;
  final int passwordIterations;
  final String name;

  /// yyyy-MM-dd.
  final String? birthDate;
  final int age;
  final String skinType;
  final String skinTone;

  /// Lista JSON de gustos ('Natural', 'Glamour'...).
  final String preferences;

  /// Foto de perfil en la carpeta de documentos de la app.
  final String? photoPath;
  final bool isAdmin;

  /// Vencimiento del VIP (entitlement de RevenueCat).
  final int? premiumUntil;
  final int createdAt;
  const UserRow({
    required this.updatedAt,
    this.deletedAt,
    required this.dirty,
    required this.id,
    required this.email,
    required this.passwordHash,
    required this.passwordSalt,
    required this.passwordIterations,
    required this.name,
    this.birthDate,
    required this.age,
    required this.skinType,
    required this.skinTone,
    required this.preferences,
    this.photoPath,
    required this.isAdmin,
    this.premiumUntil,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['dirty'] = Variable<bool>(dirty);
    map['id'] = Variable<String>(id);
    map['email'] = Variable<String>(email);
    map['password_hash'] = Variable<String>(passwordHash);
    map['password_salt'] = Variable<String>(passwordSalt);
    map['password_iterations'] = Variable<int>(passwordIterations);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || birthDate != null) {
      map['birth_date'] = Variable<String>(birthDate);
    }
    map['age'] = Variable<int>(age);
    map['skin_type'] = Variable<String>(skinType);
    map['skin_tone'] = Variable<String>(skinTone);
    map['preferences'] = Variable<String>(preferences);
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    map['is_admin'] = Variable<bool>(isAdmin);
    if (!nullToAbsent || premiumUntil != null) {
      map['premium_until'] = Variable<int>(premiumUntil);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dirty: Value(dirty),
      id: Value(id),
      email: Value(email),
      passwordHash: Value(passwordHash),
      passwordSalt: Value(passwordSalt),
      passwordIterations: Value(passwordIterations),
      name: Value(name),
      birthDate: birthDate == null && nullToAbsent
          ? const Value.absent()
          : Value(birthDate),
      age: Value(age),
      skinType: Value(skinType),
      skinTone: Value(skinTone),
      preferences: Value(preferences),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
      isAdmin: Value(isAdmin),
      premiumUntil: premiumUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(premiumUntil),
      createdAt: Value(createdAt),
    );
  }

  factory UserRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserRow(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      id: serializer.fromJson<String>(json['id']),
      email: serializer.fromJson<String>(json['email']),
      passwordHash: serializer.fromJson<String>(json['passwordHash']),
      passwordSalt: serializer.fromJson<String>(json['passwordSalt']),
      passwordIterations: serializer.fromJson<int>(json['passwordIterations']),
      name: serializer.fromJson<String>(json['name']),
      birthDate: serializer.fromJson<String?>(json['birthDate']),
      age: serializer.fromJson<int>(json['age']),
      skinType: serializer.fromJson<String>(json['skinType']),
      skinTone: serializer.fromJson<String>(json['skinTone']),
      preferences: serializer.fromJson<String>(json['preferences']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
      isAdmin: serializer.fromJson<bool>(json['isAdmin']),
      premiumUntil: serializer.fromJson<int?>(json['premiumUntil']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'dirty': serializer.toJson<bool>(dirty),
      'id': serializer.toJson<String>(id),
      'email': serializer.toJson<String>(email),
      'passwordHash': serializer.toJson<String>(passwordHash),
      'passwordSalt': serializer.toJson<String>(passwordSalt),
      'passwordIterations': serializer.toJson<int>(passwordIterations),
      'name': serializer.toJson<String>(name),
      'birthDate': serializer.toJson<String?>(birthDate),
      'age': serializer.toJson<int>(age),
      'skinType': serializer.toJson<String>(skinType),
      'skinTone': serializer.toJson<String>(skinTone),
      'preferences': serializer.toJson<String>(preferences),
      'photoPath': serializer.toJson<String?>(photoPath),
      'isAdmin': serializer.toJson<bool>(isAdmin),
      'premiumUntil': serializer.toJson<int?>(premiumUntil),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  UserRow copyWith({
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    bool? dirty,
    String? id,
    String? email,
    String? passwordHash,
    String? passwordSalt,
    int? passwordIterations,
    String? name,
    Value<String?> birthDate = const Value.absent(),
    int? age,
    String? skinType,
    String? skinTone,
    String? preferences,
    Value<String?> photoPath = const Value.absent(),
    bool? isAdmin,
    Value<int?> premiumUntil = const Value.absent(),
    int? createdAt,
  }) => UserRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dirty: dirty ?? this.dirty,
    id: id ?? this.id,
    email: email ?? this.email,
    passwordHash: passwordHash ?? this.passwordHash,
    passwordSalt: passwordSalt ?? this.passwordSalt,
    passwordIterations: passwordIterations ?? this.passwordIterations,
    name: name ?? this.name,
    birthDate: birthDate.present ? birthDate.value : this.birthDate,
    age: age ?? this.age,
    skinType: skinType ?? this.skinType,
    skinTone: skinTone ?? this.skinTone,
    preferences: preferences ?? this.preferences,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
    isAdmin: isAdmin ?? this.isAdmin,
    premiumUntil: premiumUntil.present ? premiumUntil.value : this.premiumUntil,
    createdAt: createdAt ?? this.createdAt,
  );
  UserRow copyWithCompanion(UsersCompanion data) {
    return UserRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      id: data.id.present ? data.id.value : this.id,
      email: data.email.present ? data.email.value : this.email,
      passwordHash: data.passwordHash.present
          ? data.passwordHash.value
          : this.passwordHash,
      passwordSalt: data.passwordSalt.present
          ? data.passwordSalt.value
          : this.passwordSalt,
      passwordIterations: data.passwordIterations.present
          ? data.passwordIterations.value
          : this.passwordIterations,
      name: data.name.present ? data.name.value : this.name,
      birthDate: data.birthDate.present ? data.birthDate.value : this.birthDate,
      age: data.age.present ? data.age.value : this.age,
      skinType: data.skinType.present ? data.skinType.value : this.skinType,
      skinTone: data.skinTone.present ? data.skinTone.value : this.skinTone,
      preferences: data.preferences.present
          ? data.preferences.value
          : this.preferences,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      isAdmin: data.isAdmin.present ? data.isAdmin.value : this.isAdmin,
      premiumUntil: data.premiumUntil.present
          ? data.premiumUntil.value
          : this.premiumUntil,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('passwordSalt: $passwordSalt, ')
          ..write('passwordIterations: $passwordIterations, ')
          ..write('name: $name, ')
          ..write('birthDate: $birthDate, ')
          ..write('age: $age, ')
          ..write('skinType: $skinType, ')
          ..write('skinTone: $skinTone, ')
          ..write('preferences: $preferences, ')
          ..write('photoPath: $photoPath, ')
          ..write('isAdmin: $isAdmin, ')
          ..write('premiumUntil: $premiumUntil, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deletedAt,
    dirty,
    id,
    email,
    passwordHash,
    passwordSalt,
    passwordIterations,
    name,
    birthDate,
    age,
    skinType,
    skinTone,
    preferences,
    photoPath,
    isAdmin,
    premiumUntil,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserRow &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dirty == this.dirty &&
          other.id == this.id &&
          other.email == this.email &&
          other.passwordHash == this.passwordHash &&
          other.passwordSalt == this.passwordSalt &&
          other.passwordIterations == this.passwordIterations &&
          other.name == this.name &&
          other.birthDate == this.birthDate &&
          other.age == this.age &&
          other.skinType == this.skinType &&
          other.skinTone == this.skinTone &&
          other.preferences == this.preferences &&
          other.photoPath == this.photoPath &&
          other.isAdmin == this.isAdmin &&
          other.premiumUntil == this.premiumUntil &&
          other.createdAt == this.createdAt);
}

class UsersCompanion extends UpdateCompanion<UserRow> {
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<bool> dirty;
  final Value<String> id;
  final Value<String> email;
  final Value<String> passwordHash;
  final Value<String> passwordSalt;
  final Value<int> passwordIterations;
  final Value<String> name;
  final Value<String?> birthDate;
  final Value<int> age;
  final Value<String> skinType;
  final Value<String> skinTone;
  final Value<String> preferences;
  final Value<String?> photoPath;
  final Value<bool> isAdmin;
  final Value<int?> premiumUntil;
  final Value<int> createdAt;
  final Value<int> rowid;
  const UsersCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.passwordSalt = const Value.absent(),
    this.passwordIterations = const Value.absent(),
    this.name = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.age = const Value.absent(),
    this.skinType = const Value.absent(),
    this.skinTone = const Value.absent(),
    this.preferences = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.isAdmin = const Value.absent(),
    this.premiumUntil = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCompanion.insert({
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    required String id,
    required String email,
    required String passwordHash,
    required String passwordSalt,
    required int passwordIterations,
    required String name,
    this.birthDate = const Value.absent(),
    this.age = const Value.absent(),
    this.skinType = const Value.absent(),
    this.skinTone = const Value.absent(),
    this.preferences = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.isAdmin = const Value.absent(),
    this.premiumUntil = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       id = Value(id),
       email = Value(email),
       passwordHash = Value(passwordHash),
       passwordSalt = Value(passwordSalt),
       passwordIterations = Value(passwordIterations),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<UserRow> custom({
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<bool>? dirty,
    Expression<String>? id,
    Expression<String>? email,
    Expression<String>? passwordHash,
    Expression<String>? passwordSalt,
    Expression<int>? passwordIterations,
    Expression<String>? name,
    Expression<String>? birthDate,
    Expression<int>? age,
    Expression<String>? skinType,
    Expression<String>? skinTone,
    Expression<String>? preferences,
    Expression<String>? photoPath,
    Expression<bool>? isAdmin,
    Expression<int>? premiumUntil,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dirty != null) 'dirty': dirty,
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (passwordHash != null) 'password_hash': passwordHash,
      if (passwordSalt != null) 'password_salt': passwordSalt,
      if (passwordIterations != null) 'password_iterations': passwordIterations,
      if (name != null) 'name': name,
      if (birthDate != null) 'birth_date': birthDate,
      if (age != null) 'age': age,
      if (skinType != null) 'skin_type': skinType,
      if (skinTone != null) 'skin_tone': skinTone,
      if (preferences != null) 'preferences': preferences,
      if (photoPath != null) 'photo_path': photoPath,
      if (isAdmin != null) 'is_admin': isAdmin,
      if (premiumUntil != null) 'premium_until': premiumUntil,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCompanion copyWith({
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<bool>? dirty,
    Value<String>? id,
    Value<String>? email,
    Value<String>? passwordHash,
    Value<String>? passwordSalt,
    Value<int>? passwordIterations,
    Value<String>? name,
    Value<String?>? birthDate,
    Value<int>? age,
    Value<String>? skinType,
    Value<String>? skinTone,
    Value<String>? preferences,
    Value<String?>? photoPath,
    Value<bool>? isAdmin,
    Value<int?>? premiumUntil,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return UsersCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
      id: id ?? this.id,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      passwordIterations: passwordIterations ?? this.passwordIterations,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      age: age ?? this.age,
      skinType: skinType ?? this.skinType,
      skinTone: skinTone ?? this.skinTone,
      preferences: preferences ?? this.preferences,
      photoPath: photoPath ?? this.photoPath,
      isAdmin: isAdmin ?? this.isAdmin,
      premiumUntil: premiumUntil ?? this.premiumUntil,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (passwordHash.present) {
      map['password_hash'] = Variable<String>(passwordHash.value);
    }
    if (passwordSalt.present) {
      map['password_salt'] = Variable<String>(passwordSalt.value);
    }
    if (passwordIterations.present) {
      map['password_iterations'] = Variable<int>(passwordIterations.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (birthDate.present) {
      map['birth_date'] = Variable<String>(birthDate.value);
    }
    if (age.present) {
      map['age'] = Variable<int>(age.value);
    }
    if (skinType.present) {
      map['skin_type'] = Variable<String>(skinType.value);
    }
    if (skinTone.present) {
      map['skin_tone'] = Variable<String>(skinTone.value);
    }
    if (preferences.present) {
      map['preferences'] = Variable<String>(preferences.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (isAdmin.present) {
      map['is_admin'] = Variable<bool>(isAdmin.value);
    }
    if (premiumUntil.present) {
      map['premium_until'] = Variable<int>(premiumUntil.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('passwordSalt: $passwordSalt, ')
          ..write('passwordIterations: $passwordIterations, ')
          ..write('name: $name, ')
          ..write('birthDate: $birthDate, ')
          ..write('age: $age, ')
          ..write('skinType: $skinType, ')
          ..write('skinTone: $skinTone, ')
          ..write('preferences: $preferences, ')
          ..write('photoPath: $photoPath, ')
          ..write('isAdmin: $isAdmin, ')
          ..write('premiumUntil: $premiumUntil, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions
    with TableInfo<$SessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<String> slot = GeneratedColumn<String>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(kSessionSlot),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [slot, userId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {slot};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final String slot;
  final String userId;
  const SessionRow({required this.slot, required this.userId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['slot'] = Variable<String>(slot);
    map['user_id'] = Variable<String>(userId);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(slot: Value(slot), userId: Value(userId));
  }

  factory SessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      slot: serializer.fromJson<String>(json['slot']),
      userId: serializer.fromJson<String>(json['userId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'slot': serializer.toJson<String>(slot),
      'userId': serializer.toJson<String>(userId),
    };
  }

  SessionRow copyWith({String? slot, String? userId}) =>
      SessionRow(slot: slot ?? this.slot, userId: userId ?? this.userId);
  SessionRow copyWithCompanion(SessionsCompanion data) {
    return SessionRow(
      slot: data.slot.present ? data.slot.value : this.slot,
      userId: data.userId.present ? data.userId.value : this.userId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('slot: $slot, ')
          ..write('userId: $userId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(slot, userId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.slot == this.slot &&
          other.userId == this.userId);
}

class SessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<String> slot;
  final Value<String> userId;
  final Value<int> rowid;
  const SessionsCompanion({
    this.slot = const Value.absent(),
    this.userId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    this.slot = const Value.absent(),
    required String userId,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId);
  static Insertable<SessionRow> custom({
    Expression<String>? slot,
    Expression<String>? userId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (slot != null) 'slot': slot,
      if (userId != null) 'user_id': userId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? slot,
    Value<String>? userId,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      slot: slot ?? this.slot,
      userId: userId ?? this.userId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (slot.present) {
      map['slot'] = Variable<String>(slot.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('slot: $slot, ')
          ..write('userId: $userId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LooksTable extends Looks with TableInfo<$LooksTable, LookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageMeta = const VerificationMeta('image');
  @override
  late final GeneratedColumn<String> image = GeneratedColumn<String>(
    'image',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<String> steps = GeneratedColumn<String>(
    'steps',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recipeMeta = const VerificationMeta('recipe');
  @override
  late final GeneratedColumn<String> recipe = GeneratedColumn<String>(
    'recipe',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recipeSchemaMeta = const VerificationMeta(
    'recipeSchema',
  );
  @override
  late final GeneratedColumn<String> recipeSchema = GeneratedColumn<String>(
    'recipe_schema',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minEngineMeta = const VerificationMeta(
    'minEngine',
  );
  @override
  late final GeneratedColumn<int> minEngine = GeneratedColumn<int>(
    'min_engine',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _videoUrlMeta = const VerificationMeta(
    'videoUrl',
  );
  @override
  late final GeneratedColumn<String> videoUrl = GeneratedColumn<String>(
    'video_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deletedAt,
    dirty,
    id,
    name,
    category,
    image,
    steps,
    sortOrder,
    recipe,
    recipeSchema,
    minEngine,
    source,
    videoUrl,
    createdBy,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'looks';
  @override
  VerificationContext validateIntegrity(
    Insertable<LookRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('image')) {
      context.handle(
        _imageMeta,
        image.isAcceptableOrUnknown(data['image']!, _imageMeta),
      );
    }
    if (data.containsKey('steps')) {
      context.handle(
        _stepsMeta,
        steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('recipe')) {
      context.handle(
        _recipeMeta,
        recipe.isAcceptableOrUnknown(data['recipe']!, _recipeMeta),
      );
    }
    if (data.containsKey('recipe_schema')) {
      context.handle(
        _recipeSchemaMeta,
        recipeSchema.isAcceptableOrUnknown(
          data['recipe_schema']!,
          _recipeSchemaMeta,
        ),
      );
    }
    if (data.containsKey('min_engine')) {
      context.handle(
        _minEngineMeta,
        minEngine.isAcceptableOrUnknown(data['min_engine']!, _minEngineMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('video_url')) {
      context.handle(
        _videoUrlMeta,
        videoUrl.isAcceptableOrUnknown(data['video_url']!, _videoUrlMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
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
  LookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LookRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      image: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image'],
      ),
      steps: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}steps'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      ),
      recipe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe'],
      ),
      recipeSchema: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_schema'],
      ),
      minEngine: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_engine'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      videoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_url'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LooksTable createAlias(String alias) {
    return $LooksTable(attachedDatabase, alias);
  }
}

class LookRow extends DataClass implements Insertable<LookRow> {
  final int updatedAt;
  final int? deletedAt;
  final bool dirty;
  final String id;
  final String name;

  /// LookCategory.wireName ('Lips', 'Eyes', 'Complexion').
  final String category;
  final String? image;

  /// Lista JSON de pasos del tutorial ({title, image, description}).
  final String steps;

  /// Clave de orden explícita (catalogSortKey); sin ella, [createdAt].
  final int? sortOrder;

  /// Receta makeup-recipe/2 en JSON; null en looks solo de tutorial.
  final String? recipe;
  final String? recipeSchema;
  final int? minEngine;

  /// Origen de la receta en JSON ({type, prompt?, model?}).
  final String? source;

  /// Video del tutorial (contenido VIP).
  final String? videoUrl;
  final String? createdBy;
  final int createdAt;
  const LookRow({
    required this.updatedAt,
    this.deletedAt,
    required this.dirty,
    required this.id,
    required this.name,
    required this.category,
    this.image,
    required this.steps,
    this.sortOrder,
    this.recipe,
    this.recipeSchema,
    this.minEngine,
    this.source,
    this.videoUrl,
    this.createdBy,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['dirty'] = Variable<bool>(dirty);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || image != null) {
      map['image'] = Variable<String>(image);
    }
    map['steps'] = Variable<String>(steps);
    if (!nullToAbsent || sortOrder != null) {
      map['sort_order'] = Variable<int>(sortOrder);
    }
    if (!nullToAbsent || recipe != null) {
      map['recipe'] = Variable<String>(recipe);
    }
    if (!nullToAbsent || recipeSchema != null) {
      map['recipe_schema'] = Variable<String>(recipeSchema);
    }
    if (!nullToAbsent || minEngine != null) {
      map['min_engine'] = Variable<int>(minEngine);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    if (!nullToAbsent || videoUrl != null) {
      map['video_url'] = Variable<String>(videoUrl);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  LooksCompanion toCompanion(bool nullToAbsent) {
    return LooksCompanion(
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dirty: Value(dirty),
      id: Value(id),
      name: Value(name),
      category: Value(category),
      image: image == null && nullToAbsent
          ? const Value.absent()
          : Value(image),
      steps: Value(steps),
      sortOrder: sortOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(sortOrder),
      recipe: recipe == null && nullToAbsent
          ? const Value.absent()
          : Value(recipe),
      recipeSchema: recipeSchema == null && nullToAbsent
          ? const Value.absent()
          : Value(recipeSchema),
      minEngine: minEngine == null && nullToAbsent
          ? const Value.absent()
          : Value(minEngine),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      videoUrl: videoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(videoUrl),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      createdAt: Value(createdAt),
    );
  }

  factory LookRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LookRow(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      image: serializer.fromJson<String?>(json['image']),
      steps: serializer.fromJson<String>(json['steps']),
      sortOrder: serializer.fromJson<int?>(json['sortOrder']),
      recipe: serializer.fromJson<String?>(json['recipe']),
      recipeSchema: serializer.fromJson<String?>(json['recipeSchema']),
      minEngine: serializer.fromJson<int?>(json['minEngine']),
      source: serializer.fromJson<String?>(json['source']),
      videoUrl: serializer.fromJson<String?>(json['videoUrl']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'dirty': serializer.toJson<bool>(dirty),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'image': serializer.toJson<String?>(image),
      'steps': serializer.toJson<String>(steps),
      'sortOrder': serializer.toJson<int?>(sortOrder),
      'recipe': serializer.toJson<String?>(recipe),
      'recipeSchema': serializer.toJson<String?>(recipeSchema),
      'minEngine': serializer.toJson<int?>(minEngine),
      'source': serializer.toJson<String?>(source),
      'videoUrl': serializer.toJson<String?>(videoUrl),
      'createdBy': serializer.toJson<String?>(createdBy),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  LookRow copyWith({
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    bool? dirty,
    String? id,
    String? name,
    String? category,
    Value<String?> image = const Value.absent(),
    String? steps,
    Value<int?> sortOrder = const Value.absent(),
    Value<String?> recipe = const Value.absent(),
    Value<String?> recipeSchema = const Value.absent(),
    Value<int?> minEngine = const Value.absent(),
    Value<String?> source = const Value.absent(),
    Value<String?> videoUrl = const Value.absent(),
    Value<String?> createdBy = const Value.absent(),
    int? createdAt,
  }) => LookRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dirty: dirty ?? this.dirty,
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    image: image.present ? image.value : this.image,
    steps: steps ?? this.steps,
    sortOrder: sortOrder.present ? sortOrder.value : this.sortOrder,
    recipe: recipe.present ? recipe.value : this.recipe,
    recipeSchema: recipeSchema.present ? recipeSchema.value : this.recipeSchema,
    minEngine: minEngine.present ? minEngine.value : this.minEngine,
    source: source.present ? source.value : this.source,
    videoUrl: videoUrl.present ? videoUrl.value : this.videoUrl,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    createdAt: createdAt ?? this.createdAt,
  );
  LookRow copyWithCompanion(LooksCompanion data) {
    return LookRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      image: data.image.present ? data.image.value : this.image,
      steps: data.steps.present ? data.steps.value : this.steps,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      recipe: data.recipe.present ? data.recipe.value : this.recipe,
      recipeSchema: data.recipeSchema.present
          ? data.recipeSchema.value
          : this.recipeSchema,
      minEngine: data.minEngine.present ? data.minEngine.value : this.minEngine,
      source: data.source.present ? data.source.value : this.source,
      videoUrl: data.videoUrl.present ? data.videoUrl.value : this.videoUrl,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LookRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('image: $image, ')
          ..write('steps: $steps, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('recipe: $recipe, ')
          ..write('recipeSchema: $recipeSchema, ')
          ..write('minEngine: $minEngine, ')
          ..write('source: $source, ')
          ..write('videoUrl: $videoUrl, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deletedAt,
    dirty,
    id,
    name,
    category,
    image,
    steps,
    sortOrder,
    recipe,
    recipeSchema,
    minEngine,
    source,
    videoUrl,
    createdBy,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LookRow &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dirty == this.dirty &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.image == this.image &&
          other.steps == this.steps &&
          other.sortOrder == this.sortOrder &&
          other.recipe == this.recipe &&
          other.recipeSchema == this.recipeSchema &&
          other.minEngine == this.minEngine &&
          other.source == this.source &&
          other.videoUrl == this.videoUrl &&
          other.createdBy == this.createdBy &&
          other.createdAt == this.createdAt);
}

class LooksCompanion extends UpdateCompanion<LookRow> {
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<bool> dirty;
  final Value<String> id;
  final Value<String> name;
  final Value<String> category;
  final Value<String?> image;
  final Value<String> steps;
  final Value<int?> sortOrder;
  final Value<String?> recipe;
  final Value<String?> recipeSchema;
  final Value<int?> minEngine;
  final Value<String?> source;
  final Value<String?> videoUrl;
  final Value<String?> createdBy;
  final Value<int> createdAt;
  final Value<int> rowid;
  const LooksCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.image = const Value.absent(),
    this.steps = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.recipe = const Value.absent(),
    this.recipeSchema = const Value.absent(),
    this.minEngine = const Value.absent(),
    this.source = const Value.absent(),
    this.videoUrl = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LooksCompanion.insert({
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    required String id,
    required String name,
    required String category,
    this.image = const Value.absent(),
    this.steps = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.recipe = const Value.absent(),
    this.recipeSchema = const Value.absent(),
    this.minEngine = const Value.absent(),
    this.source = const Value.absent(),
    this.videoUrl = const Value.absent(),
    this.createdBy = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       id = Value(id),
       name = Value(name),
       category = Value(category),
       createdAt = Value(createdAt);
  static Insertable<LookRow> custom({
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<bool>? dirty,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? image,
    Expression<String>? steps,
    Expression<int>? sortOrder,
    Expression<String>? recipe,
    Expression<String>? recipeSchema,
    Expression<int>? minEngine,
    Expression<String>? source,
    Expression<String>? videoUrl,
    Expression<String>? createdBy,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dirty != null) 'dirty': dirty,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (image != null) 'image': image,
      if (steps != null) 'steps': steps,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (recipe != null) 'recipe': recipe,
      if (recipeSchema != null) 'recipe_schema': recipeSchema,
      if (minEngine != null) 'min_engine': minEngine,
      if (source != null) 'source': source,
      if (videoUrl != null) 'video_url': videoUrl,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LooksCompanion copyWith({
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<bool>? dirty,
    Value<String>? id,
    Value<String>? name,
    Value<String>? category,
    Value<String?>? image,
    Value<String>? steps,
    Value<int?>? sortOrder,
    Value<String?>? recipe,
    Value<String?>? recipeSchema,
    Value<int?>? minEngine,
    Value<String?>? source,
    Value<String?>? videoUrl,
    Value<String?>? createdBy,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return LooksCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      image: image ?? this.image,
      steps: steps ?? this.steps,
      sortOrder: sortOrder ?? this.sortOrder,
      recipe: recipe ?? this.recipe,
      recipeSchema: recipeSchema ?? this.recipeSchema,
      minEngine: minEngine ?? this.minEngine,
      source: source ?? this.source,
      videoUrl: videoUrl ?? this.videoUrl,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (image.present) {
      map['image'] = Variable<String>(image.value);
    }
    if (steps.present) {
      map['steps'] = Variable<String>(steps.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (recipe.present) {
      map['recipe'] = Variable<String>(recipe.value);
    }
    if (recipeSchema.present) {
      map['recipe_schema'] = Variable<String>(recipeSchema.value);
    }
    if (minEngine.present) {
      map['min_engine'] = Variable<int>(minEngine.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (videoUrl.present) {
      map['video_url'] = Variable<String>(videoUrl.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LooksCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('image: $image, ')
          ..write('steps: $steps, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('recipe: $recipe, ')
          ..write('recipeSchema: $recipeSchema, ')
          ..write('minEngine: $minEngine, ')
          ..write('source: $source, ')
          ..write('videoUrl: $videoUrl, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LookDraftsTable extends LookDrafts
    with TableInfo<$LookDraftsTable, LookDraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LookDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageMeta = const VerificationMeta('image');
  @override
  late final GeneratedColumn<String> image = GeneratedColumn<String>(
    'image',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recipeMeta = const VerificationMeta('recipe');
  @override
  late final GeneratedColumn<String> recipe = GeneratedColumn<String>(
    'recipe',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipeSchemaMeta = const VerificationMeta(
    'recipeSchema',
  );
  @override
  late final GeneratedColumn<String> recipeSchema = GeneratedColumn<String>(
    'recipe_schema',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minEngineMeta = const VerificationMeta(
    'minEngine',
  );
  @override
  late final GeneratedColumn<int> minEngine = GeneratedColumn<int>(
    'min_engine',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deletedAt,
    dirty,
    id,
    name,
    category,
    image,
    recipe,
    recipeSchema,
    minEngine,
    source,
    createdBy,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'look_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LookDraftRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('image')) {
      context.handle(
        _imageMeta,
        image.isAcceptableOrUnknown(data['image']!, _imageMeta),
      );
    }
    if (data.containsKey('recipe')) {
      context.handle(
        _recipeMeta,
        recipe.isAcceptableOrUnknown(data['recipe']!, _recipeMeta),
      );
    } else if (isInserting) {
      context.missing(_recipeMeta);
    }
    if (data.containsKey('recipe_schema')) {
      context.handle(
        _recipeSchemaMeta,
        recipeSchema.isAcceptableOrUnknown(
          data['recipe_schema']!,
          _recipeSchemaMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipeSchemaMeta);
    }
    if (data.containsKey('min_engine')) {
      context.handle(
        _minEngineMeta,
        minEngine.isAcceptableOrUnknown(data['min_engine']!, _minEngineMeta),
      );
    } else if (isInserting) {
      context.missing(_minEngineMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
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
  LookDraftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LookDraftRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      image: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image'],
      ),
      recipe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe'],
      )!,
      recipeSchema: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_schema'],
      )!,
      minEngine: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_engine'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LookDraftsTable createAlias(String alias) {
    return $LookDraftsTable(attachedDatabase, alias);
  }
}

class LookDraftRow extends DataClass implements Insertable<LookDraftRow> {
  final int updatedAt;
  final int? deletedAt;
  final bool dirty;
  final String id;
  final String name;
  final String category;
  final String? image;
  final String recipe;
  final String recipeSchema;
  final int minEngine;
  final String? source;
  final String createdBy;
  final int createdAt;
  const LookDraftRow({
    required this.updatedAt,
    this.deletedAt,
    required this.dirty,
    required this.id,
    required this.name,
    required this.category,
    this.image,
    required this.recipe,
    required this.recipeSchema,
    required this.minEngine,
    this.source,
    required this.createdBy,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['dirty'] = Variable<bool>(dirty);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || image != null) {
      map['image'] = Variable<String>(image);
    }
    map['recipe'] = Variable<String>(recipe);
    map['recipe_schema'] = Variable<String>(recipeSchema);
    map['min_engine'] = Variable<int>(minEngine);
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    map['created_by'] = Variable<String>(createdBy);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  LookDraftsCompanion toCompanion(bool nullToAbsent) {
    return LookDraftsCompanion(
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dirty: Value(dirty),
      id: Value(id),
      name: Value(name),
      category: Value(category),
      image: image == null && nullToAbsent
          ? const Value.absent()
          : Value(image),
      recipe: Value(recipe),
      recipeSchema: Value(recipeSchema),
      minEngine: Value(minEngine),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      createdBy: Value(createdBy),
      createdAt: Value(createdAt),
    );
  }

  factory LookDraftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LookDraftRow(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      image: serializer.fromJson<String?>(json['image']),
      recipe: serializer.fromJson<String>(json['recipe']),
      recipeSchema: serializer.fromJson<String>(json['recipeSchema']),
      minEngine: serializer.fromJson<int>(json['minEngine']),
      source: serializer.fromJson<String?>(json['source']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'dirty': serializer.toJson<bool>(dirty),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'image': serializer.toJson<String?>(image),
      'recipe': serializer.toJson<String>(recipe),
      'recipeSchema': serializer.toJson<String>(recipeSchema),
      'minEngine': serializer.toJson<int>(minEngine),
      'source': serializer.toJson<String?>(source),
      'createdBy': serializer.toJson<String>(createdBy),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  LookDraftRow copyWith({
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    bool? dirty,
    String? id,
    String? name,
    String? category,
    Value<String?> image = const Value.absent(),
    String? recipe,
    String? recipeSchema,
    int? minEngine,
    Value<String?> source = const Value.absent(),
    String? createdBy,
    int? createdAt,
  }) => LookDraftRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dirty: dirty ?? this.dirty,
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    image: image.present ? image.value : this.image,
    recipe: recipe ?? this.recipe,
    recipeSchema: recipeSchema ?? this.recipeSchema,
    minEngine: minEngine ?? this.minEngine,
    source: source.present ? source.value : this.source,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
  );
  LookDraftRow copyWithCompanion(LookDraftsCompanion data) {
    return LookDraftRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      image: data.image.present ? data.image.value : this.image,
      recipe: data.recipe.present ? data.recipe.value : this.recipe,
      recipeSchema: data.recipeSchema.present
          ? data.recipeSchema.value
          : this.recipeSchema,
      minEngine: data.minEngine.present ? data.minEngine.value : this.minEngine,
      source: data.source.present ? data.source.value : this.source,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LookDraftRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('image: $image, ')
          ..write('recipe: $recipe, ')
          ..write('recipeSchema: $recipeSchema, ')
          ..write('minEngine: $minEngine, ')
          ..write('source: $source, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deletedAt,
    dirty,
    id,
    name,
    category,
    image,
    recipe,
    recipeSchema,
    minEngine,
    source,
    createdBy,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LookDraftRow &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dirty == this.dirty &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.image == this.image &&
          other.recipe == this.recipe &&
          other.recipeSchema == this.recipeSchema &&
          other.minEngine == this.minEngine &&
          other.source == this.source &&
          other.createdBy == this.createdBy &&
          other.createdAt == this.createdAt);
}

class LookDraftsCompanion extends UpdateCompanion<LookDraftRow> {
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<bool> dirty;
  final Value<String> id;
  final Value<String> name;
  final Value<String> category;
  final Value<String?> image;
  final Value<String> recipe;
  final Value<String> recipeSchema;
  final Value<int> minEngine;
  final Value<String?> source;
  final Value<String> createdBy;
  final Value<int> createdAt;
  final Value<int> rowid;
  const LookDraftsCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.image = const Value.absent(),
    this.recipe = const Value.absent(),
    this.recipeSchema = const Value.absent(),
    this.minEngine = const Value.absent(),
    this.source = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LookDraftsCompanion.insert({
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    required String id,
    required String name,
    required String category,
    this.image = const Value.absent(),
    required String recipe,
    required String recipeSchema,
    required int minEngine,
    this.source = const Value.absent(),
    required String createdBy,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       id = Value(id),
       name = Value(name),
       category = Value(category),
       recipe = Value(recipe),
       recipeSchema = Value(recipeSchema),
       minEngine = Value(minEngine),
       createdBy = Value(createdBy),
       createdAt = Value(createdAt);
  static Insertable<LookDraftRow> custom({
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<bool>? dirty,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? image,
    Expression<String>? recipe,
    Expression<String>? recipeSchema,
    Expression<int>? minEngine,
    Expression<String>? source,
    Expression<String>? createdBy,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dirty != null) 'dirty': dirty,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (image != null) 'image': image,
      if (recipe != null) 'recipe': recipe,
      if (recipeSchema != null) 'recipe_schema': recipeSchema,
      if (minEngine != null) 'min_engine': minEngine,
      if (source != null) 'source': source,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LookDraftsCompanion copyWith({
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<bool>? dirty,
    Value<String>? id,
    Value<String>? name,
    Value<String>? category,
    Value<String?>? image,
    Value<String>? recipe,
    Value<String>? recipeSchema,
    Value<int>? minEngine,
    Value<String?>? source,
    Value<String>? createdBy,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return LookDraftsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      image: image ?? this.image,
      recipe: recipe ?? this.recipe,
      recipeSchema: recipeSchema ?? this.recipeSchema,
      minEngine: minEngine ?? this.minEngine,
      source: source ?? this.source,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (image.present) {
      map['image'] = Variable<String>(image.value);
    }
    if (recipe.present) {
      map['recipe'] = Variable<String>(recipe.value);
    }
    if (recipeSchema.present) {
      map['recipe_schema'] = Variable<String>(recipeSchema.value);
    }
    if (minEngine.present) {
      map['min_engine'] = Variable<int>(minEngine.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LookDraftsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('image: $image, ')
          ..write('recipe: $recipe, ')
          ..write('recipeSchema: $recipeSchema, ')
          ..write('minEngine: $minEngine, ')
          ..write('source: $source, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedLooksTable extends SavedLooks
    with TableInfo<$SavedLooksTable, SavedLookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedLooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _lookIdMeta = const VerificationMeta('lookId');
  @override
  late final GeneratedColumn<String> lookId = GeneratedColumn<String>(
    'look_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deletedAt,
    dirty,
    userId,
    lookId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_looks';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedLookRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('look_id')) {
      context.handle(
        _lookIdMeta,
        lookId.isAcceptableOrUnknown(data['look_id']!, _lookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lookIdMeta);
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
  Set<GeneratedColumn> get $primaryKey => {userId, lookId};
  @override
  SavedLookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedLookRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      lookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}look_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SavedLooksTable createAlias(String alias) {
    return $SavedLooksTable(attachedDatabase, alias);
  }
}

class SavedLookRow extends DataClass implements Insertable<SavedLookRow> {
  final int updatedAt;
  final int? deletedAt;
  final bool dirty;
  final String userId;
  final String lookId;
  final int createdAt;
  const SavedLookRow({
    required this.updatedAt,
    this.deletedAt,
    required this.dirty,
    required this.userId,
    required this.lookId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['dirty'] = Variable<bool>(dirty);
    map['user_id'] = Variable<String>(userId);
    map['look_id'] = Variable<String>(lookId);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  SavedLooksCompanion toCompanion(bool nullToAbsent) {
    return SavedLooksCompanion(
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dirty: Value(dirty),
      userId: Value(userId),
      lookId: Value(lookId),
      createdAt: Value(createdAt),
    );
  }

  factory SavedLookRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedLookRow(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      userId: serializer.fromJson<String>(json['userId']),
      lookId: serializer.fromJson<String>(json['lookId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'dirty': serializer.toJson<bool>(dirty),
      'userId': serializer.toJson<String>(userId),
      'lookId': serializer.toJson<String>(lookId),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  SavedLookRow copyWith({
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    bool? dirty,
    String? userId,
    String? lookId,
    int? createdAt,
  }) => SavedLookRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dirty: dirty ?? this.dirty,
    userId: userId ?? this.userId,
    lookId: lookId ?? this.lookId,
    createdAt: createdAt ?? this.createdAt,
  );
  SavedLookRow copyWithCompanion(SavedLooksCompanion data) {
    return SavedLookRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      userId: data.userId.present ? data.userId.value : this.userId,
      lookId: data.lookId.present ? data.lookId.value : this.lookId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedLookRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('userId: $userId, ')
          ..write('lookId: $lookId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(updatedAt, deletedAt, dirty, userId, lookId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedLookRow &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dirty == this.dirty &&
          other.userId == this.userId &&
          other.lookId == this.lookId &&
          other.createdAt == this.createdAt);
}

class SavedLooksCompanion extends UpdateCompanion<SavedLookRow> {
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<bool> dirty;
  final Value<String> userId;
  final Value<String> lookId;
  final Value<int> createdAt;
  final Value<int> rowid;
  const SavedLooksCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.userId = const Value.absent(),
    this.lookId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedLooksCompanion.insert({
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    required String userId,
    required String lookId,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       userId = Value(userId),
       lookId = Value(lookId),
       createdAt = Value(createdAt);
  static Insertable<SavedLookRow> custom({
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<bool>? dirty,
    Expression<String>? userId,
    Expression<String>? lookId,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dirty != null) 'dirty': dirty,
      if (userId != null) 'user_id': userId,
      if (lookId != null) 'look_id': lookId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedLooksCompanion copyWith({
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<bool>? dirty,
    Value<String>? userId,
    Value<String>? lookId,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return SavedLooksCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
      userId: userId ?? this.userId,
      lookId: lookId ?? this.lookId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (lookId.present) {
      map['look_id'] = Variable<String>(lookId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedLooksCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('userId: $userId, ')
          ..write('lookId: $lookId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiLooksTable extends AiLooks with TableInfo<$AiLooksTable, AiLookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiLooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _recipeMeta = const VerificationMeta('recipe');
  @override
  late final GeneratedColumn<String> recipe = GeneratedColumn<String>(
    'recipe',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deletedAt,
    dirty,
    id,
    userId,
    recipe,
    source,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_looks';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiLookRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('recipe')) {
      context.handle(
        _recipeMeta,
        recipe.isAcceptableOrUnknown(data['recipe']!, _recipeMeta),
      );
    } else if (isInserting) {
      context.missing(_recipeMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
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
  AiLookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiLookRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      recipe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AiLooksTable createAlias(String alias) {
    return $AiLooksTable(attachedDatabase, alias);
  }
}

class AiLookRow extends DataClass implements Insertable<AiLookRow> {
  final int updatedAt;
  final int? deletedAt;
  final bool dirty;
  final String id;
  final String userId;
  final String recipe;

  /// AiLookSource.wireName ('prompt' o 'remix').
  final String source;
  final int createdAt;
  const AiLookRow({
    required this.updatedAt,
    this.deletedAt,
    required this.dirty,
    required this.id,
    required this.userId,
    required this.recipe,
    required this.source,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['dirty'] = Variable<bool>(dirty);
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['recipe'] = Variable<String>(recipe);
    map['source'] = Variable<String>(source);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  AiLooksCompanion toCompanion(bool nullToAbsent) {
    return AiLooksCompanion(
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dirty: Value(dirty),
      id: Value(id),
      userId: Value(userId),
      recipe: Value(recipe),
      source: Value(source),
      createdAt: Value(createdAt),
    );
  }

  factory AiLookRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiLookRow(
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      recipe: serializer.fromJson<String>(json['recipe']),
      source: serializer.fromJson<String>(json['source']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'dirty': serializer.toJson<bool>(dirty),
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'recipe': serializer.toJson<String>(recipe),
      'source': serializer.toJson<String>(source),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  AiLookRow copyWith({
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    bool? dirty,
    String? id,
    String? userId,
    String? recipe,
    String? source,
    int? createdAt,
  }) => AiLookRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dirty: dirty ?? this.dirty,
    id: id ?? this.id,
    userId: userId ?? this.userId,
    recipe: recipe ?? this.recipe,
    source: source ?? this.source,
    createdAt: createdAt ?? this.createdAt,
  );
  AiLookRow copyWithCompanion(AiLooksCompanion data) {
    return AiLookRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      recipe: data.recipe.present ? data.recipe.value : this.recipe,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiLookRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('recipe: $recipe, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deletedAt,
    dirty,
    id,
    userId,
    recipe,
    source,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiLookRow &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dirty == this.dirty &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.recipe == this.recipe &&
          other.source == this.source &&
          other.createdAt == this.createdAt);
}

class AiLooksCompanion extends UpdateCompanion<AiLookRow> {
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<bool> dirty;
  final Value<String> id;
  final Value<String> userId;
  final Value<String> recipe;
  final Value<String> source;
  final Value<int> createdAt;
  final Value<int> rowid;
  const AiLooksCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.recipe = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiLooksCompanion.insert({
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    required String id,
    required String userId,
    required String recipe,
    required String source,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       id = Value(id),
       userId = Value(userId),
       recipe = Value(recipe),
       source = Value(source),
       createdAt = Value(createdAt);
  static Insertable<AiLookRow> custom({
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<bool>? dirty,
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? recipe,
    Expression<String>? source,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dirty != null) 'dirty': dirty,
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (recipe != null) 'recipe': recipe,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiLooksCompanion copyWith({
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<bool>? dirty,
    Value<String>? id,
    Value<String>? userId,
    Value<String>? recipe,
    Value<String>? source,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return AiLooksCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
      id: id ?? this.id,
      userId: userId ?? this.userId,
      recipe: recipe ?? this.recipe,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (recipe.present) {
      map['recipe'] = Variable<String>(recipe.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiLooksCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('recipe: $recipe, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $LooksTable looks = $LooksTable(this);
  late final $LookDraftsTable lookDrafts = $LookDraftsTable(this);
  late final $SavedLooksTable savedLooks = $SavedLooksTable(this);
  late final $AiLooksTable aiLooks = $AiLooksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    users,
    sessions,
    looks,
    lookDrafts,
    savedLooks,
    aiLooks,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'users',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sessions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'users',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('saved_looks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'users',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('ai_looks', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$UsersTableCreateCompanionBuilder =
    UsersCompanion Function({
      required int updatedAt,
      Value<int?> deletedAt,
      Value<bool> dirty,
      required String id,
      required String email,
      required String passwordHash,
      required String passwordSalt,
      required int passwordIterations,
      required String name,
      Value<String?> birthDate,
      Value<int> age,
      Value<String> skinType,
      Value<String> skinTone,
      Value<String> preferences,
      Value<String?> photoPath,
      Value<bool> isAdmin,
      Value<int?> premiumUntil,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$UsersTableUpdateCompanionBuilder =
    UsersCompanion Function({
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<bool> dirty,
      Value<String> id,
      Value<String> email,
      Value<String> passwordHash,
      Value<String> passwordSalt,
      Value<int> passwordIterations,
      Value<String> name,
      Value<String?> birthDate,
      Value<int> age,
      Value<String> skinType,
      Value<String> skinTone,
      Value<String> preferences,
      Value<String?> photoPath,
      Value<bool> isAdmin,
      Value<int?> premiumUntil,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$UsersTableReferences
    extends BaseReferences<_$AppDatabase, $UsersTable, UserRow> {
  $$UsersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SessionsTable, List<SessionRow>>
  _sessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sessions,
    aliasName: 'users__id__sessions__user_id',
  );

  $$SessionsTableProcessedTableManager get sessionsRefs {
    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SavedLooksTable, List<SavedLookRow>>
  _savedLooksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.savedLooks,
    aliasName: 'users__id__saved_looks__user_id',
  );

  $$SavedLooksTableProcessedTableManager get savedLooksRefs {
    final manager = $$SavedLooksTableTableManager(
      $_db,
      $_db.savedLooks,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_savedLooksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AiLooksTable, List<AiLookRow>> _aiLooksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.aiLooks,
    aliasName: 'users__id__ai_looks__user_id',
  );

  $$AiLooksTableProcessedTableManager get aiLooksRefs {
    final manager = $$AiLooksTableTableManager(
      $_db,
      $_db.aiLooks,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_aiLooksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passwordSalt => $composableBuilder(
    column: $table.passwordSalt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get passwordIterations => $composableBuilder(
    column: $table.passwordIterations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skinType => $composableBuilder(
    column: $table.skinType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skinTone => $composableBuilder(
    column: $table.skinTone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferences => $composableBuilder(
    column: $table.preferences,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAdmin => $composableBuilder(
    column: $table.isAdmin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get premiumUntil => $composableBuilder(
    column: $table.premiumUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sessionsRefs(
    Expression<bool> Function($$SessionsTableFilterComposer f) f,
  ) {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> savedLooksRefs(
    Expression<bool> Function($$SavedLooksTableFilterComposer f) f,
  ) {
    final $$SavedLooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedLooks,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedLooksTableFilterComposer(
            $db: $db,
            $table: $db.savedLooks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> aiLooksRefs(
    Expression<bool> Function($$AiLooksTableFilterComposer f) f,
  ) {
    final $$AiLooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aiLooks,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiLooksTableFilterComposer(
            $db: $db,
            $table: $db.aiLooks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passwordSalt => $composableBuilder(
    column: $table.passwordSalt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get passwordIterations => $composableBuilder(
    column: $table.passwordIterations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skinType => $composableBuilder(
    column: $table.skinType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skinTone => $composableBuilder(
    column: $table.skinTone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferences => $composableBuilder(
    column: $table.preferences,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAdmin => $composableBuilder(
    column: $table.isAdmin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get premiumUntil => $composableBuilder(
    column: $table.premiumUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get passwordSalt => $composableBuilder(
    column: $table.passwordSalt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get passwordIterations => $composableBuilder(
    column: $table.passwordIterations,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get birthDate =>
      $composableBuilder(column: $table.birthDate, builder: (column) => column);

  GeneratedColumn<int> get age =>
      $composableBuilder(column: $table.age, builder: (column) => column);

  GeneratedColumn<String> get skinType =>
      $composableBuilder(column: $table.skinType, builder: (column) => column);

  GeneratedColumn<String> get skinTone =>
      $composableBuilder(column: $table.skinTone, builder: (column) => column);

  GeneratedColumn<String> get preferences => $composableBuilder(
    column: $table.preferences,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<bool> get isAdmin =>
      $composableBuilder(column: $table.isAdmin, builder: (column) => column);

  GeneratedColumn<int> get premiumUntil => $composableBuilder(
    column: $table.premiumUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> sessionsRefs<T extends Object>(
    Expression<T> Function($$SessionsTableAnnotationComposer a) f,
  ) {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> savedLooksRefs<T extends Object>(
    Expression<T> Function($$SavedLooksTableAnnotationComposer a) f,
  ) {
    final $$SavedLooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedLooks,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedLooksTableAnnotationComposer(
            $db: $db,
            $table: $db.savedLooks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> aiLooksRefs<T extends Object>(
    Expression<T> Function($$AiLooksTableAnnotationComposer a) f,
  ) {
    final $$AiLooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aiLooks,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiLooksTableAnnotationComposer(
            $db: $db,
            $table: $db.aiLooks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UsersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsersTable,
          UserRow,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (UserRow, $$UsersTableReferences),
          UserRow,
          PrefetchHooks Function({
            bool sessionsRefs,
            bool savedLooksRefs,
            bool aiLooksRefs,
          })
        > {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> passwordHash = const Value.absent(),
                Value<String> passwordSalt = const Value.absent(),
                Value<int> passwordIterations = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> birthDate = const Value.absent(),
                Value<int> age = const Value.absent(),
                Value<String> skinType = const Value.absent(),
                Value<String> skinTone = const Value.absent(),
                Value<String> preferences = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<bool> isAdmin = const Value.absent(),
                Value<int?> premiumUntil = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                id: id,
                email: email,
                passwordHash: passwordHash,
                passwordSalt: passwordSalt,
                passwordIterations: passwordIterations,
                name: name,
                birthDate: birthDate,
                age: age,
                skinType: skinType,
                skinTone: skinTone,
                preferences: preferences,
                photoPath: photoPath,
                isAdmin: isAdmin,
                premiumUntil: premiumUntil,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String id,
                required String email,
                required String passwordHash,
                required String passwordSalt,
                required int passwordIterations,
                required String name,
                Value<String?> birthDate = const Value.absent(),
                Value<int> age = const Value.absent(),
                Value<String> skinType = const Value.absent(),
                Value<String> skinTone = const Value.absent(),
                Value<String> preferences = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<bool> isAdmin = const Value.absent(),
                Value<int?> premiumUntil = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                id: id,
                email: email,
                passwordHash: passwordHash,
                passwordSalt: passwordSalt,
                passwordIterations: passwordIterations,
                name: name,
                birthDate: birthDate,
                age: age,
                skinType: skinType,
                skinTone: skinTone,
                preferences: preferences,
                photoPath: photoPath,
                isAdmin: isAdmin,
                premiumUntil: premiumUntil,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UsersTable, UserRow>(table),
                  $$UsersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sessionsRefs = false,
                savedLooksRefs = false,
                aiLooksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sessionsRefs) db.sessions,
                    if (savedLooksRefs) db.savedLooks,
                    if (aiLooksRefs) db.aiLooks,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sessionsRefs)
                        await $_getPrefetchedDataByColumns<
                          UserRow,
                          $UsersTable,
                          SessionRow,
                          $SessionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._sessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).sessionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'user_id',
                          typedResults: items,
                        ),
                      if (savedLooksRefs)
                        await $_getPrefetchedDataByColumns<
                          UserRow,
                          $UsersTable,
                          SavedLookRow,
                          $SavedLooksTable
                        >(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._savedLooksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).savedLooksRefs,
                          currentColumn: 'id',
                          referencedColumn: 'user_id',
                          typedResults: items,
                        ),
                      if (aiLooksRefs)
                        await $_getPrefetchedDataByColumns<
                          UserRow,
                          $UsersTable,
                          AiLookRow,
                          $AiLooksTable
                        >(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._aiLooksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(db, table, p0).aiLooksRefs,
                          currentColumn: 'id',
                          referencedColumn: 'user_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$UsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsersTable,
      UserRow,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (UserRow, $$UsersTableReferences),
      UserRow,
      PrefetchHooks Function({
        bool sessionsRefs,
        bool savedLooksRefs,
        bool aiLooksRefs,
      })
    >;
typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      Value<String> slot,
      required String userId,
      Value<int> rowid,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<String> slot,
      Value<String> userId,
      Value<int> rowid,
    });

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, SessionRow> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _userIdTable(_$AppDatabase db) =>
      db.users.createAlias('sessions__user_id__users__id');

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          SessionRow,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (SessionRow, $$SessionsTableReferences),
          SessionRow,
          PrefetchHooks Function({bool userId})
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> slot = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(slot: slot, userId: userId, rowid: rowid),
          createCompanionCallback:
              ({
                Value<String> slot = const Value.absent(),
                required String userId,
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                slot: slot,
                userId: userId,
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
          prefetchHooksCallback: ({userId = false}) {
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
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$SessionsTableReferences
                                    ._userIdTable(db),
                                referencedColumn: $$SessionsTableReferences
                                    ._userIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      SessionRow,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (SessionRow, $$SessionsTableReferences),
      SessionRow,
      PrefetchHooks Function({bool userId})
    >;
typedef $$LooksTableCreateCompanionBuilder =
    LooksCompanion Function({
      required int updatedAt,
      Value<int?> deletedAt,
      Value<bool> dirty,
      required String id,
      required String name,
      required String category,
      Value<String?> image,
      Value<String> steps,
      Value<int?> sortOrder,
      Value<String?> recipe,
      Value<String?> recipeSchema,
      Value<int?> minEngine,
      Value<String?> source,
      Value<String?> videoUrl,
      Value<String?> createdBy,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$LooksTableUpdateCompanionBuilder =
    LooksCompanion Function({
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<bool> dirty,
      Value<String> id,
      Value<String> name,
      Value<String> category,
      Value<String?> image,
      Value<String> steps,
      Value<int?> sortOrder,
      Value<String?> recipe,
      Value<String?> recipeSchema,
      Value<int?> minEngine,
      Value<String?> source,
      Value<String?> videoUrl,
      Value<String?> createdBy,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$LooksTableFilterComposer extends Composer<_$AppDatabase, $LooksTable> {
  $$LooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get image => $composableBuilder(
    column: $table.image,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipe => $composableBuilder(
    column: $table.recipe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipeSchema => $composableBuilder(
    column: $table.recipeSchema,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minEngine => $composableBuilder(
    column: $table.minEngine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoUrl => $composableBuilder(
    column: $table.videoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LooksTableOrderingComposer
    extends Composer<_$AppDatabase, $LooksTable> {
  $$LooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get image => $composableBuilder(
    column: $table.image,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipe => $composableBuilder(
    column: $table.recipe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipeSchema => $composableBuilder(
    column: $table.recipeSchema,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minEngine => $composableBuilder(
    column: $table.minEngine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoUrl => $composableBuilder(
    column: $table.videoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $LooksTable> {
  $$LooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get image =>
      $composableBuilder(column: $table.image, builder: (column) => column);

  GeneratedColumn<String> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get recipe =>
      $composableBuilder(column: $table.recipe, builder: (column) => column);

  GeneratedColumn<String> get recipeSchema => $composableBuilder(
    column: $table.recipeSchema,
    builder: (column) => column,
  );

  GeneratedColumn<int> get minEngine =>
      $composableBuilder(column: $table.minEngine, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get videoUrl =>
      $composableBuilder(column: $table.videoUrl, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LooksTable,
          LookRow,
          $$LooksTableFilterComposer,
          $$LooksTableOrderingComposer,
          $$LooksTableAnnotationComposer,
          $$LooksTableCreateCompanionBuilder,
          $$LooksTableUpdateCompanionBuilder,
          (LookRow, BaseReferences<_$AppDatabase, $LooksTable, LookRow>),
          LookRow,
          PrefetchHooks Function()
        > {
  $$LooksTableTableManager(_$AppDatabase db, $LooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String?> image = const Value.absent(),
                Value<String> steps = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
                Value<String?> recipe = const Value.absent(),
                Value<String?> recipeSchema = const Value.absent(),
                Value<int?> minEngine = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> videoUrl = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LooksCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                id: id,
                name: name,
                category: category,
                image: image,
                steps: steps,
                sortOrder: sortOrder,
                recipe: recipe,
                recipeSchema: recipeSchema,
                minEngine: minEngine,
                source: source,
                videoUrl: videoUrl,
                createdBy: createdBy,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String id,
                required String name,
                required String category,
                Value<String?> image = const Value.absent(),
                Value<String> steps = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
                Value<String?> recipe = const Value.absent(),
                Value<String?> recipeSchema = const Value.absent(),
                Value<int?> minEngine = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> videoUrl = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LooksCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                id: id,
                name: name,
                category: category,
                image: image,
                steps: steps,
                sortOrder: sortOrder,
                recipe: recipe,
                recipeSchema: recipeSchema,
                minEngine: minEngine,
                source: source,
                videoUrl: videoUrl,
                createdBy: createdBy,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LooksTable, LookRow>(table),
                  BaseReferences<_$AppDatabase, $LooksTable, LookRow>(
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

typedef $$LooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LooksTable,
      LookRow,
      $$LooksTableFilterComposer,
      $$LooksTableOrderingComposer,
      $$LooksTableAnnotationComposer,
      $$LooksTableCreateCompanionBuilder,
      $$LooksTableUpdateCompanionBuilder,
      (LookRow, BaseReferences<_$AppDatabase, $LooksTable, LookRow>),
      LookRow,
      PrefetchHooks Function()
    >;
typedef $$LookDraftsTableCreateCompanionBuilder =
    LookDraftsCompanion Function({
      required int updatedAt,
      Value<int?> deletedAt,
      Value<bool> dirty,
      required String id,
      required String name,
      required String category,
      Value<String?> image,
      required String recipe,
      required String recipeSchema,
      required int minEngine,
      Value<String?> source,
      required String createdBy,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$LookDraftsTableUpdateCompanionBuilder =
    LookDraftsCompanion Function({
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<bool> dirty,
      Value<String> id,
      Value<String> name,
      Value<String> category,
      Value<String?> image,
      Value<String> recipe,
      Value<String> recipeSchema,
      Value<int> minEngine,
      Value<String?> source,
      Value<String> createdBy,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$LookDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $LookDraftsTable> {
  $$LookDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get image => $composableBuilder(
    column: $table.image,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipe => $composableBuilder(
    column: $table.recipe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipeSchema => $composableBuilder(
    column: $table.recipeSchema,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minEngine => $composableBuilder(
    column: $table.minEngine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LookDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $LookDraftsTable> {
  $$LookDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get image => $composableBuilder(
    column: $table.image,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipe => $composableBuilder(
    column: $table.recipe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipeSchema => $composableBuilder(
    column: $table.recipeSchema,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minEngine => $composableBuilder(
    column: $table.minEngine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LookDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LookDraftsTable> {
  $$LookDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get image =>
      $composableBuilder(column: $table.image, builder: (column) => column);

  GeneratedColumn<String> get recipe =>
      $composableBuilder(column: $table.recipe, builder: (column) => column);

  GeneratedColumn<String> get recipeSchema => $composableBuilder(
    column: $table.recipeSchema,
    builder: (column) => column,
  );

  GeneratedColumn<int> get minEngine =>
      $composableBuilder(column: $table.minEngine, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LookDraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LookDraftsTable,
          LookDraftRow,
          $$LookDraftsTableFilterComposer,
          $$LookDraftsTableOrderingComposer,
          $$LookDraftsTableAnnotationComposer,
          $$LookDraftsTableCreateCompanionBuilder,
          $$LookDraftsTableUpdateCompanionBuilder,
          (
            LookDraftRow,
            BaseReferences<_$AppDatabase, $LookDraftsTable, LookDraftRow>,
          ),
          LookDraftRow,
          PrefetchHooks Function()
        > {
  $$LookDraftsTableTableManager(_$AppDatabase db, $LookDraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LookDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LookDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LookDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String?> image = const Value.absent(),
                Value<String> recipe = const Value.absent(),
                Value<String> recipeSchema = const Value.absent(),
                Value<int> minEngine = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LookDraftsCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                id: id,
                name: name,
                category: category,
                image: image,
                recipe: recipe,
                recipeSchema: recipeSchema,
                minEngine: minEngine,
                source: source,
                createdBy: createdBy,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String id,
                required String name,
                required String category,
                Value<String?> image = const Value.absent(),
                required String recipe,
                required String recipeSchema,
                required int minEngine,
                Value<String?> source = const Value.absent(),
                required String createdBy,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LookDraftsCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                id: id,
                name: name,
                category: category,
                image: image,
                recipe: recipe,
                recipeSchema: recipeSchema,
                minEngine: minEngine,
                source: source,
                createdBy: createdBy,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LookDraftsTable, LookDraftRow>(table),
                  BaseReferences<_$AppDatabase, $LookDraftsTable, LookDraftRow>(
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

typedef $$LookDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LookDraftsTable,
      LookDraftRow,
      $$LookDraftsTableFilterComposer,
      $$LookDraftsTableOrderingComposer,
      $$LookDraftsTableAnnotationComposer,
      $$LookDraftsTableCreateCompanionBuilder,
      $$LookDraftsTableUpdateCompanionBuilder,
      (
        LookDraftRow,
        BaseReferences<_$AppDatabase, $LookDraftsTable, LookDraftRow>,
      ),
      LookDraftRow,
      PrefetchHooks Function()
    >;
typedef $$SavedLooksTableCreateCompanionBuilder =
    SavedLooksCompanion Function({
      required int updatedAt,
      Value<int?> deletedAt,
      Value<bool> dirty,
      required String userId,
      required String lookId,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$SavedLooksTableUpdateCompanionBuilder =
    SavedLooksCompanion Function({
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<bool> dirty,
      Value<String> userId,
      Value<String> lookId,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$SavedLooksTableReferences
    extends BaseReferences<_$AppDatabase, $SavedLooksTable, SavedLookRow> {
  $$SavedLooksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _userIdTable(_$AppDatabase db) =>
      db.users.createAlias('saved_looks__user_id__users__id');

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SavedLooksTableFilterComposer
    extends Composer<_$AppDatabase, $SavedLooksTable> {
  $$SavedLooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lookId => $composableBuilder(
    column: $table.lookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedLooksTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedLooksTable> {
  $$SavedLooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lookId => $composableBuilder(
    column: $table.lookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedLooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedLooksTable> {
  $$SavedLooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get lookId =>
      $composableBuilder(column: $table.lookId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedLooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedLooksTable,
          SavedLookRow,
          $$SavedLooksTableFilterComposer,
          $$SavedLooksTableOrderingComposer,
          $$SavedLooksTableAnnotationComposer,
          $$SavedLooksTableCreateCompanionBuilder,
          $$SavedLooksTableUpdateCompanionBuilder,
          (SavedLookRow, $$SavedLooksTableReferences),
          SavedLookRow,
          PrefetchHooks Function({bool userId})
        > {
  $$SavedLooksTableTableManager(_$AppDatabase db, $SavedLooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedLooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedLooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedLooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> lookId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedLooksCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                userId: userId,
                lookId: lookId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String userId,
                required String lookId,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SavedLooksCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                userId: userId,
                lookId: lookId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavedLooksTable, SavedLookRow>(table),
                  $$SavedLooksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false}) {
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
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$SavedLooksTableReferences
                                    ._userIdTable(db),
                                referencedColumn: $$SavedLooksTableReferences
                                    ._userIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$SavedLooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedLooksTable,
      SavedLookRow,
      $$SavedLooksTableFilterComposer,
      $$SavedLooksTableOrderingComposer,
      $$SavedLooksTableAnnotationComposer,
      $$SavedLooksTableCreateCompanionBuilder,
      $$SavedLooksTableUpdateCompanionBuilder,
      (SavedLookRow, $$SavedLooksTableReferences),
      SavedLookRow,
      PrefetchHooks Function({bool userId})
    >;
typedef $$AiLooksTableCreateCompanionBuilder =
    AiLooksCompanion Function({
      required int updatedAt,
      Value<int?> deletedAt,
      Value<bool> dirty,
      required String id,
      required String userId,
      required String recipe,
      required String source,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$AiLooksTableUpdateCompanionBuilder =
    AiLooksCompanion Function({
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<bool> dirty,
      Value<String> id,
      Value<String> userId,
      Value<String> recipe,
      Value<String> source,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$AiLooksTableReferences
    extends BaseReferences<_$AppDatabase, $AiLooksTable, AiLookRow> {
  $$AiLooksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _userIdTable(_$AppDatabase db) =>
      db.users.createAlias('ai_looks__user_id__users__id');

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AiLooksTableFilterComposer
    extends Composer<_$AppDatabase, $AiLooksTable> {
  $$AiLooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipe => $composableBuilder(
    column: $table.recipe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AiLooksTableOrderingComposer
    extends Composer<_$AppDatabase, $AiLooksTable> {
  $$AiLooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipe => $composableBuilder(
    column: $table.recipe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AiLooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiLooksTable> {
  $$AiLooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get recipe =>
      $composableBuilder(column: $table.recipe, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AiLooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiLooksTable,
          AiLookRow,
          $$AiLooksTableFilterComposer,
          $$AiLooksTableOrderingComposer,
          $$AiLooksTableAnnotationComposer,
          $$AiLooksTableCreateCompanionBuilder,
          $$AiLooksTableUpdateCompanionBuilder,
          (AiLookRow, $$AiLooksTableReferences),
          AiLookRow,
          PrefetchHooks Function({bool userId})
        > {
  $$AiLooksTableTableManager(_$AppDatabase db, $AiLooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiLooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiLooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiLooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> recipe = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiLooksCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                id: id,
                userId: userId,
                recipe: recipe,
                source: source,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String id,
                required String userId,
                required String recipe,
                required String source,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AiLooksCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                id: id,
                userId: userId,
                recipe: recipe,
                source: source,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiLooksTable, AiLookRow>(table),
                  $$AiLooksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false}) {
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
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$AiLooksTableReferences
                                    ._userIdTable(db),
                                referencedColumn: $$AiLooksTableReferences
                                    ._userIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$AiLooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiLooksTable,
      AiLookRow,
      $$AiLooksTableFilterComposer,
      $$AiLooksTableOrderingComposer,
      $$AiLooksTableAnnotationComposer,
      $$AiLooksTableCreateCompanionBuilder,
      $$AiLooksTableUpdateCompanionBuilder,
      (AiLookRow, $$AiLooksTableReferences),
      AiLookRow,
      PrefetchHooks Function({bool userId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$LooksTableTableManager get looks =>
      $$LooksTableTableManager(_db, _db.looks);
  $$LookDraftsTableTableManager get lookDrafts =>
      $$LookDraftsTableTableManager(_db, _db.lookDrafts);
  $$SavedLooksTableTableManager get savedLooks =>
      $$SavedLooksTableTableManager(_db, _db.savedLooks);
  $$AiLooksTableTableManager get aiLooks =>
      $$AiLooksTableTableManager(_db, _db.aiLooks);
}

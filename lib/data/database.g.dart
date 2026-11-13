// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $FoodsTable extends Foods with TableInfo<$FoodsTable, Food> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
    'brand',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _baseAmountMeta = const VerificationMeta(
    'baseAmount',
  );
  @override
  late final GeneratedColumn<double> baseAmount = GeneratedColumn<double>(
    'base_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUnitMeta = const VerificationMeta(
    'baseUnit',
  );
  @override
  late final GeneratedColumn<String> baseUnit = GeneratedColumn<String>(
    'base_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceJsonMeta = const VerificationMeta(
    'sourceJson',
  );
  @override
  late final GeneratedColumn<String> sourceJson = GeneratedColumn<String>(
    'source_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    name,
    brand,
    barcode,
    baseAmount,
    baseUnit,
    sourceJson,
    archived,
    createdAtMs,
    updatedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'foods';
  @override
  VerificationContext validateIntegrity(
    Insertable<Food> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('brand')) {
      context.handle(
        _brandMeta,
        brand.isAcceptableOrUnknown(data['brand']!, _brandMeta),
      );
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('base_amount')) {
      context.handle(
        _baseAmountMeta,
        baseAmount.isAcceptableOrUnknown(data['base_amount']!, _baseAmountMeta),
      );
    } else if (isInserting) {
      context.missing(_baseAmountMeta);
    }
    if (data.containsKey('base_unit')) {
      context.handle(
        _baseUnitMeta,
        baseUnit.isAcceptableOrUnknown(data['base_unit']!, _baseUnitMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUnitMeta);
    }
    if (data.containsKey('source_json')) {
      context.handle(
        _sourceJsonMeta,
        sourceJson.isAcceptableOrUnknown(data['source_json']!, _sourceJsonMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Food map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Food(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      brand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brand'],
      ),
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      ),
      baseAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}base_amount'],
      )!,
      baseUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_unit'],
      )!,
      sourceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_json'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
    );
  }

  @override
  $FoodsTable createAlias(String alias) {
    return $FoodsTable(attachedDatabase, alias);
  }
}

class Food extends DataClass implements Insertable<Food> {
  final int id;
  final String kind;
  final String name;
  final String? brand;
  final String? barcode;
  final double baseAmount;
  final String baseUnit;
  final String? sourceJson;
  final bool archived;
  final int createdAtMs;
  final int updatedAtMs;
  const Food({
    required this.id,
    required this.kind,
    required this.name,
    this.brand,
    this.barcode,
    required this.baseAmount,
    required this.baseUnit,
    this.sourceJson,
    required this.archived,
    required this.createdAtMs,
    required this.updatedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || brand != null) {
      map['brand'] = Variable<String>(brand);
    }
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    map['base_amount'] = Variable<double>(baseAmount);
    map['base_unit'] = Variable<String>(baseUnit);
    if (!nullToAbsent || sourceJson != null) {
      map['source_json'] = Variable<String>(sourceJson);
    }
    map['archived'] = Variable<bool>(archived);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    return map;
  }

  FoodsCompanion toCompanion(bool nullToAbsent) {
    return FoodsCompanion(
      id: Value(id),
      kind: Value(kind),
      name: Value(name),
      brand: brand == null && nullToAbsent
          ? const Value.absent()
          : Value(brand),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      baseAmount: Value(baseAmount),
      baseUnit: Value(baseUnit),
      sourceJson: sourceJson == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceJson),
      archived: Value(archived),
      createdAtMs: Value(createdAtMs),
      updatedAtMs: Value(updatedAtMs),
    );
  }

  factory Food.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Food(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      brand: serializer.fromJson<String?>(json['brand']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      baseAmount: serializer.fromJson<double>(json['baseAmount']),
      baseUnit: serializer.fromJson<String>(json['baseUnit']),
      sourceJson: serializer.fromJson<String?>(json['sourceJson']),
      archived: serializer.fromJson<bool>(json['archived']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'brand': serializer.toJson<String?>(brand),
      'barcode': serializer.toJson<String?>(barcode),
      'baseAmount': serializer.toJson<double>(baseAmount),
      'baseUnit': serializer.toJson<String>(baseUnit),
      'sourceJson': serializer.toJson<String?>(sourceJson),
      'archived': serializer.toJson<bool>(archived),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
    };
  }

  Food copyWith({
    int? id,
    String? kind,
    String? name,
    Value<String?> brand = const Value.absent(),
    Value<String?> barcode = const Value.absent(),
    double? baseAmount,
    String? baseUnit,
    Value<String?> sourceJson = const Value.absent(),
    bool? archived,
    int? createdAtMs,
    int? updatedAtMs,
  }) => Food(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    brand: brand.present ? brand.value : this.brand,
    barcode: barcode.present ? barcode.value : this.barcode,
    baseAmount: baseAmount ?? this.baseAmount,
    baseUnit: baseUnit ?? this.baseUnit,
    sourceJson: sourceJson.present ? sourceJson.value : this.sourceJson,
    archived: archived ?? this.archived,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );
  Food copyWithCompanion(FoodsCompanion data) {
    return Food(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      brand: data.brand.present ? data.brand.value : this.brand,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      baseAmount: data.baseAmount.present
          ? data.baseAmount.value
          : this.baseAmount,
      baseUnit: data.baseUnit.present ? data.baseUnit.value : this.baseUnit,
      sourceJson: data.sourceJson.present
          ? data.sourceJson.value
          : this.sourceJson,
      archived: data.archived.present ? data.archived.value : this.archived,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Food(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('barcode: $barcode, ')
          ..write('baseAmount: $baseAmount, ')
          ..write('baseUnit: $baseUnit, ')
          ..write('sourceJson: $sourceJson, ')
          ..write('archived: $archived, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    name,
    brand,
    barcode,
    baseAmount,
    baseUnit,
    sourceJson,
    archived,
    createdAtMs,
    updatedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Food &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.brand == this.brand &&
          other.barcode == this.barcode &&
          other.baseAmount == this.baseAmount &&
          other.baseUnit == this.baseUnit &&
          other.sourceJson == this.sourceJson &&
          other.archived == this.archived &&
          other.createdAtMs == this.createdAtMs &&
          other.updatedAtMs == this.updatedAtMs);
}

class FoodsCompanion extends UpdateCompanion<Food> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> name;
  final Value<String?> brand;
  final Value<String?> barcode;
  final Value<double> baseAmount;
  final Value<String> baseUnit;
  final Value<String?> sourceJson;
  final Value<bool> archived;
  final Value<int> createdAtMs;
  final Value<int> updatedAtMs;
  const FoodsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.brand = const Value.absent(),
    this.barcode = const Value.absent(),
    this.baseAmount = const Value.absent(),
    this.baseUnit = const Value.absent(),
    this.sourceJson = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
  });
  FoodsCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String name,
    this.brand = const Value.absent(),
    this.barcode = const Value.absent(),
    required double baseAmount,
    required String baseUnit,
    this.sourceJson = const Value.absent(),
    this.archived = const Value.absent(),
    required int createdAtMs,
    required int updatedAtMs,
  }) : kind = Value(kind),
       name = Value(name),
       baseAmount = Value(baseAmount),
       baseUnit = Value(baseUnit),
       createdAtMs = Value(createdAtMs),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<Food> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? brand,
    Expression<String>? barcode,
    Expression<double>? baseAmount,
    Expression<String>? baseUnit,
    Expression<String>? sourceJson,
    Expression<bool>? archived,
    Expression<int>? createdAtMs,
    Expression<int>? updatedAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (brand != null) 'brand': brand,
      if (barcode != null) 'barcode': barcode,
      if (baseAmount != null) 'base_amount': baseAmount,
      if (baseUnit != null) 'base_unit': baseUnit,
      if (sourceJson != null) 'source_json': sourceJson,
      if (archived != null) 'archived': archived,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
    });
  }

  FoodsCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String>? name,
    Value<String?>? brand,
    Value<String?>? barcode,
    Value<double>? baseAmount,
    Value<String>? baseUnit,
    Value<String?>? sourceJson,
    Value<bool>? archived,
    Value<int>? createdAtMs,
    Value<int>? updatedAtMs,
  }) {
    return FoodsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      barcode: barcode ?? this.barcode,
      baseAmount: baseAmount ?? this.baseAmount,
      baseUnit: baseUnit ?? this.baseUnit,
      sourceJson: sourceJson ?? this.sourceJson,
      archived: archived ?? this.archived,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (baseAmount.present) {
      map['base_amount'] = Variable<double>(baseAmount.value);
    }
    if (baseUnit.present) {
      map['base_unit'] = Variable<String>(baseUnit.value);
    }
    if (sourceJson.present) {
      map['source_json'] = Variable<String>(sourceJson.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('barcode: $barcode, ')
          ..write('baseAmount: $baseAmount, ')
          ..write('baseUnit: $baseUnit, ')
          ..write('sourceJson: $sourceJson, ')
          ..write('archived: $archived, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }
}

class $FoodNutrientsTable extends FoodNutrients
    with TableInfo<$FoodNutrientsTable, FoodNutrient> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodNutrientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _foodIdMeta = const VerificationMeta('foodId');
  @override
  late final GeneratedColumn<int> foodId = GeneratedColumn<int>(
    'food_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES foods (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nutrientIdMeta = const VerificationMeta(
    'nutrientId',
  );
  @override
  late final GeneratedColumn<int> nutrientId = GeneratedColumn<int>(
    'nutrient_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [foodId, nutrientId, amount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'food_nutrients';
  @override
  VerificationContext validateIntegrity(
    Insertable<FoodNutrient> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('food_id')) {
      context.handle(
        _foodIdMeta,
        foodId.isAcceptableOrUnknown(data['food_id']!, _foodIdMeta),
      );
    } else if (isInserting) {
      context.missing(_foodIdMeta);
    }
    if (data.containsKey('nutrient_id')) {
      context.handle(
        _nutrientIdMeta,
        nutrientId.isAcceptableOrUnknown(data['nutrient_id']!, _nutrientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nutrientIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {foodId, nutrientId};
  @override
  FoodNutrient map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodNutrient(
      foodId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}food_id'],
      )!,
      nutrientId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}nutrient_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
    );
  }

  @override
  $FoodNutrientsTable createAlias(String alias) {
    return $FoodNutrientsTable(attachedDatabase, alias);
  }
}

class FoodNutrient extends DataClass implements Insertable<FoodNutrient> {
  final int foodId;
  final int nutrientId;
  final double amount;
  const FoodNutrient({
    required this.foodId,
    required this.nutrientId,
    required this.amount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['food_id'] = Variable<int>(foodId);
    map['nutrient_id'] = Variable<int>(nutrientId);
    map['amount'] = Variable<double>(amount);
    return map;
  }

  FoodNutrientsCompanion toCompanion(bool nullToAbsent) {
    return FoodNutrientsCompanion(
      foodId: Value(foodId),
      nutrientId: Value(nutrientId),
      amount: Value(amount),
    );
  }

  factory FoodNutrient.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoodNutrient(
      foodId: serializer.fromJson<int>(json['foodId']),
      nutrientId: serializer.fromJson<int>(json['nutrientId']),
      amount: serializer.fromJson<double>(json['amount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'foodId': serializer.toJson<int>(foodId),
      'nutrientId': serializer.toJson<int>(nutrientId),
      'amount': serializer.toJson<double>(amount),
    };
  }

  FoodNutrient copyWith({int? foodId, int? nutrientId, double? amount}) =>
      FoodNutrient(
        foodId: foodId ?? this.foodId,
        nutrientId: nutrientId ?? this.nutrientId,
        amount: amount ?? this.amount,
      );
  FoodNutrient copyWithCompanion(FoodNutrientsCompanion data) {
    return FoodNutrient(
      foodId: data.foodId.present ? data.foodId.value : this.foodId,
      nutrientId: data.nutrientId.present
          ? data.nutrientId.value
          : this.nutrientId,
      amount: data.amount.present ? data.amount.value : this.amount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoodNutrient(')
          ..write('foodId: $foodId, ')
          ..write('nutrientId: $nutrientId, ')
          ..write('amount: $amount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(foodId, nutrientId, amount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoodNutrient &&
          other.foodId == this.foodId &&
          other.nutrientId == this.nutrientId &&
          other.amount == this.amount);
}

class FoodNutrientsCompanion extends UpdateCompanion<FoodNutrient> {
  final Value<int> foodId;
  final Value<int> nutrientId;
  final Value<double> amount;
  final Value<int> rowid;
  const FoodNutrientsCompanion({
    this.foodId = const Value.absent(),
    this.nutrientId = const Value.absent(),
    this.amount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoodNutrientsCompanion.insert({
    required int foodId,
    required int nutrientId,
    required double amount,
    this.rowid = const Value.absent(),
  }) : foodId = Value(foodId),
       nutrientId = Value(nutrientId),
       amount = Value(amount);
  static Insertable<FoodNutrient> custom({
    Expression<int>? foodId,
    Expression<int>? nutrientId,
    Expression<double>? amount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (foodId != null) 'food_id': foodId,
      if (nutrientId != null) 'nutrient_id': nutrientId,
      if (amount != null) 'amount': amount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoodNutrientsCompanion copyWith({
    Value<int>? foodId,
    Value<int>? nutrientId,
    Value<double>? amount,
    Value<int>? rowid,
  }) {
    return FoodNutrientsCompanion(
      foodId: foodId ?? this.foodId,
      nutrientId: nutrientId ?? this.nutrientId,
      amount: amount ?? this.amount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (foodId.present) {
      map['food_id'] = Variable<int>(foodId.value);
    }
    if (nutrientId.present) {
      map['nutrient_id'] = Variable<int>(nutrientId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodNutrientsCompanion(')
          ..write('foodId: $foodId, ')
          ..write('nutrientId: $nutrientId, ')
          ..write('amount: $amount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FoodPortionsTable extends FoodPortions
    with TableInfo<$FoodPortionsTable, FoodPortion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodPortionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _foodIdMeta = const VerificationMeta('foodId');
  @override
  late final GeneratedColumn<int> foodId = GeneratedColumn<int>(
    'food_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES foods (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _baseQuantityMeta = const VerificationMeta(
    'baseQuantity',
  );
  @override
  late final GeneratedColumn<double> baseQuantity = GeneratedColumn<double>(
    'base_quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, foodId, label, baseQuantity];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'food_portions';
  @override
  VerificationContext validateIntegrity(
    Insertable<FoodPortion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('food_id')) {
      context.handle(
        _foodIdMeta,
        foodId.isAcceptableOrUnknown(data['food_id']!, _foodIdMeta),
      );
    } else if (isInserting) {
      context.missing(_foodIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('base_quantity')) {
      context.handle(
        _baseQuantityMeta,
        baseQuantity.isAcceptableOrUnknown(
          data['base_quantity']!,
          _baseQuantityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseQuantityMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FoodPortion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodPortion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      foodId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}food_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      baseQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}base_quantity'],
      )!,
    );
  }

  @override
  $FoodPortionsTable createAlias(String alias) {
    return $FoodPortionsTable(attachedDatabase, alias);
  }
}

class FoodPortion extends DataClass implements Insertable<FoodPortion> {
  final int id;
  final int foodId;
  final String label;
  final double baseQuantity;
  const FoodPortion({
    required this.id,
    required this.foodId,
    required this.label,
    required this.baseQuantity,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['food_id'] = Variable<int>(foodId);
    map['label'] = Variable<String>(label);
    map['base_quantity'] = Variable<double>(baseQuantity);
    return map;
  }

  FoodPortionsCompanion toCompanion(bool nullToAbsent) {
    return FoodPortionsCompanion(
      id: Value(id),
      foodId: Value(foodId),
      label: Value(label),
      baseQuantity: Value(baseQuantity),
    );
  }

  factory FoodPortion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoodPortion(
      id: serializer.fromJson<int>(json['id']),
      foodId: serializer.fromJson<int>(json['foodId']),
      label: serializer.fromJson<String>(json['label']),
      baseQuantity: serializer.fromJson<double>(json['baseQuantity']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'foodId': serializer.toJson<int>(foodId),
      'label': serializer.toJson<String>(label),
      'baseQuantity': serializer.toJson<double>(baseQuantity),
    };
  }

  FoodPortion copyWith({
    int? id,
    int? foodId,
    String? label,
    double? baseQuantity,
  }) => FoodPortion(
    id: id ?? this.id,
    foodId: foodId ?? this.foodId,
    label: label ?? this.label,
    baseQuantity: baseQuantity ?? this.baseQuantity,
  );
  FoodPortion copyWithCompanion(FoodPortionsCompanion data) {
    return FoodPortion(
      id: data.id.present ? data.id.value : this.id,
      foodId: data.foodId.present ? data.foodId.value : this.foodId,
      label: data.label.present ? data.label.value : this.label,
      baseQuantity: data.baseQuantity.present
          ? data.baseQuantity.value
          : this.baseQuantity,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoodPortion(')
          ..write('id: $id, ')
          ..write('foodId: $foodId, ')
          ..write('label: $label, ')
          ..write('baseQuantity: $baseQuantity')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, foodId, label, baseQuantity);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoodPortion &&
          other.id == this.id &&
          other.foodId == this.foodId &&
          other.label == this.label &&
          other.baseQuantity == this.baseQuantity);
}

class FoodPortionsCompanion extends UpdateCompanion<FoodPortion> {
  final Value<int> id;
  final Value<int> foodId;
  final Value<String> label;
  final Value<double> baseQuantity;
  const FoodPortionsCompanion({
    this.id = const Value.absent(),
    this.foodId = const Value.absent(),
    this.label = const Value.absent(),
    this.baseQuantity = const Value.absent(),
  });
  FoodPortionsCompanion.insert({
    this.id = const Value.absent(),
    required int foodId,
    required String label,
    required double baseQuantity,
  }) : foodId = Value(foodId),
       label = Value(label),
       baseQuantity = Value(baseQuantity);
  static Insertable<FoodPortion> custom({
    Expression<int>? id,
    Expression<int>? foodId,
    Expression<String>? label,
    Expression<double>? baseQuantity,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (foodId != null) 'food_id': foodId,
      if (label != null) 'label': label,
      if (baseQuantity != null) 'base_quantity': baseQuantity,
    });
  }

  FoodPortionsCompanion copyWith({
    Value<int>? id,
    Value<int>? foodId,
    Value<String>? label,
    Value<double>? baseQuantity,
  }) {
    return FoodPortionsCompanion(
      id: id ?? this.id,
      foodId: foodId ?? this.foodId,
      label: label ?? this.label,
      baseQuantity: baseQuantity ?? this.baseQuantity,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (foodId.present) {
      map['food_id'] = Variable<int>(foodId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (baseQuantity.present) {
      map['base_quantity'] = Variable<double>(baseQuantity.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodPortionsCompanion(')
          ..write('id: $id, ')
          ..write('foodId: $foodId, ')
          ..write('label: $label, ')
          ..write('baseQuantity: $baseQuantity')
          ..write(')'))
        .toString();
  }
}

class $RecipeIngredientsTable extends RecipeIngredients
    with TableInfo<$RecipeIngredientsTable, RecipeIngredient> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipeIngredientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _recipeFoodIdMeta = const VerificationMeta(
    'recipeFoodId',
  );
  @override
  late final GeneratedColumn<int> recipeFoodId = GeneratedColumn<int>(
    'recipe_food_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES foods (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodRefMeta = const VerificationMeta(
    'foodRef',
  );
  @override
  late final GeneratedColumn<String> foodRef = GeneratedColumn<String>(
    'food_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodNameMeta = const VerificationMeta(
    'foodName',
  );
  @override
  late final GeneratedColumn<String> foodName = GeneratedColumn<String>(
    'food_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitLabelMeta = const VerificationMeta(
    'unitLabel',
  );
  @override
  late final GeneratedColumn<String> unitLabel = GeneratedColumn<String>(
    'unit_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseQuantityMeta = const VerificationMeta(
    'baseQuantity',
  );
  @override
  late final GeneratedColumn<double> baseQuantity = GeneratedColumn<double>(
    'base_quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUnitMeta = const VerificationMeta(
    'baseUnit',
  );
  @override
  late final GeneratedColumn<String> baseUnit = GeneratedColumn<String>(
    'base_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recipeFoodId,
    position,
    foodRef,
    foodName,
    quantity,
    unitLabel,
    baseQuantity,
    baseUnit,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipe_ingredients';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecipeIngredient> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('recipe_food_id')) {
      context.handle(
        _recipeFoodIdMeta,
        recipeFoodId.isAcceptableOrUnknown(
          data['recipe_food_id']!,
          _recipeFoodIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipeFoodIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('food_ref')) {
      context.handle(
        _foodRefMeta,
        foodRef.isAcceptableOrUnknown(data['food_ref']!, _foodRefMeta),
      );
    } else if (isInserting) {
      context.missing(_foodRefMeta);
    }
    if (data.containsKey('food_name')) {
      context.handle(
        _foodNameMeta,
        foodName.isAcceptableOrUnknown(data['food_name']!, _foodNameMeta),
      );
    } else if (isInserting) {
      context.missing(_foodNameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit_label')) {
      context.handle(
        _unitLabelMeta,
        unitLabel.isAcceptableOrUnknown(data['unit_label']!, _unitLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_unitLabelMeta);
    }
    if (data.containsKey('base_quantity')) {
      context.handle(
        _baseQuantityMeta,
        baseQuantity.isAcceptableOrUnknown(
          data['base_quantity']!,
          _baseQuantityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseQuantityMeta);
    }
    if (data.containsKey('base_unit')) {
      context.handle(
        _baseUnitMeta,
        baseUnit.isAcceptableOrUnknown(data['base_unit']!, _baseUnitMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUnitMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecipeIngredient map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipeIngredient(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      recipeFoodId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recipe_food_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      foodRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_ref'],
      )!,
      foodName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      unitLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_label'],
      )!,
      baseQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}base_quantity'],
      )!,
      baseUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_unit'],
      )!,
    );
  }

  @override
  $RecipeIngredientsTable createAlias(String alias) {
    return $RecipeIngredientsTable(attachedDatabase, alias);
  }
}

class RecipeIngredient extends DataClass
    implements Insertable<RecipeIngredient> {
  final int id;
  final int recipeFoodId;
  final int position;
  final String foodRef;
  final String foodName;
  final double quantity;
  final String unitLabel;
  final double baseQuantity;
  final String baseUnit;
  const RecipeIngredient({
    required this.id,
    required this.recipeFoodId,
    required this.position,
    required this.foodRef,
    required this.foodName,
    required this.quantity,
    required this.unitLabel,
    required this.baseQuantity,
    required this.baseUnit,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['recipe_food_id'] = Variable<int>(recipeFoodId);
    map['position'] = Variable<int>(position);
    map['food_ref'] = Variable<String>(foodRef);
    map['food_name'] = Variable<String>(foodName);
    map['quantity'] = Variable<double>(quantity);
    map['unit_label'] = Variable<String>(unitLabel);
    map['base_quantity'] = Variable<double>(baseQuantity);
    map['base_unit'] = Variable<String>(baseUnit);
    return map;
  }

  RecipeIngredientsCompanion toCompanion(bool nullToAbsent) {
    return RecipeIngredientsCompanion(
      id: Value(id),
      recipeFoodId: Value(recipeFoodId),
      position: Value(position),
      foodRef: Value(foodRef),
      foodName: Value(foodName),
      quantity: Value(quantity),
      unitLabel: Value(unitLabel),
      baseQuantity: Value(baseQuantity),
      baseUnit: Value(baseUnit),
    );
  }

  factory RecipeIngredient.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipeIngredient(
      id: serializer.fromJson<int>(json['id']),
      recipeFoodId: serializer.fromJson<int>(json['recipeFoodId']),
      position: serializer.fromJson<int>(json['position']),
      foodRef: serializer.fromJson<String>(json['foodRef']),
      foodName: serializer.fromJson<String>(json['foodName']),
      quantity: serializer.fromJson<double>(json['quantity']),
      unitLabel: serializer.fromJson<String>(json['unitLabel']),
      baseQuantity: serializer.fromJson<double>(json['baseQuantity']),
      baseUnit: serializer.fromJson<String>(json['baseUnit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recipeFoodId': serializer.toJson<int>(recipeFoodId),
      'position': serializer.toJson<int>(position),
      'foodRef': serializer.toJson<String>(foodRef),
      'foodName': serializer.toJson<String>(foodName),
      'quantity': serializer.toJson<double>(quantity),
      'unitLabel': serializer.toJson<String>(unitLabel),
      'baseQuantity': serializer.toJson<double>(baseQuantity),
      'baseUnit': serializer.toJson<String>(baseUnit),
    };
  }

  RecipeIngredient copyWith({
    int? id,
    int? recipeFoodId,
    int? position,
    String? foodRef,
    String? foodName,
    double? quantity,
    String? unitLabel,
    double? baseQuantity,
    String? baseUnit,
  }) => RecipeIngredient(
    id: id ?? this.id,
    recipeFoodId: recipeFoodId ?? this.recipeFoodId,
    position: position ?? this.position,
    foodRef: foodRef ?? this.foodRef,
    foodName: foodName ?? this.foodName,
    quantity: quantity ?? this.quantity,
    unitLabel: unitLabel ?? this.unitLabel,
    baseQuantity: baseQuantity ?? this.baseQuantity,
    baseUnit: baseUnit ?? this.baseUnit,
  );
  RecipeIngredient copyWithCompanion(RecipeIngredientsCompanion data) {
    return RecipeIngredient(
      id: data.id.present ? data.id.value : this.id,
      recipeFoodId: data.recipeFoodId.present
          ? data.recipeFoodId.value
          : this.recipeFoodId,
      position: data.position.present ? data.position.value : this.position,
      foodRef: data.foodRef.present ? data.foodRef.value : this.foodRef,
      foodName: data.foodName.present ? data.foodName.value : this.foodName,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitLabel: data.unitLabel.present ? data.unitLabel.value : this.unitLabel,
      baseQuantity: data.baseQuantity.present
          ? data.baseQuantity.value
          : this.baseQuantity,
      baseUnit: data.baseUnit.present ? data.baseUnit.value : this.baseUnit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipeIngredient(')
          ..write('id: $id, ')
          ..write('recipeFoodId: $recipeFoodId, ')
          ..write('position: $position, ')
          ..write('foodRef: $foodRef, ')
          ..write('foodName: $foodName, ')
          ..write('quantity: $quantity, ')
          ..write('unitLabel: $unitLabel, ')
          ..write('baseQuantity: $baseQuantity, ')
          ..write('baseUnit: $baseUnit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    recipeFoodId,
    position,
    foodRef,
    foodName,
    quantity,
    unitLabel,
    baseQuantity,
    baseUnit,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeIngredient &&
          other.id == this.id &&
          other.recipeFoodId == this.recipeFoodId &&
          other.position == this.position &&
          other.foodRef == this.foodRef &&
          other.foodName == this.foodName &&
          other.quantity == this.quantity &&
          other.unitLabel == this.unitLabel &&
          other.baseQuantity == this.baseQuantity &&
          other.baseUnit == this.baseUnit);
}

class RecipeIngredientsCompanion extends UpdateCompanion<RecipeIngredient> {
  final Value<int> id;
  final Value<int> recipeFoodId;
  final Value<int> position;
  final Value<String> foodRef;
  final Value<String> foodName;
  final Value<double> quantity;
  final Value<String> unitLabel;
  final Value<double> baseQuantity;
  final Value<String> baseUnit;
  const RecipeIngredientsCompanion({
    this.id = const Value.absent(),
    this.recipeFoodId = const Value.absent(),
    this.position = const Value.absent(),
    this.foodRef = const Value.absent(),
    this.foodName = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitLabel = const Value.absent(),
    this.baseQuantity = const Value.absent(),
    this.baseUnit = const Value.absent(),
  });
  RecipeIngredientsCompanion.insert({
    this.id = const Value.absent(),
    required int recipeFoodId,
    required int position,
    required String foodRef,
    required String foodName,
    required double quantity,
    required String unitLabel,
    required double baseQuantity,
    required String baseUnit,
  }) : recipeFoodId = Value(recipeFoodId),
       position = Value(position),
       foodRef = Value(foodRef),
       foodName = Value(foodName),
       quantity = Value(quantity),
       unitLabel = Value(unitLabel),
       baseQuantity = Value(baseQuantity),
       baseUnit = Value(baseUnit);
  static Insertable<RecipeIngredient> custom({
    Expression<int>? id,
    Expression<int>? recipeFoodId,
    Expression<int>? position,
    Expression<String>? foodRef,
    Expression<String>? foodName,
    Expression<double>? quantity,
    Expression<String>? unitLabel,
    Expression<double>? baseQuantity,
    Expression<String>? baseUnit,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recipeFoodId != null) 'recipe_food_id': recipeFoodId,
      if (position != null) 'position': position,
      if (foodRef != null) 'food_ref': foodRef,
      if (foodName != null) 'food_name': foodName,
      if (quantity != null) 'quantity': quantity,
      if (unitLabel != null) 'unit_label': unitLabel,
      if (baseQuantity != null) 'base_quantity': baseQuantity,
      if (baseUnit != null) 'base_unit': baseUnit,
    });
  }

  RecipeIngredientsCompanion copyWith({
    Value<int>? id,
    Value<int>? recipeFoodId,
    Value<int>? position,
    Value<String>? foodRef,
    Value<String>? foodName,
    Value<double>? quantity,
    Value<String>? unitLabel,
    Value<double>? baseQuantity,
    Value<String>? baseUnit,
  }) {
    return RecipeIngredientsCompanion(
      id: id ?? this.id,
      recipeFoodId: recipeFoodId ?? this.recipeFoodId,
      position: position ?? this.position,
      foodRef: foodRef ?? this.foodRef,
      foodName: foodName ?? this.foodName,
      quantity: quantity ?? this.quantity,
      unitLabel: unitLabel ?? this.unitLabel,
      baseQuantity: baseQuantity ?? this.baseQuantity,
      baseUnit: baseUnit ?? this.baseUnit,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recipeFoodId.present) {
      map['recipe_food_id'] = Variable<int>(recipeFoodId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (foodRef.present) {
      map['food_ref'] = Variable<String>(foodRef.value);
    }
    if (foodName.present) {
      map['food_name'] = Variable<String>(foodName.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unitLabel.present) {
      map['unit_label'] = Variable<String>(unitLabel.value);
    }
    if (baseQuantity.present) {
      map['base_quantity'] = Variable<double>(baseQuantity.value);
    }
    if (baseUnit.present) {
      map['base_unit'] = Variable<String>(baseUnit.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipeIngredientsCompanion(')
          ..write('id: $id, ')
          ..write('recipeFoodId: $recipeFoodId, ')
          ..write('position: $position, ')
          ..write('foodRef: $foodRef, ')
          ..write('foodName: $foodName, ')
          ..write('quantity: $quantity, ')
          ..write('unitLabel: $unitLabel, ')
          ..write('baseQuantity: $baseQuantity, ')
          ..write('baseUnit: $baseUnit')
          ..write(')'))
        .toString();
  }
}

class $MealSlotsTable extends MealSlots
    with TableInfo<$MealSlotsTable, MealSlot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealSlotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, position, archived];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_slots';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealSlot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealSlot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealSlot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
    );
  }

  @override
  $MealSlotsTable createAlias(String alias) {
    return $MealSlotsTable(attachedDatabase, alias);
  }
}

class MealSlot extends DataClass implements Insertable<MealSlot> {
  final int id;
  final String name;
  final int position;
  final bool archived;
  const MealSlot({
    required this.id,
    required this.name,
    required this.position,
    required this.archived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['position'] = Variable<int>(position);
    map['archived'] = Variable<bool>(archived);
    return map;
  }

  MealSlotsCompanion toCompanion(bool nullToAbsent) {
    return MealSlotsCompanion(
      id: Value(id),
      name: Value(name),
      position: Value(position),
      archived: Value(archived),
    );
  }

  factory MealSlot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealSlot(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      position: serializer.fromJson<int>(json['position']),
      archived: serializer.fromJson<bool>(json['archived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'position': serializer.toJson<int>(position),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  MealSlot copyWith({int? id, String? name, int? position, bool? archived}) =>
      MealSlot(
        id: id ?? this.id,
        name: name ?? this.name,
        position: position ?? this.position,
        archived: archived ?? this.archived,
      );
  MealSlot copyWithCompanion(MealSlotsCompanion data) {
    return MealSlot(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      position: data.position.present ? data.position.value : this.position,
      archived: data.archived.present ? data.archived.value : this.archived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealSlot(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, position, archived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealSlot &&
          other.id == this.id &&
          other.name == this.name &&
          other.position == this.position &&
          other.archived == this.archived);
}

class MealSlotsCompanion extends UpdateCompanion<MealSlot> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> position;
  final Value<bool> archived;
  const MealSlotsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.position = const Value.absent(),
    this.archived = const Value.absent(),
  });
  MealSlotsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int position,
    this.archived = const Value.absent(),
  }) : name = Value(name),
       position = Value(position);
  static Insertable<MealSlot> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? position,
    Expression<bool>? archived,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (position != null) 'position': position,
      if (archived != null) 'archived': archived,
    });
  }

  MealSlotsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? position,
    Value<bool>? archived,
  }) {
    return MealSlotsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      archived: archived ?? this.archived,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealSlotsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }
}

class $MealSlotRulesTable extends MealSlotRules
    with TableInfo<$MealSlotRulesTable, MealSlotRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealSlotRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _slotIdMeta = const VerificationMeta('slotId');
  @override
  late final GeneratedColumn<int> slotId = GeneratedColumn<int>(
    'slot_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meal_slots (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [startMinute, slotId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_slot_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealSlotRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    }
    if (data.containsKey('slot_id')) {
      context.handle(
        _slotIdMeta,
        slotId.isAcceptableOrUnknown(data['slot_id']!, _slotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_slotIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {startMinute};
  @override
  MealSlotRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealSlotRule(
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      )!,
      slotId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot_id'],
      )!,
    );
  }

  @override
  $MealSlotRulesTable createAlias(String alias) {
    return $MealSlotRulesTable(attachedDatabase, alias);
  }
}

class MealSlotRule extends DataClass implements Insertable<MealSlotRule> {
  final int startMinute;
  final int slotId;
  const MealSlotRule({required this.startMinute, required this.slotId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['start_minute'] = Variable<int>(startMinute);
    map['slot_id'] = Variable<int>(slotId);
    return map;
  }

  MealSlotRulesCompanion toCompanion(bool nullToAbsent) {
    return MealSlotRulesCompanion(
      startMinute: Value(startMinute),
      slotId: Value(slotId),
    );
  }

  factory MealSlotRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealSlotRule(
      startMinute: serializer.fromJson<int>(json['startMinute']),
      slotId: serializer.fromJson<int>(json['slotId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'startMinute': serializer.toJson<int>(startMinute),
      'slotId': serializer.toJson<int>(slotId),
    };
  }

  MealSlotRule copyWith({int? startMinute, int? slotId}) => MealSlotRule(
    startMinute: startMinute ?? this.startMinute,
    slotId: slotId ?? this.slotId,
  );
  MealSlotRule copyWithCompanion(MealSlotRulesCompanion data) {
    return MealSlotRule(
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      slotId: data.slotId.present ? data.slotId.value : this.slotId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealSlotRule(')
          ..write('startMinute: $startMinute, ')
          ..write('slotId: $slotId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(startMinute, slotId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealSlotRule &&
          other.startMinute == this.startMinute &&
          other.slotId == this.slotId);
}

class MealSlotRulesCompanion extends UpdateCompanion<MealSlotRule> {
  final Value<int> startMinute;
  final Value<int> slotId;
  const MealSlotRulesCompanion({
    this.startMinute = const Value.absent(),
    this.slotId = const Value.absent(),
  });
  MealSlotRulesCompanion.insert({
    this.startMinute = const Value.absent(),
    required int slotId,
  }) : slotId = Value(slotId);
  static Insertable<MealSlotRule> custom({
    Expression<int>? startMinute,
    Expression<int>? slotId,
  }) {
    return RawValuesInsertable({
      if (startMinute != null) 'start_minute': startMinute,
      if (slotId != null) 'slot_id': slotId,
    });
  }

  MealSlotRulesCompanion copyWith({
    Value<int>? startMinute,
    Value<int>? slotId,
  }) {
    return MealSlotRulesCompanion(
      startMinute: startMinute ?? this.startMinute,
      slotId: slotId ?? this.slotId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (slotId.present) {
      map['slot_id'] = Variable<int>(slotId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealSlotRulesCompanion(')
          ..write('startMinute: $startMinute, ')
          ..write('slotId: $slotId')
          ..write(')'))
        .toString();
  }
}

class $SavedMealsTable extends SavedMeals
    with TableInfo<$SavedMealsTable, SavedMeal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedMealsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_meals';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedMeal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedMeal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedMeal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
    );
  }

  @override
  $SavedMealsTable createAlias(String alias) {
    return $SavedMealsTable(attachedDatabase, alias);
  }
}

class SavedMeal extends DataClass implements Insertable<SavedMeal> {
  final int id;
  final String name;
  final int createdAtMs;
  const SavedMeal({
    required this.id,
    required this.name,
    required this.createdAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  SavedMealsCompanion toCompanion(bool nullToAbsent) {
    return SavedMealsCompanion(
      id: Value(id),
      name: Value(name),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory SavedMeal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedMeal(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  SavedMeal copyWith({int? id, String? name, int? createdAtMs}) => SavedMeal(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );
  SavedMeal copyWithCompanion(SavedMealsCompanion data) {
    return SavedMeal(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedMeal(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedMeal &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAtMs == this.createdAtMs);
}

class SavedMealsCompanion extends UpdateCompanion<SavedMeal> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> createdAtMs;
  const SavedMealsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAtMs = const Value.absent(),
  });
  SavedMealsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int createdAtMs,
  }) : name = Value(name),
       createdAtMs = Value(createdAtMs);
  static Insertable<SavedMeal> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? createdAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
    });
  }

  SavedMealsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? createdAtMs,
  }) {
    return SavedMealsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedMealsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }
}

class $MealsTable extends Meals with TableInfo<$MealsTable, Meal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _localDateMeta = const VerificationMeta(
    'localDate',
  );
  @override
  late final GeneratedColumn<String> localDate = GeneratedColumn<String>(
    'local_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotIdMeta = const VerificationMeta('slotId');
  @override
  late final GeneratedColumn<int> slotId = GeneratedColumn<int>(
    'slot_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meal_slots (id)',
    ),
  );
  static const VerificationMeta _loggedAtMsMeta = const VerificationMeta(
    'loggedAtMs',
  );
  @override
  late final GeneratedColumn<int> loggedAtMs = GeneratedColumn<int>(
    'logged_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tzOffsetMinutesMeta = const VerificationMeta(
    'tzOffsetMinutes',
  );
  @override
  late final GeneratedColumn<int> tzOffsetMinutes = GeneratedColumn<int>(
    'tz_offset_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTextMeta = const VerificationMeta(
    'sourceText',
  );
  @override
  late final GeneratedColumn<String> sourceText = GeneratedColumn<String>(
    'source_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _savedMealIdMeta = const VerificationMeta(
    'savedMealId',
  );
  @override
  late final GeneratedColumn<int> savedMealId = GeneratedColumn<int>(
    'saved_meal_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES saved_meals (id) ON DELETE SET NULL',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    localDate,
    slotId,
    loggedAtMs,
    tzOffsetMinutes,
    sourceText,
    savedMealId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meals';
  @override
  VerificationContext validateIntegrity(
    Insertable<Meal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('local_date')) {
      context.handle(
        _localDateMeta,
        localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta),
      );
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('slot_id')) {
      context.handle(
        _slotIdMeta,
        slotId.isAcceptableOrUnknown(data['slot_id']!, _slotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_slotIdMeta);
    }
    if (data.containsKey('logged_at_ms')) {
      context.handle(
        _loggedAtMsMeta,
        loggedAtMs.isAcceptableOrUnknown(
          data['logged_at_ms']!,
          _loggedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_loggedAtMsMeta);
    }
    if (data.containsKey('tz_offset_minutes')) {
      context.handle(
        _tzOffsetMinutesMeta,
        tzOffsetMinutes.isAcceptableOrUnknown(
          data['tz_offset_minutes']!,
          _tzOffsetMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tzOffsetMinutesMeta);
    }
    if (data.containsKey('source_text')) {
      context.handle(
        _sourceTextMeta,
        sourceText.isAcceptableOrUnknown(data['source_text']!, _sourceTextMeta),
      );
    }
    if (data.containsKey('saved_meal_id')) {
      context.handle(
        _savedMealIdMeta,
        savedMealId.isAcceptableOrUnknown(
          data['saved_meal_id']!,
          _savedMealIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Meal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Meal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      localDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_date'],
      )!,
      slotId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot_id'],
      )!,
      loggedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}logged_at_ms'],
      )!,
      tzOffsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tz_offset_minutes'],
      )!,
      sourceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_text'],
      ),
      savedMealId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}saved_meal_id'],
      ),
    );
  }

  @override
  $MealsTable createAlias(String alias) {
    return $MealsTable(attachedDatabase, alias);
  }
}

class Meal extends DataClass implements Insertable<Meal> {
  final int id;
  final String localDate;
  final int slotId;
  final int loggedAtMs;
  final int tzOffsetMinutes;
  final String? sourceText;
  final int? savedMealId;
  const Meal({
    required this.id,
    required this.localDate,
    required this.slotId,
    required this.loggedAtMs,
    required this.tzOffsetMinutes,
    this.sourceText,
    this.savedMealId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['local_date'] = Variable<String>(localDate);
    map['slot_id'] = Variable<int>(slotId);
    map['logged_at_ms'] = Variable<int>(loggedAtMs);
    map['tz_offset_minutes'] = Variable<int>(tzOffsetMinutes);
    if (!nullToAbsent || sourceText != null) {
      map['source_text'] = Variable<String>(sourceText);
    }
    if (!nullToAbsent || savedMealId != null) {
      map['saved_meal_id'] = Variable<int>(savedMealId);
    }
    return map;
  }

  MealsCompanion toCompanion(bool nullToAbsent) {
    return MealsCompanion(
      id: Value(id),
      localDate: Value(localDate),
      slotId: Value(slotId),
      loggedAtMs: Value(loggedAtMs),
      tzOffsetMinutes: Value(tzOffsetMinutes),
      sourceText: sourceText == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceText),
      savedMealId: savedMealId == null && nullToAbsent
          ? const Value.absent()
          : Value(savedMealId),
    );
  }

  factory Meal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Meal(
      id: serializer.fromJson<int>(json['id']),
      localDate: serializer.fromJson<String>(json['localDate']),
      slotId: serializer.fromJson<int>(json['slotId']),
      loggedAtMs: serializer.fromJson<int>(json['loggedAtMs']),
      tzOffsetMinutes: serializer.fromJson<int>(json['tzOffsetMinutes']),
      sourceText: serializer.fromJson<String?>(json['sourceText']),
      savedMealId: serializer.fromJson<int?>(json['savedMealId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'localDate': serializer.toJson<String>(localDate),
      'slotId': serializer.toJson<int>(slotId),
      'loggedAtMs': serializer.toJson<int>(loggedAtMs),
      'tzOffsetMinutes': serializer.toJson<int>(tzOffsetMinutes),
      'sourceText': serializer.toJson<String?>(sourceText),
      'savedMealId': serializer.toJson<int?>(savedMealId),
    };
  }

  Meal copyWith({
    int? id,
    String? localDate,
    int? slotId,
    int? loggedAtMs,
    int? tzOffsetMinutes,
    Value<String?> sourceText = const Value.absent(),
    Value<int?> savedMealId = const Value.absent(),
  }) => Meal(
    id: id ?? this.id,
    localDate: localDate ?? this.localDate,
    slotId: slotId ?? this.slotId,
    loggedAtMs: loggedAtMs ?? this.loggedAtMs,
    tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
    sourceText: sourceText.present ? sourceText.value : this.sourceText,
    savedMealId: savedMealId.present ? savedMealId.value : this.savedMealId,
  );
  Meal copyWithCompanion(MealsCompanion data) {
    return Meal(
      id: data.id.present ? data.id.value : this.id,
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      slotId: data.slotId.present ? data.slotId.value : this.slotId,
      loggedAtMs: data.loggedAtMs.present
          ? data.loggedAtMs.value
          : this.loggedAtMs,
      tzOffsetMinutes: data.tzOffsetMinutes.present
          ? data.tzOffsetMinutes.value
          : this.tzOffsetMinutes,
      sourceText: data.sourceText.present
          ? data.sourceText.value
          : this.sourceText,
      savedMealId: data.savedMealId.present
          ? data.savedMealId.value
          : this.savedMealId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Meal(')
          ..write('id: $id, ')
          ..write('localDate: $localDate, ')
          ..write('slotId: $slotId, ')
          ..write('loggedAtMs: $loggedAtMs, ')
          ..write('tzOffsetMinutes: $tzOffsetMinutes, ')
          ..write('sourceText: $sourceText, ')
          ..write('savedMealId: $savedMealId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    localDate,
    slotId,
    loggedAtMs,
    tzOffsetMinutes,
    sourceText,
    savedMealId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Meal &&
          other.id == this.id &&
          other.localDate == this.localDate &&
          other.slotId == this.slotId &&
          other.loggedAtMs == this.loggedAtMs &&
          other.tzOffsetMinutes == this.tzOffsetMinutes &&
          other.sourceText == this.sourceText &&
          other.savedMealId == this.savedMealId);
}

class MealsCompanion extends UpdateCompanion<Meal> {
  final Value<int> id;
  final Value<String> localDate;
  final Value<int> slotId;
  final Value<int> loggedAtMs;
  final Value<int> tzOffsetMinutes;
  final Value<String?> sourceText;
  final Value<int?> savedMealId;
  const MealsCompanion({
    this.id = const Value.absent(),
    this.localDate = const Value.absent(),
    this.slotId = const Value.absent(),
    this.loggedAtMs = const Value.absent(),
    this.tzOffsetMinutes = const Value.absent(),
    this.sourceText = const Value.absent(),
    this.savedMealId = const Value.absent(),
  });
  MealsCompanion.insert({
    this.id = const Value.absent(),
    required String localDate,
    required int slotId,
    required int loggedAtMs,
    required int tzOffsetMinutes,
    this.sourceText = const Value.absent(),
    this.savedMealId = const Value.absent(),
  }) : localDate = Value(localDate),
       slotId = Value(slotId),
       loggedAtMs = Value(loggedAtMs),
       tzOffsetMinutes = Value(tzOffsetMinutes);
  static Insertable<Meal> custom({
    Expression<int>? id,
    Expression<String>? localDate,
    Expression<int>? slotId,
    Expression<int>? loggedAtMs,
    Expression<int>? tzOffsetMinutes,
    Expression<String>? sourceText,
    Expression<int>? savedMealId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (localDate != null) 'local_date': localDate,
      if (slotId != null) 'slot_id': slotId,
      if (loggedAtMs != null) 'logged_at_ms': loggedAtMs,
      if (tzOffsetMinutes != null) 'tz_offset_minutes': tzOffsetMinutes,
      if (sourceText != null) 'source_text': sourceText,
      if (savedMealId != null) 'saved_meal_id': savedMealId,
    });
  }

  MealsCompanion copyWith({
    Value<int>? id,
    Value<String>? localDate,
    Value<int>? slotId,
    Value<int>? loggedAtMs,
    Value<int>? tzOffsetMinutes,
    Value<String?>? sourceText,
    Value<int?>? savedMealId,
  }) {
    return MealsCompanion(
      id: id ?? this.id,
      localDate: localDate ?? this.localDate,
      slotId: slotId ?? this.slotId,
      loggedAtMs: loggedAtMs ?? this.loggedAtMs,
      tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
      sourceText: sourceText ?? this.sourceText,
      savedMealId: savedMealId ?? this.savedMealId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (slotId.present) {
      map['slot_id'] = Variable<int>(slotId.value);
    }
    if (loggedAtMs.present) {
      map['logged_at_ms'] = Variable<int>(loggedAtMs.value);
    }
    if (tzOffsetMinutes.present) {
      map['tz_offset_minutes'] = Variable<int>(tzOffsetMinutes.value);
    }
    if (sourceText.present) {
      map['source_text'] = Variable<String>(sourceText.value);
    }
    if (savedMealId.present) {
      map['saved_meal_id'] = Variable<int>(savedMealId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealsCompanion(')
          ..write('id: $id, ')
          ..write('localDate: $localDate, ')
          ..write('slotId: $slotId, ')
          ..write('loggedAtMs: $loggedAtMs, ')
          ..write('tzOffsetMinutes: $tzOffsetMinutes, ')
          ..write('sourceText: $sourceText, ')
          ..write('savedMealId: $savedMealId')
          ..write(')'))
        .toString();
  }
}

class $MealEntriesTable extends MealEntries
    with TableInfo<$MealEntriesTable, MealEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _mealIdMeta = const VerificationMeta('mealId');
  @override
  late final GeneratedColumn<int> mealId = GeneratedColumn<int>(
    'meal_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meals (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodRefMeta = const VerificationMeta(
    'foodRef',
  );
  @override
  late final GeneratedColumn<String> foodRef = GeneratedColumn<String>(
    'food_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodNameMeta = const VerificationMeta(
    'foodName',
  );
  @override
  late final GeneratedColumn<String> foodName = GeneratedColumn<String>(
    'food_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitLabelMeta = const VerificationMeta(
    'unitLabel',
  );
  @override
  late final GeneratedColumn<String> unitLabel = GeneratedColumn<String>(
    'unit_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseQuantityMeta = const VerificationMeta(
    'baseQuantity',
  );
  @override
  late final GeneratedColumn<double> baseQuantity = GeneratedColumn<double>(
    'base_quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUnitMeta = const VerificationMeta(
    'baseUnit',
  );
  @override
  late final GeneratedColumn<String> baseUnit = GeneratedColumn<String>(
    'base_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mealId,
    position,
    foodRef,
    foodName,
    quantity,
    unitLabel,
    baseQuantity,
    baseUnit,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('meal_id')) {
      context.handle(
        _mealIdMeta,
        mealId.isAcceptableOrUnknown(data['meal_id']!, _mealIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mealIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('food_ref')) {
      context.handle(
        _foodRefMeta,
        foodRef.isAcceptableOrUnknown(data['food_ref']!, _foodRefMeta),
      );
    } else if (isInserting) {
      context.missing(_foodRefMeta);
    }
    if (data.containsKey('food_name')) {
      context.handle(
        _foodNameMeta,
        foodName.isAcceptableOrUnknown(data['food_name']!, _foodNameMeta),
      );
    } else if (isInserting) {
      context.missing(_foodNameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit_label')) {
      context.handle(
        _unitLabelMeta,
        unitLabel.isAcceptableOrUnknown(data['unit_label']!, _unitLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_unitLabelMeta);
    }
    if (data.containsKey('base_quantity')) {
      context.handle(
        _baseQuantityMeta,
        baseQuantity.isAcceptableOrUnknown(
          data['base_quantity']!,
          _baseQuantityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseQuantityMeta);
    }
    if (data.containsKey('base_unit')) {
      context.handle(
        _baseUnitMeta,
        baseUnit.isAcceptableOrUnknown(data['base_unit']!, _baseUnitMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUnitMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mealId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meal_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      foodRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_ref'],
      )!,
      foodName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      unitLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_label'],
      )!,
      baseQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}base_quantity'],
      )!,
      baseUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_unit'],
      )!,
    );
  }

  @override
  $MealEntriesTable createAlias(String alias) {
    return $MealEntriesTable(attachedDatabase, alias);
  }
}

class MealEntry extends DataClass implements Insertable<MealEntry> {
  final int id;
  final int mealId;
  final int position;
  final String foodRef;
  final String foodName;
  final double quantity;
  final String unitLabel;
  final double baseQuantity;
  final String baseUnit;
  const MealEntry({
    required this.id,
    required this.mealId,
    required this.position,
    required this.foodRef,
    required this.foodName,
    required this.quantity,
    required this.unitLabel,
    required this.baseQuantity,
    required this.baseUnit,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['meal_id'] = Variable<int>(mealId);
    map['position'] = Variable<int>(position);
    map['food_ref'] = Variable<String>(foodRef);
    map['food_name'] = Variable<String>(foodName);
    map['quantity'] = Variable<double>(quantity);
    map['unit_label'] = Variable<String>(unitLabel);
    map['base_quantity'] = Variable<double>(baseQuantity);
    map['base_unit'] = Variable<String>(baseUnit);
    return map;
  }

  MealEntriesCompanion toCompanion(bool nullToAbsent) {
    return MealEntriesCompanion(
      id: Value(id),
      mealId: Value(mealId),
      position: Value(position),
      foodRef: Value(foodRef),
      foodName: Value(foodName),
      quantity: Value(quantity),
      unitLabel: Value(unitLabel),
      baseQuantity: Value(baseQuantity),
      baseUnit: Value(baseUnit),
    );
  }

  factory MealEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealEntry(
      id: serializer.fromJson<int>(json['id']),
      mealId: serializer.fromJson<int>(json['mealId']),
      position: serializer.fromJson<int>(json['position']),
      foodRef: serializer.fromJson<String>(json['foodRef']),
      foodName: serializer.fromJson<String>(json['foodName']),
      quantity: serializer.fromJson<double>(json['quantity']),
      unitLabel: serializer.fromJson<String>(json['unitLabel']),
      baseQuantity: serializer.fromJson<double>(json['baseQuantity']),
      baseUnit: serializer.fromJson<String>(json['baseUnit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mealId': serializer.toJson<int>(mealId),
      'position': serializer.toJson<int>(position),
      'foodRef': serializer.toJson<String>(foodRef),
      'foodName': serializer.toJson<String>(foodName),
      'quantity': serializer.toJson<double>(quantity),
      'unitLabel': serializer.toJson<String>(unitLabel),
      'baseQuantity': serializer.toJson<double>(baseQuantity),
      'baseUnit': serializer.toJson<String>(baseUnit),
    };
  }

  MealEntry copyWith({
    int? id,
    int? mealId,
    int? position,
    String? foodRef,
    String? foodName,
    double? quantity,
    String? unitLabel,
    double? baseQuantity,
    String? baseUnit,
  }) => MealEntry(
    id: id ?? this.id,
    mealId: mealId ?? this.mealId,
    position: position ?? this.position,
    foodRef: foodRef ?? this.foodRef,
    foodName: foodName ?? this.foodName,
    quantity: quantity ?? this.quantity,
    unitLabel: unitLabel ?? this.unitLabel,
    baseQuantity: baseQuantity ?? this.baseQuantity,
    baseUnit: baseUnit ?? this.baseUnit,
  );
  MealEntry copyWithCompanion(MealEntriesCompanion data) {
    return MealEntry(
      id: data.id.present ? data.id.value : this.id,
      mealId: data.mealId.present ? data.mealId.value : this.mealId,
      position: data.position.present ? data.position.value : this.position,
      foodRef: data.foodRef.present ? data.foodRef.value : this.foodRef,
      foodName: data.foodName.present ? data.foodName.value : this.foodName,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitLabel: data.unitLabel.present ? data.unitLabel.value : this.unitLabel,
      baseQuantity: data.baseQuantity.present
          ? data.baseQuantity.value
          : this.baseQuantity,
      baseUnit: data.baseUnit.present ? data.baseUnit.value : this.baseUnit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealEntry(')
          ..write('id: $id, ')
          ..write('mealId: $mealId, ')
          ..write('position: $position, ')
          ..write('foodRef: $foodRef, ')
          ..write('foodName: $foodName, ')
          ..write('quantity: $quantity, ')
          ..write('unitLabel: $unitLabel, ')
          ..write('baseQuantity: $baseQuantity, ')
          ..write('baseUnit: $baseUnit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mealId,
    position,
    foodRef,
    foodName,
    quantity,
    unitLabel,
    baseQuantity,
    baseUnit,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealEntry &&
          other.id == this.id &&
          other.mealId == this.mealId &&
          other.position == this.position &&
          other.foodRef == this.foodRef &&
          other.foodName == this.foodName &&
          other.quantity == this.quantity &&
          other.unitLabel == this.unitLabel &&
          other.baseQuantity == this.baseQuantity &&
          other.baseUnit == this.baseUnit);
}

class MealEntriesCompanion extends UpdateCompanion<MealEntry> {
  final Value<int> id;
  final Value<int> mealId;
  final Value<int> position;
  final Value<String> foodRef;
  final Value<String> foodName;
  final Value<double> quantity;
  final Value<String> unitLabel;
  final Value<double> baseQuantity;
  final Value<String> baseUnit;
  const MealEntriesCompanion({
    this.id = const Value.absent(),
    this.mealId = const Value.absent(),
    this.position = const Value.absent(),
    this.foodRef = const Value.absent(),
    this.foodName = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitLabel = const Value.absent(),
    this.baseQuantity = const Value.absent(),
    this.baseUnit = const Value.absent(),
  });
  MealEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int mealId,
    required int position,
    required String foodRef,
    required String foodName,
    required double quantity,
    required String unitLabel,
    required double baseQuantity,
    required String baseUnit,
  }) : mealId = Value(mealId),
       position = Value(position),
       foodRef = Value(foodRef),
       foodName = Value(foodName),
       quantity = Value(quantity),
       unitLabel = Value(unitLabel),
       baseQuantity = Value(baseQuantity),
       baseUnit = Value(baseUnit);
  static Insertable<MealEntry> custom({
    Expression<int>? id,
    Expression<int>? mealId,
    Expression<int>? position,
    Expression<String>? foodRef,
    Expression<String>? foodName,
    Expression<double>? quantity,
    Expression<String>? unitLabel,
    Expression<double>? baseQuantity,
    Expression<String>? baseUnit,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mealId != null) 'meal_id': mealId,
      if (position != null) 'position': position,
      if (foodRef != null) 'food_ref': foodRef,
      if (foodName != null) 'food_name': foodName,
      if (quantity != null) 'quantity': quantity,
      if (unitLabel != null) 'unit_label': unitLabel,
      if (baseQuantity != null) 'base_quantity': baseQuantity,
      if (baseUnit != null) 'base_unit': baseUnit,
    });
  }

  MealEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? mealId,
    Value<int>? position,
    Value<String>? foodRef,
    Value<String>? foodName,
    Value<double>? quantity,
    Value<String>? unitLabel,
    Value<double>? baseQuantity,
    Value<String>? baseUnit,
  }) {
    return MealEntriesCompanion(
      id: id ?? this.id,
      mealId: mealId ?? this.mealId,
      position: position ?? this.position,
      foodRef: foodRef ?? this.foodRef,
      foodName: foodName ?? this.foodName,
      quantity: quantity ?? this.quantity,
      unitLabel: unitLabel ?? this.unitLabel,
      baseQuantity: baseQuantity ?? this.baseQuantity,
      baseUnit: baseUnit ?? this.baseUnit,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mealId.present) {
      map['meal_id'] = Variable<int>(mealId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (foodRef.present) {
      map['food_ref'] = Variable<String>(foodRef.value);
    }
    if (foodName.present) {
      map['food_name'] = Variable<String>(foodName.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unitLabel.present) {
      map['unit_label'] = Variable<String>(unitLabel.value);
    }
    if (baseQuantity.present) {
      map['base_quantity'] = Variable<double>(baseQuantity.value);
    }
    if (baseUnit.present) {
      map['base_unit'] = Variable<String>(baseUnit.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealEntriesCompanion(')
          ..write('id: $id, ')
          ..write('mealId: $mealId, ')
          ..write('position: $position, ')
          ..write('foodRef: $foodRef, ')
          ..write('foodName: $foodName, ')
          ..write('quantity: $quantity, ')
          ..write('unitLabel: $unitLabel, ')
          ..write('baseQuantity: $baseQuantity, ')
          ..write('baseUnit: $baseUnit')
          ..write(')'))
        .toString();
  }
}

class $MealEntryNutrientsTable extends MealEntryNutrients
    with TableInfo<$MealEntryNutrientsTable, MealEntryNutrient> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealEntryNutrientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<int> entryId = GeneratedColumn<int>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meal_entries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nutrientIdMeta = const VerificationMeta(
    'nutrientId',
  );
  @override
  late final GeneratedColumn<int> nutrientId = GeneratedColumn<int>(
    'nutrient_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entryId, nutrientId, amount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_entry_nutrients';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealEntryNutrient> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('nutrient_id')) {
      context.handle(
        _nutrientIdMeta,
        nutrientId.isAcceptableOrUnknown(data['nutrient_id']!, _nutrientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nutrientIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId, nutrientId};
  @override
  MealEntryNutrient map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealEntryNutrient(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entry_id'],
      )!,
      nutrientId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}nutrient_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
    );
  }

  @override
  $MealEntryNutrientsTable createAlias(String alias) {
    return $MealEntryNutrientsTable(attachedDatabase, alias);
  }
}

class MealEntryNutrient extends DataClass
    implements Insertable<MealEntryNutrient> {
  final int entryId;
  final int nutrientId;
  final double amount;
  const MealEntryNutrient({
    required this.entryId,
    required this.nutrientId,
    required this.amount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<int>(entryId);
    map['nutrient_id'] = Variable<int>(nutrientId);
    map['amount'] = Variable<double>(amount);
    return map;
  }

  MealEntryNutrientsCompanion toCompanion(bool nullToAbsent) {
    return MealEntryNutrientsCompanion(
      entryId: Value(entryId),
      nutrientId: Value(nutrientId),
      amount: Value(amount),
    );
  }

  factory MealEntryNutrient.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealEntryNutrient(
      entryId: serializer.fromJson<int>(json['entryId']),
      nutrientId: serializer.fromJson<int>(json['nutrientId']),
      amount: serializer.fromJson<double>(json['amount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<int>(entryId),
      'nutrientId': serializer.toJson<int>(nutrientId),
      'amount': serializer.toJson<double>(amount),
    };
  }

  MealEntryNutrient copyWith({int? entryId, int? nutrientId, double? amount}) =>
      MealEntryNutrient(
        entryId: entryId ?? this.entryId,
        nutrientId: nutrientId ?? this.nutrientId,
        amount: amount ?? this.amount,
      );
  MealEntryNutrient copyWithCompanion(MealEntryNutrientsCompanion data) {
    return MealEntryNutrient(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      nutrientId: data.nutrientId.present
          ? data.nutrientId.value
          : this.nutrientId,
      amount: data.amount.present ? data.amount.value : this.amount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealEntryNutrient(')
          ..write('entryId: $entryId, ')
          ..write('nutrientId: $nutrientId, ')
          ..write('amount: $amount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entryId, nutrientId, amount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealEntryNutrient &&
          other.entryId == this.entryId &&
          other.nutrientId == this.nutrientId &&
          other.amount == this.amount);
}

class MealEntryNutrientsCompanion extends UpdateCompanion<MealEntryNutrient> {
  final Value<int> entryId;
  final Value<int> nutrientId;
  final Value<double> amount;
  final Value<int> rowid;
  const MealEntryNutrientsCompanion({
    this.entryId = const Value.absent(),
    this.nutrientId = const Value.absent(),
    this.amount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MealEntryNutrientsCompanion.insert({
    required int entryId,
    required int nutrientId,
    required double amount,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       nutrientId = Value(nutrientId),
       amount = Value(amount);
  static Insertable<MealEntryNutrient> custom({
    Expression<int>? entryId,
    Expression<int>? nutrientId,
    Expression<double>? amount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (nutrientId != null) 'nutrient_id': nutrientId,
      if (amount != null) 'amount': amount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MealEntryNutrientsCompanion copyWith({
    Value<int>? entryId,
    Value<int>? nutrientId,
    Value<double>? amount,
    Value<int>? rowid,
  }) {
    return MealEntryNutrientsCompanion(
      entryId: entryId ?? this.entryId,
      nutrientId: nutrientId ?? this.nutrientId,
      amount: amount ?? this.amount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<int>(entryId.value);
    }
    if (nutrientId.present) {
      map['nutrient_id'] = Variable<int>(nutrientId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealEntryNutrientsCompanion(')
          ..write('entryId: $entryId, ')
          ..write('nutrientId: $nutrientId, ')
          ..write('amount: $amount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedMealItemsTable extends SavedMealItems
    with TableInfo<$SavedMealItemsTable, SavedMealItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedMealItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _savedMealIdMeta = const VerificationMeta(
    'savedMealId',
  );
  @override
  late final GeneratedColumn<int> savedMealId = GeneratedColumn<int>(
    'saved_meal_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES saved_meals (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodRefMeta = const VerificationMeta(
    'foodRef',
  );
  @override
  late final GeneratedColumn<String> foodRef = GeneratedColumn<String>(
    'food_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodNameMeta = const VerificationMeta(
    'foodName',
  );
  @override
  late final GeneratedColumn<String> foodName = GeneratedColumn<String>(
    'food_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitLabelMeta = const VerificationMeta(
    'unitLabel',
  );
  @override
  late final GeneratedColumn<String> unitLabel = GeneratedColumn<String>(
    'unit_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseQuantityMeta = const VerificationMeta(
    'baseQuantity',
  );
  @override
  late final GeneratedColumn<double> baseQuantity = GeneratedColumn<double>(
    'base_quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUnitMeta = const VerificationMeta(
    'baseUnit',
  );
  @override
  late final GeneratedColumn<String> baseUnit = GeneratedColumn<String>(
    'base_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    savedMealId,
    position,
    foodRef,
    foodName,
    quantity,
    unitLabel,
    baseQuantity,
    baseUnit,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_meal_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedMealItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('saved_meal_id')) {
      context.handle(
        _savedMealIdMeta,
        savedMealId.isAcceptableOrUnknown(
          data['saved_meal_id']!,
          _savedMealIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_savedMealIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('food_ref')) {
      context.handle(
        _foodRefMeta,
        foodRef.isAcceptableOrUnknown(data['food_ref']!, _foodRefMeta),
      );
    } else if (isInserting) {
      context.missing(_foodRefMeta);
    }
    if (data.containsKey('food_name')) {
      context.handle(
        _foodNameMeta,
        foodName.isAcceptableOrUnknown(data['food_name']!, _foodNameMeta),
      );
    } else if (isInserting) {
      context.missing(_foodNameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit_label')) {
      context.handle(
        _unitLabelMeta,
        unitLabel.isAcceptableOrUnknown(data['unit_label']!, _unitLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_unitLabelMeta);
    }
    if (data.containsKey('base_quantity')) {
      context.handle(
        _baseQuantityMeta,
        baseQuantity.isAcceptableOrUnknown(
          data['base_quantity']!,
          _baseQuantityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseQuantityMeta);
    }
    if (data.containsKey('base_unit')) {
      context.handle(
        _baseUnitMeta,
        baseUnit.isAcceptableOrUnknown(data['base_unit']!, _baseUnitMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUnitMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedMealItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedMealItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      savedMealId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}saved_meal_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      foodRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_ref'],
      )!,
      foodName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      unitLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_label'],
      )!,
      baseQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}base_quantity'],
      )!,
      baseUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_unit'],
      )!,
    );
  }

  @override
  $SavedMealItemsTable createAlias(String alias) {
    return $SavedMealItemsTable(attachedDatabase, alias);
  }
}

class SavedMealItem extends DataClass implements Insertable<SavedMealItem> {
  final int id;
  final int savedMealId;
  final int position;
  final String foodRef;
  final String foodName;
  final double quantity;
  final String unitLabel;
  final double baseQuantity;
  final String baseUnit;
  const SavedMealItem({
    required this.id,
    required this.savedMealId,
    required this.position,
    required this.foodRef,
    required this.foodName,
    required this.quantity,
    required this.unitLabel,
    required this.baseQuantity,
    required this.baseUnit,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['saved_meal_id'] = Variable<int>(savedMealId);
    map['position'] = Variable<int>(position);
    map['food_ref'] = Variable<String>(foodRef);
    map['food_name'] = Variable<String>(foodName);
    map['quantity'] = Variable<double>(quantity);
    map['unit_label'] = Variable<String>(unitLabel);
    map['base_quantity'] = Variable<double>(baseQuantity);
    map['base_unit'] = Variable<String>(baseUnit);
    return map;
  }

  SavedMealItemsCompanion toCompanion(bool nullToAbsent) {
    return SavedMealItemsCompanion(
      id: Value(id),
      savedMealId: Value(savedMealId),
      position: Value(position),
      foodRef: Value(foodRef),
      foodName: Value(foodName),
      quantity: Value(quantity),
      unitLabel: Value(unitLabel),
      baseQuantity: Value(baseQuantity),
      baseUnit: Value(baseUnit),
    );
  }

  factory SavedMealItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedMealItem(
      id: serializer.fromJson<int>(json['id']),
      savedMealId: serializer.fromJson<int>(json['savedMealId']),
      position: serializer.fromJson<int>(json['position']),
      foodRef: serializer.fromJson<String>(json['foodRef']),
      foodName: serializer.fromJson<String>(json['foodName']),
      quantity: serializer.fromJson<double>(json['quantity']),
      unitLabel: serializer.fromJson<String>(json['unitLabel']),
      baseQuantity: serializer.fromJson<double>(json['baseQuantity']),
      baseUnit: serializer.fromJson<String>(json['baseUnit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'savedMealId': serializer.toJson<int>(savedMealId),
      'position': serializer.toJson<int>(position),
      'foodRef': serializer.toJson<String>(foodRef),
      'foodName': serializer.toJson<String>(foodName),
      'quantity': serializer.toJson<double>(quantity),
      'unitLabel': serializer.toJson<String>(unitLabel),
      'baseQuantity': serializer.toJson<double>(baseQuantity),
      'baseUnit': serializer.toJson<String>(baseUnit),
    };
  }

  SavedMealItem copyWith({
    int? id,
    int? savedMealId,
    int? position,
    String? foodRef,
    String? foodName,
    double? quantity,
    String? unitLabel,
    double? baseQuantity,
    String? baseUnit,
  }) => SavedMealItem(
    id: id ?? this.id,
    savedMealId: savedMealId ?? this.savedMealId,
    position: position ?? this.position,
    foodRef: foodRef ?? this.foodRef,
    foodName: foodName ?? this.foodName,
    quantity: quantity ?? this.quantity,
    unitLabel: unitLabel ?? this.unitLabel,
    baseQuantity: baseQuantity ?? this.baseQuantity,
    baseUnit: baseUnit ?? this.baseUnit,
  );
  SavedMealItem copyWithCompanion(SavedMealItemsCompanion data) {
    return SavedMealItem(
      id: data.id.present ? data.id.value : this.id,
      savedMealId: data.savedMealId.present
          ? data.savedMealId.value
          : this.savedMealId,
      position: data.position.present ? data.position.value : this.position,
      foodRef: data.foodRef.present ? data.foodRef.value : this.foodRef,
      foodName: data.foodName.present ? data.foodName.value : this.foodName,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitLabel: data.unitLabel.present ? data.unitLabel.value : this.unitLabel,
      baseQuantity: data.baseQuantity.present
          ? data.baseQuantity.value
          : this.baseQuantity,
      baseUnit: data.baseUnit.present ? data.baseUnit.value : this.baseUnit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedMealItem(')
          ..write('id: $id, ')
          ..write('savedMealId: $savedMealId, ')
          ..write('position: $position, ')
          ..write('foodRef: $foodRef, ')
          ..write('foodName: $foodName, ')
          ..write('quantity: $quantity, ')
          ..write('unitLabel: $unitLabel, ')
          ..write('baseQuantity: $baseQuantity, ')
          ..write('baseUnit: $baseUnit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    savedMealId,
    position,
    foodRef,
    foodName,
    quantity,
    unitLabel,
    baseQuantity,
    baseUnit,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedMealItem &&
          other.id == this.id &&
          other.savedMealId == this.savedMealId &&
          other.position == this.position &&
          other.foodRef == this.foodRef &&
          other.foodName == this.foodName &&
          other.quantity == this.quantity &&
          other.unitLabel == this.unitLabel &&
          other.baseQuantity == this.baseQuantity &&
          other.baseUnit == this.baseUnit);
}

class SavedMealItemsCompanion extends UpdateCompanion<SavedMealItem> {
  final Value<int> id;
  final Value<int> savedMealId;
  final Value<int> position;
  final Value<String> foodRef;
  final Value<String> foodName;
  final Value<double> quantity;
  final Value<String> unitLabel;
  final Value<double> baseQuantity;
  final Value<String> baseUnit;
  const SavedMealItemsCompanion({
    this.id = const Value.absent(),
    this.savedMealId = const Value.absent(),
    this.position = const Value.absent(),
    this.foodRef = const Value.absent(),
    this.foodName = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitLabel = const Value.absent(),
    this.baseQuantity = const Value.absent(),
    this.baseUnit = const Value.absent(),
  });
  SavedMealItemsCompanion.insert({
    this.id = const Value.absent(),
    required int savedMealId,
    required int position,
    required String foodRef,
    required String foodName,
    required double quantity,
    required String unitLabel,
    required double baseQuantity,
    required String baseUnit,
  }) : savedMealId = Value(savedMealId),
       position = Value(position),
       foodRef = Value(foodRef),
       foodName = Value(foodName),
       quantity = Value(quantity),
       unitLabel = Value(unitLabel),
       baseQuantity = Value(baseQuantity),
       baseUnit = Value(baseUnit);
  static Insertable<SavedMealItem> custom({
    Expression<int>? id,
    Expression<int>? savedMealId,
    Expression<int>? position,
    Expression<String>? foodRef,
    Expression<String>? foodName,
    Expression<double>? quantity,
    Expression<String>? unitLabel,
    Expression<double>? baseQuantity,
    Expression<String>? baseUnit,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (savedMealId != null) 'saved_meal_id': savedMealId,
      if (position != null) 'position': position,
      if (foodRef != null) 'food_ref': foodRef,
      if (foodName != null) 'food_name': foodName,
      if (quantity != null) 'quantity': quantity,
      if (unitLabel != null) 'unit_label': unitLabel,
      if (baseQuantity != null) 'base_quantity': baseQuantity,
      if (baseUnit != null) 'base_unit': baseUnit,
    });
  }

  SavedMealItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? savedMealId,
    Value<int>? position,
    Value<String>? foodRef,
    Value<String>? foodName,
    Value<double>? quantity,
    Value<String>? unitLabel,
    Value<double>? baseQuantity,
    Value<String>? baseUnit,
  }) {
    return SavedMealItemsCompanion(
      id: id ?? this.id,
      savedMealId: savedMealId ?? this.savedMealId,
      position: position ?? this.position,
      foodRef: foodRef ?? this.foodRef,
      foodName: foodName ?? this.foodName,
      quantity: quantity ?? this.quantity,
      unitLabel: unitLabel ?? this.unitLabel,
      baseQuantity: baseQuantity ?? this.baseQuantity,
      baseUnit: baseUnit ?? this.baseUnit,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (savedMealId.present) {
      map['saved_meal_id'] = Variable<int>(savedMealId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (foodRef.present) {
      map['food_ref'] = Variable<String>(foodRef.value);
    }
    if (foodName.present) {
      map['food_name'] = Variable<String>(foodName.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unitLabel.present) {
      map['unit_label'] = Variable<String>(unitLabel.value);
    }
    if (baseQuantity.present) {
      map['base_quantity'] = Variable<double>(baseQuantity.value);
    }
    if (baseUnit.present) {
      map['base_unit'] = Variable<String>(baseUnit.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedMealItemsCompanion(')
          ..write('id: $id, ')
          ..write('savedMealId: $savedMealId, ')
          ..write('position: $position, ')
          ..write('foodRef: $foodRef, ')
          ..write('foodName: $foodName, ')
          ..write('quantity: $quantity, ')
          ..write('unitLabel: $unitLabel, ')
          ..write('baseQuantity: $baseQuantity, ')
          ..write('baseUnit: $baseUnit')
          ..write(')'))
        .toString();
  }
}

class $SavedMealItemNutrientsTable extends SavedMealItemNutrients
    with TableInfo<$SavedMealItemNutrientsTable, SavedMealItemNutrient> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedMealItemNutrientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<int> itemId = GeneratedColumn<int>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES saved_meal_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nutrientIdMeta = const VerificationMeta(
    'nutrientId',
  );
  @override
  late final GeneratedColumn<int> nutrientId = GeneratedColumn<int>(
    'nutrient_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [itemId, nutrientId, amount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_meal_item_nutrients';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedMealItemNutrient> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('nutrient_id')) {
      context.handle(
        _nutrientIdMeta,
        nutrientId.isAcceptableOrUnknown(data['nutrient_id']!, _nutrientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nutrientIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId, nutrientId};
  @override
  SavedMealItemNutrient map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedMealItemNutrient(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_id'],
      )!,
      nutrientId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}nutrient_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
    );
  }

  @override
  $SavedMealItemNutrientsTable createAlias(String alias) {
    return $SavedMealItemNutrientsTable(attachedDatabase, alias);
  }
}

class SavedMealItemNutrient extends DataClass
    implements Insertable<SavedMealItemNutrient> {
  final int itemId;
  final int nutrientId;
  final double amount;
  const SavedMealItemNutrient({
    required this.itemId,
    required this.nutrientId,
    required this.amount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<int>(itemId);
    map['nutrient_id'] = Variable<int>(nutrientId);
    map['amount'] = Variable<double>(amount);
    return map;
  }

  SavedMealItemNutrientsCompanion toCompanion(bool nullToAbsent) {
    return SavedMealItemNutrientsCompanion(
      itemId: Value(itemId),
      nutrientId: Value(nutrientId),
      amount: Value(amount),
    );
  }

  factory SavedMealItemNutrient.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedMealItemNutrient(
      itemId: serializer.fromJson<int>(json['itemId']),
      nutrientId: serializer.fromJson<int>(json['nutrientId']),
      amount: serializer.fromJson<double>(json['amount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<int>(itemId),
      'nutrientId': serializer.toJson<int>(nutrientId),
      'amount': serializer.toJson<double>(amount),
    };
  }

  SavedMealItemNutrient copyWith({
    int? itemId,
    int? nutrientId,
    double? amount,
  }) => SavedMealItemNutrient(
    itemId: itemId ?? this.itemId,
    nutrientId: nutrientId ?? this.nutrientId,
    amount: amount ?? this.amount,
  );
  SavedMealItemNutrient copyWithCompanion(
    SavedMealItemNutrientsCompanion data,
  ) {
    return SavedMealItemNutrient(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      nutrientId: data.nutrientId.present
          ? data.nutrientId.value
          : this.nutrientId,
      amount: data.amount.present ? data.amount.value : this.amount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedMealItemNutrient(')
          ..write('itemId: $itemId, ')
          ..write('nutrientId: $nutrientId, ')
          ..write('amount: $amount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, nutrientId, amount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedMealItemNutrient &&
          other.itemId == this.itemId &&
          other.nutrientId == this.nutrientId &&
          other.amount == this.amount);
}

class SavedMealItemNutrientsCompanion
    extends UpdateCompanion<SavedMealItemNutrient> {
  final Value<int> itemId;
  final Value<int> nutrientId;
  final Value<double> amount;
  final Value<int> rowid;
  const SavedMealItemNutrientsCompanion({
    this.itemId = const Value.absent(),
    this.nutrientId = const Value.absent(),
    this.amount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedMealItemNutrientsCompanion.insert({
    required int itemId,
    required int nutrientId,
    required double amount,
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       nutrientId = Value(nutrientId),
       amount = Value(amount);
  static Insertable<SavedMealItemNutrient> custom({
    Expression<int>? itemId,
    Expression<int>? nutrientId,
    Expression<double>? amount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (nutrientId != null) 'nutrient_id': nutrientId,
      if (amount != null) 'amount': amount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedMealItemNutrientsCompanion copyWith({
    Value<int>? itemId,
    Value<int>? nutrientId,
    Value<double>? amount,
    Value<int>? rowid,
  }) {
    return SavedMealItemNutrientsCompanion(
      itemId: itemId ?? this.itemId,
      nutrientId: nutrientId ?? this.nutrientId,
      amount: amount ?? this.amount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<int>(itemId.value);
    }
    if (nutrientId.present) {
      map['nutrient_id'] = Variable<int>(nutrientId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedMealItemNutrientsCompanion(')
          ..write('itemId: $itemId, ')
          ..write('nutrientId: $nutrientId, ')
          ..write('amount: $amount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AliasesTable extends Aliases with TableInfo<$AliasesTable, Alias> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AliasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _phraseMeta = const VerificationMeta('phrase');
  @override
  late final GeneratedColumn<String> phrase = GeneratedColumn<String>(
    'phrase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _savedMealIdMeta = const VerificationMeta(
    'savedMealId',
  );
  @override
  late final GeneratedColumn<int> savedMealId = GeneratedColumn<int>(
    'saved_meal_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES saved_meals (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [id, phrase, savedMealId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'aliases';
  @override
  VerificationContext validateIntegrity(
    Insertable<Alias> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('phrase')) {
      context.handle(
        _phraseMeta,
        phrase.isAcceptableOrUnknown(data['phrase']!, _phraseMeta),
      );
    } else if (isInserting) {
      context.missing(_phraseMeta);
    }
    if (data.containsKey('saved_meal_id')) {
      context.handle(
        _savedMealIdMeta,
        savedMealId.isAcceptableOrUnknown(
          data['saved_meal_id']!,
          _savedMealIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_savedMealIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Alias map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Alias(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      phrase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phrase'],
      )!,
      savedMealId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}saved_meal_id'],
      )!,
    );
  }

  @override
  $AliasesTable createAlias(String alias) {
    return $AliasesTable(attachedDatabase, alias);
  }
}

class Alias extends DataClass implements Insertable<Alias> {
  final int id;
  final String phrase;
  final int savedMealId;
  const Alias({
    required this.id,
    required this.phrase,
    required this.savedMealId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['phrase'] = Variable<String>(phrase);
    map['saved_meal_id'] = Variable<int>(savedMealId);
    return map;
  }

  AliasesCompanion toCompanion(bool nullToAbsent) {
    return AliasesCompanion(
      id: Value(id),
      phrase: Value(phrase),
      savedMealId: Value(savedMealId),
    );
  }

  factory Alias.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Alias(
      id: serializer.fromJson<int>(json['id']),
      phrase: serializer.fromJson<String>(json['phrase']),
      savedMealId: serializer.fromJson<int>(json['savedMealId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'phrase': serializer.toJson<String>(phrase),
      'savedMealId': serializer.toJson<int>(savedMealId),
    };
  }

  Alias copyWith({int? id, String? phrase, int? savedMealId}) => Alias(
    id: id ?? this.id,
    phrase: phrase ?? this.phrase,
    savedMealId: savedMealId ?? this.savedMealId,
  );
  Alias copyWithCompanion(AliasesCompanion data) {
    return Alias(
      id: data.id.present ? data.id.value : this.id,
      phrase: data.phrase.present ? data.phrase.value : this.phrase,
      savedMealId: data.savedMealId.present
          ? data.savedMealId.value
          : this.savedMealId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Alias(')
          ..write('id: $id, ')
          ..write('phrase: $phrase, ')
          ..write('savedMealId: $savedMealId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, phrase, savedMealId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Alias &&
          other.id == this.id &&
          other.phrase == this.phrase &&
          other.savedMealId == this.savedMealId);
}

class AliasesCompanion extends UpdateCompanion<Alias> {
  final Value<int> id;
  final Value<String> phrase;
  final Value<int> savedMealId;
  const AliasesCompanion({
    this.id = const Value.absent(),
    this.phrase = const Value.absent(),
    this.savedMealId = const Value.absent(),
  });
  AliasesCompanion.insert({
    this.id = const Value.absent(),
    required String phrase,
    required int savedMealId,
  }) : phrase = Value(phrase),
       savedMealId = Value(savedMealId);
  static Insertable<Alias> custom({
    Expression<int>? id,
    Expression<String>? phrase,
    Expression<int>? savedMealId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (phrase != null) 'phrase': phrase,
      if (savedMealId != null) 'saved_meal_id': savedMealId,
    });
  }

  AliasesCompanion copyWith({
    Value<int>? id,
    Value<String>? phrase,
    Value<int>? savedMealId,
  }) {
    return AliasesCompanion(
      id: id ?? this.id,
      phrase: phrase ?? this.phrase,
      savedMealId: savedMealId ?? this.savedMealId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (phrase.present) {
      map['phrase'] = Variable<String>(phrase.value);
    }
    if (savedMealId.present) {
      map['saved_meal_id'] = Variable<int>(savedMealId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AliasesCompanion(')
          ..write('id: $id, ')
          ..write('phrase: $phrase, ')
          ..write('savedMealId: $savedMealId')
          ..write(')'))
        .toString();
  }
}

class $LearnedMatchesTable extends LearnedMatches
    with TableInfo<$LearnedMatchesTable, LearnedMatche> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearnedMatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _phraseMeta = const VerificationMeta('phrase');
  @override
  late final GeneratedColumn<String> phrase = GeneratedColumn<String>(
    'phrase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodRefMeta = const VerificationMeta(
    'foodRef',
  );
  @override
  late final GeneratedColumn<String> foodRef = GeneratedColumn<String>(
    'food_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodNameMeta = const VerificationMeta(
    'foodName',
  );
  @override
  late final GeneratedColumn<String> foodName = GeneratedColumn<String>(
    'food_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitLabelMeta = const VerificationMeta(
    'unitLabel',
  );
  @override
  late final GeneratedColumn<String> unitLabel = GeneratedColumn<String>(
    'unit_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timesUsedMeta = const VerificationMeta(
    'timesUsed',
  );
  @override
  late final GeneratedColumn<int> timesUsed = GeneratedColumn<int>(
    'times_used',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    phrase,
    foodRef,
    foodName,
    unitLabel,
    quantity,
    timesUsed,
    updatedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learned_matches';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearnedMatche> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('phrase')) {
      context.handle(
        _phraseMeta,
        phrase.isAcceptableOrUnknown(data['phrase']!, _phraseMeta),
      );
    } else if (isInserting) {
      context.missing(_phraseMeta);
    }
    if (data.containsKey('food_ref')) {
      context.handle(
        _foodRefMeta,
        foodRef.isAcceptableOrUnknown(data['food_ref']!, _foodRefMeta),
      );
    } else if (isInserting) {
      context.missing(_foodRefMeta);
    }
    if (data.containsKey('food_name')) {
      context.handle(
        _foodNameMeta,
        foodName.isAcceptableOrUnknown(data['food_name']!, _foodNameMeta),
      );
    } else if (isInserting) {
      context.missing(_foodNameMeta);
    }
    if (data.containsKey('unit_label')) {
      context.handle(
        _unitLabelMeta,
        unitLabel.isAcceptableOrUnknown(data['unit_label']!, _unitLabelMeta),
      );
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('times_used')) {
      context.handle(
        _timesUsedMeta,
        timesUsed.isAcceptableOrUnknown(data['times_used']!, _timesUsedMeta),
      );
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {phrase};
  @override
  LearnedMatche map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearnedMatche(
      phrase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phrase'],
      )!,
      foodRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_ref'],
      )!,
      foodName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_name'],
      )!,
      unitLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_label'],
      ),
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      ),
      timesUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}times_used'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
    );
  }

  @override
  $LearnedMatchesTable createAlias(String alias) {
    return $LearnedMatchesTable(attachedDatabase, alias);
  }
}

class LearnedMatche extends DataClass implements Insertable<LearnedMatche> {
  final String phrase;
  final String foodRef;
  final String foodName;
  final String? unitLabel;
  final double? quantity;
  final int timesUsed;
  final int updatedAtMs;
  const LearnedMatche({
    required this.phrase,
    required this.foodRef,
    required this.foodName,
    this.unitLabel,
    this.quantity,
    required this.timesUsed,
    required this.updatedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['phrase'] = Variable<String>(phrase);
    map['food_ref'] = Variable<String>(foodRef);
    map['food_name'] = Variable<String>(foodName);
    if (!nullToAbsent || unitLabel != null) {
      map['unit_label'] = Variable<String>(unitLabel);
    }
    if (!nullToAbsent || quantity != null) {
      map['quantity'] = Variable<double>(quantity);
    }
    map['times_used'] = Variable<int>(timesUsed);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    return map;
  }

  LearnedMatchesCompanion toCompanion(bool nullToAbsent) {
    return LearnedMatchesCompanion(
      phrase: Value(phrase),
      foodRef: Value(foodRef),
      foodName: Value(foodName),
      unitLabel: unitLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(unitLabel),
      quantity: quantity == null && nullToAbsent
          ? const Value.absent()
          : Value(quantity),
      timesUsed: Value(timesUsed),
      updatedAtMs: Value(updatedAtMs),
    );
  }

  factory LearnedMatche.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearnedMatche(
      phrase: serializer.fromJson<String>(json['phrase']),
      foodRef: serializer.fromJson<String>(json['foodRef']),
      foodName: serializer.fromJson<String>(json['foodName']),
      unitLabel: serializer.fromJson<String?>(json['unitLabel']),
      quantity: serializer.fromJson<double?>(json['quantity']),
      timesUsed: serializer.fromJson<int>(json['timesUsed']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'phrase': serializer.toJson<String>(phrase),
      'foodRef': serializer.toJson<String>(foodRef),
      'foodName': serializer.toJson<String>(foodName),
      'unitLabel': serializer.toJson<String?>(unitLabel),
      'quantity': serializer.toJson<double?>(quantity),
      'timesUsed': serializer.toJson<int>(timesUsed),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
    };
  }

  LearnedMatche copyWith({
    String? phrase,
    String? foodRef,
    String? foodName,
    Value<String?> unitLabel = const Value.absent(),
    Value<double?> quantity = const Value.absent(),
    int? timesUsed,
    int? updatedAtMs,
  }) => LearnedMatche(
    phrase: phrase ?? this.phrase,
    foodRef: foodRef ?? this.foodRef,
    foodName: foodName ?? this.foodName,
    unitLabel: unitLabel.present ? unitLabel.value : this.unitLabel,
    quantity: quantity.present ? quantity.value : this.quantity,
    timesUsed: timesUsed ?? this.timesUsed,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );
  LearnedMatche copyWithCompanion(LearnedMatchesCompanion data) {
    return LearnedMatche(
      phrase: data.phrase.present ? data.phrase.value : this.phrase,
      foodRef: data.foodRef.present ? data.foodRef.value : this.foodRef,
      foodName: data.foodName.present ? data.foodName.value : this.foodName,
      unitLabel: data.unitLabel.present ? data.unitLabel.value : this.unitLabel,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      timesUsed: data.timesUsed.present ? data.timesUsed.value : this.timesUsed,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearnedMatche(')
          ..write('phrase: $phrase, ')
          ..write('foodRef: $foodRef, ')
          ..write('foodName: $foodName, ')
          ..write('unitLabel: $unitLabel, ')
          ..write('quantity: $quantity, ')
          ..write('timesUsed: $timesUsed, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    phrase,
    foodRef,
    foodName,
    unitLabel,
    quantity,
    timesUsed,
    updatedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearnedMatche &&
          other.phrase == this.phrase &&
          other.foodRef == this.foodRef &&
          other.foodName == this.foodName &&
          other.unitLabel == this.unitLabel &&
          other.quantity == this.quantity &&
          other.timesUsed == this.timesUsed &&
          other.updatedAtMs == this.updatedAtMs);
}

class LearnedMatchesCompanion extends UpdateCompanion<LearnedMatche> {
  final Value<String> phrase;
  final Value<String> foodRef;
  final Value<String> foodName;
  final Value<String?> unitLabel;
  final Value<double?> quantity;
  final Value<int> timesUsed;
  final Value<int> updatedAtMs;
  final Value<int> rowid;
  const LearnedMatchesCompanion({
    this.phrase = const Value.absent(),
    this.foodRef = const Value.absent(),
    this.foodName = const Value.absent(),
    this.unitLabel = const Value.absent(),
    this.quantity = const Value.absent(),
    this.timesUsed = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearnedMatchesCompanion.insert({
    required String phrase,
    required String foodRef,
    required String foodName,
    this.unitLabel = const Value.absent(),
    this.quantity = const Value.absent(),
    this.timesUsed = const Value.absent(),
    required int updatedAtMs,
    this.rowid = const Value.absent(),
  }) : phrase = Value(phrase),
       foodRef = Value(foodRef),
       foodName = Value(foodName),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<LearnedMatche> custom({
    Expression<String>? phrase,
    Expression<String>? foodRef,
    Expression<String>? foodName,
    Expression<String>? unitLabel,
    Expression<double>? quantity,
    Expression<int>? timesUsed,
    Expression<int>? updatedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (phrase != null) 'phrase': phrase,
      if (foodRef != null) 'food_ref': foodRef,
      if (foodName != null) 'food_name': foodName,
      if (unitLabel != null) 'unit_label': unitLabel,
      if (quantity != null) 'quantity': quantity,
      if (timesUsed != null) 'times_used': timesUsed,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearnedMatchesCompanion copyWith({
    Value<String>? phrase,
    Value<String>? foodRef,
    Value<String>? foodName,
    Value<String?>? unitLabel,
    Value<double?>? quantity,
    Value<int>? timesUsed,
    Value<int>? updatedAtMs,
    Value<int>? rowid,
  }) {
    return LearnedMatchesCompanion(
      phrase: phrase ?? this.phrase,
      foodRef: foodRef ?? this.foodRef,
      foodName: foodName ?? this.foodName,
      unitLabel: unitLabel ?? this.unitLabel,
      quantity: quantity ?? this.quantity,
      timesUsed: timesUsed ?? this.timesUsed,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (phrase.present) {
      map['phrase'] = Variable<String>(phrase.value);
    }
    if (foodRef.present) {
      map['food_ref'] = Variable<String>(foodRef.value);
    }
    if (foodName.present) {
      map['food_name'] = Variable<String>(foodName.value);
    }
    if (unitLabel.present) {
      map['unit_label'] = Variable<String>(unitLabel.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (timesUsed.present) {
      map['times_used'] = Variable<int>(timesUsed.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearnedMatchesCompanion(')
          ..write('phrase: $phrase, ')
          ..write('foodRef: $foodRef, ')
          ..write('foodName: $foodName, ')
          ..write('unitLabel: $unitLabel, ')
          ..write('quantity: $quantity, ')
          ..write('timesUsed: $timesUsed, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WeightEntriesTable extends WeightEntries
    with TableInfo<$WeightEntriesTable, WeightEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeightEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _localDateMeta = const VerificationMeta(
    'localDate',
  );
  @override
  late final GeneratedColumn<String> localDate = GeneratedColumn<String>(
    'local_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _measuredAtMsMeta = const VerificationMeta(
    'measuredAtMs',
  );
  @override
  late final GeneratedColumn<int> measuredAtMs = GeneratedColumn<int>(
    'measured_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tzOffsetMinutesMeta = const VerificationMeta(
    'tzOffsetMinutes',
  );
  @override
  late final GeneratedColumn<int> tzOffsetMinutes = GeneratedColumn<int>(
    'tz_offset_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMsMeta = const VerificationMeta(
    'deletedAtMs',
  );
  @override
  late final GeneratedColumn<int> deletedAtMs = GeneratedColumn<int>(
    'deleted_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    localDate,
    measuredAtMs,
    tzOffsetMinutes,
    weightKg,
    source,
    sourceId,
    createdAtMs,
    updatedAtMs,
    deletedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weight_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeightEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('local_date')) {
      context.handle(
        _localDateMeta,
        localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta),
      );
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('measured_at_ms')) {
      context.handle(
        _measuredAtMsMeta,
        measuredAtMs.isAcceptableOrUnknown(
          data['measured_at_ms']!,
          _measuredAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_measuredAtMsMeta);
    }
    if (data.containsKey('tz_offset_minutes')) {
      context.handle(
        _tzOffsetMinutesMeta,
        tzOffsetMinutes.isAcceptableOrUnknown(
          data['tz_offset_minutes']!,
          _tzOffsetMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tzOffsetMinutesMeta);
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    } else if (isInserting) {
      context.missing(_weightKgMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    if (data.containsKey('deleted_at_ms')) {
      context.handle(
        _deletedAtMsMeta,
        deletedAtMs.isAcceptableOrUnknown(
          data['deleted_at_ms']!,
          _deletedAtMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {source, sourceId},
  ];
  @override
  WeightEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeightEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      localDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_date'],
      )!,
      measuredAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}measured_at_ms'],
      )!,
      tzOffsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tz_offset_minutes'],
      )!,
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
      deletedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_ms'],
      ),
    );
  }

  @override
  $WeightEntriesTable createAlias(String alias) {
    return $WeightEntriesTable(attachedDatabase, alias);
  }
}

class WeightEntry extends DataClass implements Insertable<WeightEntry> {
  final int id;
  final String localDate;
  final int measuredAtMs;
  final int tzOffsetMinutes;
  final double weightKg;
  final String source;
  final String? sourceId;
  final int createdAtMs;
  final int updatedAtMs;
  final int? deletedAtMs;
  const WeightEntry({
    required this.id,
    required this.localDate,
    required this.measuredAtMs,
    required this.tzOffsetMinutes,
    required this.weightKg,
    required this.source,
    this.sourceId,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.deletedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['local_date'] = Variable<String>(localDate);
    map['measured_at_ms'] = Variable<int>(measuredAtMs);
    map['tz_offset_minutes'] = Variable<int>(tzOffsetMinutes);
    map['weight_kg'] = Variable<double>(weightKg);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    if (!nullToAbsent || deletedAtMs != null) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs);
    }
    return map;
  }

  WeightEntriesCompanion toCompanion(bool nullToAbsent) {
    return WeightEntriesCompanion(
      id: Value(id),
      localDate: Value(localDate),
      measuredAtMs: Value(measuredAtMs),
      tzOffsetMinutes: Value(tzOffsetMinutes),
      weightKg: Value(weightKg),
      source: Value(source),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      createdAtMs: Value(createdAtMs),
      updatedAtMs: Value(updatedAtMs),
      deletedAtMs: deletedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtMs),
    );
  }

  factory WeightEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeightEntry(
      id: serializer.fromJson<int>(json['id']),
      localDate: serializer.fromJson<String>(json['localDate']),
      measuredAtMs: serializer.fromJson<int>(json['measuredAtMs']),
      tzOffsetMinutes: serializer.fromJson<int>(json['tzOffsetMinutes']),
      weightKg: serializer.fromJson<double>(json['weightKg']),
      source: serializer.fromJson<String>(json['source']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
      deletedAtMs: serializer.fromJson<int?>(json['deletedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'localDate': serializer.toJson<String>(localDate),
      'measuredAtMs': serializer.toJson<int>(measuredAtMs),
      'tzOffsetMinutes': serializer.toJson<int>(tzOffsetMinutes),
      'weightKg': serializer.toJson<double>(weightKg),
      'source': serializer.toJson<String>(source),
      'sourceId': serializer.toJson<String?>(sourceId),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
      'deletedAtMs': serializer.toJson<int?>(deletedAtMs),
    };
  }

  WeightEntry copyWith({
    int? id,
    String? localDate,
    int? measuredAtMs,
    int? tzOffsetMinutes,
    double? weightKg,
    String? source,
    Value<String?> sourceId = const Value.absent(),
    int? createdAtMs,
    int? updatedAtMs,
    Value<int?> deletedAtMs = const Value.absent(),
  }) => WeightEntry(
    id: id ?? this.id,
    localDate: localDate ?? this.localDate,
    measuredAtMs: measuredAtMs ?? this.measuredAtMs,
    tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
    weightKg: weightKg ?? this.weightKg,
    source: source ?? this.source,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    deletedAtMs: deletedAtMs.present ? deletedAtMs.value : this.deletedAtMs,
  );
  WeightEntry copyWithCompanion(WeightEntriesCompanion data) {
    return WeightEntry(
      id: data.id.present ? data.id.value : this.id,
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      measuredAtMs: data.measuredAtMs.present
          ? data.measuredAtMs.value
          : this.measuredAtMs,
      tzOffsetMinutes: data.tzOffsetMinutes.present
          ? data.tzOffsetMinutes.value
          : this.tzOffsetMinutes,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      source: data.source.present ? data.source.value : this.source,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
      deletedAtMs: data.deletedAtMs.present
          ? data.deletedAtMs.value
          : this.deletedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeightEntry(')
          ..write('id: $id, ')
          ..write('localDate: $localDate, ')
          ..write('measuredAtMs: $measuredAtMs, ')
          ..write('tzOffsetMinutes: $tzOffsetMinutes, ')
          ..write('weightKg: $weightKg, ')
          ..write('source: $source, ')
          ..write('sourceId: $sourceId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('deletedAtMs: $deletedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    localDate,
    measuredAtMs,
    tzOffsetMinutes,
    weightKg,
    source,
    sourceId,
    createdAtMs,
    updatedAtMs,
    deletedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeightEntry &&
          other.id == this.id &&
          other.localDate == this.localDate &&
          other.measuredAtMs == this.measuredAtMs &&
          other.tzOffsetMinutes == this.tzOffsetMinutes &&
          other.weightKg == this.weightKg &&
          other.source == this.source &&
          other.sourceId == this.sourceId &&
          other.createdAtMs == this.createdAtMs &&
          other.updatedAtMs == this.updatedAtMs &&
          other.deletedAtMs == this.deletedAtMs);
}

class WeightEntriesCompanion extends UpdateCompanion<WeightEntry> {
  final Value<int> id;
  final Value<String> localDate;
  final Value<int> measuredAtMs;
  final Value<int> tzOffsetMinutes;
  final Value<double> weightKg;
  final Value<String> source;
  final Value<String?> sourceId;
  final Value<int> createdAtMs;
  final Value<int> updatedAtMs;
  final Value<int?> deletedAtMs;
  const WeightEntriesCompanion({
    this.id = const Value.absent(),
    this.localDate = const Value.absent(),
    this.measuredAtMs = const Value.absent(),
    this.tzOffsetMinutes = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.deletedAtMs = const Value.absent(),
  });
  WeightEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String localDate,
    required int measuredAtMs,
    required int tzOffsetMinutes,
    required double weightKg,
    this.source = const Value.absent(),
    this.sourceId = const Value.absent(),
    required int createdAtMs,
    required int updatedAtMs,
    this.deletedAtMs = const Value.absent(),
  }) : localDate = Value(localDate),
       measuredAtMs = Value(measuredAtMs),
       tzOffsetMinutes = Value(tzOffsetMinutes),
       weightKg = Value(weightKg),
       createdAtMs = Value(createdAtMs),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<WeightEntry> custom({
    Expression<int>? id,
    Expression<String>? localDate,
    Expression<int>? measuredAtMs,
    Expression<int>? tzOffsetMinutes,
    Expression<double>? weightKg,
    Expression<String>? source,
    Expression<String>? sourceId,
    Expression<int>? createdAtMs,
    Expression<int>? updatedAtMs,
    Expression<int>? deletedAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (localDate != null) 'local_date': localDate,
      if (measuredAtMs != null) 'measured_at_ms': measuredAtMs,
      if (tzOffsetMinutes != null) 'tz_offset_minutes': tzOffsetMinutes,
      if (weightKg != null) 'weight_kg': weightKg,
      if (source != null) 'source': source,
      if (sourceId != null) 'source_id': sourceId,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (deletedAtMs != null) 'deleted_at_ms': deletedAtMs,
    });
  }

  WeightEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? localDate,
    Value<int>? measuredAtMs,
    Value<int>? tzOffsetMinutes,
    Value<double>? weightKg,
    Value<String>? source,
    Value<String?>? sourceId,
    Value<int>? createdAtMs,
    Value<int>? updatedAtMs,
    Value<int?>? deletedAtMs,
  }) {
    return WeightEntriesCompanion(
      id: id ?? this.id,
      localDate: localDate ?? this.localDate,
      measuredAtMs: measuredAtMs ?? this.measuredAtMs,
      tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
      weightKg: weightKg ?? this.weightKg,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (measuredAtMs.present) {
      map['measured_at_ms'] = Variable<int>(measuredAtMs.value);
    }
    if (tzOffsetMinutes.present) {
      map['tz_offset_minutes'] = Variable<int>(tzOffsetMinutes.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (deletedAtMs.present) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeightEntriesCompanion(')
          ..write('id: $id, ')
          ..write('localDate: $localDate, ')
          ..write('measuredAtMs: $measuredAtMs, ')
          ..write('tzOffsetMinutes: $tzOffsetMinutes, ')
          ..write('weightKg: $weightKg, ')
          ..write('source: $source, ')
          ..write('sourceId: $sourceId, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('deletedAtMs: $deletedAtMs')
          ..write(')'))
        .toString();
  }
}

class $ExercisesTable extends Exercises
    with TableInfo<$ExercisesTable, Exercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _primaryMusclesMeta = const VerificationMeta(
    'primaryMuscles',
  );
  @override
  late final GeneratedColumn<String> primaryMuscles = GeneratedColumn<String>(
    'primary_muscles',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _secondaryMusclesMeta = const VerificationMeta(
    'secondaryMuscles',
  );
  @override
  late final GeneratedColumn<String> secondaryMuscles = GeneratedColumn<String>(
    'secondary_muscles',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _equipmentMeta = const VerificationMeta(
    'equipment',
  );
  @override
  late final GeneratedColumn<String> equipment = GeneratedColumn<String>(
    'equipment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    category,
    primaryMuscles,
    secondaryMuscles,
    equipment,
    archived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<Exercise> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
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
    }
    if (data.containsKey('primary_muscles')) {
      context.handle(
        _primaryMusclesMeta,
        primaryMuscles.isAcceptableOrUnknown(
          data['primary_muscles']!,
          _primaryMusclesMeta,
        ),
      );
    }
    if (data.containsKey('secondary_muscles')) {
      context.handle(
        _secondaryMusclesMeta,
        secondaryMuscles.isAcceptableOrUnknown(
          data['secondary_muscles']!,
          _secondaryMusclesMeta,
        ),
      );
    }
    if (data.containsKey('equipment')) {
      context.handle(
        _equipmentMeta,
        equipment.isAcceptableOrUnknown(data['equipment']!, _equipmentMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Exercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Exercise(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      primaryMuscles: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_muscles'],
      )!,
      secondaryMuscles: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secondary_muscles'],
      )!,
      equipment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equipment'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
    );
  }

  @override
  $ExercisesTable createAlias(String alias) {
    return $ExercisesTable(attachedDatabase, alias);
  }
}

class Exercise extends DataClass implements Insertable<Exercise> {
  final int id;
  final String name;
  final String? category;
  final String primaryMuscles;
  final String secondaryMuscles;
  final String? equipment;
  final bool archived;
  const Exercise({
    required this.id,
    required this.name,
    this.category,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    this.equipment,
    required this.archived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['primary_muscles'] = Variable<String>(primaryMuscles);
    map['secondary_muscles'] = Variable<String>(secondaryMuscles);
    if (!nullToAbsent || equipment != null) {
      map['equipment'] = Variable<String>(equipment);
    }
    map['archived'] = Variable<bool>(archived);
    return map;
  }

  ExercisesCompanion toCompanion(bool nullToAbsent) {
    return ExercisesCompanion(
      id: Value(id),
      name: Value(name),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      primaryMuscles: Value(primaryMuscles),
      secondaryMuscles: Value(secondaryMuscles),
      equipment: equipment == null && nullToAbsent
          ? const Value.absent()
          : Value(equipment),
      archived: Value(archived),
    );
  }

  factory Exercise.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Exercise(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String?>(json['category']),
      primaryMuscles: serializer.fromJson<String>(json['primaryMuscles']),
      secondaryMuscles: serializer.fromJson<String>(json['secondaryMuscles']),
      equipment: serializer.fromJson<String?>(json['equipment']),
      archived: serializer.fromJson<bool>(json['archived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String?>(category),
      'primaryMuscles': serializer.toJson<String>(primaryMuscles),
      'secondaryMuscles': serializer.toJson<String>(secondaryMuscles),
      'equipment': serializer.toJson<String?>(equipment),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  Exercise copyWith({
    int? id,
    String? name,
    Value<String?> category = const Value.absent(),
    String? primaryMuscles,
    String? secondaryMuscles,
    Value<String?> equipment = const Value.absent(),
    bool? archived,
  }) => Exercise(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category.present ? category.value : this.category,
    primaryMuscles: primaryMuscles ?? this.primaryMuscles,
    secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
    equipment: equipment.present ? equipment.value : this.equipment,
    archived: archived ?? this.archived,
  );
  Exercise copyWithCompanion(ExercisesCompanion data) {
    return Exercise(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      primaryMuscles: data.primaryMuscles.present
          ? data.primaryMuscles.value
          : this.primaryMuscles,
      secondaryMuscles: data.secondaryMuscles.present
          ? data.secondaryMuscles.value
          : this.secondaryMuscles,
      equipment: data.equipment.present ? data.equipment.value : this.equipment,
      archived: data.archived.present ? data.archived.value : this.archived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Exercise(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('primaryMuscles: $primaryMuscles, ')
          ..write('secondaryMuscles: $secondaryMuscles, ')
          ..write('equipment: $equipment, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    primaryMuscles,
    secondaryMuscles,
    equipment,
    archived,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Exercise &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.primaryMuscles == this.primaryMuscles &&
          other.secondaryMuscles == this.secondaryMuscles &&
          other.equipment == this.equipment &&
          other.archived == this.archived);
}

class ExercisesCompanion extends UpdateCompanion<Exercise> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> category;
  final Value<String> primaryMuscles;
  final Value<String> secondaryMuscles;
  final Value<String?> equipment;
  final Value<bool> archived;
  const ExercisesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.primaryMuscles = const Value.absent(),
    this.secondaryMuscles = const Value.absent(),
    this.equipment = const Value.absent(),
    this.archived = const Value.absent(),
  });
  ExercisesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.category = const Value.absent(),
    this.primaryMuscles = const Value.absent(),
    this.secondaryMuscles = const Value.absent(),
    this.equipment = const Value.absent(),
    this.archived = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Exercise> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? primaryMuscles,
    Expression<String>? secondaryMuscles,
    Expression<String>? equipment,
    Expression<bool>? archived,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (primaryMuscles != null) 'primary_muscles': primaryMuscles,
      if (secondaryMuscles != null) 'secondary_muscles': secondaryMuscles,
      if (equipment != null) 'equipment': equipment,
      if (archived != null) 'archived': archived,
    });
  }

  ExercisesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? category,
    Value<String>? primaryMuscles,
    Value<String>? secondaryMuscles,
    Value<String?>? equipment,
    Value<bool>? archived,
  }) {
    return ExercisesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      primaryMuscles: primaryMuscles ?? this.primaryMuscles,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      equipment: equipment ?? this.equipment,
      archived: archived ?? this.archived,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (primaryMuscles.present) {
      map['primary_muscles'] = Variable<String>(primaryMuscles.value);
    }
    if (secondaryMuscles.present) {
      map['secondary_muscles'] = Variable<String>(secondaryMuscles.value);
    }
    if (equipment.present) {
      map['equipment'] = Variable<String>(equipment.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('primaryMuscles: $primaryMuscles, ')
          ..write('secondaryMuscles: $secondaryMuscles, ')
          ..write('equipment: $equipment, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }
}

class $RoutinesTable extends Routines with TableInfo<$RoutinesTable, Routine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    position,
    archived,
    createdAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routines';
  @override
  VerificationContext validateIntegrity(
    Insertable<Routine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Routine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Routine(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
    );
  }

  @override
  $RoutinesTable createAlias(String alias) {
    return $RoutinesTable(attachedDatabase, alias);
  }
}

class Routine extends DataClass implements Insertable<Routine> {
  final int id;
  final String name;
  final int position;
  final bool archived;
  final int createdAtMs;
  const Routine({
    required this.id,
    required this.name,
    required this.position,
    required this.archived,
    required this.createdAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['position'] = Variable<int>(position);
    map['archived'] = Variable<bool>(archived);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  RoutinesCompanion toCompanion(bool nullToAbsent) {
    return RoutinesCompanion(
      id: Value(id),
      name: Value(name),
      position: Value(position),
      archived: Value(archived),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory Routine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Routine(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      position: serializer.fromJson<int>(json['position']),
      archived: serializer.fromJson<bool>(json['archived']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'position': serializer.toJson<int>(position),
      'archived': serializer.toJson<bool>(archived),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  Routine copyWith({
    int? id,
    String? name,
    int? position,
    bool? archived,
    int? createdAtMs,
  }) => Routine(
    id: id ?? this.id,
    name: name ?? this.name,
    position: position ?? this.position,
    archived: archived ?? this.archived,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );
  Routine copyWithCompanion(RoutinesCompanion data) {
    return Routine(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      position: data.position.present ? data.position.value : this.position,
      archived: data.archived.present ? data.archived.value : this.archived,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Routine(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('archived: $archived, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, position, archived, createdAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Routine &&
          other.id == this.id &&
          other.name == this.name &&
          other.position == this.position &&
          other.archived == this.archived &&
          other.createdAtMs == this.createdAtMs);
}

class RoutinesCompanion extends UpdateCompanion<Routine> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> position;
  final Value<bool> archived;
  final Value<int> createdAtMs;
  const RoutinesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.position = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAtMs = const Value.absent(),
  });
  RoutinesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int position,
    this.archived = const Value.absent(),
    required int createdAtMs,
  }) : name = Value(name),
       position = Value(position),
       createdAtMs = Value(createdAtMs);
  static Insertable<Routine> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? position,
    Expression<bool>? archived,
    Expression<int>? createdAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (position != null) 'position': position,
      if (archived != null) 'archived': archived,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
    });
  }

  RoutinesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? position,
    Value<bool>? archived,
    Value<int>? createdAtMs,
  }) {
    return RoutinesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      archived: archived ?? this.archived,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutinesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('archived: $archived, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }
}

class $RoutineExercisesTable extends RoutineExercises
    with TableInfo<$RoutineExercisesTable, RoutineExercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutineExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _routineIdMeta = const VerificationMeta(
    'routineId',
  );
  @override
  late final GeneratedColumn<int> routineId = GeneratedColumn<int>(
    'routine_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES routines (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseRefMeta = const VerificationMeta(
    'exerciseRef',
  );
  @override
  late final GeneratedColumn<String> exerciseRef = GeneratedColumn<String>(
    'exercise_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseNameMeta = const VerificationMeta(
    'exerciseName',
  );
  @override
  late final GeneratedColumn<String> exerciseName = GeneratedColumn<String>(
    'exercise_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetSetsMeta = const VerificationMeta(
    'targetSets',
  );
  @override
  late final GeneratedColumn<int> targetSets = GeneratedColumn<int>(
    'target_sets',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _restSecondsMeta = const VerificationMeta(
    'restSeconds',
  );
  @override
  late final GeneratedColumn<int> restSeconds = GeneratedColumn<int>(
    'rest_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    routineId,
    position,
    exerciseRef,
    exerciseName,
    targetSets,
    restSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routine_exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoutineExercise> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('routine_id')) {
      context.handle(
        _routineIdMeta,
        routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_routineIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('exercise_ref')) {
      context.handle(
        _exerciseRefMeta,
        exerciseRef.isAcceptableOrUnknown(
          data['exercise_ref']!,
          _exerciseRefMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exerciseRefMeta);
    }
    if (data.containsKey('exercise_name')) {
      context.handle(
        _exerciseNameMeta,
        exerciseName.isAcceptableOrUnknown(
          data['exercise_name']!,
          _exerciseNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exerciseNameMeta);
    }
    if (data.containsKey('target_sets')) {
      context.handle(
        _targetSetsMeta,
        targetSets.isAcceptableOrUnknown(data['target_sets']!, _targetSetsMeta),
      );
    }
    if (data.containsKey('rest_seconds')) {
      context.handle(
        _restSecondsMeta,
        restSeconds.isAcceptableOrUnknown(
          data['rest_seconds']!,
          _restSecondsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoutineExercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutineExercise(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      routineId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}routine_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      exerciseRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_ref'],
      )!,
      exerciseName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_name'],
      )!,
      targetSets: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_sets'],
      ),
      restSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_seconds'],
      ),
    );
  }

  @override
  $RoutineExercisesTable createAlias(String alias) {
    return $RoutineExercisesTable(attachedDatabase, alias);
  }
}

class RoutineExercise extends DataClass implements Insertable<RoutineExercise> {
  final int id;
  final int routineId;
  final int position;
  final String exerciseRef;
  final String exerciseName;
  final int? targetSets;
  final int? restSeconds;
  const RoutineExercise({
    required this.id,
    required this.routineId,
    required this.position,
    required this.exerciseRef,
    required this.exerciseName,
    this.targetSets,
    this.restSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['routine_id'] = Variable<int>(routineId);
    map['position'] = Variable<int>(position);
    map['exercise_ref'] = Variable<String>(exerciseRef);
    map['exercise_name'] = Variable<String>(exerciseName);
    if (!nullToAbsent || targetSets != null) {
      map['target_sets'] = Variable<int>(targetSets);
    }
    if (!nullToAbsent || restSeconds != null) {
      map['rest_seconds'] = Variable<int>(restSeconds);
    }
    return map;
  }

  RoutineExercisesCompanion toCompanion(bool nullToAbsent) {
    return RoutineExercisesCompanion(
      id: Value(id),
      routineId: Value(routineId),
      position: Value(position),
      exerciseRef: Value(exerciseRef),
      exerciseName: Value(exerciseName),
      targetSets: targetSets == null && nullToAbsent
          ? const Value.absent()
          : Value(targetSets),
      restSeconds: restSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(restSeconds),
    );
  }

  factory RoutineExercise.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutineExercise(
      id: serializer.fromJson<int>(json['id']),
      routineId: serializer.fromJson<int>(json['routineId']),
      position: serializer.fromJson<int>(json['position']),
      exerciseRef: serializer.fromJson<String>(json['exerciseRef']),
      exerciseName: serializer.fromJson<String>(json['exerciseName']),
      targetSets: serializer.fromJson<int?>(json['targetSets']),
      restSeconds: serializer.fromJson<int?>(json['restSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'routineId': serializer.toJson<int>(routineId),
      'position': serializer.toJson<int>(position),
      'exerciseRef': serializer.toJson<String>(exerciseRef),
      'exerciseName': serializer.toJson<String>(exerciseName),
      'targetSets': serializer.toJson<int?>(targetSets),
      'restSeconds': serializer.toJson<int?>(restSeconds),
    };
  }

  RoutineExercise copyWith({
    int? id,
    int? routineId,
    int? position,
    String? exerciseRef,
    String? exerciseName,
    Value<int?> targetSets = const Value.absent(),
    Value<int?> restSeconds = const Value.absent(),
  }) => RoutineExercise(
    id: id ?? this.id,
    routineId: routineId ?? this.routineId,
    position: position ?? this.position,
    exerciseRef: exerciseRef ?? this.exerciseRef,
    exerciseName: exerciseName ?? this.exerciseName,
    targetSets: targetSets.present ? targetSets.value : this.targetSets,
    restSeconds: restSeconds.present ? restSeconds.value : this.restSeconds,
  );
  RoutineExercise copyWithCompanion(RoutineExercisesCompanion data) {
    return RoutineExercise(
      id: data.id.present ? data.id.value : this.id,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      position: data.position.present ? data.position.value : this.position,
      exerciseRef: data.exerciseRef.present
          ? data.exerciseRef.value
          : this.exerciseRef,
      exerciseName: data.exerciseName.present
          ? data.exerciseName.value
          : this.exerciseName,
      targetSets: data.targetSets.present
          ? data.targetSets.value
          : this.targetSets,
      restSeconds: data.restSeconds.present
          ? data.restSeconds.value
          : this.restSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutineExercise(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('position: $position, ')
          ..write('exerciseRef: $exerciseRef, ')
          ..write('exerciseName: $exerciseName, ')
          ..write('targetSets: $targetSets, ')
          ..write('restSeconds: $restSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    routineId,
    position,
    exerciseRef,
    exerciseName,
    targetSets,
    restSeconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutineExercise &&
          other.id == this.id &&
          other.routineId == this.routineId &&
          other.position == this.position &&
          other.exerciseRef == this.exerciseRef &&
          other.exerciseName == this.exerciseName &&
          other.targetSets == this.targetSets &&
          other.restSeconds == this.restSeconds);
}

class RoutineExercisesCompanion extends UpdateCompanion<RoutineExercise> {
  final Value<int> id;
  final Value<int> routineId;
  final Value<int> position;
  final Value<String> exerciseRef;
  final Value<String> exerciseName;
  final Value<int?> targetSets;
  final Value<int?> restSeconds;
  const RoutineExercisesCompanion({
    this.id = const Value.absent(),
    this.routineId = const Value.absent(),
    this.position = const Value.absent(),
    this.exerciseRef = const Value.absent(),
    this.exerciseName = const Value.absent(),
    this.targetSets = const Value.absent(),
    this.restSeconds = const Value.absent(),
  });
  RoutineExercisesCompanion.insert({
    this.id = const Value.absent(),
    required int routineId,
    required int position,
    required String exerciseRef,
    required String exerciseName,
    this.targetSets = const Value.absent(),
    this.restSeconds = const Value.absent(),
  }) : routineId = Value(routineId),
       position = Value(position),
       exerciseRef = Value(exerciseRef),
       exerciseName = Value(exerciseName);
  static Insertable<RoutineExercise> custom({
    Expression<int>? id,
    Expression<int>? routineId,
    Expression<int>? position,
    Expression<String>? exerciseRef,
    Expression<String>? exerciseName,
    Expression<int>? targetSets,
    Expression<int>? restSeconds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineId != null) 'routine_id': routineId,
      if (position != null) 'position': position,
      if (exerciseRef != null) 'exercise_ref': exerciseRef,
      if (exerciseName != null) 'exercise_name': exerciseName,
      if (targetSets != null) 'target_sets': targetSets,
      if (restSeconds != null) 'rest_seconds': restSeconds,
    });
  }

  RoutineExercisesCompanion copyWith({
    Value<int>? id,
    Value<int>? routineId,
    Value<int>? position,
    Value<String>? exerciseRef,
    Value<String>? exerciseName,
    Value<int?>? targetSets,
    Value<int?>? restSeconds,
  }) {
    return RoutineExercisesCompanion(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      position: position ?? this.position,
      exerciseRef: exerciseRef ?? this.exerciseRef,
      exerciseName: exerciseName ?? this.exerciseName,
      targetSets: targetSets ?? this.targetSets,
      restSeconds: restSeconds ?? this.restSeconds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<int>(routineId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (exerciseRef.present) {
      map['exercise_ref'] = Variable<String>(exerciseRef.value);
    }
    if (exerciseName.present) {
      map['exercise_name'] = Variable<String>(exerciseName.value);
    }
    if (targetSets.present) {
      map['target_sets'] = Variable<int>(targetSets.value);
    }
    if (restSeconds.present) {
      map['rest_seconds'] = Variable<int>(restSeconds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutineExercisesCompanion(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('position: $position, ')
          ..write('exerciseRef: $exerciseRef, ')
          ..write('exerciseName: $exerciseName, ')
          ..write('targetSets: $targetSets, ')
          ..write('restSeconds: $restSeconds')
          ..write(')'))
        .toString();
  }
}

class $WorkoutsTable extends Workouts with TableInfo<$WorkoutsTable, Workout> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _localDateMeta = const VerificationMeta(
    'localDate',
  );
  @override
  late final GeneratedColumn<String> localDate = GeneratedColumn<String>(
    'local_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMsMeta = const VerificationMeta(
    'startedAtMs',
  );
  @override
  late final GeneratedColumn<int> startedAtMs = GeneratedColumn<int>(
    'started_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMsMeta = const VerificationMeta(
    'endedAtMs',
  );
  @override
  late final GeneratedColumn<int> endedAtMs = GeneratedColumn<int>(
    'ended_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tzOffsetMinutesMeta = const VerificationMeta(
    'tzOffsetMinutes',
  );
  @override
  late final GeneratedColumn<int> tzOffsetMinutes = GeneratedColumn<int>(
    'tz_offset_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routineIdMeta = const VerificationMeta(
    'routineId',
  );
  @override
  late final GeneratedColumn<int> routineId = GeneratedColumn<int>(
    'routine_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES routines (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _kcalEstimatedMeta = const VerificationMeta(
    'kcalEstimated',
  );
  @override
  late final GeneratedColumn<double> kcalEstimated = GeneratedColumn<double>(
    'kcal_estimated',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kcalOverrideMeta = const VerificationMeta(
    'kcalOverride',
  );
  @override
  late final GeneratedColumn<double> kcalOverride = GeneratedColumn<double>(
    'kcal_override',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    localDate,
    startedAtMs,
    endedAtMs,
    tzOffsetMinutes,
    routineId,
    kcalEstimated,
    kcalOverride,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workouts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Workout> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('local_date')) {
      context.handle(
        _localDateMeta,
        localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta),
      );
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('started_at_ms')) {
      context.handle(
        _startedAtMsMeta,
        startedAtMs.isAcceptableOrUnknown(
          data['started_at_ms']!,
          _startedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtMsMeta);
    }
    if (data.containsKey('ended_at_ms')) {
      context.handle(
        _endedAtMsMeta,
        endedAtMs.isAcceptableOrUnknown(data['ended_at_ms']!, _endedAtMsMeta),
      );
    }
    if (data.containsKey('tz_offset_minutes')) {
      context.handle(
        _tzOffsetMinutesMeta,
        tzOffsetMinutes.isAcceptableOrUnknown(
          data['tz_offset_minutes']!,
          _tzOffsetMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tzOffsetMinutesMeta);
    }
    if (data.containsKey('routine_id')) {
      context.handle(
        _routineIdMeta,
        routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta),
      );
    }
    if (data.containsKey('kcal_estimated')) {
      context.handle(
        _kcalEstimatedMeta,
        kcalEstimated.isAcceptableOrUnknown(
          data['kcal_estimated']!,
          _kcalEstimatedMeta,
        ),
      );
    }
    if (data.containsKey('kcal_override')) {
      context.handle(
        _kcalOverrideMeta,
        kcalOverride.isAcceptableOrUnknown(
          data['kcal_override']!,
          _kcalOverrideMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Workout map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Workout(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      localDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_date'],
      )!,
      startedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_ms'],
      )!,
      endedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at_ms'],
      ),
      tzOffsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tz_offset_minutes'],
      )!,
      routineId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}routine_id'],
      ),
      kcalEstimated: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal_estimated'],
      ),
      kcalOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal_override'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $WorkoutsTable createAlias(String alias) {
    return $WorkoutsTable(attachedDatabase, alias);
  }
}

class Workout extends DataClass implements Insertable<Workout> {
  final int id;
  final String localDate;
  final int startedAtMs;
  final int? endedAtMs;
  final int tzOffsetMinutes;
  final int? routineId;
  final double? kcalEstimated;
  final double? kcalOverride;
  final String? note;
  const Workout({
    required this.id,
    required this.localDate,
    required this.startedAtMs,
    this.endedAtMs,
    required this.tzOffsetMinutes,
    this.routineId,
    this.kcalEstimated,
    this.kcalOverride,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['local_date'] = Variable<String>(localDate);
    map['started_at_ms'] = Variable<int>(startedAtMs);
    if (!nullToAbsent || endedAtMs != null) {
      map['ended_at_ms'] = Variable<int>(endedAtMs);
    }
    map['tz_offset_minutes'] = Variable<int>(tzOffsetMinutes);
    if (!nullToAbsent || routineId != null) {
      map['routine_id'] = Variable<int>(routineId);
    }
    if (!nullToAbsent || kcalEstimated != null) {
      map['kcal_estimated'] = Variable<double>(kcalEstimated);
    }
    if (!nullToAbsent || kcalOverride != null) {
      map['kcal_override'] = Variable<double>(kcalOverride);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  WorkoutsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutsCompanion(
      id: Value(id),
      localDate: Value(localDate),
      startedAtMs: Value(startedAtMs),
      endedAtMs: endedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAtMs),
      tzOffsetMinutes: Value(tzOffsetMinutes),
      routineId: routineId == null && nullToAbsent
          ? const Value.absent()
          : Value(routineId),
      kcalEstimated: kcalEstimated == null && nullToAbsent
          ? const Value.absent()
          : Value(kcalEstimated),
      kcalOverride: kcalOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(kcalOverride),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory Workout.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Workout(
      id: serializer.fromJson<int>(json['id']),
      localDate: serializer.fromJson<String>(json['localDate']),
      startedAtMs: serializer.fromJson<int>(json['startedAtMs']),
      endedAtMs: serializer.fromJson<int?>(json['endedAtMs']),
      tzOffsetMinutes: serializer.fromJson<int>(json['tzOffsetMinutes']),
      routineId: serializer.fromJson<int?>(json['routineId']),
      kcalEstimated: serializer.fromJson<double?>(json['kcalEstimated']),
      kcalOverride: serializer.fromJson<double?>(json['kcalOverride']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'localDate': serializer.toJson<String>(localDate),
      'startedAtMs': serializer.toJson<int>(startedAtMs),
      'endedAtMs': serializer.toJson<int?>(endedAtMs),
      'tzOffsetMinutes': serializer.toJson<int>(tzOffsetMinutes),
      'routineId': serializer.toJson<int?>(routineId),
      'kcalEstimated': serializer.toJson<double?>(kcalEstimated),
      'kcalOverride': serializer.toJson<double?>(kcalOverride),
      'note': serializer.toJson<String?>(note),
    };
  }

  Workout copyWith({
    int? id,
    String? localDate,
    int? startedAtMs,
    Value<int?> endedAtMs = const Value.absent(),
    int? tzOffsetMinutes,
    Value<int?> routineId = const Value.absent(),
    Value<double?> kcalEstimated = const Value.absent(),
    Value<double?> kcalOverride = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => Workout(
    id: id ?? this.id,
    localDate: localDate ?? this.localDate,
    startedAtMs: startedAtMs ?? this.startedAtMs,
    endedAtMs: endedAtMs.present ? endedAtMs.value : this.endedAtMs,
    tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
    routineId: routineId.present ? routineId.value : this.routineId,
    kcalEstimated: kcalEstimated.present
        ? kcalEstimated.value
        : this.kcalEstimated,
    kcalOverride: kcalOverride.present ? kcalOverride.value : this.kcalOverride,
    note: note.present ? note.value : this.note,
  );
  Workout copyWithCompanion(WorkoutsCompanion data) {
    return Workout(
      id: data.id.present ? data.id.value : this.id,
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      startedAtMs: data.startedAtMs.present
          ? data.startedAtMs.value
          : this.startedAtMs,
      endedAtMs: data.endedAtMs.present ? data.endedAtMs.value : this.endedAtMs,
      tzOffsetMinutes: data.tzOffsetMinutes.present
          ? data.tzOffsetMinutes.value
          : this.tzOffsetMinutes,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      kcalEstimated: data.kcalEstimated.present
          ? data.kcalEstimated.value
          : this.kcalEstimated,
      kcalOverride: data.kcalOverride.present
          ? data.kcalOverride.value
          : this.kcalOverride,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Workout(')
          ..write('id: $id, ')
          ..write('localDate: $localDate, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('endedAtMs: $endedAtMs, ')
          ..write('tzOffsetMinutes: $tzOffsetMinutes, ')
          ..write('routineId: $routineId, ')
          ..write('kcalEstimated: $kcalEstimated, ')
          ..write('kcalOverride: $kcalOverride, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    localDate,
    startedAtMs,
    endedAtMs,
    tzOffsetMinutes,
    routineId,
    kcalEstimated,
    kcalOverride,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Workout &&
          other.id == this.id &&
          other.localDate == this.localDate &&
          other.startedAtMs == this.startedAtMs &&
          other.endedAtMs == this.endedAtMs &&
          other.tzOffsetMinutes == this.tzOffsetMinutes &&
          other.routineId == this.routineId &&
          other.kcalEstimated == this.kcalEstimated &&
          other.kcalOverride == this.kcalOverride &&
          other.note == this.note);
}

class WorkoutsCompanion extends UpdateCompanion<Workout> {
  final Value<int> id;
  final Value<String> localDate;
  final Value<int> startedAtMs;
  final Value<int?> endedAtMs;
  final Value<int> tzOffsetMinutes;
  final Value<int?> routineId;
  final Value<double?> kcalEstimated;
  final Value<double?> kcalOverride;
  final Value<String?> note;
  const WorkoutsCompanion({
    this.id = const Value.absent(),
    this.localDate = const Value.absent(),
    this.startedAtMs = const Value.absent(),
    this.endedAtMs = const Value.absent(),
    this.tzOffsetMinutes = const Value.absent(),
    this.routineId = const Value.absent(),
    this.kcalEstimated = const Value.absent(),
    this.kcalOverride = const Value.absent(),
    this.note = const Value.absent(),
  });
  WorkoutsCompanion.insert({
    this.id = const Value.absent(),
    required String localDate,
    required int startedAtMs,
    this.endedAtMs = const Value.absent(),
    required int tzOffsetMinutes,
    this.routineId = const Value.absent(),
    this.kcalEstimated = const Value.absent(),
    this.kcalOverride = const Value.absent(),
    this.note = const Value.absent(),
  }) : localDate = Value(localDate),
       startedAtMs = Value(startedAtMs),
       tzOffsetMinutes = Value(tzOffsetMinutes);
  static Insertable<Workout> custom({
    Expression<int>? id,
    Expression<String>? localDate,
    Expression<int>? startedAtMs,
    Expression<int>? endedAtMs,
    Expression<int>? tzOffsetMinutes,
    Expression<int>? routineId,
    Expression<double>? kcalEstimated,
    Expression<double>? kcalOverride,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (localDate != null) 'local_date': localDate,
      if (startedAtMs != null) 'started_at_ms': startedAtMs,
      if (endedAtMs != null) 'ended_at_ms': endedAtMs,
      if (tzOffsetMinutes != null) 'tz_offset_minutes': tzOffsetMinutes,
      if (routineId != null) 'routine_id': routineId,
      if (kcalEstimated != null) 'kcal_estimated': kcalEstimated,
      if (kcalOverride != null) 'kcal_override': kcalOverride,
      if (note != null) 'note': note,
    });
  }

  WorkoutsCompanion copyWith({
    Value<int>? id,
    Value<String>? localDate,
    Value<int>? startedAtMs,
    Value<int?>? endedAtMs,
    Value<int>? tzOffsetMinutes,
    Value<int?>? routineId,
    Value<double?>? kcalEstimated,
    Value<double?>? kcalOverride,
    Value<String?>? note,
  }) {
    return WorkoutsCompanion(
      id: id ?? this.id,
      localDate: localDate ?? this.localDate,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      endedAtMs: endedAtMs ?? this.endedAtMs,
      tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
      routineId: routineId ?? this.routineId,
      kcalEstimated: kcalEstimated ?? this.kcalEstimated,
      kcalOverride: kcalOverride ?? this.kcalOverride,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (startedAtMs.present) {
      map['started_at_ms'] = Variable<int>(startedAtMs.value);
    }
    if (endedAtMs.present) {
      map['ended_at_ms'] = Variable<int>(endedAtMs.value);
    }
    if (tzOffsetMinutes.present) {
      map['tz_offset_minutes'] = Variable<int>(tzOffsetMinutes.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<int>(routineId.value);
    }
    if (kcalEstimated.present) {
      map['kcal_estimated'] = Variable<double>(kcalEstimated.value);
    }
    if (kcalOverride.present) {
      map['kcal_override'] = Variable<double>(kcalOverride.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutsCompanion(')
          ..write('id: $id, ')
          ..write('localDate: $localDate, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('endedAtMs: $endedAtMs, ')
          ..write('tzOffsetMinutes: $tzOffsetMinutes, ')
          ..write('routineId: $routineId, ')
          ..write('kcalEstimated: $kcalEstimated, ')
          ..write('kcalOverride: $kcalOverride, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSetsTable extends WorkoutSets
    with TableInfo<$WorkoutSetsTable, WorkoutSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _workoutIdMeta = const VerificationMeta(
    'workoutId',
  );
  @override
  late final GeneratedColumn<int> workoutId = GeneratedColumn<int>(
    'workout_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workouts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseRefMeta = const VerificationMeta(
    'exerciseRef',
  );
  @override
  late final GeneratedColumn<String> exerciseRef = GeneratedColumn<String>(
    'exercise_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseNameMeta = const VerificationMeta(
    'exerciseName',
  );
  @override
  late final GeneratedColumn<String> exerciseName = GeneratedColumn<String>(
    'exercise_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMsMeta = const VerificationMeta(
    'completedAtMs',
  );
  @override
  late final GeneratedColumn<int> completedAtMs = GeneratedColumn<int>(
    'completed_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workoutId,
    position,
    exerciseRef,
    exerciseName,
    weightKg,
    reps,
    completedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutSet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('workout_id')) {
      context.handle(
        _workoutIdMeta,
        workoutId.isAcceptableOrUnknown(data['workout_id']!, _workoutIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workoutIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('exercise_ref')) {
      context.handle(
        _exerciseRefMeta,
        exerciseRef.isAcceptableOrUnknown(
          data['exercise_ref']!,
          _exerciseRefMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exerciseRefMeta);
    }
    if (data.containsKey('exercise_name')) {
      context.handle(
        _exerciseNameMeta,
        exerciseName.isAcceptableOrUnknown(
          data['exercise_name']!,
          _exerciseNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exerciseNameMeta);
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('completed_at_ms')) {
      context.handle(
        _completedAtMsMeta,
        completedAtMs.isAcceptableOrUnknown(
          data['completed_at_ms']!,
          _completedAtMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      workoutId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}workout_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      exerciseRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_ref'],
      )!,
      exerciseName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_name'],
      )!,
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      ),
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      ),
      completedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at_ms'],
      ),
    );
  }

  @override
  $WorkoutSetsTable createAlias(String alias) {
    return $WorkoutSetsTable(attachedDatabase, alias);
  }
}

class WorkoutSet extends DataClass implements Insertable<WorkoutSet> {
  final int id;
  final int workoutId;
  final int position;
  final String exerciseRef;
  final String exerciseName;
  final double? weightKg;
  final int? reps;
  final int? completedAtMs;
  const WorkoutSet({
    required this.id,
    required this.workoutId,
    required this.position,
    required this.exerciseRef,
    required this.exerciseName,
    this.weightKg,
    this.reps,
    this.completedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['workout_id'] = Variable<int>(workoutId);
    map['position'] = Variable<int>(position);
    map['exercise_ref'] = Variable<String>(exerciseRef);
    map['exercise_name'] = Variable<String>(exerciseName);
    if (!nullToAbsent || weightKg != null) {
      map['weight_kg'] = Variable<double>(weightKg);
    }
    if (!nullToAbsent || reps != null) {
      map['reps'] = Variable<int>(reps);
    }
    if (!nullToAbsent || completedAtMs != null) {
      map['completed_at_ms'] = Variable<int>(completedAtMs);
    }
    return map;
  }

  WorkoutSetsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSetsCompanion(
      id: Value(id),
      workoutId: Value(workoutId),
      position: Value(position),
      exerciseRef: Value(exerciseRef),
      exerciseName: Value(exerciseName),
      weightKg: weightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(weightKg),
      reps: reps == null && nullToAbsent ? const Value.absent() : Value(reps),
      completedAtMs: completedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAtMs),
    );
  }

  factory WorkoutSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSet(
      id: serializer.fromJson<int>(json['id']),
      workoutId: serializer.fromJson<int>(json['workoutId']),
      position: serializer.fromJson<int>(json['position']),
      exerciseRef: serializer.fromJson<String>(json['exerciseRef']),
      exerciseName: serializer.fromJson<String>(json['exerciseName']),
      weightKg: serializer.fromJson<double?>(json['weightKg']),
      reps: serializer.fromJson<int?>(json['reps']),
      completedAtMs: serializer.fromJson<int?>(json['completedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'workoutId': serializer.toJson<int>(workoutId),
      'position': serializer.toJson<int>(position),
      'exerciseRef': serializer.toJson<String>(exerciseRef),
      'exerciseName': serializer.toJson<String>(exerciseName),
      'weightKg': serializer.toJson<double?>(weightKg),
      'reps': serializer.toJson<int?>(reps),
      'completedAtMs': serializer.toJson<int?>(completedAtMs),
    };
  }

  WorkoutSet copyWith({
    int? id,
    int? workoutId,
    int? position,
    String? exerciseRef,
    String? exerciseName,
    Value<double?> weightKg = const Value.absent(),
    Value<int?> reps = const Value.absent(),
    Value<int?> completedAtMs = const Value.absent(),
  }) => WorkoutSet(
    id: id ?? this.id,
    workoutId: workoutId ?? this.workoutId,
    position: position ?? this.position,
    exerciseRef: exerciseRef ?? this.exerciseRef,
    exerciseName: exerciseName ?? this.exerciseName,
    weightKg: weightKg.present ? weightKg.value : this.weightKg,
    reps: reps.present ? reps.value : this.reps,
    completedAtMs: completedAtMs.present
        ? completedAtMs.value
        : this.completedAtMs,
  );
  WorkoutSet copyWithCompanion(WorkoutSetsCompanion data) {
    return WorkoutSet(
      id: data.id.present ? data.id.value : this.id,
      workoutId: data.workoutId.present ? data.workoutId.value : this.workoutId,
      position: data.position.present ? data.position.value : this.position,
      exerciseRef: data.exerciseRef.present
          ? data.exerciseRef.value
          : this.exerciseRef,
      exerciseName: data.exerciseName.present
          ? data.exerciseName.value
          : this.exerciseName,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      reps: data.reps.present ? data.reps.value : this.reps,
      completedAtMs: data.completedAtMs.present
          ? data.completedAtMs.value
          : this.completedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSet(')
          ..write('id: $id, ')
          ..write('workoutId: $workoutId, ')
          ..write('position: $position, ')
          ..write('exerciseRef: $exerciseRef, ')
          ..write('exerciseName: $exerciseName, ')
          ..write('weightKg: $weightKg, ')
          ..write('reps: $reps, ')
          ..write('completedAtMs: $completedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workoutId,
    position,
    exerciseRef,
    exerciseName,
    weightKg,
    reps,
    completedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSet &&
          other.id == this.id &&
          other.workoutId == this.workoutId &&
          other.position == this.position &&
          other.exerciseRef == this.exerciseRef &&
          other.exerciseName == this.exerciseName &&
          other.weightKg == this.weightKg &&
          other.reps == this.reps &&
          other.completedAtMs == this.completedAtMs);
}

class WorkoutSetsCompanion extends UpdateCompanion<WorkoutSet> {
  final Value<int> id;
  final Value<int> workoutId;
  final Value<int> position;
  final Value<String> exerciseRef;
  final Value<String> exerciseName;
  final Value<double?> weightKg;
  final Value<int?> reps;
  final Value<int?> completedAtMs;
  const WorkoutSetsCompanion({
    this.id = const Value.absent(),
    this.workoutId = const Value.absent(),
    this.position = const Value.absent(),
    this.exerciseRef = const Value.absent(),
    this.exerciseName = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.reps = const Value.absent(),
    this.completedAtMs = const Value.absent(),
  });
  WorkoutSetsCompanion.insert({
    this.id = const Value.absent(),
    required int workoutId,
    required int position,
    required String exerciseRef,
    required String exerciseName,
    this.weightKg = const Value.absent(),
    this.reps = const Value.absent(),
    this.completedAtMs = const Value.absent(),
  }) : workoutId = Value(workoutId),
       position = Value(position),
       exerciseRef = Value(exerciseRef),
       exerciseName = Value(exerciseName);
  static Insertable<WorkoutSet> custom({
    Expression<int>? id,
    Expression<int>? workoutId,
    Expression<int>? position,
    Expression<String>? exerciseRef,
    Expression<String>? exerciseName,
    Expression<double>? weightKg,
    Expression<int>? reps,
    Expression<int>? completedAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workoutId != null) 'workout_id': workoutId,
      if (position != null) 'position': position,
      if (exerciseRef != null) 'exercise_ref': exerciseRef,
      if (exerciseName != null) 'exercise_name': exerciseName,
      if (weightKg != null) 'weight_kg': weightKg,
      if (reps != null) 'reps': reps,
      if (completedAtMs != null) 'completed_at_ms': completedAtMs,
    });
  }

  WorkoutSetsCompanion copyWith({
    Value<int>? id,
    Value<int>? workoutId,
    Value<int>? position,
    Value<String>? exerciseRef,
    Value<String>? exerciseName,
    Value<double?>? weightKg,
    Value<int?>? reps,
    Value<int?>? completedAtMs,
  }) {
    return WorkoutSetsCompanion(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      position: position ?? this.position,
      exerciseRef: exerciseRef ?? this.exerciseRef,
      exerciseName: exerciseName ?? this.exerciseName,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      completedAtMs: completedAtMs ?? this.completedAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (workoutId.present) {
      map['workout_id'] = Variable<int>(workoutId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (exerciseRef.present) {
      map['exercise_ref'] = Variable<String>(exerciseRef.value);
    }
    if (exerciseName.present) {
      map['exercise_name'] = Variable<String>(exerciseName.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (completedAtMs.present) {
      map['completed_at_ms'] = Variable<int>(completedAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSetsCompanion(')
          ..write('id: $id, ')
          ..write('workoutId: $workoutId, ')
          ..write('position: $position, ')
          ..write('exerciseRef: $exerciseRef, ')
          ..write('exerciseName: $exerciseName, ')
          ..write('weightKg: $weightKg, ')
          ..write('reps: $reps, ')
          ..write('completedAtMs: $completedAtMs')
          ..write(')'))
        .toString();
  }
}

class $CardioSessionsTable extends CardioSessions
    with TableInfo<$CardioSessionsTable, CardioSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardioSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _localDateMeta = const VerificationMeta(
    'localDate',
  );
  @override
  late final GeneratedColumn<String> localDate = GeneratedColumn<String>(
    'local_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMsMeta = const VerificationMeta(
    'startedAtMs',
  );
  @override
  late final GeneratedColumn<int> startedAtMs = GeneratedColumn<int>(
    'started_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tzOffsetMinutesMeta = const VerificationMeta(
    'tzOffsetMinutes',
  );
  @override
  late final GeneratedColumn<int> tzOffsetMinutes = GeneratedColumn<int>(
    'tz_offset_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityCodeMeta = const VerificationMeta(
    'activityCode',
  );
  @override
  late final GeneratedColumn<String> activityCode = GeneratedColumn<String>(
    'activity_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activityNameMeta = const VerificationMeta(
    'activityName',
  );
  @override
  late final GeneratedColumn<String> activityName = GeneratedColumn<String>(
    'activity_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metMeta = const VerificationMeta('met');
  @override
  late final GeneratedColumn<double> met = GeneratedColumn<double>(
    'met',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _distanceMetersMeta = const VerificationMeta(
    'distanceMeters',
  );
  @override
  late final GeneratedColumn<double> distanceMeters = GeneratedColumn<double>(
    'distance_meters',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avgHeartRateMeta = const VerificationMeta(
    'avgHeartRate',
  );
  @override
  late final GeneratedColumn<int> avgHeartRate = GeneratedColumn<int>(
    'avg_heart_rate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kcalEstimatedMeta = const VerificationMeta(
    'kcalEstimated',
  );
  @override
  late final GeneratedColumn<double> kcalEstimated = GeneratedColumn<double>(
    'kcal_estimated',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kcalOverrideMeta = const VerificationMeta(
    'kcalOverride',
  );
  @override
  late final GeneratedColumn<double> kcalOverride = GeneratedColumn<double>(
    'kcal_override',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMsMeta = const VerificationMeta(
    'deletedAtMs',
  );
  @override
  late final GeneratedColumn<int> deletedAtMs = GeneratedColumn<int>(
    'deleted_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    localDate,
    startedAtMs,
    tzOffsetMinutes,
    activityCode,
    activityName,
    met,
    durationSeconds,
    distanceMeters,
    avgHeartRate,
    kcalEstimated,
    kcalOverride,
    source,
    sourceId,
    deletedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cardio_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardioSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('local_date')) {
      context.handle(
        _localDateMeta,
        localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta),
      );
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('started_at_ms')) {
      context.handle(
        _startedAtMsMeta,
        startedAtMs.isAcceptableOrUnknown(
          data['started_at_ms']!,
          _startedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtMsMeta);
    }
    if (data.containsKey('tz_offset_minutes')) {
      context.handle(
        _tzOffsetMinutesMeta,
        tzOffsetMinutes.isAcceptableOrUnknown(
          data['tz_offset_minutes']!,
          _tzOffsetMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tzOffsetMinutesMeta);
    }
    if (data.containsKey('activity_code')) {
      context.handle(
        _activityCodeMeta,
        activityCode.isAcceptableOrUnknown(
          data['activity_code']!,
          _activityCodeMeta,
        ),
      );
    }
    if (data.containsKey('activity_name')) {
      context.handle(
        _activityNameMeta,
        activityName.isAcceptableOrUnknown(
          data['activity_name']!,
          _activityNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activityNameMeta);
    }
    if (data.containsKey('met')) {
      context.handle(
        _metMeta,
        met.isAcceptableOrUnknown(data['met']!, _metMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('distance_meters')) {
      context.handle(
        _distanceMetersMeta,
        distanceMeters.isAcceptableOrUnknown(
          data['distance_meters']!,
          _distanceMetersMeta,
        ),
      );
    }
    if (data.containsKey('avg_heart_rate')) {
      context.handle(
        _avgHeartRateMeta,
        avgHeartRate.isAcceptableOrUnknown(
          data['avg_heart_rate']!,
          _avgHeartRateMeta,
        ),
      );
    }
    if (data.containsKey('kcal_estimated')) {
      context.handle(
        _kcalEstimatedMeta,
        kcalEstimated.isAcceptableOrUnknown(
          data['kcal_estimated']!,
          _kcalEstimatedMeta,
        ),
      );
    }
    if (data.containsKey('kcal_override')) {
      context.handle(
        _kcalOverrideMeta,
        kcalOverride.isAcceptableOrUnknown(
          data['kcal_override']!,
          _kcalOverrideMeta,
        ),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('deleted_at_ms')) {
      context.handle(
        _deletedAtMsMeta,
        deletedAtMs.isAcceptableOrUnknown(
          data['deleted_at_ms']!,
          _deletedAtMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {source, sourceId},
  ];
  @override
  CardioSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardioSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      localDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_date'],
      )!,
      startedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_ms'],
      )!,
      tzOffsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tz_offset_minutes'],
      )!,
      activityCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_code'],
      ),
      activityName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_name'],
      )!,
      met: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}met'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      distanceMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_meters'],
      ),
      avgHeartRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avg_heart_rate'],
      ),
      kcalEstimated: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal_estimated'],
      ),
      kcalOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal_override'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      deletedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_ms'],
      ),
    );
  }

  @override
  $CardioSessionsTable createAlias(String alias) {
    return $CardioSessionsTable(attachedDatabase, alias);
  }
}

class CardioSession extends DataClass implements Insertable<CardioSession> {
  final int id;
  final String localDate;
  final int startedAtMs;
  final int tzOffsetMinutes;
  final String? activityCode;
  final String activityName;
  final double? met;
  final int durationSeconds;
  final double? distanceMeters;
  final int? avgHeartRate;
  final double? kcalEstimated;
  final double? kcalOverride;
  final String source;
  final String? sourceId;
  final int? deletedAtMs;
  const CardioSession({
    required this.id,
    required this.localDate,
    required this.startedAtMs,
    required this.tzOffsetMinutes,
    this.activityCode,
    required this.activityName,
    this.met,
    required this.durationSeconds,
    this.distanceMeters,
    this.avgHeartRate,
    this.kcalEstimated,
    this.kcalOverride,
    required this.source,
    this.sourceId,
    this.deletedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['local_date'] = Variable<String>(localDate);
    map['started_at_ms'] = Variable<int>(startedAtMs);
    map['tz_offset_minutes'] = Variable<int>(tzOffsetMinutes);
    if (!nullToAbsent || activityCode != null) {
      map['activity_code'] = Variable<String>(activityCode);
    }
    map['activity_name'] = Variable<String>(activityName);
    if (!nullToAbsent || met != null) {
      map['met'] = Variable<double>(met);
    }
    map['duration_seconds'] = Variable<int>(durationSeconds);
    if (!nullToAbsent || distanceMeters != null) {
      map['distance_meters'] = Variable<double>(distanceMeters);
    }
    if (!nullToAbsent || avgHeartRate != null) {
      map['avg_heart_rate'] = Variable<int>(avgHeartRate);
    }
    if (!nullToAbsent || kcalEstimated != null) {
      map['kcal_estimated'] = Variable<double>(kcalEstimated);
    }
    if (!nullToAbsent || kcalOverride != null) {
      map['kcal_override'] = Variable<double>(kcalOverride);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    if (!nullToAbsent || deletedAtMs != null) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs);
    }
    return map;
  }

  CardioSessionsCompanion toCompanion(bool nullToAbsent) {
    return CardioSessionsCompanion(
      id: Value(id),
      localDate: Value(localDate),
      startedAtMs: Value(startedAtMs),
      tzOffsetMinutes: Value(tzOffsetMinutes),
      activityCode: activityCode == null && nullToAbsent
          ? const Value.absent()
          : Value(activityCode),
      activityName: Value(activityName),
      met: met == null && nullToAbsent ? const Value.absent() : Value(met),
      durationSeconds: Value(durationSeconds),
      distanceMeters: distanceMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceMeters),
      avgHeartRate: avgHeartRate == null && nullToAbsent
          ? const Value.absent()
          : Value(avgHeartRate),
      kcalEstimated: kcalEstimated == null && nullToAbsent
          ? const Value.absent()
          : Value(kcalEstimated),
      kcalOverride: kcalOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(kcalOverride),
      source: Value(source),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      deletedAtMs: deletedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtMs),
    );
  }

  factory CardioSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardioSession(
      id: serializer.fromJson<int>(json['id']),
      localDate: serializer.fromJson<String>(json['localDate']),
      startedAtMs: serializer.fromJson<int>(json['startedAtMs']),
      tzOffsetMinutes: serializer.fromJson<int>(json['tzOffsetMinutes']),
      activityCode: serializer.fromJson<String?>(json['activityCode']),
      activityName: serializer.fromJson<String>(json['activityName']),
      met: serializer.fromJson<double?>(json['met']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      distanceMeters: serializer.fromJson<double?>(json['distanceMeters']),
      avgHeartRate: serializer.fromJson<int?>(json['avgHeartRate']),
      kcalEstimated: serializer.fromJson<double?>(json['kcalEstimated']),
      kcalOverride: serializer.fromJson<double?>(json['kcalOverride']),
      source: serializer.fromJson<String>(json['source']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      deletedAtMs: serializer.fromJson<int?>(json['deletedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'localDate': serializer.toJson<String>(localDate),
      'startedAtMs': serializer.toJson<int>(startedAtMs),
      'tzOffsetMinutes': serializer.toJson<int>(tzOffsetMinutes),
      'activityCode': serializer.toJson<String?>(activityCode),
      'activityName': serializer.toJson<String>(activityName),
      'met': serializer.toJson<double?>(met),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'distanceMeters': serializer.toJson<double?>(distanceMeters),
      'avgHeartRate': serializer.toJson<int?>(avgHeartRate),
      'kcalEstimated': serializer.toJson<double?>(kcalEstimated),
      'kcalOverride': serializer.toJson<double?>(kcalOverride),
      'source': serializer.toJson<String>(source),
      'sourceId': serializer.toJson<String?>(sourceId),
      'deletedAtMs': serializer.toJson<int?>(deletedAtMs),
    };
  }

  CardioSession copyWith({
    int? id,
    String? localDate,
    int? startedAtMs,
    int? tzOffsetMinutes,
    Value<String?> activityCode = const Value.absent(),
    String? activityName,
    Value<double?> met = const Value.absent(),
    int? durationSeconds,
    Value<double?> distanceMeters = const Value.absent(),
    Value<int?> avgHeartRate = const Value.absent(),
    Value<double?> kcalEstimated = const Value.absent(),
    Value<double?> kcalOverride = const Value.absent(),
    String? source,
    Value<String?> sourceId = const Value.absent(),
    Value<int?> deletedAtMs = const Value.absent(),
  }) => CardioSession(
    id: id ?? this.id,
    localDate: localDate ?? this.localDate,
    startedAtMs: startedAtMs ?? this.startedAtMs,
    tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
    activityCode: activityCode.present ? activityCode.value : this.activityCode,
    activityName: activityName ?? this.activityName,
    met: met.present ? met.value : this.met,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    distanceMeters: distanceMeters.present
        ? distanceMeters.value
        : this.distanceMeters,
    avgHeartRate: avgHeartRate.present ? avgHeartRate.value : this.avgHeartRate,
    kcalEstimated: kcalEstimated.present
        ? kcalEstimated.value
        : this.kcalEstimated,
    kcalOverride: kcalOverride.present ? kcalOverride.value : this.kcalOverride,
    source: source ?? this.source,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    deletedAtMs: deletedAtMs.present ? deletedAtMs.value : this.deletedAtMs,
  );
  CardioSession copyWithCompanion(CardioSessionsCompanion data) {
    return CardioSession(
      id: data.id.present ? data.id.value : this.id,
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      startedAtMs: data.startedAtMs.present
          ? data.startedAtMs.value
          : this.startedAtMs,
      tzOffsetMinutes: data.tzOffsetMinutes.present
          ? data.tzOffsetMinutes.value
          : this.tzOffsetMinutes,
      activityCode: data.activityCode.present
          ? data.activityCode.value
          : this.activityCode,
      activityName: data.activityName.present
          ? data.activityName.value
          : this.activityName,
      met: data.met.present ? data.met.value : this.met,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      distanceMeters: data.distanceMeters.present
          ? data.distanceMeters.value
          : this.distanceMeters,
      avgHeartRate: data.avgHeartRate.present
          ? data.avgHeartRate.value
          : this.avgHeartRate,
      kcalEstimated: data.kcalEstimated.present
          ? data.kcalEstimated.value
          : this.kcalEstimated,
      kcalOverride: data.kcalOverride.present
          ? data.kcalOverride.value
          : this.kcalOverride,
      source: data.source.present ? data.source.value : this.source,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      deletedAtMs: data.deletedAtMs.present
          ? data.deletedAtMs.value
          : this.deletedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardioSession(')
          ..write('id: $id, ')
          ..write('localDate: $localDate, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('tzOffsetMinutes: $tzOffsetMinutes, ')
          ..write('activityCode: $activityCode, ')
          ..write('activityName: $activityName, ')
          ..write('met: $met, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('avgHeartRate: $avgHeartRate, ')
          ..write('kcalEstimated: $kcalEstimated, ')
          ..write('kcalOverride: $kcalOverride, ')
          ..write('source: $source, ')
          ..write('sourceId: $sourceId, ')
          ..write('deletedAtMs: $deletedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    localDate,
    startedAtMs,
    tzOffsetMinutes,
    activityCode,
    activityName,
    met,
    durationSeconds,
    distanceMeters,
    avgHeartRate,
    kcalEstimated,
    kcalOverride,
    source,
    sourceId,
    deletedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardioSession &&
          other.id == this.id &&
          other.localDate == this.localDate &&
          other.startedAtMs == this.startedAtMs &&
          other.tzOffsetMinutes == this.tzOffsetMinutes &&
          other.activityCode == this.activityCode &&
          other.activityName == this.activityName &&
          other.met == this.met &&
          other.durationSeconds == this.durationSeconds &&
          other.distanceMeters == this.distanceMeters &&
          other.avgHeartRate == this.avgHeartRate &&
          other.kcalEstimated == this.kcalEstimated &&
          other.kcalOverride == this.kcalOverride &&
          other.source == this.source &&
          other.sourceId == this.sourceId &&
          other.deletedAtMs == this.deletedAtMs);
}

class CardioSessionsCompanion extends UpdateCompanion<CardioSession> {
  final Value<int> id;
  final Value<String> localDate;
  final Value<int> startedAtMs;
  final Value<int> tzOffsetMinutes;
  final Value<String?> activityCode;
  final Value<String> activityName;
  final Value<double?> met;
  final Value<int> durationSeconds;
  final Value<double?> distanceMeters;
  final Value<int?> avgHeartRate;
  final Value<double?> kcalEstimated;
  final Value<double?> kcalOverride;
  final Value<String> source;
  final Value<String?> sourceId;
  final Value<int?> deletedAtMs;
  const CardioSessionsCompanion({
    this.id = const Value.absent(),
    this.localDate = const Value.absent(),
    this.startedAtMs = const Value.absent(),
    this.tzOffsetMinutes = const Value.absent(),
    this.activityCode = const Value.absent(),
    this.activityName = const Value.absent(),
    this.met = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    this.avgHeartRate = const Value.absent(),
    this.kcalEstimated = const Value.absent(),
    this.kcalOverride = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.deletedAtMs = const Value.absent(),
  });
  CardioSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String localDate,
    required int startedAtMs,
    required int tzOffsetMinutes,
    this.activityCode = const Value.absent(),
    required String activityName,
    this.met = const Value.absent(),
    required int durationSeconds,
    this.distanceMeters = const Value.absent(),
    this.avgHeartRate = const Value.absent(),
    this.kcalEstimated = const Value.absent(),
    this.kcalOverride = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.deletedAtMs = const Value.absent(),
  }) : localDate = Value(localDate),
       startedAtMs = Value(startedAtMs),
       tzOffsetMinutes = Value(tzOffsetMinutes),
       activityName = Value(activityName),
       durationSeconds = Value(durationSeconds);
  static Insertable<CardioSession> custom({
    Expression<int>? id,
    Expression<String>? localDate,
    Expression<int>? startedAtMs,
    Expression<int>? tzOffsetMinutes,
    Expression<String>? activityCode,
    Expression<String>? activityName,
    Expression<double>? met,
    Expression<int>? durationSeconds,
    Expression<double>? distanceMeters,
    Expression<int>? avgHeartRate,
    Expression<double>? kcalEstimated,
    Expression<double>? kcalOverride,
    Expression<String>? source,
    Expression<String>? sourceId,
    Expression<int>? deletedAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (localDate != null) 'local_date': localDate,
      if (startedAtMs != null) 'started_at_ms': startedAtMs,
      if (tzOffsetMinutes != null) 'tz_offset_minutes': tzOffsetMinutes,
      if (activityCode != null) 'activity_code': activityCode,
      if (activityName != null) 'activity_name': activityName,
      if (met != null) 'met': met,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (avgHeartRate != null) 'avg_heart_rate': avgHeartRate,
      if (kcalEstimated != null) 'kcal_estimated': kcalEstimated,
      if (kcalOverride != null) 'kcal_override': kcalOverride,
      if (source != null) 'source': source,
      if (sourceId != null) 'source_id': sourceId,
      if (deletedAtMs != null) 'deleted_at_ms': deletedAtMs,
    });
  }

  CardioSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? localDate,
    Value<int>? startedAtMs,
    Value<int>? tzOffsetMinutes,
    Value<String?>? activityCode,
    Value<String>? activityName,
    Value<double?>? met,
    Value<int>? durationSeconds,
    Value<double?>? distanceMeters,
    Value<int?>? avgHeartRate,
    Value<double?>? kcalEstimated,
    Value<double?>? kcalOverride,
    Value<String>? source,
    Value<String?>? sourceId,
    Value<int?>? deletedAtMs,
  }) {
    return CardioSessionsCompanion(
      id: id ?? this.id,
      localDate: localDate ?? this.localDate,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
      activityCode: activityCode ?? this.activityCode,
      activityName: activityName ?? this.activityName,
      met: met ?? this.met,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      avgHeartRate: avgHeartRate ?? this.avgHeartRate,
      kcalEstimated: kcalEstimated ?? this.kcalEstimated,
      kcalOverride: kcalOverride ?? this.kcalOverride,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (startedAtMs.present) {
      map['started_at_ms'] = Variable<int>(startedAtMs.value);
    }
    if (tzOffsetMinutes.present) {
      map['tz_offset_minutes'] = Variable<int>(tzOffsetMinutes.value);
    }
    if (activityCode.present) {
      map['activity_code'] = Variable<String>(activityCode.value);
    }
    if (activityName.present) {
      map['activity_name'] = Variable<String>(activityName.value);
    }
    if (met.present) {
      map['met'] = Variable<double>(met.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (distanceMeters.present) {
      map['distance_meters'] = Variable<double>(distanceMeters.value);
    }
    if (avgHeartRate.present) {
      map['avg_heart_rate'] = Variable<int>(avgHeartRate.value);
    }
    if (kcalEstimated.present) {
      map['kcal_estimated'] = Variable<double>(kcalEstimated.value);
    }
    if (kcalOverride.present) {
      map['kcal_override'] = Variable<double>(kcalOverride.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (deletedAtMs.present) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardioSessionsCompanion(')
          ..write('id: $id, ')
          ..write('localDate: $localDate, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('tzOffsetMinutes: $tzOffsetMinutes, ')
          ..write('activityCode: $activityCode, ')
          ..write('activityName: $activityName, ')
          ..write('met: $met, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('avgHeartRate: $avgHeartRate, ')
          ..write('kcalEstimated: $kcalEstimated, ')
          ..write('kcalOverride: $kcalOverride, ')
          ..write('source: $source, ')
          ..write('sourceId: $sourceId, ')
          ..write('deletedAtMs: $deletedAtMs')
          ..write(')'))
        .toString();
  }
}

class $ProfileTable extends Profile with TableInfo<$ProfileTable, ProfileData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfileTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sexMeta = const VerificationMeta('sex');
  @override
  late final GeneratedColumn<String> sex = GeneratedColumn<String>(
    'sex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _heightCmMeta = const VerificationMeta(
    'heightCm',
  );
  @override
  late final GeneratedColumn<double> heightCm = GeneratedColumn<double>(
    'height_cm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, sex, birthDate, heightCm];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profile';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sex')) {
      context.handle(
        _sexMeta,
        sex.isAcceptableOrUnknown(data['sex']!, _sexMeta),
      );
    }
    if (data.containsKey('birth_date')) {
      context.handle(
        _birthDateMeta,
        birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta),
      );
    }
    if (data.containsKey('height_cm')) {
      context.handle(
        _heightCmMeta,
        heightCm.isAcceptableOrUnknown(data['height_cm']!, _heightCmMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sex'],
      ),
      birthDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}birth_date'],
      ),
      heightCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height_cm'],
      ),
    );
  }

  @override
  $ProfileTable createAlias(String alias) {
    return $ProfileTable(attachedDatabase, alias);
  }
}

class ProfileData extends DataClass implements Insertable<ProfileData> {
  final int id;
  final String? sex;
  final String? birthDate;
  final double? heightCm;
  const ProfileData({
    required this.id,
    this.sex,
    this.birthDate,
    this.heightCm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || sex != null) {
      map['sex'] = Variable<String>(sex);
    }
    if (!nullToAbsent || birthDate != null) {
      map['birth_date'] = Variable<String>(birthDate);
    }
    if (!nullToAbsent || heightCm != null) {
      map['height_cm'] = Variable<double>(heightCm);
    }
    return map;
  }

  ProfileCompanion toCompanion(bool nullToAbsent) {
    return ProfileCompanion(
      id: Value(id),
      sex: sex == null && nullToAbsent ? const Value.absent() : Value(sex),
      birthDate: birthDate == null && nullToAbsent
          ? const Value.absent()
          : Value(birthDate),
      heightCm: heightCm == null && nullToAbsent
          ? const Value.absent()
          : Value(heightCm),
    );
  }

  factory ProfileData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileData(
      id: serializer.fromJson<int>(json['id']),
      sex: serializer.fromJson<String?>(json['sex']),
      birthDate: serializer.fromJson<String?>(json['birthDate']),
      heightCm: serializer.fromJson<double?>(json['heightCm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sex': serializer.toJson<String?>(sex),
      'birthDate': serializer.toJson<String?>(birthDate),
      'heightCm': serializer.toJson<double?>(heightCm),
    };
  }

  ProfileData copyWith({
    int? id,
    Value<String?> sex = const Value.absent(),
    Value<String?> birthDate = const Value.absent(),
    Value<double?> heightCm = const Value.absent(),
  }) => ProfileData(
    id: id ?? this.id,
    sex: sex.present ? sex.value : this.sex,
    birthDate: birthDate.present ? birthDate.value : this.birthDate,
    heightCm: heightCm.present ? heightCm.value : this.heightCm,
  );
  ProfileData copyWithCompanion(ProfileCompanion data) {
    return ProfileData(
      id: data.id.present ? data.id.value : this.id,
      sex: data.sex.present ? data.sex.value : this.sex,
      birthDate: data.birthDate.present ? data.birthDate.value : this.birthDate,
      heightCm: data.heightCm.present ? data.heightCm.value : this.heightCm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileData(')
          ..write('id: $id, ')
          ..write('sex: $sex, ')
          ..write('birthDate: $birthDate, ')
          ..write('heightCm: $heightCm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sex, birthDate, heightCm);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileData &&
          other.id == this.id &&
          other.sex == this.sex &&
          other.birthDate == this.birthDate &&
          other.heightCm == this.heightCm);
}

class ProfileCompanion extends UpdateCompanion<ProfileData> {
  final Value<int> id;
  final Value<String?> sex;
  final Value<String?> birthDate;
  final Value<double?> heightCm;
  const ProfileCompanion({
    this.id = const Value.absent(),
    this.sex = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.heightCm = const Value.absent(),
  });
  ProfileCompanion.insert({
    this.id = const Value.absent(),
    this.sex = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.heightCm = const Value.absent(),
  });
  static Insertable<ProfileData> custom({
    Expression<int>? id,
    Expression<String>? sex,
    Expression<String>? birthDate,
    Expression<double>? heightCm,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sex != null) 'sex': sex,
      if (birthDate != null) 'birth_date': birthDate,
      if (heightCm != null) 'height_cm': heightCm,
    });
  }

  ProfileCompanion copyWith({
    Value<int>? id,
    Value<String?>? sex,
    Value<String?>? birthDate,
    Value<double?>? heightCm,
  }) {
    return ProfileCompanion(
      id: id ?? this.id,
      sex: sex ?? this.sex,
      birthDate: birthDate ?? this.birthDate,
      heightCm: heightCm ?? this.heightCm,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sex.present) {
      map['sex'] = Variable<String>(sex.value);
    }
    if (birthDate.present) {
      map['birth_date'] = Variable<String>(birthDate.value);
    }
    if (heightCm.present) {
      map['height_cm'] = Variable<double>(heightCm.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfileCompanion(')
          ..write('id: $id, ')
          ..write('sex: $sex, ')
          ..write('birthDate: $birthDate, ')
          ..write('heightCm: $heightCm')
          ..write(')'))
        .toString();
  }
}

class $GoalsTable extends Goals with TableInfo<$GoalsTable, Goal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _effectiveFromMeta = const VerificationMeta(
    'effectiveFrom',
  );
  @override
  late final GeneratedColumn<String> effectiveFrom = GeneratedColumn<String>(
    'effective_from',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _calorieModeMeta = const VerificationMeta(
    'calorieMode',
  );
  @override
  late final GeneratedColumn<String> calorieMode = GeneratedColumn<String>(
    'calorie_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caloriesMeta = const VerificationMeta(
    'calories',
  );
  @override
  late final GeneratedColumn<int> calories = GeneratedColumn<int>(
    'calories',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activityFactorMeta = const VerificationMeta(
    'activityFactor',
  );
  @override
  late final GeneratedColumn<double> activityFactor = GeneratedColumn<double>(
    'activity_factor',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetKgPerWeekMeta = const VerificationMeta(
    'targetKgPerWeek',
  );
  @override
  late final GeneratedColumn<double> targetKgPerWeek = GeneratedColumn<double>(
    'target_kg_per_week',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseAddBackPercentMeta =
      const VerificationMeta('exerciseAddBackPercent');
  @override
  late final GeneratedColumn<int> exerciseAddBackPercent = GeneratedColumn<int>(
    'exercise_add_back_percent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _macroModeMeta = const VerificationMeta(
    'macroMode',
  );
  @override
  late final GeneratedColumn<String> macroMode = GeneratedColumn<String>(
    'macro_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proteinTargetMeta = const VerificationMeta(
    'proteinTarget',
  );
  @override
  late final GeneratedColumn<double> proteinTarget = GeneratedColumn<double>(
    'protein_target',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _carbsTargetMeta = const VerificationMeta(
    'carbsTarget',
  );
  @override
  late final GeneratedColumn<double> carbsTarget = GeneratedColumn<double>(
    'carbs_target',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fatTargetMeta = const VerificationMeta(
    'fatTarget',
  );
  @override
  late final GeneratedColumn<double> fatTarget = GeneratedColumn<double>(
    'fat_target',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    effectiveFrom,
    calorieMode,
    calories,
    activityFactor,
    targetKgPerWeek,
    exerciseAddBackPercent,
    macroMode,
    proteinTarget,
    carbsTarget,
    fatTarget,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<Goal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('effective_from')) {
      context.handle(
        _effectiveFromMeta,
        effectiveFrom.isAcceptableOrUnknown(
          data['effective_from']!,
          _effectiveFromMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_effectiveFromMeta);
    }
    if (data.containsKey('calorie_mode')) {
      context.handle(
        _calorieModeMeta,
        calorieMode.isAcceptableOrUnknown(
          data['calorie_mode']!,
          _calorieModeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_calorieModeMeta);
    }
    if (data.containsKey('calories')) {
      context.handle(
        _caloriesMeta,
        calories.isAcceptableOrUnknown(data['calories']!, _caloriesMeta),
      );
    }
    if (data.containsKey('activity_factor')) {
      context.handle(
        _activityFactorMeta,
        activityFactor.isAcceptableOrUnknown(
          data['activity_factor']!,
          _activityFactorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activityFactorMeta);
    }
    if (data.containsKey('target_kg_per_week')) {
      context.handle(
        _targetKgPerWeekMeta,
        targetKgPerWeek.isAcceptableOrUnknown(
          data['target_kg_per_week']!,
          _targetKgPerWeekMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetKgPerWeekMeta);
    }
    if (data.containsKey('exercise_add_back_percent')) {
      context.handle(
        _exerciseAddBackPercentMeta,
        exerciseAddBackPercent.isAcceptableOrUnknown(
          data['exercise_add_back_percent']!,
          _exerciseAddBackPercentMeta,
        ),
      );
    }
    if (data.containsKey('macro_mode')) {
      context.handle(
        _macroModeMeta,
        macroMode.isAcceptableOrUnknown(data['macro_mode']!, _macroModeMeta),
      );
    } else if (isInserting) {
      context.missing(_macroModeMeta);
    }
    if (data.containsKey('protein_target')) {
      context.handle(
        _proteinTargetMeta,
        proteinTarget.isAcceptableOrUnknown(
          data['protein_target']!,
          _proteinTargetMeta,
        ),
      );
    }
    if (data.containsKey('carbs_target')) {
      context.handle(
        _carbsTargetMeta,
        carbsTarget.isAcceptableOrUnknown(
          data['carbs_target']!,
          _carbsTargetMeta,
        ),
      );
    }
    if (data.containsKey('fat_target')) {
      context.handle(
        _fatTargetMeta,
        fatTarget.isAcceptableOrUnknown(data['fat_target']!, _fatTargetMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Goal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Goal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      effectiveFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effective_from'],
      )!,
      calorieMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calorie_mode'],
      )!,
      calories: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calories'],
      ),
      activityFactor: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}activity_factor'],
      )!,
      targetKgPerWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_kg_per_week'],
      )!,
      exerciseAddBackPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exercise_add_back_percent'],
      )!,
      macroMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}macro_mode'],
      )!,
      proteinTarget: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}protein_target'],
      ),
      carbsTarget: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carbs_target'],
      ),
      fatTarget: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fat_target'],
      ),
    );
  }

  @override
  $GoalsTable createAlias(String alias) {
    return $GoalsTable(attachedDatabase, alias);
  }
}

class Goal extends DataClass implements Insertable<Goal> {
  final int id;
  final String effectiveFrom;
  final String calorieMode;
  final int? calories;
  final double activityFactor;
  final double targetKgPerWeek;
  final int exerciseAddBackPercent;
  final String macroMode;
  final double? proteinTarget;
  final double? carbsTarget;
  final double? fatTarget;
  const Goal({
    required this.id,
    required this.effectiveFrom,
    required this.calorieMode,
    this.calories,
    required this.activityFactor,
    required this.targetKgPerWeek,
    required this.exerciseAddBackPercent,
    required this.macroMode,
    this.proteinTarget,
    this.carbsTarget,
    this.fatTarget,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['effective_from'] = Variable<String>(effectiveFrom);
    map['calorie_mode'] = Variable<String>(calorieMode);
    if (!nullToAbsent || calories != null) {
      map['calories'] = Variable<int>(calories);
    }
    map['activity_factor'] = Variable<double>(activityFactor);
    map['target_kg_per_week'] = Variable<double>(targetKgPerWeek);
    map['exercise_add_back_percent'] = Variable<int>(exerciseAddBackPercent);
    map['macro_mode'] = Variable<String>(macroMode);
    if (!nullToAbsent || proteinTarget != null) {
      map['protein_target'] = Variable<double>(proteinTarget);
    }
    if (!nullToAbsent || carbsTarget != null) {
      map['carbs_target'] = Variable<double>(carbsTarget);
    }
    if (!nullToAbsent || fatTarget != null) {
      map['fat_target'] = Variable<double>(fatTarget);
    }
    return map;
  }

  GoalsCompanion toCompanion(bool nullToAbsent) {
    return GoalsCompanion(
      id: Value(id),
      effectiveFrom: Value(effectiveFrom),
      calorieMode: Value(calorieMode),
      calories: calories == null && nullToAbsent
          ? const Value.absent()
          : Value(calories),
      activityFactor: Value(activityFactor),
      targetKgPerWeek: Value(targetKgPerWeek),
      exerciseAddBackPercent: Value(exerciseAddBackPercent),
      macroMode: Value(macroMode),
      proteinTarget: proteinTarget == null && nullToAbsent
          ? const Value.absent()
          : Value(proteinTarget),
      carbsTarget: carbsTarget == null && nullToAbsent
          ? const Value.absent()
          : Value(carbsTarget),
      fatTarget: fatTarget == null && nullToAbsent
          ? const Value.absent()
          : Value(fatTarget),
    );
  }

  factory Goal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Goal(
      id: serializer.fromJson<int>(json['id']),
      effectiveFrom: serializer.fromJson<String>(json['effectiveFrom']),
      calorieMode: serializer.fromJson<String>(json['calorieMode']),
      calories: serializer.fromJson<int?>(json['calories']),
      activityFactor: serializer.fromJson<double>(json['activityFactor']),
      targetKgPerWeek: serializer.fromJson<double>(json['targetKgPerWeek']),
      exerciseAddBackPercent: serializer.fromJson<int>(
        json['exerciseAddBackPercent'],
      ),
      macroMode: serializer.fromJson<String>(json['macroMode']),
      proteinTarget: serializer.fromJson<double?>(json['proteinTarget']),
      carbsTarget: serializer.fromJson<double?>(json['carbsTarget']),
      fatTarget: serializer.fromJson<double?>(json['fatTarget']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'effectiveFrom': serializer.toJson<String>(effectiveFrom),
      'calorieMode': serializer.toJson<String>(calorieMode),
      'calories': serializer.toJson<int?>(calories),
      'activityFactor': serializer.toJson<double>(activityFactor),
      'targetKgPerWeek': serializer.toJson<double>(targetKgPerWeek),
      'exerciseAddBackPercent': serializer.toJson<int>(exerciseAddBackPercent),
      'macroMode': serializer.toJson<String>(macroMode),
      'proteinTarget': serializer.toJson<double?>(proteinTarget),
      'carbsTarget': serializer.toJson<double?>(carbsTarget),
      'fatTarget': serializer.toJson<double?>(fatTarget),
    };
  }

  Goal copyWith({
    int? id,
    String? effectiveFrom,
    String? calorieMode,
    Value<int?> calories = const Value.absent(),
    double? activityFactor,
    double? targetKgPerWeek,
    int? exerciseAddBackPercent,
    String? macroMode,
    Value<double?> proteinTarget = const Value.absent(),
    Value<double?> carbsTarget = const Value.absent(),
    Value<double?> fatTarget = const Value.absent(),
  }) => Goal(
    id: id ?? this.id,
    effectiveFrom: effectiveFrom ?? this.effectiveFrom,
    calorieMode: calorieMode ?? this.calorieMode,
    calories: calories.present ? calories.value : this.calories,
    activityFactor: activityFactor ?? this.activityFactor,
    targetKgPerWeek: targetKgPerWeek ?? this.targetKgPerWeek,
    exerciseAddBackPercent:
        exerciseAddBackPercent ?? this.exerciseAddBackPercent,
    macroMode: macroMode ?? this.macroMode,
    proteinTarget: proteinTarget.present
        ? proteinTarget.value
        : this.proteinTarget,
    carbsTarget: carbsTarget.present ? carbsTarget.value : this.carbsTarget,
    fatTarget: fatTarget.present ? fatTarget.value : this.fatTarget,
  );
  Goal copyWithCompanion(GoalsCompanion data) {
    return Goal(
      id: data.id.present ? data.id.value : this.id,
      effectiveFrom: data.effectiveFrom.present
          ? data.effectiveFrom.value
          : this.effectiveFrom,
      calorieMode: data.calorieMode.present
          ? data.calorieMode.value
          : this.calorieMode,
      calories: data.calories.present ? data.calories.value : this.calories,
      activityFactor: data.activityFactor.present
          ? data.activityFactor.value
          : this.activityFactor,
      targetKgPerWeek: data.targetKgPerWeek.present
          ? data.targetKgPerWeek.value
          : this.targetKgPerWeek,
      exerciseAddBackPercent: data.exerciseAddBackPercent.present
          ? data.exerciseAddBackPercent.value
          : this.exerciseAddBackPercent,
      macroMode: data.macroMode.present ? data.macroMode.value : this.macroMode,
      proteinTarget: data.proteinTarget.present
          ? data.proteinTarget.value
          : this.proteinTarget,
      carbsTarget: data.carbsTarget.present
          ? data.carbsTarget.value
          : this.carbsTarget,
      fatTarget: data.fatTarget.present ? data.fatTarget.value : this.fatTarget,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Goal(')
          ..write('id: $id, ')
          ..write('effectiveFrom: $effectiveFrom, ')
          ..write('calorieMode: $calorieMode, ')
          ..write('calories: $calories, ')
          ..write('activityFactor: $activityFactor, ')
          ..write('targetKgPerWeek: $targetKgPerWeek, ')
          ..write('exerciseAddBackPercent: $exerciseAddBackPercent, ')
          ..write('macroMode: $macroMode, ')
          ..write('proteinTarget: $proteinTarget, ')
          ..write('carbsTarget: $carbsTarget, ')
          ..write('fatTarget: $fatTarget')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    effectiveFrom,
    calorieMode,
    calories,
    activityFactor,
    targetKgPerWeek,
    exerciseAddBackPercent,
    macroMode,
    proteinTarget,
    carbsTarget,
    fatTarget,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Goal &&
          other.id == this.id &&
          other.effectiveFrom == this.effectiveFrom &&
          other.calorieMode == this.calorieMode &&
          other.calories == this.calories &&
          other.activityFactor == this.activityFactor &&
          other.targetKgPerWeek == this.targetKgPerWeek &&
          other.exerciseAddBackPercent == this.exerciseAddBackPercent &&
          other.macroMode == this.macroMode &&
          other.proteinTarget == this.proteinTarget &&
          other.carbsTarget == this.carbsTarget &&
          other.fatTarget == this.fatTarget);
}

class GoalsCompanion extends UpdateCompanion<Goal> {
  final Value<int> id;
  final Value<String> effectiveFrom;
  final Value<String> calorieMode;
  final Value<int?> calories;
  final Value<double> activityFactor;
  final Value<double> targetKgPerWeek;
  final Value<int> exerciseAddBackPercent;
  final Value<String> macroMode;
  final Value<double?> proteinTarget;
  final Value<double?> carbsTarget;
  final Value<double?> fatTarget;
  const GoalsCompanion({
    this.id = const Value.absent(),
    this.effectiveFrom = const Value.absent(),
    this.calorieMode = const Value.absent(),
    this.calories = const Value.absent(),
    this.activityFactor = const Value.absent(),
    this.targetKgPerWeek = const Value.absent(),
    this.exerciseAddBackPercent = const Value.absent(),
    this.macroMode = const Value.absent(),
    this.proteinTarget = const Value.absent(),
    this.carbsTarget = const Value.absent(),
    this.fatTarget = const Value.absent(),
  });
  GoalsCompanion.insert({
    this.id = const Value.absent(),
    required String effectiveFrom,
    required String calorieMode,
    this.calories = const Value.absent(),
    required double activityFactor,
    required double targetKgPerWeek,
    this.exerciseAddBackPercent = const Value.absent(),
    required String macroMode,
    this.proteinTarget = const Value.absent(),
    this.carbsTarget = const Value.absent(),
    this.fatTarget = const Value.absent(),
  }) : effectiveFrom = Value(effectiveFrom),
       calorieMode = Value(calorieMode),
       activityFactor = Value(activityFactor),
       targetKgPerWeek = Value(targetKgPerWeek),
       macroMode = Value(macroMode);
  static Insertable<Goal> custom({
    Expression<int>? id,
    Expression<String>? effectiveFrom,
    Expression<String>? calorieMode,
    Expression<int>? calories,
    Expression<double>? activityFactor,
    Expression<double>? targetKgPerWeek,
    Expression<int>? exerciseAddBackPercent,
    Expression<String>? macroMode,
    Expression<double>? proteinTarget,
    Expression<double>? carbsTarget,
    Expression<double>? fatTarget,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (effectiveFrom != null) 'effective_from': effectiveFrom,
      if (calorieMode != null) 'calorie_mode': calorieMode,
      if (calories != null) 'calories': calories,
      if (activityFactor != null) 'activity_factor': activityFactor,
      if (targetKgPerWeek != null) 'target_kg_per_week': targetKgPerWeek,
      if (exerciseAddBackPercent != null)
        'exercise_add_back_percent': exerciseAddBackPercent,
      if (macroMode != null) 'macro_mode': macroMode,
      if (proteinTarget != null) 'protein_target': proteinTarget,
      if (carbsTarget != null) 'carbs_target': carbsTarget,
      if (fatTarget != null) 'fat_target': fatTarget,
    });
  }

  GoalsCompanion copyWith({
    Value<int>? id,
    Value<String>? effectiveFrom,
    Value<String>? calorieMode,
    Value<int?>? calories,
    Value<double>? activityFactor,
    Value<double>? targetKgPerWeek,
    Value<int>? exerciseAddBackPercent,
    Value<String>? macroMode,
    Value<double?>? proteinTarget,
    Value<double?>? carbsTarget,
    Value<double?>? fatTarget,
  }) {
    return GoalsCompanion(
      id: id ?? this.id,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      calorieMode: calorieMode ?? this.calorieMode,
      calories: calories ?? this.calories,
      activityFactor: activityFactor ?? this.activityFactor,
      targetKgPerWeek: targetKgPerWeek ?? this.targetKgPerWeek,
      exerciseAddBackPercent:
          exerciseAddBackPercent ?? this.exerciseAddBackPercent,
      macroMode: macroMode ?? this.macroMode,
      proteinTarget: proteinTarget ?? this.proteinTarget,
      carbsTarget: carbsTarget ?? this.carbsTarget,
      fatTarget: fatTarget ?? this.fatTarget,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (effectiveFrom.present) {
      map['effective_from'] = Variable<String>(effectiveFrom.value);
    }
    if (calorieMode.present) {
      map['calorie_mode'] = Variable<String>(calorieMode.value);
    }
    if (calories.present) {
      map['calories'] = Variable<int>(calories.value);
    }
    if (activityFactor.present) {
      map['activity_factor'] = Variable<double>(activityFactor.value);
    }
    if (targetKgPerWeek.present) {
      map['target_kg_per_week'] = Variable<double>(targetKgPerWeek.value);
    }
    if (exerciseAddBackPercent.present) {
      map['exercise_add_back_percent'] = Variable<int>(
        exerciseAddBackPercent.value,
      );
    }
    if (macroMode.present) {
      map['macro_mode'] = Variable<String>(macroMode.value);
    }
    if (proteinTarget.present) {
      map['protein_target'] = Variable<double>(proteinTarget.value);
    }
    if (carbsTarget.present) {
      map['carbs_target'] = Variable<double>(carbsTarget.value);
    }
    if (fatTarget.present) {
      map['fat_target'] = Variable<double>(fatTarget.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalsCompanion(')
          ..write('id: $id, ')
          ..write('effectiveFrom: $effectiveFrom, ')
          ..write('calorieMode: $calorieMode, ')
          ..write('calories: $calories, ')
          ..write('activityFactor: $activityFactor, ')
          ..write('targetKgPerWeek: $targetKgPerWeek, ')
          ..write('exerciseAddBackPercent: $exerciseAddBackPercent, ')
          ..write('macroMode: $macroMode, ')
          ..write('proteinTarget: $proteinTarget, ')
          ..write('carbsTarget: $carbsTarget, ')
          ..write('fatTarget: $fatTarget')
          ..write(')'))
        .toString();
  }
}

class $GoalNutrientsTable extends GoalNutrients
    with TableInfo<$GoalNutrientsTable, GoalNutrient> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalNutrientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<int> goalId = GeneratedColumn<int>(
    'goal_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goals (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nutrientIdMeta = const VerificationMeta(
    'nutrientId',
  );
  @override
  late final GeneratedColumn<int> nutrientId = GeneratedColumn<int>(
    'nutrient_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetAmountMeta = const VerificationMeta(
    'targetAmount',
  );
  @override
  late final GeneratedColumn<double> targetAmount = GeneratedColumn<double>(
    'target_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [goalId, nutrientId, targetAmount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goal_nutrients';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoalNutrient> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_goalIdMeta);
    }
    if (data.containsKey('nutrient_id')) {
      context.handle(
        _nutrientIdMeta,
        nutrientId.isAcceptableOrUnknown(data['nutrient_id']!, _nutrientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nutrientIdMeta);
    }
    if (data.containsKey('target_amount')) {
      context.handle(
        _targetAmountMeta,
        targetAmount.isAcceptableOrUnknown(
          data['target_amount']!,
          _targetAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetAmountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {goalId, nutrientId};
  @override
  GoalNutrient map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalNutrient(
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}goal_id'],
      )!,
      nutrientId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}nutrient_id'],
      )!,
      targetAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_amount'],
      )!,
    );
  }

  @override
  $GoalNutrientsTable createAlias(String alias) {
    return $GoalNutrientsTable(attachedDatabase, alias);
  }
}

class GoalNutrient extends DataClass implements Insertable<GoalNutrient> {
  final int goalId;
  final int nutrientId;
  final double targetAmount;
  const GoalNutrient({
    required this.goalId,
    required this.nutrientId,
    required this.targetAmount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['goal_id'] = Variable<int>(goalId);
    map['nutrient_id'] = Variable<int>(nutrientId);
    map['target_amount'] = Variable<double>(targetAmount);
    return map;
  }

  GoalNutrientsCompanion toCompanion(bool nullToAbsent) {
    return GoalNutrientsCompanion(
      goalId: Value(goalId),
      nutrientId: Value(nutrientId),
      targetAmount: Value(targetAmount),
    );
  }

  factory GoalNutrient.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalNutrient(
      goalId: serializer.fromJson<int>(json['goalId']),
      nutrientId: serializer.fromJson<int>(json['nutrientId']),
      targetAmount: serializer.fromJson<double>(json['targetAmount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'goalId': serializer.toJson<int>(goalId),
      'nutrientId': serializer.toJson<int>(nutrientId),
      'targetAmount': serializer.toJson<double>(targetAmount),
    };
  }

  GoalNutrient copyWith({int? goalId, int? nutrientId, double? targetAmount}) =>
      GoalNutrient(
        goalId: goalId ?? this.goalId,
        nutrientId: nutrientId ?? this.nutrientId,
        targetAmount: targetAmount ?? this.targetAmount,
      );
  GoalNutrient copyWithCompanion(GoalNutrientsCompanion data) {
    return GoalNutrient(
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      nutrientId: data.nutrientId.present
          ? data.nutrientId.value
          : this.nutrientId,
      targetAmount: data.targetAmount.present
          ? data.targetAmount.value
          : this.targetAmount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalNutrient(')
          ..write('goalId: $goalId, ')
          ..write('nutrientId: $nutrientId, ')
          ..write('targetAmount: $targetAmount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(goalId, nutrientId, targetAmount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalNutrient &&
          other.goalId == this.goalId &&
          other.nutrientId == this.nutrientId &&
          other.targetAmount == this.targetAmount);
}

class GoalNutrientsCompanion extends UpdateCompanion<GoalNutrient> {
  final Value<int> goalId;
  final Value<int> nutrientId;
  final Value<double> targetAmount;
  final Value<int> rowid;
  const GoalNutrientsCompanion({
    this.goalId = const Value.absent(),
    this.nutrientId = const Value.absent(),
    this.targetAmount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalNutrientsCompanion.insert({
    required int goalId,
    required int nutrientId,
    required double targetAmount,
    this.rowid = const Value.absent(),
  }) : goalId = Value(goalId),
       nutrientId = Value(nutrientId),
       targetAmount = Value(targetAmount);
  static Insertable<GoalNutrient> custom({
    Expression<int>? goalId,
    Expression<int>? nutrientId,
    Expression<double>? targetAmount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (goalId != null) 'goal_id': goalId,
      if (nutrientId != null) 'nutrient_id': nutrientId,
      if (targetAmount != null) 'target_amount': targetAmount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalNutrientsCompanion copyWith({
    Value<int>? goalId,
    Value<int>? nutrientId,
    Value<double>? targetAmount,
    Value<int>? rowid,
  }) {
    return GoalNutrientsCompanion(
      goalId: goalId ?? this.goalId,
      nutrientId: nutrientId ?? this.nutrientId,
      targetAmount: targetAmount ?? this.targetAmount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (goalId.present) {
      map['goal_id'] = Variable<int>(goalId.value);
    }
    if (nutrientId.present) {
      map['nutrient_id'] = Variable<int>(nutrientId.value);
    }
    if (targetAmount.present) {
      map['target_amount'] = Variable<double>(targetAmount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalNutrientsCompanion(')
          ..write('goalId: $goalId, ')
          ..write('nutrientId: $nutrientId, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
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

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
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
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
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

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
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
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FoodsTable foods = $FoodsTable(this);
  late final $FoodNutrientsTable foodNutrients = $FoodNutrientsTable(this);
  late final $FoodPortionsTable foodPortions = $FoodPortionsTable(this);
  late final $RecipeIngredientsTable recipeIngredients =
      $RecipeIngredientsTable(this);
  late final $MealSlotsTable mealSlots = $MealSlotsTable(this);
  late final $MealSlotRulesTable mealSlotRules = $MealSlotRulesTable(this);
  late final $SavedMealsTable savedMeals = $SavedMealsTable(this);
  late final $MealsTable meals = $MealsTable(this);
  late final $MealEntriesTable mealEntries = $MealEntriesTable(this);
  late final $MealEntryNutrientsTable mealEntryNutrients =
      $MealEntryNutrientsTable(this);
  late final $SavedMealItemsTable savedMealItems = $SavedMealItemsTable(this);
  late final $SavedMealItemNutrientsTable savedMealItemNutrients =
      $SavedMealItemNutrientsTable(this);
  late final $AliasesTable aliases = $AliasesTable(this);
  late final $LearnedMatchesTable learnedMatches = $LearnedMatchesTable(this);
  late final $WeightEntriesTable weightEntries = $WeightEntriesTable(this);
  late final $ExercisesTable exercises = $ExercisesTable(this);
  late final $RoutinesTable routines = $RoutinesTable(this);
  late final $RoutineExercisesTable routineExercises = $RoutineExercisesTable(
    this,
  );
  late final $WorkoutsTable workouts = $WorkoutsTable(this);
  late final $WorkoutSetsTable workoutSets = $WorkoutSetsTable(this);
  late final $CardioSessionsTable cardioSessions = $CardioSessionsTable(this);
  late final $ProfileTable profile = $ProfileTable(this);
  late final $GoalsTable goals = $GoalsTable(this);
  late final $GoalNutrientsTable goalNutrients = $GoalNutrientsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    foods,
    foodNutrients,
    foodPortions,
    recipeIngredients,
    mealSlots,
    mealSlotRules,
    savedMeals,
    meals,
    mealEntries,
    mealEntryNutrients,
    savedMealItems,
    savedMealItemNutrients,
    aliases,
    learnedMatches,
    weightEntries,
    exercises,
    routines,
    routineExercises,
    workouts,
    workoutSets,
    cardioSessions,
    profile,
    goals,
    goalNutrients,
    settings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'foods',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('food_nutrients', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'foods',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('food_portions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'foods',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('recipe_ingredients', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'saved_meals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('meals', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('meal_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meal_entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('meal_entry_nutrients', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'saved_meals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('saved_meal_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'saved_meal_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('saved_meal_item_nutrients', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'saved_meals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('aliases', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'routines',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('routine_exercises', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'routines',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workouts', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workouts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workout_sets', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'goals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('goal_nutrients', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$FoodsTableCreateCompanionBuilder = FoodsCompanion Function({
  Value<int> id,
  required String kind,
  required String name,
  Value<String?> brand,
  Value<String?> barcode,
  required double baseAmount,
  required String baseUnit,
  Value<String?> sourceJson,
  Value<bool> archived,
  required int createdAtMs,
  required int updatedAtMs,
});
typedef $$FoodsTableUpdateCompanionBuilder = FoodsCompanion Function({
  Value<int> id,
  Value<String> kind,
  Value<String> name,
  Value<String?> brand,
  Value<String?> barcode,
  Value<double> baseAmount,
  Value<String> baseUnit,
  Value<String?> sourceJson,
  Value<bool> archived,
  Value<int> createdAtMs,
  Value<int> updatedAtMs,
});

final class $$FoodsTableReferences
    extends BaseReferences<_$AppDatabase, $FoodsTable, Food> {
  $$FoodsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FoodNutrientsTable, List<FoodNutrient>>
  _foodNutrientsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.foodNutrients,
    aliasName: 'foods__id__food_nutrients__food_id',
  );

  $$FoodNutrientsTableProcessedTableManager get foodNutrientsRefs {
    final manager = $$FoodNutrientsTableTableManager(
      $_db,
      $_db.foodNutrients,
    ).filter((f) => f.foodId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_foodNutrientsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FoodPortionsTable, List<FoodPortion>>
  _foodPortionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.foodPortions,
    aliasName: 'foods__id__food_portions__food_id',
  );

  $$FoodPortionsTableProcessedTableManager get foodPortionsRefs {
    final manager = $$FoodPortionsTableTableManager(
      $_db,
      $_db.foodPortions,
    ).filter((f) => f.foodId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_foodPortionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecipeIngredientsTable, List<RecipeIngredient>>
  _recipeIngredientsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.recipeIngredients,
        aliasName: 'foods__id__recipe_ingredients__recipe_food_id',
      );

  $$RecipeIngredientsTableProcessedTableManager get recipeIngredientsRefs {
    final manager = $$RecipeIngredientsTableTableManager(
      $_db,
      $_db.recipeIngredients,
    ).filter((f) => f.recipeFoodId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _recipeIngredientsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FoodsTableFilterComposer extends Composer<_$AppDatabase, $FoodsTable> {
  $$FoodsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get baseAmount => $composableBuilder(
    column: $table.baseAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUnit => $composableBuilder(
    column: $table.baseUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> foodNutrientsRefs(
    Expression<bool> Function($$FoodNutrientsTableFilterComposer f) f,
  ) {
    final $$FoodNutrientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.foodNutrients,
      getReferencedColumn: (t) => t.foodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodNutrientsTableFilterComposer(
            $db: $db,
            $table: $db.foodNutrients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> foodPortionsRefs(
    Expression<bool> Function($$FoodPortionsTableFilterComposer f) f,
  ) {
    final $$FoodPortionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.foodPortions,
      getReferencedColumn: (t) => t.foodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodPortionsTableFilterComposer(
            $db: $db,
            $table: $db.foodPortions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recipeIngredientsRefs(
    Expression<bool> Function($$RecipeIngredientsTableFilterComposer f) f,
  ) {
    final $$RecipeIngredientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipeIngredients,
      getReferencedColumn: (t) => t.recipeFoodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipeIngredientsTableFilterComposer(
            $db: $db,
            $table: $db.recipeIngredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoodsTableOrderingComposer
    extends Composer<_$AppDatabase, $FoodsTable> {
  $$FoodsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get baseAmount => $composableBuilder(
    column: $table.baseAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUnit => $composableBuilder(
    column: $table.baseUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoodsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoodsTable> {
  $$FoodsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<double> get baseAmount => $composableBuilder(
    column: $table.baseAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseUnit =>
      $composableBuilder(column: $table.baseUnit, builder: (column) => column);

  GeneratedColumn<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  Expression<T> foodNutrientsRefs<T extends Object>(
    Expression<T> Function($$FoodNutrientsTableAnnotationComposer a) f,
  ) {
    final $$FoodNutrientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.foodNutrients,
      getReferencedColumn: (t) => t.foodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodNutrientsTableAnnotationComposer(
            $db: $db,
            $table: $db.foodNutrients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> foodPortionsRefs<T extends Object>(
    Expression<T> Function($$FoodPortionsTableAnnotationComposer a) f,
  ) {
    final $$FoodPortionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.foodPortions,
      getReferencedColumn: (t) => t.foodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodPortionsTableAnnotationComposer(
            $db: $db,
            $table: $db.foodPortions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> recipeIngredientsRefs<T extends Object>(
    Expression<T> Function($$RecipeIngredientsTableAnnotationComposer a) f,
  ) {
    final $$RecipeIngredientsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.recipeIngredients,
          getReferencedColumn: (t) => t.recipeFoodId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecipeIngredientsTableAnnotationComposer(
                $db: $db,
                $table: $db.recipeIngredients,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$FoodsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoodsTable,
          Food,
          $$FoodsTableFilterComposer,
          $$FoodsTableOrderingComposer,
          $$FoodsTableAnnotationComposer,
          $$FoodsTableCreateCompanionBuilder,
          $$FoodsTableUpdateCompanionBuilder,
          (Food, $$FoodsTableReferences),
          Food,
          PrefetchHooks Function({
            bool foodNutrientsRefs,
            bool foodPortionsRefs,
            bool recipeIngredientsRefs,
          })
        > {
  $$FoodsTableTableManager(_$AppDatabase db, $FoodsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> brand = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<double> baseAmount = const Value.absent(),
                Value<String> baseUnit = const Value.absent(),
                Value<String?> sourceJson = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
              }) => FoodsCompanion(
                id: id,
                kind: kind,
                name: name,
                brand: brand,
                barcode: barcode,
                baseAmount: baseAmount,
                baseUnit: baseUnit,
                sourceJson: sourceJson,
                archived: archived,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kind,
                required String name,
                Value<String?> brand = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                required double baseAmount,
                required String baseUnit,
                Value<String?> sourceJson = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                required int createdAtMs,
                required int updatedAtMs,
              }) => FoodsCompanion.insert(
                id: id,
                kind: kind,
                name: name,
                brand: brand,
                barcode: barcode,
                baseAmount: baseAmount,
                baseUnit: baseUnit,
                sourceJson: sourceJson,
                archived: archived,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FoodsTable, Food>(table),
                  $$FoodsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                foodNutrientsRefs = false,
                foodPortionsRefs = false,
                recipeIngredientsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (foodNutrientsRefs) db.foodNutrients,
                    if (foodPortionsRefs) db.foodPortions,
                    if (recipeIngredientsRefs) db.recipeIngredients,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (foodNutrientsRefs)
                        await $_getPrefetchedDataByColumns<
                          Food,
                          $FoodsTable,
                          FoodNutrient,
                          $FoodNutrientsTable
                        >(
                          currentTable: table,
                          referencedTable: $$FoodsTableReferences
                              ._foodNutrientsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FoodsTableReferences(
                                db,
                                table,
                                p0,
                              ).foodNutrientsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'food_id',
                          typedResults: items,
                        ),
                      if (foodPortionsRefs)
                        await $_getPrefetchedDataByColumns<
                          Food,
                          $FoodsTable,
                          FoodPortion,
                          $FoodPortionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$FoodsTableReferences
                              ._foodPortionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FoodsTableReferences(
                                db,
                                table,
                                p0,
                              ).foodPortionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'food_id',
                          typedResults: items,
                        ),
                      if (recipeIngredientsRefs)
                        await $_getPrefetchedDataByColumns<
                          Food,
                          $FoodsTable,
                          RecipeIngredient,
                          $RecipeIngredientsTable
                        >(
                          currentTable: table,
                          referencedTable: $$FoodsTableReferences
                              ._recipeIngredientsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FoodsTableReferences(
                                db,
                                table,
                                p0,
                              ).recipeIngredientsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'recipe_food_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FoodsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoodsTable,
      Food,
      $$FoodsTableFilterComposer,
      $$FoodsTableOrderingComposer,
      $$FoodsTableAnnotationComposer,
      $$FoodsTableCreateCompanionBuilder,
      $$FoodsTableUpdateCompanionBuilder,
      (Food, $$FoodsTableReferences),
      Food,
      PrefetchHooks Function({
        bool foodNutrientsRefs,
        bool foodPortionsRefs,
        bool recipeIngredientsRefs,
      })
    >;
typedef $$FoodNutrientsTableCreateCompanionBuilder =
    FoodNutrientsCompanion Function({
      required int foodId,
      required int nutrientId,
      required double amount,
      Value<int> rowid,
    });
typedef $$FoodNutrientsTableUpdateCompanionBuilder =
    FoodNutrientsCompanion Function({
      Value<int> foodId,
      Value<int> nutrientId,
      Value<double> amount,
      Value<int> rowid,
    });

final class $$FoodNutrientsTableReferences
    extends BaseReferences<_$AppDatabase, $FoodNutrientsTable, FoodNutrient> {
  $$FoodNutrientsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FoodsTable _foodIdTable(_$AppDatabase db) =>
      db.foods.createAlias('food_nutrients__food_id__foods__id');

  $$FoodsTableProcessedTableManager get foodId {
    final $_column = $_itemColumn<int>('food_id')!;

    final manager = $$FoodsTableTableManager(
      $_db,
      $_db.foods,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_foodIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FoodNutrientsTableFilterComposer
    extends Composer<_$AppDatabase, $FoodNutrientsTable> {
  $$FoodNutrientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get nutrientId => $composableBuilder(
    column: $table.nutrientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  $$FoodsTableFilterComposer get foodId {
    final $$FoodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableFilterComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoodNutrientsTableOrderingComposer
    extends Composer<_$AppDatabase, $FoodNutrientsTable> {
  $$FoodNutrientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get nutrientId => $composableBuilder(
    column: $table.nutrientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  $$FoodsTableOrderingComposer get foodId {
    final $$FoodsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableOrderingComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoodNutrientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoodNutrientsTable> {
  $$FoodNutrientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get nutrientId => $composableBuilder(
    column: $table.nutrientId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  $$FoodsTableAnnotationComposer get foodId {
    final $$FoodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableAnnotationComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoodNutrientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoodNutrientsTable,
          FoodNutrient,
          $$FoodNutrientsTableFilterComposer,
          $$FoodNutrientsTableOrderingComposer,
          $$FoodNutrientsTableAnnotationComposer,
          $$FoodNutrientsTableCreateCompanionBuilder,
          $$FoodNutrientsTableUpdateCompanionBuilder,
          (FoodNutrient, $$FoodNutrientsTableReferences),
          FoodNutrient,
          PrefetchHooks Function({bool foodId})
        > {
  $$FoodNutrientsTableTableManager(_$AppDatabase db, $FoodNutrientsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodNutrientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodNutrientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodNutrientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> foodId = const Value.absent(),
                Value<int> nutrientId = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoodNutrientsCompanion(
                foodId: foodId,
                nutrientId: nutrientId,
                amount: amount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int foodId,
                required int nutrientId,
                required double amount,
                Value<int> rowid = const Value.absent(),
              }) => FoodNutrientsCompanion.insert(
                foodId: foodId,
                nutrientId: nutrientId,
                amount: amount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FoodNutrientsTable, FoodNutrient>(table),
                  $$FoodNutrientsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({foodId = false}) {
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
                    if (foodId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.foodId,
                        referencedTable: $$FoodNutrientsTableReferences
                            ._foodIdTable(db),
                        referencedColumn: $$FoodNutrientsTableReferences
                            ._foodIdTable(db)
                            .id,
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

typedef $$FoodNutrientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoodNutrientsTable,
      FoodNutrient,
      $$FoodNutrientsTableFilterComposer,
      $$FoodNutrientsTableOrderingComposer,
      $$FoodNutrientsTableAnnotationComposer,
      $$FoodNutrientsTableCreateCompanionBuilder,
      $$FoodNutrientsTableUpdateCompanionBuilder,
      (FoodNutrient, $$FoodNutrientsTableReferences),
      FoodNutrient,
      PrefetchHooks Function({bool foodId})
    >;
typedef $$FoodPortionsTableCreateCompanionBuilder =
    FoodPortionsCompanion Function({
      Value<int> id,
      required int foodId,
      required String label,
      required double baseQuantity,
    });
typedef $$FoodPortionsTableUpdateCompanionBuilder =
    FoodPortionsCompanion Function({
      Value<int> id,
      Value<int> foodId,
      Value<String> label,
      Value<double> baseQuantity,
    });

final class $$FoodPortionsTableReferences
    extends BaseReferences<_$AppDatabase, $FoodPortionsTable, FoodPortion> {
  $$FoodPortionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FoodsTable _foodIdTable(_$AppDatabase db) =>
      db.foods.createAlias('food_portions__food_id__foods__id');

  $$FoodsTableProcessedTableManager get foodId {
    final $_column = $_itemColumn<int>('food_id')!;

    final manager = $$FoodsTableTableManager(
      $_db,
      $_db.foods,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_foodIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FoodPortionsTableFilterComposer
    extends Composer<_$AppDatabase, $FoodPortionsTable> {
  $$FoodPortionsTableFilterComposer({
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

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get baseQuantity => $composableBuilder(
    column: $table.baseQuantity,
    builder: (column) => ColumnFilters(column),
  );

  $$FoodsTableFilterComposer get foodId {
    final $$FoodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableFilterComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoodPortionsTableOrderingComposer
    extends Composer<_$AppDatabase, $FoodPortionsTable> {
  $$FoodPortionsTableOrderingComposer({
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

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get baseQuantity => $composableBuilder(
    column: $table.baseQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  $$FoodsTableOrderingComposer get foodId {
    final $$FoodsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableOrderingComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoodPortionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoodPortionsTable> {
  $$FoodPortionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<double> get baseQuantity => $composableBuilder(
    column: $table.baseQuantity,
    builder: (column) => column,
  );

  $$FoodsTableAnnotationComposer get foodId {
    final $$FoodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableAnnotationComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoodPortionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoodPortionsTable,
          FoodPortion,
          $$FoodPortionsTableFilterComposer,
          $$FoodPortionsTableOrderingComposer,
          $$FoodPortionsTableAnnotationComposer,
          $$FoodPortionsTableCreateCompanionBuilder,
          $$FoodPortionsTableUpdateCompanionBuilder,
          (FoodPortion, $$FoodPortionsTableReferences),
          FoodPortion,
          PrefetchHooks Function({bool foodId})
        > {
  $$FoodPortionsTableTableManager(_$AppDatabase db, $FoodPortionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodPortionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodPortionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodPortionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> foodId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<double> baseQuantity = const Value.absent(),
              }) => FoodPortionsCompanion(
                id: id,
                foodId: foodId,
                label: label,
                baseQuantity: baseQuantity,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int foodId,
                required String label,
                required double baseQuantity,
              }) => FoodPortionsCompanion.insert(
                id: id,
                foodId: foodId,
                label: label,
                baseQuantity: baseQuantity,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FoodPortionsTable, FoodPortion>(table),
                  $$FoodPortionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({foodId = false}) {
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
                    if (foodId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.foodId,
                        referencedTable: $$FoodPortionsTableReferences
                            ._foodIdTable(db),
                        referencedColumn: $$FoodPortionsTableReferences
                            ._foodIdTable(db)
                            .id,
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

typedef $$FoodPortionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoodPortionsTable,
      FoodPortion,
      $$FoodPortionsTableFilterComposer,
      $$FoodPortionsTableOrderingComposer,
      $$FoodPortionsTableAnnotationComposer,
      $$FoodPortionsTableCreateCompanionBuilder,
      $$FoodPortionsTableUpdateCompanionBuilder,
      (FoodPortion, $$FoodPortionsTableReferences),
      FoodPortion,
      PrefetchHooks Function({bool foodId})
    >;
typedef $$RecipeIngredientsTableCreateCompanionBuilder =
    RecipeIngredientsCompanion Function({
      Value<int> id,
      required int recipeFoodId,
      required int position,
      required String foodRef,
      required String foodName,
      required double quantity,
      required String unitLabel,
      required double baseQuantity,
      required String baseUnit,
    });
typedef $$RecipeIngredientsTableUpdateCompanionBuilder =
    RecipeIngredientsCompanion Function({
      Value<int> id,
      Value<int> recipeFoodId,
      Value<int> position,
      Value<String> foodRef,
      Value<String> foodName,
      Value<double> quantity,
      Value<String> unitLabel,
      Value<double> baseQuantity,
      Value<String> baseUnit,
    });

final class $$RecipeIngredientsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $RecipeIngredientsTable,
          RecipeIngredient
        > {
  $$RecipeIngredientsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FoodsTable _recipeFoodIdTable(_$AppDatabase db) =>
      db.foods.createAlias('recipe_ingredients__recipe_food_id__foods__id');

  $$FoodsTableProcessedTableManager get recipeFoodId {
    final $_column = $_itemColumn<int>('recipe_food_id')!;

    final manager = $$FoodsTableTableManager(
      $_db,
      $_db.foods,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recipeFoodIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecipeIngredientsTableFilterComposer
    extends Composer<_$AppDatabase, $RecipeIngredientsTable> {
  $$RecipeIngredientsTableFilterComposer({
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

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foodRef => $composableBuilder(
    column: $table.foodRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foodName => $composableBuilder(
    column: $table.foodName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitLabel => $composableBuilder(
    column: $table.unitLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get baseQuantity => $composableBuilder(
    column: $table.baseQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUnit => $composableBuilder(
    column: $table.baseUnit,
    builder: (column) => ColumnFilters(column),
  );

  $$FoodsTableFilterComposer get recipeFoodId {
    final $$FoodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeFoodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableFilterComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeIngredientsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipeIngredientsTable> {
  $$RecipeIngredientsTableOrderingComposer({
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

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodRef => $composableBuilder(
    column: $table.foodRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodName => $composableBuilder(
    column: $table.foodName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitLabel => $composableBuilder(
    column: $table.unitLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get baseQuantity => $composableBuilder(
    column: $table.baseQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUnit => $composableBuilder(
    column: $table.baseUnit,
    builder: (column) => ColumnOrderings(column),
  );

  $$FoodsTableOrderingComposer get recipeFoodId {
    final $$FoodsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeFoodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableOrderingComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeIngredientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipeIngredientsTable> {
  $$RecipeIngredientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get foodRef =>
      $composableBuilder(column: $table.foodRef, builder: (column) => column);

  GeneratedColumn<String> get foodName =>
      $composableBuilder(column: $table.foodName, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unitLabel =>
      $composableBuilder(column: $table.unitLabel, builder: (column) => column);

  GeneratedColumn<double> get baseQuantity => $composableBuilder(
    column: $table.baseQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseUnit =>
      $composableBuilder(column: $table.baseUnit, builder: (column) => column);

  $$FoodsTableAnnotationComposer get recipeFoodId {
    final $$FoodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeFoodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableAnnotationComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeIngredientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecipeIngredientsTable,
          RecipeIngredient,
          $$RecipeIngredientsTableFilterComposer,
          $$RecipeIngredientsTableOrderingComposer,
          $$RecipeIngredientsTableAnnotationComposer,
          $$RecipeIngredientsTableCreateCompanionBuilder,
          $$RecipeIngredientsTableUpdateCompanionBuilder,
          (RecipeIngredient, $$RecipeIngredientsTableReferences),
          RecipeIngredient,
          PrefetchHooks Function({bool recipeFoodId})
        > {
  $$RecipeIngredientsTableTableManager(
    _$AppDatabase db,
    $RecipeIngredientsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipeIngredientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipeIngredientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipeIngredientsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> recipeFoodId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> foodRef = const Value.absent(),
                Value<String> foodName = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<String> unitLabel = const Value.absent(),
                Value<double> baseQuantity = const Value.absent(),
                Value<String> baseUnit = const Value.absent(),
              }) => RecipeIngredientsCompanion(
                id: id,
                recipeFoodId: recipeFoodId,
                position: position,
                foodRef: foodRef,
                foodName: foodName,
                quantity: quantity,
                unitLabel: unitLabel,
                baseQuantity: baseQuantity,
                baseUnit: baseUnit,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int recipeFoodId,
                required int position,
                required String foodRef,
                required String foodName,
                required double quantity,
                required String unitLabel,
                required double baseQuantity,
                required String baseUnit,
              }) => RecipeIngredientsCompanion.insert(
                id: id,
                recipeFoodId: recipeFoodId,
                position: position,
                foodRef: foodRef,
                foodName: foodName,
                quantity: quantity,
                unitLabel: unitLabel,
                baseQuantity: baseQuantity,
                baseUnit: baseUnit,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecipeIngredientsTable, RecipeIngredient>(table),
                  $$RecipeIngredientsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recipeFoodId = false}) {
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
                    if (recipeFoodId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recipeFoodId,
                        referencedTable: $$RecipeIngredientsTableReferences
                            ._recipeFoodIdTable(db),
                        referencedColumn: $$RecipeIngredientsTableReferences
                            ._recipeFoodIdTable(db)
                            .id,
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

typedef $$RecipeIngredientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecipeIngredientsTable,
      RecipeIngredient,
      $$RecipeIngredientsTableFilterComposer,
      $$RecipeIngredientsTableOrderingComposer,
      $$RecipeIngredientsTableAnnotationComposer,
      $$RecipeIngredientsTableCreateCompanionBuilder,
      $$RecipeIngredientsTableUpdateCompanionBuilder,
      (RecipeIngredient, $$RecipeIngredientsTableReferences),
      RecipeIngredient,
      PrefetchHooks Function({bool recipeFoodId})
    >;
typedef $$MealSlotsTableCreateCompanionBuilder = MealSlotsCompanion Function({
  Value<int> id,
  required String name,
  required int position,
  Value<bool> archived,
});
typedef $$MealSlotsTableUpdateCompanionBuilder = MealSlotsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int> position,
  Value<bool> archived,
});

final class $$MealSlotsTableReferences
    extends BaseReferences<_$AppDatabase, $MealSlotsTable, MealSlot> {
  $$MealSlotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MealSlotRulesTable, List<MealSlotRule>>
  _mealSlotRulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mealSlotRules,
    aliasName: 'meal_slots__id__meal_slot_rules__slot_id',
  );

  $$MealSlotRulesTableProcessedTableManager get mealSlotRulesRefs {
    final manager = $$MealSlotRulesTableTableManager(
      $_db,
      $_db.mealSlotRules,
    ).filter((f) => f.slotId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mealSlotRulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MealsTable, List<Meal>> _mealsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.meals,
    aliasName: 'meal_slots__id__meals__slot_id',
  );

  $$MealsTableProcessedTableManager get mealsRefs {
    final manager = $$MealsTableTableManager(
      $_db,
      $_db.meals,
    ).filter((f) => f.slotId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mealsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MealSlotsTableFilterComposer
    extends Composer<_$AppDatabase, $MealSlotsTable> {
  $$MealSlotsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mealSlotRulesRefs(
    Expression<bool> Function($$MealSlotRulesTableFilterComposer f) f,
  ) {
    final $$MealSlotRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealSlotRules,
      getReferencedColumn: (t) => t.slotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealSlotRulesTableFilterComposer(
            $db: $db,
            $table: $db.mealSlotRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> mealsRefs(
    Expression<bool> Function($$MealsTableFilterComposer f) f,
  ) {
    final $$MealsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.slotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableFilterComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealSlotsTableOrderingComposer
    extends Composer<_$AppDatabase, $MealSlotsTable> {
  $$MealSlotsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MealSlotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealSlotsTable> {
  $$MealSlotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  Expression<T> mealSlotRulesRefs<T extends Object>(
    Expression<T> Function($$MealSlotRulesTableAnnotationComposer a) f,
  ) {
    final $$MealSlotRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealSlotRules,
      getReferencedColumn: (t) => t.slotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealSlotRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.mealSlotRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> mealsRefs<T extends Object>(
    Expression<T> Function($$MealsTableAnnotationComposer a) f,
  ) {
    final $$MealsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.slotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableAnnotationComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealSlotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealSlotsTable,
          MealSlot,
          $$MealSlotsTableFilterComposer,
          $$MealSlotsTableOrderingComposer,
          $$MealSlotsTableAnnotationComposer,
          $$MealSlotsTableCreateCompanionBuilder,
          $$MealSlotsTableUpdateCompanionBuilder,
          (MealSlot, $$MealSlotsTableReferences),
          MealSlot,
          PrefetchHooks Function({bool mealSlotRulesRefs, bool mealsRefs})
        > {
  $$MealSlotsTableTableManager(_$AppDatabase db, $MealSlotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealSlotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealSlotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealSlotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<bool> archived = const Value.absent(),
              }) => MealSlotsCompanion(
                id: id,
                name: name,
                position: position,
                archived: archived,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int position,
                Value<bool> archived = const Value.absent(),
              }) => MealSlotsCompanion.insert(
                id: id,
                name: name,
                position: position,
                archived: archived,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MealSlotsTable, MealSlot>(table),
                  $$MealSlotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({mealSlotRulesRefs = false, mealsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (mealSlotRulesRefs) db.mealSlotRules,
                    if (mealsRefs) db.meals,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (mealSlotRulesRefs)
                        await $_getPrefetchedDataByColumns<
                          MealSlot,
                          $MealSlotsTable,
                          MealSlotRule,
                          $MealSlotRulesTable
                        >(
                          currentTable: table,
                          referencedTable: $$MealSlotsTableReferences
                              ._mealSlotRulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MealSlotsTableReferences(
                                db,
                                table,
                                p0,
                              ).mealSlotRulesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'slot_id',
                          typedResults: items,
                        ),
                      if (mealsRefs)
                        await $_getPrefetchedDataByColumns<
                          MealSlot,
                          $MealSlotsTable,
                          Meal,
                          $MealsTable
                        >(
                          currentTable: table,
                          referencedTable: $$MealSlotsTableReferences
                              ._mealsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MealSlotsTableReferences(
                                db,
                                table,
                                p0,
                              ).mealsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'slot_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MealSlotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealSlotsTable,
      MealSlot,
      $$MealSlotsTableFilterComposer,
      $$MealSlotsTableOrderingComposer,
      $$MealSlotsTableAnnotationComposer,
      $$MealSlotsTableCreateCompanionBuilder,
      $$MealSlotsTableUpdateCompanionBuilder,
      (MealSlot, $$MealSlotsTableReferences),
      MealSlot,
      PrefetchHooks Function({bool mealSlotRulesRefs, bool mealsRefs})
    >;
typedef $$MealSlotRulesTableCreateCompanionBuilder =
    MealSlotRulesCompanion Function({
      Value<int> startMinute,
      required int slotId,
    });
typedef $$MealSlotRulesTableUpdateCompanionBuilder =
    MealSlotRulesCompanion Function({
      Value<int> startMinute,
      Value<int> slotId,
    });

final class $$MealSlotRulesTableReferences
    extends BaseReferences<_$AppDatabase, $MealSlotRulesTable, MealSlotRule> {
  $$MealSlotRulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MealSlotsTable _slotIdTable(_$AppDatabase db) =>
      db.mealSlots.createAlias('meal_slot_rules__slot_id__meal_slots__id');

  $$MealSlotsTableProcessedTableManager get slotId {
    final $_column = $_itemColumn<int>('slot_id')!;

    final manager = $$MealSlotsTableTableManager(
      $_db,
      $_db.mealSlots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_slotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MealSlotRulesTableFilterComposer
    extends Composer<_$AppDatabase, $MealSlotRulesTable> {
  $$MealSlotRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  $$MealSlotsTableFilterComposer get slotId {
    final $$MealSlotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotId,
      referencedTable: $db.mealSlots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealSlotsTableFilterComposer(
            $db: $db,
            $table: $db.mealSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealSlotRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $MealSlotRulesTable> {
  $$MealSlotRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  $$MealSlotsTableOrderingComposer get slotId {
    final $$MealSlotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotId,
      referencedTable: $db.mealSlots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealSlotsTableOrderingComposer(
            $db: $db,
            $table: $db.mealSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealSlotRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealSlotRulesTable> {
  $$MealSlotRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  $$MealSlotsTableAnnotationComposer get slotId {
    final $$MealSlotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotId,
      referencedTable: $db.mealSlots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealSlotsTableAnnotationComposer(
            $db: $db,
            $table: $db.mealSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealSlotRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealSlotRulesTable,
          MealSlotRule,
          $$MealSlotRulesTableFilterComposer,
          $$MealSlotRulesTableOrderingComposer,
          $$MealSlotRulesTableAnnotationComposer,
          $$MealSlotRulesTableCreateCompanionBuilder,
          $$MealSlotRulesTableUpdateCompanionBuilder,
          (MealSlotRule, $$MealSlotRulesTableReferences),
          MealSlotRule,
          PrefetchHooks Function({bool slotId})
        > {
  $$MealSlotRulesTableTableManager(_$AppDatabase db, $MealSlotRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealSlotRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealSlotRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealSlotRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> startMinute = const Value.absent(),
                Value<int> slotId = const Value.absent(),
              }) => MealSlotRulesCompanion(
                startMinute: startMinute,
                slotId: slotId,
              ),
          createCompanionCallback:
              ({
                Value<int> startMinute = const Value.absent(),
                required int slotId,
              }) => MealSlotRulesCompanion.insert(
                startMinute: startMinute,
                slotId: slotId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MealSlotRulesTable, MealSlotRule>(table),
                  $$MealSlotRulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({slotId = false}) {
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
                    if (slotId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.slotId,
                        referencedTable: $$MealSlotRulesTableReferences
                            ._slotIdTable(db),
                        referencedColumn: $$MealSlotRulesTableReferences
                            ._slotIdTable(db)
                            .id,
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

typedef $$MealSlotRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealSlotRulesTable,
      MealSlotRule,
      $$MealSlotRulesTableFilterComposer,
      $$MealSlotRulesTableOrderingComposer,
      $$MealSlotRulesTableAnnotationComposer,
      $$MealSlotRulesTableCreateCompanionBuilder,
      $$MealSlotRulesTableUpdateCompanionBuilder,
      (MealSlotRule, $$MealSlotRulesTableReferences),
      MealSlotRule,
      PrefetchHooks Function({bool slotId})
    >;
typedef $$SavedMealsTableCreateCompanionBuilder = SavedMealsCompanion Function({
  Value<int> id,
  required String name,
  required int createdAtMs,
});
typedef $$SavedMealsTableUpdateCompanionBuilder = SavedMealsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int> createdAtMs,
});

final class $$SavedMealsTableReferences
    extends BaseReferences<_$AppDatabase, $SavedMealsTable, SavedMeal> {
  $$SavedMealsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MealsTable, List<Meal>> _mealsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.meals,
    aliasName: 'saved_meals__id__meals__saved_meal_id',
  );

  $$MealsTableProcessedTableManager get mealsRefs {
    final manager = $$MealsTableTableManager(
      $_db,
      $_db.meals,
    ).filter((f) => f.savedMealId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mealsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SavedMealItemsTable, List<SavedMealItem>>
  _savedMealItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.savedMealItems,
    aliasName: 'saved_meals__id__saved_meal_items__saved_meal_id',
  );

  $$SavedMealItemsTableProcessedTableManager get savedMealItemsRefs {
    final manager = $$SavedMealItemsTableTableManager(
      $_db,
      $_db.savedMealItems,
    ).filter((f) => f.savedMealId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_savedMealItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AliasesTable, List<Alias>> _aliasesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.aliases,
    aliasName: 'saved_meals__id__aliases__saved_meal_id',
  );

  $$AliasesTableProcessedTableManager get aliasesRefs {
    final manager = $$AliasesTableTableManager(
      $_db,
      $_db.aliases,
    ).filter((f) => f.savedMealId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_aliasesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SavedMealsTableFilterComposer
    extends Composer<_$AppDatabase, $SavedMealsTable> {
  $$SavedMealsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mealsRefs(
    Expression<bool> Function($$MealsTableFilterComposer f) f,
  ) {
    final $$MealsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.savedMealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableFilterComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> savedMealItemsRefs(
    Expression<bool> Function($$SavedMealItemsTableFilterComposer f) f,
  ) {
    final $$SavedMealItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedMealItems,
      getReferencedColumn: (t) => t.savedMealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealItemsTableFilterComposer(
            $db: $db,
            $table: $db.savedMealItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> aliasesRefs(
    Expression<bool> Function($$AliasesTableFilterComposer f) f,
  ) {
    final $$AliasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aliases,
      getReferencedColumn: (t) => t.savedMealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AliasesTableFilterComposer(
            $db: $db,
            $table: $db.aliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SavedMealsTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedMealsTable> {
  $$SavedMealsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedMealsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedMealsTable> {
  $$SavedMealsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  Expression<T> mealsRefs<T extends Object>(
    Expression<T> Function($$MealsTableAnnotationComposer a) f,
  ) {
    final $$MealsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.savedMealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableAnnotationComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> savedMealItemsRefs<T extends Object>(
    Expression<T> Function($$SavedMealItemsTableAnnotationComposer a) f,
  ) {
    final $$SavedMealItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedMealItems,
      getReferencedColumn: (t) => t.savedMealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedMealItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> aliasesRefs<T extends Object>(
    Expression<T> Function($$AliasesTableAnnotationComposer a) f,
  ) {
    final $$AliasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aliases,
      getReferencedColumn: (t) => t.savedMealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AliasesTableAnnotationComposer(
            $db: $db,
            $table: $db.aliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SavedMealsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedMealsTable,
          SavedMeal,
          $$SavedMealsTableFilterComposer,
          $$SavedMealsTableOrderingComposer,
          $$SavedMealsTableAnnotationComposer,
          $$SavedMealsTableCreateCompanionBuilder,
          $$SavedMealsTableUpdateCompanionBuilder,
          (SavedMeal, $$SavedMealsTableReferences),
          SavedMeal,
          PrefetchHooks Function({
            bool mealsRefs,
            bool savedMealItemsRefs,
            bool aliasesRefs,
          })
        > {
  $$SavedMealsTableTableManager(_$AppDatabase db, $SavedMealsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedMealsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedMealsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedMealsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
              }) => SavedMealsCompanion(
                id: id,
                name: name,
                createdAtMs: createdAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int createdAtMs,
              }) => SavedMealsCompanion.insert(
                id: id,
                name: name,
                createdAtMs: createdAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavedMealsTable, SavedMeal>(table),
                  $$SavedMealsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                mealsRefs = false,
                savedMealItemsRefs = false,
                aliasesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (mealsRefs) db.meals,
                    if (savedMealItemsRefs) db.savedMealItems,
                    if (aliasesRefs) db.aliases,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (mealsRefs)
                        await $_getPrefetchedDataByColumns<
                          SavedMeal,
                          $SavedMealsTable,
                          Meal,
                          $MealsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SavedMealsTableReferences
                              ._mealsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SavedMealsTableReferences(
                                db,
                                table,
                                p0,
                              ).mealsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'saved_meal_id',
                          typedResults: items,
                        ),
                      if (savedMealItemsRefs)
                        await $_getPrefetchedDataByColumns<
                          SavedMeal,
                          $SavedMealsTable,
                          SavedMealItem,
                          $SavedMealItemsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SavedMealsTableReferences
                              ._savedMealItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SavedMealsTableReferences(
                                db,
                                table,
                                p0,
                              ).savedMealItemsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'saved_meal_id',
                          typedResults: items,
                        ),
                      if (aliasesRefs)
                        await $_getPrefetchedDataByColumns<
                          SavedMeal,
                          $SavedMealsTable,
                          Alias,
                          $AliasesTable
                        >(
                          currentTable: table,
                          referencedTable: $$SavedMealsTableReferences
                              ._aliasesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SavedMealsTableReferences(
                                db,
                                table,
                                p0,
                              ).aliasesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'saved_meal_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SavedMealsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedMealsTable,
      SavedMeal,
      $$SavedMealsTableFilterComposer,
      $$SavedMealsTableOrderingComposer,
      $$SavedMealsTableAnnotationComposer,
      $$SavedMealsTableCreateCompanionBuilder,
      $$SavedMealsTableUpdateCompanionBuilder,
      (SavedMeal, $$SavedMealsTableReferences),
      SavedMeal,
      PrefetchHooks Function({
        bool mealsRefs,
        bool savedMealItemsRefs,
        bool aliasesRefs,
      })
    >;
typedef $$MealsTableCreateCompanionBuilder = MealsCompanion Function({
  Value<int> id,
  required String localDate,
  required int slotId,
  required int loggedAtMs,
  required int tzOffsetMinutes,
  Value<String?> sourceText,
  Value<int?> savedMealId,
});
typedef $$MealsTableUpdateCompanionBuilder = MealsCompanion Function({
  Value<int> id,
  Value<String> localDate,
  Value<int> slotId,
  Value<int> loggedAtMs,
  Value<int> tzOffsetMinutes,
  Value<String?> sourceText,
  Value<int?> savedMealId,
});

final class $$MealsTableReferences
    extends BaseReferences<_$AppDatabase, $MealsTable, Meal> {
  $$MealsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MealSlotsTable _slotIdTable(_$AppDatabase db) =>
      db.mealSlots.createAlias('meals__slot_id__meal_slots__id');

  $$MealSlotsTableProcessedTableManager get slotId {
    final $_column = $_itemColumn<int>('slot_id')!;

    final manager = $$MealSlotsTableTableManager(
      $_db,
      $_db.mealSlots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_slotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SavedMealsTable _savedMealIdTable(_$AppDatabase db) =>
      db.savedMeals.createAlias('meals__saved_meal_id__saved_meals__id');

  $$SavedMealsTableProcessedTableManager? get savedMealId {
    final $_column = $_itemColumn<int>('saved_meal_id');
    if ($_column == null) return null;
    final manager = $$SavedMealsTableTableManager(
      $_db,
      $_db.savedMeals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_savedMealIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MealEntriesTable, List<MealEntry>>
  _mealEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mealEntries,
    aliasName: 'meals__id__meal_entries__meal_id',
  );

  $$MealEntriesTableProcessedTableManager get mealEntriesRefs {
    final manager = $$MealEntriesTableTableManager(
      $_db,
      $_db.mealEntries,
    ).filter((f) => f.mealId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mealEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MealsTableFilterComposer extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableFilterComposer({
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

  ColumnFilters<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get loggedAtMs => $composableBuilder(
    column: $table.loggedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tzOffsetMinutes => $composableBuilder(
    column: $table.tzOffsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnFilters(column),
  );

  $$MealSlotsTableFilterComposer get slotId {
    final $$MealSlotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotId,
      referencedTable: $db.mealSlots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealSlotsTableFilterComposer(
            $db: $db,
            $table: $db.mealSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SavedMealsTableFilterComposer get savedMealId {
    final $$SavedMealsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.savedMealId,
      referencedTable: $db.savedMeals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealsTableFilterComposer(
            $db: $db,
            $table: $db.savedMeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> mealEntriesRefs(
    Expression<bool> Function($$MealEntriesTableFilterComposer f) f,
  ) {
    final $$MealEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealEntries,
      getReferencedColumn: (t) => t.mealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealEntriesTableFilterComposer(
            $db: $db,
            $table: $db.mealEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealsTableOrderingComposer
    extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableOrderingComposer({
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

  ColumnOrderings<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get loggedAtMs => $composableBuilder(
    column: $table.loggedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tzOffsetMinutes => $composableBuilder(
    column: $table.tzOffsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnOrderings(column),
  );

  $$MealSlotsTableOrderingComposer get slotId {
    final $$MealSlotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotId,
      referencedTable: $db.mealSlots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealSlotsTableOrderingComposer(
            $db: $db,
            $table: $db.mealSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SavedMealsTableOrderingComposer get savedMealId {
    final $$SavedMealsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.savedMealId,
      referencedTable: $db.savedMeals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealsTableOrderingComposer(
            $db: $db,
            $table: $db.savedMeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumn<int> get loggedAtMs => $composableBuilder(
    column: $table.loggedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tzOffsetMinutes => $composableBuilder(
    column: $table.tzOffsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => column,
  );

  $$MealSlotsTableAnnotationComposer get slotId {
    final $$MealSlotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotId,
      referencedTable: $db.mealSlots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealSlotsTableAnnotationComposer(
            $db: $db,
            $table: $db.mealSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SavedMealsTableAnnotationComposer get savedMealId {
    final $$SavedMealsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.savedMealId,
      referencedTable: $db.savedMeals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedMeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> mealEntriesRefs<T extends Object>(
    Expression<T> Function($$MealEntriesTableAnnotationComposer a) f,
  ) {
    final $$MealEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealEntries,
      getReferencedColumn: (t) => t.mealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.mealEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealsTable,
          Meal,
          $$MealsTableFilterComposer,
          $$MealsTableOrderingComposer,
          $$MealsTableAnnotationComposer,
          $$MealsTableCreateCompanionBuilder,
          $$MealsTableUpdateCompanionBuilder,
          (Meal, $$MealsTableReferences),
          Meal,
          PrefetchHooks Function({
            bool slotId,
            bool savedMealId,
            bool mealEntriesRefs,
          })
        > {
  $$MealsTableTableManager(_$AppDatabase db, $MealsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> localDate = const Value.absent(),
                Value<int> slotId = const Value.absent(),
                Value<int> loggedAtMs = const Value.absent(),
                Value<int> tzOffsetMinutes = const Value.absent(),
                Value<String?> sourceText = const Value.absent(),
                Value<int?> savedMealId = const Value.absent(),
              }) => MealsCompanion(
                id: id,
                localDate: localDate,
                slotId: slotId,
                loggedAtMs: loggedAtMs,
                tzOffsetMinutes: tzOffsetMinutes,
                sourceText: sourceText,
                savedMealId: savedMealId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String localDate,
                required int slotId,
                required int loggedAtMs,
                required int tzOffsetMinutes,
                Value<String?> sourceText = const Value.absent(),
                Value<int?> savedMealId = const Value.absent(),
              }) => MealsCompanion.insert(
                id: id,
                localDate: localDate,
                slotId: slotId,
                loggedAtMs: loggedAtMs,
                tzOffsetMinutes: tzOffsetMinutes,
                sourceText: sourceText,
                savedMealId: savedMealId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MealsTable, Meal>(table),
                  $$MealsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({slotId = false, savedMealId = false, mealEntriesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (mealEntriesRefs) db.mealEntries,
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
                        if (slotId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.slotId,
                            referencedTable: $$MealsTableReferences
                                ._slotIdTable(db),
                            referencedColumn: $$MealsTableReferences
                                ._slotIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (savedMealId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.savedMealId,
                            referencedTable: $$MealsTableReferences
                                ._savedMealIdTable(db),
                            referencedColumn: $$MealsTableReferences
                                ._savedMealIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (mealEntriesRefs)
                        await $_getPrefetchedDataByColumns<
                          Meal,
                          $MealsTable,
                          MealEntry,
                          $MealEntriesTable
                        >(
                          currentTable: table,
                          referencedTable: $$MealsTableReferences
                              ._mealEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MealsTableReferences(
                                db,
                                table,
                                p0,
                              ).mealEntriesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'meal_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MealsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealsTable,
      Meal,
      $$MealsTableFilterComposer,
      $$MealsTableOrderingComposer,
      $$MealsTableAnnotationComposer,
      $$MealsTableCreateCompanionBuilder,
      $$MealsTableUpdateCompanionBuilder,
      (Meal, $$MealsTableReferences),
      Meal,
      PrefetchHooks Function({
        bool slotId,
        bool savedMealId,
        bool mealEntriesRefs,
      })
    >;
typedef $$MealEntriesTableCreateCompanionBuilder =
    MealEntriesCompanion Function({
      Value<int> id,
      required int mealId,
      required int position,
      required String foodRef,
      required String foodName,
      required double quantity,
      required String unitLabel,
      required double baseQuantity,
      required String baseUnit,
    });
typedef $$MealEntriesTableUpdateCompanionBuilder =
    MealEntriesCompanion Function({
      Value<int> id,
      Value<int> mealId,
      Value<int> position,
      Value<String> foodRef,
      Value<String> foodName,
      Value<double> quantity,
      Value<String> unitLabel,
      Value<double> baseQuantity,
      Value<String> baseUnit,
    });

final class $$MealEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $MealEntriesTable, MealEntry> {
  $$MealEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MealsTable _mealIdTable(_$AppDatabase db) =>
      db.meals.createAlias('meal_entries__meal_id__meals__id');

  $$MealsTableProcessedTableManager get mealId {
    final $_column = $_itemColumn<int>('meal_id')!;

    final manager = $$MealsTableTableManager(
      $_db,
      $_db.meals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mealIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MealEntryNutrientsTable, List<MealEntryNutrient>>
  _mealEntryNutrientsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.mealEntryNutrients,
        aliasName: 'meal_entries__id__meal_entry_nutrients__entry_id',
      );

  $$MealEntryNutrientsTableProcessedTableManager get mealEntryNutrientsRefs {
    final manager = $$MealEntryNutrientsTableTableManager(
      $_db,
      $_db.mealEntryNutrients,
    ).filter((f) => f.entryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _mealEntryNutrientsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MealEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MealEntriesTable> {
  $$MealEntriesTableFilterComposer({
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

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foodRef => $composableBuilder(
    column: $table.foodRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foodName => $composableBuilder(
    column: $table.foodName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitLabel => $composableBuilder(
    column: $table.unitLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get baseQuantity => $composableBuilder(
    column: $table.baseQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUnit => $composableBuilder(
    column: $table.baseUnit,
    builder: (column) => ColumnFilters(column),
  );

  $$MealsTableFilterComposer get mealId {
    final $$MealsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableFilterComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> mealEntryNutrientsRefs(
    Expression<bool> Function($$MealEntryNutrientsTableFilterComposer f) f,
  ) {
    final $$MealEntryNutrientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealEntryNutrients,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealEntryNutrientsTableFilterComposer(
            $db: $db,
            $table: $db.mealEntryNutrients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MealEntriesTable> {
  $$MealEntriesTableOrderingComposer({
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

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodRef => $composableBuilder(
    column: $table.foodRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodName => $composableBuilder(
    column: $table.foodName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitLabel => $composableBuilder(
    column: $table.unitLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get baseQuantity => $composableBuilder(
    column: $table.baseQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUnit => $composableBuilder(
    column: $table.baseUnit,
    builder: (column) => ColumnOrderings(column),
  );

  $$MealsTableOrderingComposer get mealId {
    final $$MealsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableOrderingComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealEntriesTable> {
  $$MealEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get foodRef =>
      $composableBuilder(column: $table.foodRef, builder: (column) => column);

  GeneratedColumn<String> get foodName =>
      $composableBuilder(column: $table.foodName, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unitLabel =>
      $composableBuilder(column: $table.unitLabel, builder: (column) => column);

  GeneratedColumn<double> get baseQuantity => $composableBuilder(
    column: $table.baseQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseUnit =>
      $composableBuilder(column: $table.baseUnit, builder: (column) => column);

  $$MealsTableAnnotationComposer get mealId {
    final $$MealsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableAnnotationComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> mealEntryNutrientsRefs<T extends Object>(
    Expression<T> Function($$MealEntryNutrientsTableAnnotationComposer a) f,
  ) {
    final $$MealEntryNutrientsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.mealEntryNutrients,
          getReferencedColumn: (t) => t.entryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MealEntryNutrientsTableAnnotationComposer(
                $db: $db,
                $table: $db.mealEntryNutrients,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MealEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealEntriesTable,
          MealEntry,
          $$MealEntriesTableFilterComposer,
          $$MealEntriesTableOrderingComposer,
          $$MealEntriesTableAnnotationComposer,
          $$MealEntriesTableCreateCompanionBuilder,
          $$MealEntriesTableUpdateCompanionBuilder,
          (MealEntry, $$MealEntriesTableReferences),
          MealEntry,
          PrefetchHooks Function({bool mealId, bool mealEntryNutrientsRefs})
        > {
  $$MealEntriesTableTableManager(_$AppDatabase db, $MealEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> mealId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> foodRef = const Value.absent(),
                Value<String> foodName = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<String> unitLabel = const Value.absent(),
                Value<double> baseQuantity = const Value.absent(),
                Value<String> baseUnit = const Value.absent(),
              }) => MealEntriesCompanion(
                id: id,
                mealId: mealId,
                position: position,
                foodRef: foodRef,
                foodName: foodName,
                quantity: quantity,
                unitLabel: unitLabel,
                baseQuantity: baseQuantity,
                baseUnit: baseUnit,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int mealId,
                required int position,
                required String foodRef,
                required String foodName,
                required double quantity,
                required String unitLabel,
                required double baseQuantity,
                required String baseUnit,
              }) => MealEntriesCompanion.insert(
                id: id,
                mealId: mealId,
                position: position,
                foodRef: foodRef,
                foodName: foodName,
                quantity: quantity,
                unitLabel: unitLabel,
                baseQuantity: baseQuantity,
                baseUnit: baseUnit,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MealEntriesTable, MealEntry>(table),
                  $$MealEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({mealId = false, mealEntryNutrientsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (mealEntryNutrientsRefs) db.mealEntryNutrients,
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
                        if (mealId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.mealId,
                            referencedTable: $$MealEntriesTableReferences
                                ._mealIdTable(db),
                            referencedColumn: $$MealEntriesTableReferences
                                ._mealIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (mealEntryNutrientsRefs)
                        await $_getPrefetchedDataByColumns<
                          MealEntry,
                          $MealEntriesTable,
                          MealEntryNutrient,
                          $MealEntryNutrientsTable
                        >(
                          currentTable: table,
                          referencedTable: $$MealEntriesTableReferences
                              ._mealEntryNutrientsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MealEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).mealEntryNutrientsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'entry_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MealEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealEntriesTable,
      MealEntry,
      $$MealEntriesTableFilterComposer,
      $$MealEntriesTableOrderingComposer,
      $$MealEntriesTableAnnotationComposer,
      $$MealEntriesTableCreateCompanionBuilder,
      $$MealEntriesTableUpdateCompanionBuilder,
      (MealEntry, $$MealEntriesTableReferences),
      MealEntry,
      PrefetchHooks Function({bool mealId, bool mealEntryNutrientsRefs})
    >;
typedef $$MealEntryNutrientsTableCreateCompanionBuilder =
    MealEntryNutrientsCompanion Function({
      required int entryId,
      required int nutrientId,
      required double amount,
      Value<int> rowid,
    });
typedef $$MealEntryNutrientsTableUpdateCompanionBuilder =
    MealEntryNutrientsCompanion Function({
      Value<int> entryId,
      Value<int> nutrientId,
      Value<double> amount,
      Value<int> rowid,
    });

final class $$MealEntryNutrientsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MealEntryNutrientsTable,
          MealEntryNutrient
        > {
  $$MealEntryNutrientsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MealEntriesTable _entryIdTable(_$AppDatabase db) => db.mealEntries
      .createAlias('meal_entry_nutrients__entry_id__meal_entries__id');

  $$MealEntriesTableProcessedTableManager get entryId {
    final $_column = $_itemColumn<int>('entry_id')!;

    final manager = $$MealEntriesTableTableManager(
      $_db,
      $_db.mealEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MealEntryNutrientsTableFilterComposer
    extends Composer<_$AppDatabase, $MealEntryNutrientsTable> {
  $$MealEntryNutrientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get nutrientId => $composableBuilder(
    column: $table.nutrientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  $$MealEntriesTableFilterComposer get entryId {
    final $$MealEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.mealEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealEntriesTableFilterComposer(
            $db: $db,
            $table: $db.mealEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealEntryNutrientsTableOrderingComposer
    extends Composer<_$AppDatabase, $MealEntryNutrientsTable> {
  $$MealEntryNutrientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get nutrientId => $composableBuilder(
    column: $table.nutrientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  $$MealEntriesTableOrderingComposer get entryId {
    final $$MealEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.mealEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.mealEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealEntryNutrientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealEntryNutrientsTable> {
  $$MealEntryNutrientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get nutrientId => $composableBuilder(
    column: $table.nutrientId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  $$MealEntriesTableAnnotationComposer get entryId {
    final $$MealEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.mealEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.mealEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealEntryNutrientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealEntryNutrientsTable,
          MealEntryNutrient,
          $$MealEntryNutrientsTableFilterComposer,
          $$MealEntryNutrientsTableOrderingComposer,
          $$MealEntryNutrientsTableAnnotationComposer,
          $$MealEntryNutrientsTableCreateCompanionBuilder,
          $$MealEntryNutrientsTableUpdateCompanionBuilder,
          (MealEntryNutrient, $$MealEntryNutrientsTableReferences),
          MealEntryNutrient,
          PrefetchHooks Function({bool entryId})
        > {
  $$MealEntryNutrientsTableTableManager(
    _$AppDatabase db,
    $MealEntryNutrientsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealEntryNutrientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealEntryNutrientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealEntryNutrientsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> entryId = const Value.absent(),
                Value<int> nutrientId = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MealEntryNutrientsCompanion(
                entryId: entryId,
                nutrientId: nutrientId,
                amount: amount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int entryId,
                required int nutrientId,
                required double amount,
                Value<int> rowid = const Value.absent(),
              }) => MealEntryNutrientsCompanion.insert(
                entryId: entryId,
                nutrientId: nutrientId,
                amount: amount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MealEntryNutrientsTable, MealEntryNutrient>(
                    table,
                  ),
                  $$MealEntryNutrientsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({entryId = false}) {
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
                    if (entryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.entryId,
                        referencedTable: $$MealEntryNutrientsTableReferences
                            ._entryIdTable(db),
                        referencedColumn: $$MealEntryNutrientsTableReferences
                            ._entryIdTable(db)
                            .id,
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

typedef $$MealEntryNutrientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealEntryNutrientsTable,
      MealEntryNutrient,
      $$MealEntryNutrientsTableFilterComposer,
      $$MealEntryNutrientsTableOrderingComposer,
      $$MealEntryNutrientsTableAnnotationComposer,
      $$MealEntryNutrientsTableCreateCompanionBuilder,
      $$MealEntryNutrientsTableUpdateCompanionBuilder,
      (MealEntryNutrient, $$MealEntryNutrientsTableReferences),
      MealEntryNutrient,
      PrefetchHooks Function({bool entryId})
    >;
typedef $$SavedMealItemsTableCreateCompanionBuilder =
    SavedMealItemsCompanion Function({
      Value<int> id,
      required int savedMealId,
      required int position,
      required String foodRef,
      required String foodName,
      required double quantity,
      required String unitLabel,
      required double baseQuantity,
      required String baseUnit,
    });
typedef $$SavedMealItemsTableUpdateCompanionBuilder =
    SavedMealItemsCompanion Function({
      Value<int> id,
      Value<int> savedMealId,
      Value<int> position,
      Value<String> foodRef,
      Value<String> foodName,
      Value<double> quantity,
      Value<String> unitLabel,
      Value<double> baseQuantity,
      Value<String> baseUnit,
    });

final class $$SavedMealItemsTableReferences
    extends BaseReferences<_$AppDatabase, $SavedMealItemsTable, SavedMealItem> {
  $$SavedMealItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SavedMealsTable _savedMealIdTable(_$AppDatabase db) => db.savedMeals
      .createAlias('saved_meal_items__saved_meal_id__saved_meals__id');

  $$SavedMealsTableProcessedTableManager get savedMealId {
    final $_column = $_itemColumn<int>('saved_meal_id')!;

    final manager = $$SavedMealsTableTableManager(
      $_db,
      $_db.savedMeals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_savedMealIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $SavedMealItemNutrientsTable,
    List<SavedMealItemNutrient>
  >
  _savedMealItemNutrientsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.savedMealItemNutrients,
        aliasName: 'saved_meal_items__id__saved_meal_item_nutrients__item_id',
      );

  $$SavedMealItemNutrientsTableProcessedTableManager
  get savedMealItemNutrientsRefs {
    final manager = $$SavedMealItemNutrientsTableTableManager(
      $_db,
      $_db.savedMealItemNutrients,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _savedMealItemNutrientsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SavedMealItemsTableFilterComposer
    extends Composer<_$AppDatabase, $SavedMealItemsTable> {
  $$SavedMealItemsTableFilterComposer({
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

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foodRef => $composableBuilder(
    column: $table.foodRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foodName => $composableBuilder(
    column: $table.foodName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitLabel => $composableBuilder(
    column: $table.unitLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get baseQuantity => $composableBuilder(
    column: $table.baseQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUnit => $composableBuilder(
    column: $table.baseUnit,
    builder: (column) => ColumnFilters(column),
  );

  $$SavedMealsTableFilterComposer get savedMealId {
    final $$SavedMealsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.savedMealId,
      referencedTable: $db.savedMeals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealsTableFilterComposer(
            $db: $db,
            $table: $db.savedMeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> savedMealItemNutrientsRefs(
    Expression<bool> Function($$SavedMealItemNutrientsTableFilterComposer f) f,
  ) {
    final $$SavedMealItemNutrientsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.savedMealItemNutrients,
          getReferencedColumn: (t) => t.itemId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SavedMealItemNutrientsTableFilterComposer(
                $db: $db,
                $table: $db.savedMealItemNutrients,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$SavedMealItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedMealItemsTable> {
  $$SavedMealItemsTableOrderingComposer({
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

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodRef => $composableBuilder(
    column: $table.foodRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodName => $composableBuilder(
    column: $table.foodName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitLabel => $composableBuilder(
    column: $table.unitLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get baseQuantity => $composableBuilder(
    column: $table.baseQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUnit => $composableBuilder(
    column: $table.baseUnit,
    builder: (column) => ColumnOrderings(column),
  );

  $$SavedMealsTableOrderingComposer get savedMealId {
    final $$SavedMealsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.savedMealId,
      referencedTable: $db.savedMeals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealsTableOrderingComposer(
            $db: $db,
            $table: $db.savedMeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedMealItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedMealItemsTable> {
  $$SavedMealItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get foodRef =>
      $composableBuilder(column: $table.foodRef, builder: (column) => column);

  GeneratedColumn<String> get foodName =>
      $composableBuilder(column: $table.foodName, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unitLabel =>
      $composableBuilder(column: $table.unitLabel, builder: (column) => column);

  GeneratedColumn<double> get baseQuantity => $composableBuilder(
    column: $table.baseQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseUnit =>
      $composableBuilder(column: $table.baseUnit, builder: (column) => column);

  $$SavedMealsTableAnnotationComposer get savedMealId {
    final $$SavedMealsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.savedMealId,
      referencedTable: $db.savedMeals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedMeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> savedMealItemNutrientsRefs<T extends Object>(
    Expression<T> Function($$SavedMealItemNutrientsTableAnnotationComposer a) f,
  ) {
    final $$SavedMealItemNutrientsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.savedMealItemNutrients,
          getReferencedColumn: (t) => t.itemId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SavedMealItemNutrientsTableAnnotationComposer(
                $db: $db,
                $table: $db.savedMealItemNutrients,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$SavedMealItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedMealItemsTable,
          SavedMealItem,
          $$SavedMealItemsTableFilterComposer,
          $$SavedMealItemsTableOrderingComposer,
          $$SavedMealItemsTableAnnotationComposer,
          $$SavedMealItemsTableCreateCompanionBuilder,
          $$SavedMealItemsTableUpdateCompanionBuilder,
          (SavedMealItem, $$SavedMealItemsTableReferences),
          SavedMealItem,
          PrefetchHooks Function({
            bool savedMealId,
            bool savedMealItemNutrientsRefs,
          })
        > {
  $$SavedMealItemsTableTableManager(
    _$AppDatabase db,
    $SavedMealItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedMealItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedMealItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedMealItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> savedMealId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> foodRef = const Value.absent(),
                Value<String> foodName = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<String> unitLabel = const Value.absent(),
                Value<double> baseQuantity = const Value.absent(),
                Value<String> baseUnit = const Value.absent(),
              }) => SavedMealItemsCompanion(
                id: id,
                savedMealId: savedMealId,
                position: position,
                foodRef: foodRef,
                foodName: foodName,
                quantity: quantity,
                unitLabel: unitLabel,
                baseQuantity: baseQuantity,
                baseUnit: baseUnit,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int savedMealId,
                required int position,
                required String foodRef,
                required String foodName,
                required double quantity,
                required String unitLabel,
                required double baseQuantity,
                required String baseUnit,
              }) => SavedMealItemsCompanion.insert(
                id: id,
                savedMealId: savedMealId,
                position: position,
                foodRef: foodRef,
                foodName: foodName,
                quantity: quantity,
                unitLabel: unitLabel,
                baseQuantity: baseQuantity,
                baseUnit: baseUnit,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavedMealItemsTable, SavedMealItem>(table),
                  $$SavedMealItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({savedMealId = false, savedMealItemNutrientsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (savedMealItemNutrientsRefs) db.savedMealItemNutrients,
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
                        if (savedMealId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.savedMealId,
                            referencedTable: $$SavedMealItemsTableReferences
                                ._savedMealIdTable(db),
                            referencedColumn: $$SavedMealItemsTableReferences
                                ._savedMealIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (savedMealItemNutrientsRefs)
                        await $_getPrefetchedDataByColumns<
                          SavedMealItem,
                          $SavedMealItemsTable,
                          SavedMealItemNutrient,
                          $SavedMealItemNutrientsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SavedMealItemsTableReferences
                              ._savedMealItemNutrientsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SavedMealItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).savedMealItemNutrientsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'item_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SavedMealItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedMealItemsTable,
      SavedMealItem,
      $$SavedMealItemsTableFilterComposer,
      $$SavedMealItemsTableOrderingComposer,
      $$SavedMealItemsTableAnnotationComposer,
      $$SavedMealItemsTableCreateCompanionBuilder,
      $$SavedMealItemsTableUpdateCompanionBuilder,
      (SavedMealItem, $$SavedMealItemsTableReferences),
      SavedMealItem,
      PrefetchHooks Function({
        bool savedMealId,
        bool savedMealItemNutrientsRefs,
      })
    >;
typedef $$SavedMealItemNutrientsTableCreateCompanionBuilder =
    SavedMealItemNutrientsCompanion Function({
      required int itemId,
      required int nutrientId,
      required double amount,
      Value<int> rowid,
    });
typedef $$SavedMealItemNutrientsTableUpdateCompanionBuilder =
    SavedMealItemNutrientsCompanion Function({
      Value<int> itemId,
      Value<int> nutrientId,
      Value<double> amount,
      Value<int> rowid,
    });

final class $$SavedMealItemNutrientsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SavedMealItemNutrientsTable,
          SavedMealItemNutrient
        > {
  $$SavedMealItemNutrientsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SavedMealItemsTable _itemIdTable(_$AppDatabase db) => db
      .savedMealItems
      .createAlias('saved_meal_item_nutrients__item_id__saved_meal_items__id');

  $$SavedMealItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<int>('item_id')!;

    final manager = $$SavedMealItemsTableTableManager(
      $_db,
      $_db.savedMealItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SavedMealItemNutrientsTableFilterComposer
    extends Composer<_$AppDatabase, $SavedMealItemNutrientsTable> {
  $$SavedMealItemNutrientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get nutrientId => $composableBuilder(
    column: $table.nutrientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  $$SavedMealItemsTableFilterComposer get itemId {
    final $$SavedMealItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.savedMealItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealItemsTableFilterComposer(
            $db: $db,
            $table: $db.savedMealItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedMealItemNutrientsTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedMealItemNutrientsTable> {
  $$SavedMealItemNutrientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get nutrientId => $composableBuilder(
    column: $table.nutrientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  $$SavedMealItemsTableOrderingComposer get itemId {
    final $$SavedMealItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.savedMealItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealItemsTableOrderingComposer(
            $db: $db,
            $table: $db.savedMealItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedMealItemNutrientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedMealItemNutrientsTable> {
  $$SavedMealItemNutrientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get nutrientId => $composableBuilder(
    column: $table.nutrientId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  $$SavedMealItemsTableAnnotationComposer get itemId {
    final $$SavedMealItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.savedMealItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedMealItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedMealItemNutrientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedMealItemNutrientsTable,
          SavedMealItemNutrient,
          $$SavedMealItemNutrientsTableFilterComposer,
          $$SavedMealItemNutrientsTableOrderingComposer,
          $$SavedMealItemNutrientsTableAnnotationComposer,
          $$SavedMealItemNutrientsTableCreateCompanionBuilder,
          $$SavedMealItemNutrientsTableUpdateCompanionBuilder,
          (SavedMealItemNutrient, $$SavedMealItemNutrientsTableReferences),
          SavedMealItemNutrient,
          PrefetchHooks Function({bool itemId})
        > {
  $$SavedMealItemNutrientsTableTableManager(
    _$AppDatabase db,
    $SavedMealItemNutrientsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedMealItemNutrientsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SavedMealItemNutrientsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SavedMealItemNutrientsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> itemId = const Value.absent(),
                Value<int> nutrientId = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedMealItemNutrientsCompanion(
                itemId: itemId,
                nutrientId: nutrientId,
                amount: amount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int itemId,
                required int nutrientId,
                required double amount,
                Value<int> rowid = const Value.absent(),
              }) => SavedMealItemNutrientsCompanion.insert(
                itemId: itemId,
                nutrientId: nutrientId,
                amount: amount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $SavedMealItemNutrientsTable,
                    SavedMealItemNutrient
                  >(table),
                  $$SavedMealItemNutrientsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
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
                    if (itemId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.itemId,
                        referencedTable: $$SavedMealItemNutrientsTableReferences
                            ._itemIdTable(db),
                        referencedColumn:
                            $$SavedMealItemNutrientsTableReferences
                                ._itemIdTable(db)
                                .id,
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

typedef $$SavedMealItemNutrientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedMealItemNutrientsTable,
      SavedMealItemNutrient,
      $$SavedMealItemNutrientsTableFilterComposer,
      $$SavedMealItemNutrientsTableOrderingComposer,
      $$SavedMealItemNutrientsTableAnnotationComposer,
      $$SavedMealItemNutrientsTableCreateCompanionBuilder,
      $$SavedMealItemNutrientsTableUpdateCompanionBuilder,
      (SavedMealItemNutrient, $$SavedMealItemNutrientsTableReferences),
      SavedMealItemNutrient,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$AliasesTableCreateCompanionBuilder = AliasesCompanion Function({
  Value<int> id,
  required String phrase,
  required int savedMealId,
});
typedef $$AliasesTableUpdateCompanionBuilder = AliasesCompanion Function({
  Value<int> id,
  Value<String> phrase,
  Value<int> savedMealId,
});

final class $$AliasesTableReferences
    extends BaseReferences<_$AppDatabase, $AliasesTable, Alias> {
  $$AliasesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SavedMealsTable _savedMealIdTable(_$AppDatabase db) =>
      db.savedMeals.createAlias('aliases__saved_meal_id__saved_meals__id');

  $$SavedMealsTableProcessedTableManager get savedMealId {
    final $_column = $_itemColumn<int>('saved_meal_id')!;

    final manager = $$SavedMealsTableTableManager(
      $_db,
      $_db.savedMeals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_savedMealIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AliasesTableFilterComposer
    extends Composer<_$AppDatabase, $AliasesTable> {
  $$AliasesTableFilterComposer({
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

  ColumnFilters<String> get phrase => $composableBuilder(
    column: $table.phrase,
    builder: (column) => ColumnFilters(column),
  );

  $$SavedMealsTableFilterComposer get savedMealId {
    final $$SavedMealsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.savedMealId,
      referencedTable: $db.savedMeals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealsTableFilterComposer(
            $db: $db,
            $table: $db.savedMeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AliasesTableOrderingComposer
    extends Composer<_$AppDatabase, $AliasesTable> {
  $$AliasesTableOrderingComposer({
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

  ColumnOrderings<String> get phrase => $composableBuilder(
    column: $table.phrase,
    builder: (column) => ColumnOrderings(column),
  );

  $$SavedMealsTableOrderingComposer get savedMealId {
    final $$SavedMealsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.savedMealId,
      referencedTable: $db.savedMeals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealsTableOrderingComposer(
            $db: $db,
            $table: $db.savedMeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AliasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AliasesTable> {
  $$AliasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get phrase =>
      $composableBuilder(column: $table.phrase, builder: (column) => column);

  $$SavedMealsTableAnnotationComposer get savedMealId {
    final $$SavedMealsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.savedMealId,
      referencedTable: $db.savedMeals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedMealsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedMeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AliasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AliasesTable,
          Alias,
          $$AliasesTableFilterComposer,
          $$AliasesTableOrderingComposer,
          $$AliasesTableAnnotationComposer,
          $$AliasesTableCreateCompanionBuilder,
          $$AliasesTableUpdateCompanionBuilder,
          (Alias, $$AliasesTableReferences),
          Alias,
          PrefetchHooks Function({bool savedMealId})
        > {
  $$AliasesTableTableManager(_$AppDatabase db, $AliasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AliasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AliasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AliasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> phrase = const Value.absent(),
                Value<int> savedMealId = const Value.absent(),
              }) => AliasesCompanion(
                id: id,
                phrase: phrase,
                savedMealId: savedMealId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String phrase,
                required int savedMealId,
              }) => AliasesCompanion.insert(
                id: id,
                phrase: phrase,
                savedMealId: savedMealId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AliasesTable, Alias>(table),
                  $$AliasesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({savedMealId = false}) {
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
                    if (savedMealId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.savedMealId,
                        referencedTable: $$AliasesTableReferences
                            ._savedMealIdTable(db),
                        referencedColumn: $$AliasesTableReferences
                            ._savedMealIdTable(db)
                            .id,
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

typedef $$AliasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AliasesTable,
      Alias,
      $$AliasesTableFilterComposer,
      $$AliasesTableOrderingComposer,
      $$AliasesTableAnnotationComposer,
      $$AliasesTableCreateCompanionBuilder,
      $$AliasesTableUpdateCompanionBuilder,
      (Alias, $$AliasesTableReferences),
      Alias,
      PrefetchHooks Function({bool savedMealId})
    >;
typedef $$LearnedMatchesTableCreateCompanionBuilder =
    LearnedMatchesCompanion Function({
      required String phrase,
      required String foodRef,
      required String foodName,
      Value<String?> unitLabel,
      Value<double?> quantity,
      Value<int> timesUsed,
      required int updatedAtMs,
      Value<int> rowid,
    });
typedef $$LearnedMatchesTableUpdateCompanionBuilder =
    LearnedMatchesCompanion Function({
      Value<String> phrase,
      Value<String> foodRef,
      Value<String> foodName,
      Value<String?> unitLabel,
      Value<double?> quantity,
      Value<int> timesUsed,
      Value<int> updatedAtMs,
      Value<int> rowid,
    });

class $$LearnedMatchesTableFilterComposer
    extends Composer<_$AppDatabase, $LearnedMatchesTable> {
  $$LearnedMatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get phrase => $composableBuilder(
    column: $table.phrase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foodRef => $composableBuilder(
    column: $table.foodRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foodName => $composableBuilder(
    column: $table.foodName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitLabel => $composableBuilder(
    column: $table.unitLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timesUsed => $composableBuilder(
    column: $table.timesUsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LearnedMatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $LearnedMatchesTable> {
  $$LearnedMatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get phrase => $composableBuilder(
    column: $table.phrase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodRef => $composableBuilder(
    column: $table.foodRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodName => $composableBuilder(
    column: $table.foodName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitLabel => $composableBuilder(
    column: $table.unitLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timesUsed => $composableBuilder(
    column: $table.timesUsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LearnedMatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LearnedMatchesTable> {
  $$LearnedMatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get phrase =>
      $composableBuilder(column: $table.phrase, builder: (column) => column);

  GeneratedColumn<String> get foodRef =>
      $composableBuilder(column: $table.foodRef, builder: (column) => column);

  GeneratedColumn<String> get foodName =>
      $composableBuilder(column: $table.foodName, builder: (column) => column);

  GeneratedColumn<String> get unitLabel =>
      $composableBuilder(column: $table.unitLabel, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<int> get timesUsed =>
      $composableBuilder(column: $table.timesUsed, builder: (column) => column);

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );
}

class $$LearnedMatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LearnedMatchesTable,
          LearnedMatche,
          $$LearnedMatchesTableFilterComposer,
          $$LearnedMatchesTableOrderingComposer,
          $$LearnedMatchesTableAnnotationComposer,
          $$LearnedMatchesTableCreateCompanionBuilder,
          $$LearnedMatchesTableUpdateCompanionBuilder,
          (
            LearnedMatche,
            BaseReferences<_$AppDatabase, $LearnedMatchesTable, LearnedMatche>,
          ),
          LearnedMatche,
          PrefetchHooks Function()
        > {
  $$LearnedMatchesTableTableManager(
    _$AppDatabase db,
    $LearnedMatchesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearnedMatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearnedMatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearnedMatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> phrase = const Value.absent(),
                Value<String> foodRef = const Value.absent(),
                Value<String> foodName = const Value.absent(),
                Value<String?> unitLabel = const Value.absent(),
                Value<double?> quantity = const Value.absent(),
                Value<int> timesUsed = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearnedMatchesCompanion(
                phrase: phrase,
                foodRef: foodRef,
                foodName: foodName,
                unitLabel: unitLabel,
                quantity: quantity,
                timesUsed: timesUsed,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String phrase,
                required String foodRef,
                required String foodName,
                Value<String?> unitLabel = const Value.absent(),
                Value<double?> quantity = const Value.absent(),
                Value<int> timesUsed = const Value.absent(),
                required int updatedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => LearnedMatchesCompanion.insert(
                phrase: phrase,
                foodRef: foodRef,
                foodName: foodName,
                unitLabel: unitLabel,
                quantity: quantity,
                timesUsed: timesUsed,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LearnedMatchesTable, LearnedMatche>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LearnedMatchesTable,
                    LearnedMatche
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LearnedMatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LearnedMatchesTable,
      LearnedMatche,
      $$LearnedMatchesTableFilterComposer,
      $$LearnedMatchesTableOrderingComposer,
      $$LearnedMatchesTableAnnotationComposer,
      $$LearnedMatchesTableCreateCompanionBuilder,
      $$LearnedMatchesTableUpdateCompanionBuilder,
      (
        LearnedMatche,
        BaseReferences<_$AppDatabase, $LearnedMatchesTable, LearnedMatche>,
      ),
      LearnedMatche,
      PrefetchHooks Function()
    >;
typedef $$WeightEntriesTableCreateCompanionBuilder =
    WeightEntriesCompanion Function({
      Value<int> id,
      required String localDate,
      required int measuredAtMs,
      required int tzOffsetMinutes,
      required double weightKg,
      Value<String> source,
      Value<String?> sourceId,
      required int createdAtMs,
      required int updatedAtMs,
      Value<int?> deletedAtMs,
    });
typedef $$WeightEntriesTableUpdateCompanionBuilder =
    WeightEntriesCompanion Function({
      Value<int> id,
      Value<String> localDate,
      Value<int> measuredAtMs,
      Value<int> tzOffsetMinutes,
      Value<double> weightKg,
      Value<String> source,
      Value<String?> sourceId,
      Value<int> createdAtMs,
      Value<int> updatedAtMs,
      Value<int?> deletedAtMs,
    });

class $$WeightEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $WeightEntriesTable> {
  $$WeightEntriesTableFilterComposer({
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

  ColumnFilters<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get measuredAtMs => $composableBuilder(
    column: $table.measuredAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tzOffsetMinutes => $composableBuilder(
    column: $table.tzOffsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WeightEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $WeightEntriesTable> {
  $$WeightEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get measuredAtMs => $composableBuilder(
    column: $table.measuredAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tzOffsetMinutes => $composableBuilder(
    column: $table.tzOffsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WeightEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeightEntriesTable> {
  $$WeightEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumn<int> get measuredAtMs => $composableBuilder(
    column: $table.measuredAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tzOffsetMinutes => $composableBuilder(
    column: $table.tzOffsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => column,
  );
}

class $$WeightEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WeightEntriesTable,
          WeightEntry,
          $$WeightEntriesTableFilterComposer,
          $$WeightEntriesTableOrderingComposer,
          $$WeightEntriesTableAnnotationComposer,
          $$WeightEntriesTableCreateCompanionBuilder,
          $$WeightEntriesTableUpdateCompanionBuilder,
          (
            WeightEntry,
            BaseReferences<_$AppDatabase, $WeightEntriesTable, WeightEntry>,
          ),
          WeightEntry,
          PrefetchHooks Function()
        > {
  $$WeightEntriesTableTableManager(_$AppDatabase db, $WeightEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeightEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeightEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeightEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> localDate = const Value.absent(),
                Value<int> measuredAtMs = const Value.absent(),
                Value<int> tzOffsetMinutes = const Value.absent(),
                Value<double> weightKg = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int?> deletedAtMs = const Value.absent(),
              }) => WeightEntriesCompanion(
                id: id,
                localDate: localDate,
                measuredAtMs: measuredAtMs,
                tzOffsetMinutes: tzOffsetMinutes,
                weightKg: weightKg,
                source: source,
                sourceId: sourceId,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
                deletedAtMs: deletedAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String localDate,
                required int measuredAtMs,
                required int tzOffsetMinutes,
                required double weightKg,
                Value<String> source = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                required int createdAtMs,
                required int updatedAtMs,
                Value<int?> deletedAtMs = const Value.absent(),
              }) => WeightEntriesCompanion.insert(
                id: id,
                localDate: localDate,
                measuredAtMs: measuredAtMs,
                tzOffsetMinutes: tzOffsetMinutes,
                weightKg: weightKg,
                source: source,
                sourceId: sourceId,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
                deletedAtMs: deletedAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WeightEntriesTable, WeightEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $WeightEntriesTable,
                    WeightEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WeightEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WeightEntriesTable,
      WeightEntry,
      $$WeightEntriesTableFilterComposer,
      $$WeightEntriesTableOrderingComposer,
      $$WeightEntriesTableAnnotationComposer,
      $$WeightEntriesTableCreateCompanionBuilder,
      $$WeightEntriesTableUpdateCompanionBuilder,
      (
        WeightEntry,
        BaseReferences<_$AppDatabase, $WeightEntriesTable, WeightEntry>,
      ),
      WeightEntry,
      PrefetchHooks Function()
    >;
typedef $$ExercisesTableCreateCompanionBuilder = ExercisesCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> category,
  Value<String> primaryMuscles,
  Value<String> secondaryMuscles,
  Value<String?> equipment,
  Value<bool> archived,
});
typedef $$ExercisesTableUpdateCompanionBuilder = ExercisesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> category,
  Value<String> primaryMuscles,
  Value<String> secondaryMuscles,
  Value<String?> equipment,
  Value<bool> archived,
});

class $$ExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryMuscles => $composableBuilder(
    column: $table.primaryMuscles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secondaryMuscles => $composableBuilder(
    column: $table.secondaryMuscles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equipment => $composableBuilder(
    column: $table.equipment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryMuscles => $composableBuilder(
    column: $table.primaryMuscles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secondaryMuscles => $composableBuilder(
    column: $table.secondaryMuscles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equipment => $composableBuilder(
    column: $table.equipment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get primaryMuscles => $composableBuilder(
    column: $table.primaryMuscles,
    builder: (column) => column,
  );

  GeneratedColumn<String> get secondaryMuscles => $composableBuilder(
    column: $table.secondaryMuscles,
    builder: (column) => column,
  );

  GeneratedColumn<String> get equipment =>
      $composableBuilder(column: $table.equipment, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);
}

class $$ExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExercisesTable,
          Exercise,
          $$ExercisesTableFilterComposer,
          $$ExercisesTableOrderingComposer,
          $$ExercisesTableAnnotationComposer,
          $$ExercisesTableCreateCompanionBuilder,
          $$ExercisesTableUpdateCompanionBuilder,
          (Exercise, BaseReferences<_$AppDatabase, $ExercisesTable, Exercise>),
          Exercise,
          PrefetchHooks Function()
        > {
  $$ExercisesTableTableManager(_$AppDatabase db, $ExercisesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String> primaryMuscles = const Value.absent(),
                Value<String> secondaryMuscles = const Value.absent(),
                Value<String?> equipment = const Value.absent(),
                Value<bool> archived = const Value.absent(),
              }) => ExercisesCompanion(
                id: id,
                name: name,
                category: category,
                primaryMuscles: primaryMuscles,
                secondaryMuscles: secondaryMuscles,
                equipment: equipment,
                archived: archived,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> category = const Value.absent(),
                Value<String> primaryMuscles = const Value.absent(),
                Value<String> secondaryMuscles = const Value.absent(),
                Value<String?> equipment = const Value.absent(),
                Value<bool> archived = const Value.absent(),
              }) => ExercisesCompanion.insert(
                id: id,
                name: name,
                category: category,
                primaryMuscles: primaryMuscles,
                secondaryMuscles: secondaryMuscles,
                equipment: equipment,
                archived: archived,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExercisesTable, Exercise>(table),
                  BaseReferences<_$AppDatabase, $ExercisesTable, Exercise>(
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

typedef $$ExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExercisesTable,
      Exercise,
      $$ExercisesTableFilterComposer,
      $$ExercisesTableOrderingComposer,
      $$ExercisesTableAnnotationComposer,
      $$ExercisesTableCreateCompanionBuilder,
      $$ExercisesTableUpdateCompanionBuilder,
      (Exercise, BaseReferences<_$AppDatabase, $ExercisesTable, Exercise>),
      Exercise,
      PrefetchHooks Function()
    >;
typedef $$RoutinesTableCreateCompanionBuilder = RoutinesCompanion Function({
  Value<int> id,
  required String name,
  required int position,
  Value<bool> archived,
  required int createdAtMs,
});
typedef $$RoutinesTableUpdateCompanionBuilder = RoutinesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int> position,
  Value<bool> archived,
  Value<int> createdAtMs,
});

final class $$RoutinesTableReferences
    extends BaseReferences<_$AppDatabase, $RoutinesTable, Routine> {
  $$RoutinesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RoutineExercisesTable, List<RoutineExercise>>
  _routineExercisesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.routineExercises,
    aliasName: 'routines__id__routine_exercises__routine_id',
  );

  $$RoutineExercisesTableProcessedTableManager get routineExercisesRefs {
    final manager = $$RoutineExercisesTableTableManager(
      $_db,
      $_db.routineExercises,
    ).filter((f) => f.routineId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _routineExercisesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WorkoutsTable, List<Workout>> _workoutsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.workouts,
    aliasName: 'routines__id__workouts__routine_id',
  );

  $$WorkoutsTableProcessedTableManager get workoutsRefs {
    final manager = $$WorkoutsTableTableManager(
      $_db,
      $_db.workouts,
    ).filter((f) => f.routineId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_workoutsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RoutinesTableFilterComposer
    extends Composer<_$AppDatabase, $RoutinesTable> {
  $$RoutinesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> routineExercisesRefs(
    Expression<bool> Function($$RoutineExercisesTableFilterComposer f) f,
  ) {
    final $$RoutineExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routineExercises,
      getReferencedColumn: (t) => t.routineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutineExercisesTableFilterComposer(
            $db: $db,
            $table: $db.routineExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> workoutsRefs(
    Expression<bool> Function($$WorkoutsTableFilterComposer f) f,
  ) {
    final $$WorkoutsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workouts,
      getReferencedColumn: (t) => t.routineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutsTableFilterComposer(
            $db: $db,
            $table: $db.workouts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoutinesTableOrderingComposer
    extends Composer<_$AppDatabase, $RoutinesTable> {
  $$RoutinesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RoutinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoutinesTable> {
  $$RoutinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  Expression<T> routineExercisesRefs<T extends Object>(
    Expression<T> Function($$RoutineExercisesTableAnnotationComposer a) f,
  ) {
    final $$RoutineExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routineExercises,
      getReferencedColumn: (t) => t.routineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutineExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.routineExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> workoutsRefs<T extends Object>(
    Expression<T> Function($$WorkoutsTableAnnotationComposer a) f,
  ) {
    final $$WorkoutsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workouts,
      getReferencedColumn: (t) => t.routineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutsTableAnnotationComposer(
            $db: $db,
            $table: $db.workouts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoutinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoutinesTable,
          Routine,
          $$RoutinesTableFilterComposer,
          $$RoutinesTableOrderingComposer,
          $$RoutinesTableAnnotationComposer,
          $$RoutinesTableCreateCompanionBuilder,
          $$RoutinesTableUpdateCompanionBuilder,
          (Routine, $$RoutinesTableReferences),
          Routine,
          PrefetchHooks Function({bool routineExercisesRefs, bool workoutsRefs})
        > {
  $$RoutinesTableTableManager(_$AppDatabase db, $RoutinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
              }) => RoutinesCompanion(
                id: id,
                name: name,
                position: position,
                archived: archived,
                createdAtMs: createdAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int position,
                Value<bool> archived = const Value.absent(),
                required int createdAtMs,
              }) => RoutinesCompanion.insert(
                id: id,
                name: name,
                position: position,
                archived: archived,
                createdAtMs: createdAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RoutinesTable, Routine>(table),
                  $$RoutinesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({routineExercisesRefs = false, workoutsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (routineExercisesRefs) db.routineExercises,
                    if (workoutsRefs) db.workouts,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (routineExercisesRefs)
                        await $_getPrefetchedDataByColumns<
                          Routine,
                          $RoutinesTable,
                          RoutineExercise,
                          $RoutineExercisesTable
                        >(
                          currentTable: table,
                          referencedTable: $$RoutinesTableReferences
                              ._routineExercisesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RoutinesTableReferences(
                                db,
                                table,
                                p0,
                              ).routineExercisesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'routine_id',
                          typedResults: items,
                        ),
                      if (workoutsRefs)
                        await $_getPrefetchedDataByColumns<
                          Routine,
                          $RoutinesTable,
                          Workout,
                          $WorkoutsTable
                        >(
                          currentTable: table,
                          referencedTable: $$RoutinesTableReferences
                              ._workoutsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RoutinesTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'routine_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RoutinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoutinesTable,
      Routine,
      $$RoutinesTableFilterComposer,
      $$RoutinesTableOrderingComposer,
      $$RoutinesTableAnnotationComposer,
      $$RoutinesTableCreateCompanionBuilder,
      $$RoutinesTableUpdateCompanionBuilder,
      (Routine, $$RoutinesTableReferences),
      Routine,
      PrefetchHooks Function({bool routineExercisesRefs, bool workoutsRefs})
    >;
typedef $$RoutineExercisesTableCreateCompanionBuilder =
    RoutineExercisesCompanion Function({
      Value<int> id,
      required int routineId,
      required int position,
      required String exerciseRef,
      required String exerciseName,
      Value<int?> targetSets,
      Value<int?> restSeconds,
    });
typedef $$RoutineExercisesTableUpdateCompanionBuilder =
    RoutineExercisesCompanion Function({
      Value<int> id,
      Value<int> routineId,
      Value<int> position,
      Value<String> exerciseRef,
      Value<String> exerciseName,
      Value<int?> targetSets,
      Value<int?> restSeconds,
    });

final class $$RoutineExercisesTableReferences
    extends
        BaseReferences<_$AppDatabase, $RoutineExercisesTable, RoutineExercise> {
  $$RoutineExercisesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RoutinesTable _routineIdTable(_$AppDatabase db) =>
      db.routines.createAlias('routine_exercises__routine_id__routines__id');

  $$RoutinesTableProcessedTableManager get routineId {
    final $_column = $_itemColumn<int>('routine_id')!;

    final manager = $$RoutinesTableTableManager(
      $_db,
      $_db.routines,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_routineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RoutineExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $RoutineExercisesTable> {
  $$RoutineExercisesTableFilterComposer({
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

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseRef => $composableBuilder(
    column: $table.exerciseRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseName => $composableBuilder(
    column: $table.exerciseName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetSets => $composableBuilder(
    column: $table.targetSets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnFilters(column),
  );

  $$RoutinesTableFilterComposer get routineId {
    final $$RoutinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableFilterComposer(
            $db: $db,
            $table: $db.routines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoutineExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $RoutineExercisesTable> {
  $$RoutineExercisesTableOrderingComposer({
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

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseRef => $composableBuilder(
    column: $table.exerciseRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseName => $composableBuilder(
    column: $table.exerciseName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetSets => $composableBuilder(
    column: $table.targetSets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  $$RoutinesTableOrderingComposer get routineId {
    final $$RoutinesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableOrderingComposer(
            $db: $db,
            $table: $db.routines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoutineExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoutineExercisesTable> {
  $$RoutineExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get exerciseRef => $composableBuilder(
    column: $table.exerciseRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exerciseName => $composableBuilder(
    column: $table.exerciseName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetSets => $composableBuilder(
    column: $table.targetSets,
    builder: (column) => column,
  );

  GeneratedColumn<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => column,
  );

  $$RoutinesTableAnnotationComposer get routineId {
    final $$RoutinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableAnnotationComposer(
            $db: $db,
            $table: $db.routines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoutineExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoutineExercisesTable,
          RoutineExercise,
          $$RoutineExercisesTableFilterComposer,
          $$RoutineExercisesTableOrderingComposer,
          $$RoutineExercisesTableAnnotationComposer,
          $$RoutineExercisesTableCreateCompanionBuilder,
          $$RoutineExercisesTableUpdateCompanionBuilder,
          (RoutineExercise, $$RoutineExercisesTableReferences),
          RoutineExercise,
          PrefetchHooks Function({bool routineId})
        > {
  $$RoutineExercisesTableTableManager(
    _$AppDatabase db,
    $RoutineExercisesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutineExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutineExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutineExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> routineId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> exerciseRef = const Value.absent(),
                Value<String> exerciseName = const Value.absent(),
                Value<int?> targetSets = const Value.absent(),
                Value<int?> restSeconds = const Value.absent(),
              }) => RoutineExercisesCompanion(
                id: id,
                routineId: routineId,
                position: position,
                exerciseRef: exerciseRef,
                exerciseName: exerciseName,
                targetSets: targetSets,
                restSeconds: restSeconds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int routineId,
                required int position,
                required String exerciseRef,
                required String exerciseName,
                Value<int?> targetSets = const Value.absent(),
                Value<int?> restSeconds = const Value.absent(),
              }) => RoutineExercisesCompanion.insert(
                id: id,
                routineId: routineId,
                position: position,
                exerciseRef: exerciseRef,
                exerciseName: exerciseName,
                targetSets: targetSets,
                restSeconds: restSeconds,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RoutineExercisesTable, RoutineExercise>(table),
                  $$RoutineExercisesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({routineId = false}) {
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
                    if (routineId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.routineId,
                        referencedTable: $$RoutineExercisesTableReferences
                            ._routineIdTable(db),
                        referencedColumn: $$RoutineExercisesTableReferences
                            ._routineIdTable(db)
                            .id,
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

typedef $$RoutineExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoutineExercisesTable,
      RoutineExercise,
      $$RoutineExercisesTableFilterComposer,
      $$RoutineExercisesTableOrderingComposer,
      $$RoutineExercisesTableAnnotationComposer,
      $$RoutineExercisesTableCreateCompanionBuilder,
      $$RoutineExercisesTableUpdateCompanionBuilder,
      (RoutineExercise, $$RoutineExercisesTableReferences),
      RoutineExercise,
      PrefetchHooks Function({bool routineId})
    >;
typedef $$WorkoutsTableCreateCompanionBuilder = WorkoutsCompanion Function({
  Value<int> id,
  required String localDate,
  required int startedAtMs,
  Value<int?> endedAtMs,
  required int tzOffsetMinutes,
  Value<int?> routineId,
  Value<double?> kcalEstimated,
  Value<double?> kcalOverride,
  Value<String?> note,
});
typedef $$WorkoutsTableUpdateCompanionBuilder = WorkoutsCompanion Function({
  Value<int> id,
  Value<String> localDate,
  Value<int> startedAtMs,
  Value<int?> endedAtMs,
  Value<int> tzOffsetMinutes,
  Value<int?> routineId,
  Value<double?> kcalEstimated,
  Value<double?> kcalOverride,
  Value<String?> note,
});

final class $$WorkoutsTableReferences
    extends BaseReferences<_$AppDatabase, $WorkoutsTable, Workout> {
  $$WorkoutsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RoutinesTable _routineIdTable(_$AppDatabase db) =>
      db.routines.createAlias('workouts__routine_id__routines__id');

  $$RoutinesTableProcessedTableManager? get routineId {
    final $_column = $_itemColumn<int>('routine_id');
    if ($_column == null) return null;
    final manager = $$RoutinesTableTableManager(
      $_db,
      $_db.routines,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_routineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$WorkoutSetsTable, List<WorkoutSet>>
  _workoutSetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workoutSets,
    aliasName: 'workouts__id__workout_sets__workout_id',
  );

  $$WorkoutSetsTableProcessedTableManager get workoutSetsRefs {
    final manager = $$WorkoutSetsTableTableManager(
      $_db,
      $_db.workoutSets,
    ).filter((f) => f.workoutId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_workoutSetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkoutsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutsTable> {
  $$WorkoutsTableFilterComposer({
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

  ColumnFilters<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAtMs => $composableBuilder(
    column: $table.endedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tzOffsetMinutes => $composableBuilder(
    column: $table.tzOffsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcalEstimated => $composableBuilder(
    column: $table.kcalEstimated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcalOverride => $composableBuilder(
    column: $table.kcalOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$RoutinesTableFilterComposer get routineId {
    final $$RoutinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableFilterComposer(
            $db: $db,
            $table: $db.routines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> workoutSetsRefs(
    Expression<bool> Function($$WorkoutSetsTableFilterComposer f) f,
  ) {
    final $$WorkoutSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.workoutId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableFilterComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutsTable> {
  $$WorkoutsTableOrderingComposer({
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

  ColumnOrderings<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAtMs => $composableBuilder(
    column: $table.endedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tzOffsetMinutes => $composableBuilder(
    column: $table.tzOffsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcalEstimated => $composableBuilder(
    column: $table.kcalEstimated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcalOverride => $composableBuilder(
    column: $table.kcalOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$RoutinesTableOrderingComposer get routineId {
    final $$RoutinesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableOrderingComposer(
            $db: $db,
            $table: $db.routines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutsTable> {
  $$WorkoutsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumn<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endedAtMs =>
      $composableBuilder(column: $table.endedAtMs, builder: (column) => column);

  GeneratedColumn<int> get tzOffsetMinutes => $composableBuilder(
    column: $table.tzOffsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<double> get kcalEstimated => $composableBuilder(
    column: $table.kcalEstimated,
    builder: (column) => column,
  );

  GeneratedColumn<double> get kcalOverride => $composableBuilder(
    column: $table.kcalOverride,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$RoutinesTableAnnotationComposer get routineId {
    final $$RoutinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableAnnotationComposer(
            $db: $db,
            $table: $db.routines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> workoutSetsRefs<T extends Object>(
    Expression<T> Function($$WorkoutSetsTableAnnotationComposer a) f,
  ) {
    final $$WorkoutSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.workoutId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutsTable,
          Workout,
          $$WorkoutsTableFilterComposer,
          $$WorkoutsTableOrderingComposer,
          $$WorkoutsTableAnnotationComposer,
          $$WorkoutsTableCreateCompanionBuilder,
          $$WorkoutsTableUpdateCompanionBuilder,
          (Workout, $$WorkoutsTableReferences),
          Workout,
          PrefetchHooks Function({bool routineId, bool workoutSetsRefs})
        > {
  $$WorkoutsTableTableManager(_$AppDatabase db, $WorkoutsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> localDate = const Value.absent(),
                Value<int> startedAtMs = const Value.absent(),
                Value<int?> endedAtMs = const Value.absent(),
                Value<int> tzOffsetMinutes = const Value.absent(),
                Value<int?> routineId = const Value.absent(),
                Value<double?> kcalEstimated = const Value.absent(),
                Value<double?> kcalOverride = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => WorkoutsCompanion(
                id: id,
                localDate: localDate,
                startedAtMs: startedAtMs,
                endedAtMs: endedAtMs,
                tzOffsetMinutes: tzOffsetMinutes,
                routineId: routineId,
                kcalEstimated: kcalEstimated,
                kcalOverride: kcalOverride,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String localDate,
                required int startedAtMs,
                Value<int?> endedAtMs = const Value.absent(),
                required int tzOffsetMinutes,
                Value<int?> routineId = const Value.absent(),
                Value<double?> kcalEstimated = const Value.absent(),
                Value<double?> kcalOverride = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => WorkoutsCompanion.insert(
                id: id,
                localDate: localDate,
                startedAtMs: startedAtMs,
                endedAtMs: endedAtMs,
                tzOffsetMinutes: tzOffsetMinutes,
                routineId: routineId,
                kcalEstimated: kcalEstimated,
                kcalOverride: kcalOverride,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkoutsTable, Workout>(table),
                  $$WorkoutsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({routineId = false, workoutSetsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (workoutSetsRefs) db.workoutSets,
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
                        if (routineId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.routineId,
                            referencedTable: $$WorkoutsTableReferences
                                ._routineIdTable(db),
                            referencedColumn: $$WorkoutsTableReferences
                                ._routineIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (workoutSetsRefs)
                        await $_getPrefetchedDataByColumns<
                          Workout,
                          $WorkoutsTable,
                          WorkoutSet,
                          $WorkoutSetsTable
                        >(
                          currentTable: table,
                          referencedTable: $$WorkoutsTableReferences
                              ._workoutSetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkoutsTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutSetsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'workout_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WorkoutsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutsTable,
      Workout,
      $$WorkoutsTableFilterComposer,
      $$WorkoutsTableOrderingComposer,
      $$WorkoutsTableAnnotationComposer,
      $$WorkoutsTableCreateCompanionBuilder,
      $$WorkoutsTableUpdateCompanionBuilder,
      (Workout, $$WorkoutsTableReferences),
      Workout,
      PrefetchHooks Function({bool routineId, bool workoutSetsRefs})
    >;
typedef $$WorkoutSetsTableCreateCompanionBuilder =
    WorkoutSetsCompanion Function({
      Value<int> id,
      required int workoutId,
      required int position,
      required String exerciseRef,
      required String exerciseName,
      Value<double?> weightKg,
      Value<int?> reps,
      Value<int?> completedAtMs,
    });
typedef $$WorkoutSetsTableUpdateCompanionBuilder =
    WorkoutSetsCompanion Function({
      Value<int> id,
      Value<int> workoutId,
      Value<int> position,
      Value<String> exerciseRef,
      Value<String> exerciseName,
      Value<double?> weightKg,
      Value<int?> reps,
      Value<int?> completedAtMs,
    });

final class $$WorkoutSetsTableReferences
    extends BaseReferences<_$AppDatabase, $WorkoutSetsTable, WorkoutSet> {
  $$WorkoutSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WorkoutsTable _workoutIdTable(_$AppDatabase db) =>
      db.workouts.createAlias('workout_sets__workout_id__workouts__id');

  $$WorkoutsTableProcessedTableManager get workoutId {
    final $_column = $_itemColumn<int>('workout_id')!;

    final manager = $$WorkoutsTableTableManager(
      $_db,
      $_db.workouts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workoutIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorkoutSetsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableFilterComposer({
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

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseRef => $composableBuilder(
    column: $table.exerciseRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseName => $composableBuilder(
    column: $table.exerciseName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAtMs => $composableBuilder(
    column: $table.completedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkoutsTableFilterComposer get workoutId {
    final $$WorkoutsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutId,
      referencedTable: $db.workouts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutsTableFilterComposer(
            $db: $db,
            $table: $db.workouts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutSetsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableOrderingComposer({
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

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseRef => $composableBuilder(
    column: $table.exerciseRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseName => $composableBuilder(
    column: $table.exerciseName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAtMs => $composableBuilder(
    column: $table.completedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkoutsTableOrderingComposer get workoutId {
    final $$WorkoutsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutId,
      referencedTable: $db.workouts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutsTableOrderingComposer(
            $db: $db,
            $table: $db.workouts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutSetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get exerciseRef => $composableBuilder(
    column: $table.exerciseRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exerciseName => $composableBuilder(
    column: $table.exerciseName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get completedAtMs => $composableBuilder(
    column: $table.completedAtMs,
    builder: (column) => column,
  );

  $$WorkoutsTableAnnotationComposer get workoutId {
    final $$WorkoutsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutId,
      referencedTable: $db.workouts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutsTableAnnotationComposer(
            $db: $db,
            $table: $db.workouts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutSetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutSetsTable,
          WorkoutSet,
          $$WorkoutSetsTableFilterComposer,
          $$WorkoutSetsTableOrderingComposer,
          $$WorkoutSetsTableAnnotationComposer,
          $$WorkoutSetsTableCreateCompanionBuilder,
          $$WorkoutSetsTableUpdateCompanionBuilder,
          (WorkoutSet, $$WorkoutSetsTableReferences),
          WorkoutSet,
          PrefetchHooks Function({bool workoutId})
        > {
  $$WorkoutSetsTableTableManager(_$AppDatabase db, $WorkoutSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> workoutId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> exerciseRef = const Value.absent(),
                Value<String> exerciseName = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<int?> reps = const Value.absent(),
                Value<int?> completedAtMs = const Value.absent(),
              }) => WorkoutSetsCompanion(
                id: id,
                workoutId: workoutId,
                position: position,
                exerciseRef: exerciseRef,
                exerciseName: exerciseName,
                weightKg: weightKg,
                reps: reps,
                completedAtMs: completedAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int workoutId,
                required int position,
                required String exerciseRef,
                required String exerciseName,
                Value<double?> weightKg = const Value.absent(),
                Value<int?> reps = const Value.absent(),
                Value<int?> completedAtMs = const Value.absent(),
              }) => WorkoutSetsCompanion.insert(
                id: id,
                workoutId: workoutId,
                position: position,
                exerciseRef: exerciseRef,
                exerciseName: exerciseName,
                weightKg: weightKg,
                reps: reps,
                completedAtMs: completedAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkoutSetsTable, WorkoutSet>(table),
                  $$WorkoutSetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({workoutId = false}) {
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
                    if (workoutId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.workoutId,
                        referencedTable: $$WorkoutSetsTableReferences
                            ._workoutIdTable(db),
                        referencedColumn: $$WorkoutSetsTableReferences
                            ._workoutIdTable(db)
                            .id,
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

typedef $$WorkoutSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutSetsTable,
      WorkoutSet,
      $$WorkoutSetsTableFilterComposer,
      $$WorkoutSetsTableOrderingComposer,
      $$WorkoutSetsTableAnnotationComposer,
      $$WorkoutSetsTableCreateCompanionBuilder,
      $$WorkoutSetsTableUpdateCompanionBuilder,
      (WorkoutSet, $$WorkoutSetsTableReferences),
      WorkoutSet,
      PrefetchHooks Function({bool workoutId})
    >;
typedef $$CardioSessionsTableCreateCompanionBuilder =
    CardioSessionsCompanion Function({
      Value<int> id,
      required String localDate,
      required int startedAtMs,
      required int tzOffsetMinutes,
      Value<String?> activityCode,
      required String activityName,
      Value<double?> met,
      required int durationSeconds,
      Value<double?> distanceMeters,
      Value<int?> avgHeartRate,
      Value<double?> kcalEstimated,
      Value<double?> kcalOverride,
      Value<String> source,
      Value<String?> sourceId,
      Value<int?> deletedAtMs,
    });
typedef $$CardioSessionsTableUpdateCompanionBuilder =
    CardioSessionsCompanion Function({
      Value<int> id,
      Value<String> localDate,
      Value<int> startedAtMs,
      Value<int> tzOffsetMinutes,
      Value<String?> activityCode,
      Value<String> activityName,
      Value<double?> met,
      Value<int> durationSeconds,
      Value<double?> distanceMeters,
      Value<int?> avgHeartRate,
      Value<double?> kcalEstimated,
      Value<double?> kcalOverride,
      Value<String> source,
      Value<String?> sourceId,
      Value<int?> deletedAtMs,
    });

class $$CardioSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $CardioSessionsTable> {
  $$CardioSessionsTableFilterComposer({
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

  ColumnFilters<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tzOffsetMinutes => $composableBuilder(
    column: $table.tzOffsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityName => $composableBuilder(
    column: $table.activityName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get met => $composableBuilder(
    column: $table.met,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get avgHeartRate => $composableBuilder(
    column: $table.avgHeartRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcalEstimated => $composableBuilder(
    column: $table.kcalEstimated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcalOverride => $composableBuilder(
    column: $table.kcalOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CardioSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CardioSessionsTable> {
  $$CardioSessionsTableOrderingComposer({
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

  ColumnOrderings<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tzOffsetMinutes => $composableBuilder(
    column: $table.tzOffsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityName => $composableBuilder(
    column: $table.activityName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get met => $composableBuilder(
    column: $table.met,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get avgHeartRate => $composableBuilder(
    column: $table.avgHeartRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcalEstimated => $composableBuilder(
    column: $table.kcalEstimated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcalOverride => $composableBuilder(
    column: $table.kcalOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CardioSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardioSessionsTable> {
  $$CardioSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumn<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tzOffsetMinutes => $composableBuilder(
    column: $table.tzOffsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activityName => $composableBuilder(
    column: $table.activityName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get met =>
      $composableBuilder(column: $table.met, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get avgHeartRate => $composableBuilder(
    column: $table.avgHeartRate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get kcalEstimated => $composableBuilder(
    column: $table.kcalEstimated,
    builder: (column) => column,
  );

  GeneratedColumn<double> get kcalOverride => $composableBuilder(
    column: $table.kcalOverride,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => column,
  );
}

class $$CardioSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardioSessionsTable,
          CardioSession,
          $$CardioSessionsTableFilterComposer,
          $$CardioSessionsTableOrderingComposer,
          $$CardioSessionsTableAnnotationComposer,
          $$CardioSessionsTableCreateCompanionBuilder,
          $$CardioSessionsTableUpdateCompanionBuilder,
          (
            CardioSession,
            BaseReferences<_$AppDatabase, $CardioSessionsTable, CardioSession>,
          ),
          CardioSession,
          PrefetchHooks Function()
        > {
  $$CardioSessionsTableTableManager(
    _$AppDatabase db,
    $CardioSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardioSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardioSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardioSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> localDate = const Value.absent(),
                Value<int> startedAtMs = const Value.absent(),
                Value<int> tzOffsetMinutes = const Value.absent(),
                Value<String?> activityCode = const Value.absent(),
                Value<String> activityName = const Value.absent(),
                Value<double?> met = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<double?> distanceMeters = const Value.absent(),
                Value<int?> avgHeartRate = const Value.absent(),
                Value<double?> kcalEstimated = const Value.absent(),
                Value<double?> kcalOverride = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<int?> deletedAtMs = const Value.absent(),
              }) => CardioSessionsCompanion(
                id: id,
                localDate: localDate,
                startedAtMs: startedAtMs,
                tzOffsetMinutes: tzOffsetMinutes,
                activityCode: activityCode,
                activityName: activityName,
                met: met,
                durationSeconds: durationSeconds,
                distanceMeters: distanceMeters,
                avgHeartRate: avgHeartRate,
                kcalEstimated: kcalEstimated,
                kcalOverride: kcalOverride,
                source: source,
                sourceId: sourceId,
                deletedAtMs: deletedAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String localDate,
                required int startedAtMs,
                required int tzOffsetMinutes,
                Value<String?> activityCode = const Value.absent(),
                required String activityName,
                Value<double?> met = const Value.absent(),
                required int durationSeconds,
                Value<double?> distanceMeters = const Value.absent(),
                Value<int?> avgHeartRate = const Value.absent(),
                Value<double?> kcalEstimated = const Value.absent(),
                Value<double?> kcalOverride = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<int?> deletedAtMs = const Value.absent(),
              }) => CardioSessionsCompanion.insert(
                id: id,
                localDate: localDate,
                startedAtMs: startedAtMs,
                tzOffsetMinutes: tzOffsetMinutes,
                activityCode: activityCode,
                activityName: activityName,
                met: met,
                durationSeconds: durationSeconds,
                distanceMeters: distanceMeters,
                avgHeartRate: avgHeartRate,
                kcalEstimated: kcalEstimated,
                kcalOverride: kcalOverride,
                source: source,
                sourceId: sourceId,
                deletedAtMs: deletedAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CardioSessionsTable, CardioSession>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CardioSessionsTable,
                    CardioSession
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CardioSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardioSessionsTable,
      CardioSession,
      $$CardioSessionsTableFilterComposer,
      $$CardioSessionsTableOrderingComposer,
      $$CardioSessionsTableAnnotationComposer,
      $$CardioSessionsTableCreateCompanionBuilder,
      $$CardioSessionsTableUpdateCompanionBuilder,
      (
        CardioSession,
        BaseReferences<_$AppDatabase, $CardioSessionsTable, CardioSession>,
      ),
      CardioSession,
      PrefetchHooks Function()
    >;
typedef $$ProfileTableCreateCompanionBuilder = ProfileCompanion Function({
  Value<int> id,
  Value<String?> sex,
  Value<String?> birthDate,
  Value<double?> heightCm,
});
typedef $$ProfileTableUpdateCompanionBuilder = ProfileCompanion Function({
  Value<int> id,
  Value<String?> sex,
  Value<String?> birthDate,
  Value<double?> heightCm,
});

class $$ProfileTableFilterComposer
    extends Composer<_$AppDatabase, $ProfileTable> {
  $$ProfileTableFilterComposer({
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

  ColumnFilters<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfileTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfileTable> {
  $$ProfileTableOrderingComposer({
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

  ColumnOrderings<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfileTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfileTable> {
  $$ProfileTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sex =>
      $composableBuilder(column: $table.sex, builder: (column) => column);

  GeneratedColumn<String> get birthDate =>
      $composableBuilder(column: $table.birthDate, builder: (column) => column);

  GeneratedColumn<double> get heightCm =>
      $composableBuilder(column: $table.heightCm, builder: (column) => column);
}

class $$ProfileTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfileTable,
          ProfileData,
          $$ProfileTableFilterComposer,
          $$ProfileTableOrderingComposer,
          $$ProfileTableAnnotationComposer,
          $$ProfileTableCreateCompanionBuilder,
          $$ProfileTableUpdateCompanionBuilder,
          (
            ProfileData,
            BaseReferences<_$AppDatabase, $ProfileTable, ProfileData>,
          ),
          ProfileData,
          PrefetchHooks Function()
        > {
  $$ProfileTableTableManager(_$AppDatabase db, $ProfileTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfileTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfileTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfileTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> sex = const Value.absent(),
                Value<String?> birthDate = const Value.absent(),
                Value<double?> heightCm = const Value.absent(),
              }) => ProfileCompanion(
                id: id,
                sex: sex,
                birthDate: birthDate,
                heightCm: heightCm,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> sex = const Value.absent(),
                Value<String?> birthDate = const Value.absent(),
                Value<double?> heightCm = const Value.absent(),
              }) => ProfileCompanion.insert(
                id: id,
                sex: sex,
                birthDate: birthDate,
                heightCm: heightCm,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProfileTable, ProfileData>(table),
                  BaseReferences<_$AppDatabase, $ProfileTable, ProfileData>(
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

typedef $$ProfileTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfileTable,
      ProfileData,
      $$ProfileTableFilterComposer,
      $$ProfileTableOrderingComposer,
      $$ProfileTableAnnotationComposer,
      $$ProfileTableCreateCompanionBuilder,
      $$ProfileTableUpdateCompanionBuilder,
      (ProfileData, BaseReferences<_$AppDatabase, $ProfileTable, ProfileData>),
      ProfileData,
      PrefetchHooks Function()
    >;
typedef $$GoalsTableCreateCompanionBuilder = GoalsCompanion Function({
  Value<int> id,
  required String effectiveFrom,
  required String calorieMode,
  Value<int?> calories,
  required double activityFactor,
  required double targetKgPerWeek,
  Value<int> exerciseAddBackPercent,
  required String macroMode,
  Value<double?> proteinTarget,
  Value<double?> carbsTarget,
  Value<double?> fatTarget,
});
typedef $$GoalsTableUpdateCompanionBuilder = GoalsCompanion Function({
  Value<int> id,
  Value<String> effectiveFrom,
  Value<String> calorieMode,
  Value<int?> calories,
  Value<double> activityFactor,
  Value<double> targetKgPerWeek,
  Value<int> exerciseAddBackPercent,
  Value<String> macroMode,
  Value<double?> proteinTarget,
  Value<double?> carbsTarget,
  Value<double?> fatTarget,
});

final class $$GoalsTableReferences
    extends BaseReferences<_$AppDatabase, $GoalsTable, Goal> {
  $$GoalsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$GoalNutrientsTable, List<GoalNutrient>>
  _goalNutrientsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.goalNutrients,
    aliasName: 'goals__id__goal_nutrients__goal_id',
  );

  $$GoalNutrientsTableProcessedTableManager get goalNutrientsRefs {
    final manager = $$GoalNutrientsTableTableManager(
      $_db,
      $_db.goalNutrients,
    ).filter((f) => f.goalId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_goalNutrientsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GoalsTableFilterComposer extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableFilterComposer({
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

  ColumnFilters<String> get effectiveFrom => $composableBuilder(
    column: $table.effectiveFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calorieMode => $composableBuilder(
    column: $table.calorieMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get activityFactor => $composableBuilder(
    column: $table.activityFactor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetKgPerWeek => $composableBuilder(
    column: $table.targetKgPerWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exerciseAddBackPercent => $composableBuilder(
    column: $table.exerciseAddBackPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get macroMode => $composableBuilder(
    column: $table.macroMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get proteinTarget => $composableBuilder(
    column: $table.proteinTarget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbsTarget => $composableBuilder(
    column: $table.carbsTarget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fatTarget => $composableBuilder(
    column: $table.fatTarget,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> goalNutrientsRefs(
    Expression<bool> Function($$GoalNutrientsTableFilterComposer f) f,
  ) {
    final $$GoalNutrientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.goalNutrients,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalNutrientsTableFilterComposer(
            $db: $db,
            $table: $db.goalNutrients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GoalsTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableOrderingComposer({
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

  ColumnOrderings<String> get effectiveFrom => $composableBuilder(
    column: $table.effectiveFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calorieMode => $composableBuilder(
    column: $table.calorieMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get activityFactor => $composableBuilder(
    column: $table.activityFactor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetKgPerWeek => $composableBuilder(
    column: $table.targetKgPerWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exerciseAddBackPercent => $composableBuilder(
    column: $table.exerciseAddBackPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get macroMode => $composableBuilder(
    column: $table.macroMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get proteinTarget => $composableBuilder(
    column: $table.proteinTarget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbsTarget => $composableBuilder(
    column: $table.carbsTarget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fatTarget => $composableBuilder(
    column: $table.fatTarget,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GoalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get effectiveFrom => $composableBuilder(
    column: $table.effectiveFrom,
    builder: (column) => column,
  );

  GeneratedColumn<String> get calorieMode => $composableBuilder(
    column: $table.calorieMode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get calories =>
      $composableBuilder(column: $table.calories, builder: (column) => column);

  GeneratedColumn<double> get activityFactor => $composableBuilder(
    column: $table.activityFactor,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetKgPerWeek => $composableBuilder(
    column: $table.targetKgPerWeek,
    builder: (column) => column,
  );

  GeneratedColumn<int> get exerciseAddBackPercent => $composableBuilder(
    column: $table.exerciseAddBackPercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get macroMode =>
      $composableBuilder(column: $table.macroMode, builder: (column) => column);

  GeneratedColumn<double> get proteinTarget => $composableBuilder(
    column: $table.proteinTarget,
    builder: (column) => column,
  );

  GeneratedColumn<double> get carbsTarget => $composableBuilder(
    column: $table.carbsTarget,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fatTarget =>
      $composableBuilder(column: $table.fatTarget, builder: (column) => column);

  Expression<T> goalNutrientsRefs<T extends Object>(
    Expression<T> Function($$GoalNutrientsTableAnnotationComposer a) f,
  ) {
    final $$GoalNutrientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.goalNutrients,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalNutrientsTableAnnotationComposer(
            $db: $db,
            $table: $db.goalNutrients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GoalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalsTable,
          Goal,
          $$GoalsTableFilterComposer,
          $$GoalsTableOrderingComposer,
          $$GoalsTableAnnotationComposer,
          $$GoalsTableCreateCompanionBuilder,
          $$GoalsTableUpdateCompanionBuilder,
          (Goal, $$GoalsTableReferences),
          Goal,
          PrefetchHooks Function({bool goalNutrientsRefs})
        > {
  $$GoalsTableTableManager(_$AppDatabase db, $GoalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> effectiveFrom = const Value.absent(),
                Value<String> calorieMode = const Value.absent(),
                Value<int?> calories = const Value.absent(),
                Value<double> activityFactor = const Value.absent(),
                Value<double> targetKgPerWeek = const Value.absent(),
                Value<int> exerciseAddBackPercent = const Value.absent(),
                Value<String> macroMode = const Value.absent(),
                Value<double?> proteinTarget = const Value.absent(),
                Value<double?> carbsTarget = const Value.absent(),
                Value<double?> fatTarget = const Value.absent(),
              }) => GoalsCompanion(
                id: id,
                effectiveFrom: effectiveFrom,
                calorieMode: calorieMode,
                calories: calories,
                activityFactor: activityFactor,
                targetKgPerWeek: targetKgPerWeek,
                exerciseAddBackPercent: exerciseAddBackPercent,
                macroMode: macroMode,
                proteinTarget: proteinTarget,
                carbsTarget: carbsTarget,
                fatTarget: fatTarget,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String effectiveFrom,
                required String calorieMode,
                Value<int?> calories = const Value.absent(),
                required double activityFactor,
                required double targetKgPerWeek,
                Value<int> exerciseAddBackPercent = const Value.absent(),
                required String macroMode,
                Value<double?> proteinTarget = const Value.absent(),
                Value<double?> carbsTarget = const Value.absent(),
                Value<double?> fatTarget = const Value.absent(),
              }) => GoalsCompanion.insert(
                id: id,
                effectiveFrom: effectiveFrom,
                calorieMode: calorieMode,
                calories: calories,
                activityFactor: activityFactor,
                targetKgPerWeek: targetKgPerWeek,
                exerciseAddBackPercent: exerciseAddBackPercent,
                macroMode: macroMode,
                proteinTarget: proteinTarget,
                carbsTarget: carbsTarget,
                fatTarget: fatTarget,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GoalsTable, Goal>(table),
                  $$GoalsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({goalNutrientsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (goalNutrientsRefs) db.goalNutrients,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (goalNutrientsRefs)
                    await $_getPrefetchedDataByColumns<
                      Goal,
                      $GoalsTable,
                      GoalNutrient,
                      $GoalNutrientsTable
                    >(
                      currentTable: table,
                      referencedTable: $$GoalsTableReferences
                          ._goalNutrientsRefsTable(db),
                      managerFromTypedResult: (p0) => $$GoalsTableReferences(
                        db,
                        table,
                        p0,
                      ).goalNutrientsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'goal_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$GoalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalsTable,
      Goal,
      $$GoalsTableFilterComposer,
      $$GoalsTableOrderingComposer,
      $$GoalsTableAnnotationComposer,
      $$GoalsTableCreateCompanionBuilder,
      $$GoalsTableUpdateCompanionBuilder,
      (Goal, $$GoalsTableReferences),
      Goal,
      PrefetchHooks Function({bool goalNutrientsRefs})
    >;
typedef $$GoalNutrientsTableCreateCompanionBuilder =
    GoalNutrientsCompanion Function({
      required int goalId,
      required int nutrientId,
      required double targetAmount,
      Value<int> rowid,
    });
typedef $$GoalNutrientsTableUpdateCompanionBuilder =
    GoalNutrientsCompanion Function({
      Value<int> goalId,
      Value<int> nutrientId,
      Value<double> targetAmount,
      Value<int> rowid,
    });

final class $$GoalNutrientsTableReferences
    extends BaseReferences<_$AppDatabase, $GoalNutrientsTable, GoalNutrient> {
  $$GoalNutrientsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $GoalsTable _goalIdTable(_$AppDatabase db) =>
      db.goals.createAlias('goal_nutrients__goal_id__goals__id');

  $$GoalsTableProcessedTableManager get goalId {
    final $_column = $_itemColumn<int>('goal_id')!;

    final manager = $$GoalsTableTableManager(
      $_db,
      $_db.goals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_goalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GoalNutrientsTableFilterComposer
    extends Composer<_$AppDatabase, $GoalNutrientsTable> {
  $$GoalNutrientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get nutrientId => $composableBuilder(
    column: $table.nutrientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => ColumnFilters(column),
  );

  $$GoalsTableFilterComposer get goalId {
    final $$GoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableFilterComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalNutrientsTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalNutrientsTable> {
  $$GoalNutrientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get nutrientId => $composableBuilder(
    column: $table.nutrientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => ColumnOrderings(column),
  );

  $$GoalsTableOrderingComposer get goalId {
    final $$GoalsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableOrderingComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalNutrientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalNutrientsTable> {
  $$GoalNutrientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get nutrientId => $composableBuilder(
    column: $table.nutrientId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => column,
  );

  $$GoalsTableAnnotationComposer get goalId {
    final $$GoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalNutrientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalNutrientsTable,
          GoalNutrient,
          $$GoalNutrientsTableFilterComposer,
          $$GoalNutrientsTableOrderingComposer,
          $$GoalNutrientsTableAnnotationComposer,
          $$GoalNutrientsTableCreateCompanionBuilder,
          $$GoalNutrientsTableUpdateCompanionBuilder,
          (GoalNutrient, $$GoalNutrientsTableReferences),
          GoalNutrient,
          PrefetchHooks Function({bool goalId})
        > {
  $$GoalNutrientsTableTableManager(_$AppDatabase db, $GoalNutrientsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalNutrientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalNutrientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalNutrientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> goalId = const Value.absent(),
                Value<int> nutrientId = const Value.absent(),
                Value<double> targetAmount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalNutrientsCompanion(
                goalId: goalId,
                nutrientId: nutrientId,
                targetAmount: targetAmount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int goalId,
                required int nutrientId,
                required double targetAmount,
                Value<int> rowid = const Value.absent(),
              }) => GoalNutrientsCompanion.insert(
                goalId: goalId,
                nutrientId: nutrientId,
                targetAmount: targetAmount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GoalNutrientsTable, GoalNutrient>(table),
                  $$GoalNutrientsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({goalId = false}) {
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
                    if (goalId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.goalId,
                        referencedTable: $$GoalNutrientsTableReferences
                            ._goalIdTable(db),
                        referencedColumn: $$GoalNutrientsTableReferences
                            ._goalIdTable(db)
                            .id,
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

typedef $$GoalNutrientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalNutrientsTable,
      GoalNutrient,
      $$GoalNutrientsTableFilterComposer,
      $$GoalNutrientsTableOrderingComposer,
      $$GoalNutrientsTableAnnotationComposer,
      $$GoalNutrientsTableCreateCompanionBuilder,
      $$GoalNutrientsTableUpdateCompanionBuilder,
      (GoalNutrient, $$GoalNutrientsTableReferences),
      GoalNutrient,
      PrefetchHooks Function({bool goalId})
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
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

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, Setting>(
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

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FoodsTableTableManager get foods =>
      $$FoodsTableTableManager(_db, _db.foods);
  $$FoodNutrientsTableTableManager get foodNutrients =>
      $$FoodNutrientsTableTableManager(_db, _db.foodNutrients);
  $$FoodPortionsTableTableManager get foodPortions =>
      $$FoodPortionsTableTableManager(_db, _db.foodPortions);
  $$RecipeIngredientsTableTableManager get recipeIngredients =>
      $$RecipeIngredientsTableTableManager(_db, _db.recipeIngredients);
  $$MealSlotsTableTableManager get mealSlots =>
      $$MealSlotsTableTableManager(_db, _db.mealSlots);
  $$MealSlotRulesTableTableManager get mealSlotRules =>
      $$MealSlotRulesTableTableManager(_db, _db.mealSlotRules);
  $$SavedMealsTableTableManager get savedMeals =>
      $$SavedMealsTableTableManager(_db, _db.savedMeals);
  $$MealsTableTableManager get meals =>
      $$MealsTableTableManager(_db, _db.meals);
  $$MealEntriesTableTableManager get mealEntries =>
      $$MealEntriesTableTableManager(_db, _db.mealEntries);
  $$MealEntryNutrientsTableTableManager get mealEntryNutrients =>
      $$MealEntryNutrientsTableTableManager(_db, _db.mealEntryNutrients);
  $$SavedMealItemsTableTableManager get savedMealItems =>
      $$SavedMealItemsTableTableManager(_db, _db.savedMealItems);
  $$SavedMealItemNutrientsTableTableManager get savedMealItemNutrients =>
      $$SavedMealItemNutrientsTableTableManager(
        _db,
        _db.savedMealItemNutrients,
      );
  $$AliasesTableTableManager get aliases =>
      $$AliasesTableTableManager(_db, _db.aliases);
  $$LearnedMatchesTableTableManager get learnedMatches =>
      $$LearnedMatchesTableTableManager(_db, _db.learnedMatches);
  $$WeightEntriesTableTableManager get weightEntries =>
      $$WeightEntriesTableTableManager(_db, _db.weightEntries);
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db, _db.exercises);
  $$RoutinesTableTableManager get routines =>
      $$RoutinesTableTableManager(_db, _db.routines);
  $$RoutineExercisesTableTableManager get routineExercises =>
      $$RoutineExercisesTableTableManager(_db, _db.routineExercises);
  $$WorkoutsTableTableManager get workouts =>
      $$WorkoutsTableTableManager(_db, _db.workouts);
  $$WorkoutSetsTableTableManager get workoutSets =>
      $$WorkoutSetsTableTableManager(_db, _db.workoutSets);
  $$CardioSessionsTableTableManager get cardioSessions =>
      $$CardioSessionsTableTableManager(_db, _db.cardioSessions);
  $$ProfileTableTableManager get profile =>
      $$ProfileTableTableManager(_db, _db.profile);
  $$GoalsTableTableManager get goals =>
      $$GoalsTableTableManager(_db, _db.goals);
  $$GoalNutrientsTableTableManager get goalNutrients =>
      $$GoalNutrientsTableTableManager(_db, _db.goalNutrients);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}

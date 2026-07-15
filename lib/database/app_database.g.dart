// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $RepartosTable extends Repartos with TableInfo<$RepartosTable, Reparto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RepartosTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
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
  );
  static const VerificationMeta _ordenMeta = const VerificationMeta('orden');
  @override
  late final GeneratedColumn<int> orden = GeneratedColumn<int>(
    'orden',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, nombre, userId, orden];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'repartos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reparto> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nombre')) {
      context.handle(
        _nombreMeta,
        nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta),
      );
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('orden')) {
      context.handle(
        _ordenMeta,
        orden.isAcceptableOrUnknown(data['orden']!, _ordenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reparto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reparto(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      orden: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}orden'],
      )!,
    );
  }

  @override
  $RepartosTable createAlias(String alias) {
    return $RepartosTable(attachedDatabase, alias);
  }
}

class Reparto extends DataClass implements Insertable<Reparto> {
  final int id;
  final String nombre;
  final String userId;
  final int orden;
  const Reparto({
    required this.id,
    required this.nombre,
    required this.userId,
    required this.orden,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['nombre'] = Variable<String>(nombre);
    map['user_id'] = Variable<String>(userId);
    map['orden'] = Variable<int>(orden);
    return map;
  }

  RepartosCompanion toCompanion(bool nullToAbsent) {
    return RepartosCompanion(
      id: Value(id),
      nombre: Value(nombre),
      userId: Value(userId),
      orden: Value(orden),
    );
  }

  factory Reparto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reparto(
      id: serializer.fromJson<int>(json['id']),
      nombre: serializer.fromJson<String>(json['nombre']),
      userId: serializer.fromJson<String>(json['userId']),
      orden: serializer.fromJson<int>(json['orden']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nombre': serializer.toJson<String>(nombre),
      'userId': serializer.toJson<String>(userId),
      'orden': serializer.toJson<int>(orden),
    };
  }

  Reparto copyWith({int? id, String? nombre, String? userId, int? orden}) =>
      Reparto(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        userId: userId ?? this.userId,
        orden: orden ?? this.orden,
      );
  Reparto copyWithCompanion(RepartosCompanion data) {
    return Reparto(
      id: data.id.present ? data.id.value : this.id,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      userId: data.userId.present ? data.userId.value : this.userId,
      orden: data.orden.present ? data.orden.value : this.orden,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reparto(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('userId: $userId, ')
          ..write('orden: $orden')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nombre, userId, orden);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reparto &&
          other.id == this.id &&
          other.nombre == this.nombre &&
          other.userId == this.userId &&
          other.orden == this.orden);
}

class RepartosCompanion extends UpdateCompanion<Reparto> {
  final Value<int> id;
  final Value<String> nombre;
  final Value<String> userId;
  final Value<int> orden;
  const RepartosCompanion({
    this.id = const Value.absent(),
    this.nombre = const Value.absent(),
    this.userId = const Value.absent(),
    this.orden = const Value.absent(),
  });
  RepartosCompanion.insert({
    this.id = const Value.absent(),
    required String nombre,
    required String userId,
    this.orden = const Value.absent(),
  }) : nombre = Value(nombre),
       userId = Value(userId);
  static Insertable<Reparto> custom({
    Expression<int>? id,
    Expression<String>? nombre,
    Expression<String>? userId,
    Expression<int>? orden,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nombre != null) 'nombre': nombre,
      if (userId != null) 'user_id': userId,
      if (orden != null) 'orden': orden,
    });
  }

  RepartosCompanion copyWith({
    Value<int>? id,
    Value<String>? nombre,
    Value<String>? userId,
    Value<int>? orden,
  }) {
    return RepartosCompanion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      userId: userId ?? this.userId,
      orden: orden ?? this.orden,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (orden.present) {
      map['orden'] = Variable<int>(orden.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RepartosCompanion(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('userId: $userId, ')
          ..write('orden: $orden')
          ..write(')'))
        .toString();
  }
}

class $ProductosTable extends Productos
    with TableInfo<$ProductosTable, Producto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductosTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _repartoIdMeta = const VerificationMeta(
    'repartoId',
  );
  @override
  late final GeneratedColumn<int> repartoId = GeneratedColumn<int>(
    'reparto_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordenMeta = const VerificationMeta('orden');
  @override
  late final GeneratedColumn<int> orden = GeneratedColumn<int>(
    'orden',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _precioMeta = const VerificationMeta('precio');
  @override
  late final GeneratedColumn<double> precio = GeneratedColumn<double>(
    'precio',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    repartoId,
    nombre,
    orden,
    precio,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'productos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Producto> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('reparto_id')) {
      context.handle(
        _repartoIdMeta,
        repartoId.isAcceptableOrUnknown(data['reparto_id']!, _repartoIdMeta),
      );
    }
    if (data.containsKey('nombre')) {
      context.handle(
        _nombreMeta,
        nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta),
      );
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('orden')) {
      context.handle(
        _ordenMeta,
        orden.isAcceptableOrUnknown(data['orden']!, _ordenMeta),
      );
    }
    if (data.containsKey('precio')) {
      context.handle(
        _precioMeta,
        precio.isAcceptableOrUnknown(data['precio']!, _precioMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Producto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Producto(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      repartoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reparto_id'],
      ),
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      orden: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}orden'],
      )!,
      precio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}precio'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $ProductosTable createAlias(String alias) {
    return $ProductosTable(attachedDatabase, alias);
  }
}

class Producto extends DataClass implements Insertable<Producto> {
  final int id;
  final int? repartoId;
  final String nombre;
  final int orden;
  final double precio;
  final bool deleted;
  const Producto({
    required this.id,
    this.repartoId,
    required this.nombre,
    required this.orden,
    required this.precio,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || repartoId != null) {
      map['reparto_id'] = Variable<int>(repartoId);
    }
    map['nombre'] = Variable<String>(nombre);
    map['orden'] = Variable<int>(orden);
    map['precio'] = Variable<double>(precio);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  ProductosCompanion toCompanion(bool nullToAbsent) {
    return ProductosCompanion(
      id: Value(id),
      repartoId: repartoId == null && nullToAbsent
          ? const Value.absent()
          : Value(repartoId),
      nombre: Value(nombre),
      orden: Value(orden),
      precio: Value(precio),
      deleted: Value(deleted),
    );
  }

  factory Producto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Producto(
      id: serializer.fromJson<int>(json['id']),
      repartoId: serializer.fromJson<int?>(json['repartoId']),
      nombre: serializer.fromJson<String>(json['nombre']),
      orden: serializer.fromJson<int>(json['orden']),
      precio: serializer.fromJson<double>(json['precio']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'repartoId': serializer.toJson<int?>(repartoId),
      'nombre': serializer.toJson<String>(nombre),
      'orden': serializer.toJson<int>(orden),
      'precio': serializer.toJson<double>(precio),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  Producto copyWith({
    int? id,
    Value<int?> repartoId = const Value.absent(),
    String? nombre,
    int? orden,
    double? precio,
    bool? deleted,
  }) => Producto(
    id: id ?? this.id,
    repartoId: repartoId.present ? repartoId.value : this.repartoId,
    nombre: nombre ?? this.nombre,
    orden: orden ?? this.orden,
    precio: precio ?? this.precio,
    deleted: deleted ?? this.deleted,
  );
  Producto copyWithCompanion(ProductosCompanion data) {
    return Producto(
      id: data.id.present ? data.id.value : this.id,
      repartoId: data.repartoId.present ? data.repartoId.value : this.repartoId,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      orden: data.orden.present ? data.orden.value : this.orden,
      precio: data.precio.present ? data.precio.value : this.precio,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Producto(')
          ..write('id: $id, ')
          ..write('repartoId: $repartoId, ')
          ..write('nombre: $nombre, ')
          ..write('orden: $orden, ')
          ..write('precio: $precio, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, repartoId, nombre, orden, precio, deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Producto &&
          other.id == this.id &&
          other.repartoId == this.repartoId &&
          other.nombre == this.nombre &&
          other.orden == this.orden &&
          other.precio == this.precio &&
          other.deleted == this.deleted);
}

class ProductosCompanion extends UpdateCompanion<Producto> {
  final Value<int> id;
  final Value<int?> repartoId;
  final Value<String> nombre;
  final Value<int> orden;
  final Value<double> precio;
  final Value<bool> deleted;
  const ProductosCompanion({
    this.id = const Value.absent(),
    this.repartoId = const Value.absent(),
    this.nombre = const Value.absent(),
    this.orden = const Value.absent(),
    this.precio = const Value.absent(),
    this.deleted = const Value.absent(),
  });
  ProductosCompanion.insert({
    this.id = const Value.absent(),
    this.repartoId = const Value.absent(),
    required String nombre,
    this.orden = const Value.absent(),
    this.precio = const Value.absent(),
    this.deleted = const Value.absent(),
  }) : nombre = Value(nombre);
  static Insertable<Producto> custom({
    Expression<int>? id,
    Expression<int>? repartoId,
    Expression<String>? nombre,
    Expression<int>? orden,
    Expression<double>? precio,
    Expression<bool>? deleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (repartoId != null) 'reparto_id': repartoId,
      if (nombre != null) 'nombre': nombre,
      if (orden != null) 'orden': orden,
      if (precio != null) 'precio': precio,
      if (deleted != null) 'deleted': deleted,
    });
  }

  ProductosCompanion copyWith({
    Value<int>? id,
    Value<int?>? repartoId,
    Value<String>? nombre,
    Value<int>? orden,
    Value<double>? precio,
    Value<bool>? deleted,
  }) {
    return ProductosCompanion(
      id: id ?? this.id,
      repartoId: repartoId ?? this.repartoId,
      nombre: nombre ?? this.nombre,
      orden: orden ?? this.orden,
      precio: precio ?? this.precio,
      deleted: deleted ?? this.deleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (repartoId.present) {
      map['reparto_id'] = Variable<int>(repartoId.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (orden.present) {
      map['orden'] = Variable<int>(orden.value);
    }
    if (precio.present) {
      map['precio'] = Variable<double>(precio.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductosCompanion(')
          ..write('id: $id, ')
          ..write('repartoId: $repartoId, ')
          ..write('nombre: $nombre, ')
          ..write('orden: $orden, ')
          ..write('precio: $precio, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }
}

class $ProductoPreciosTable extends ProductoPrecios
    with TableInfo<$ProductoPreciosTable, ProductoPrecio> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductoPreciosTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _repartoIdMeta = const VerificationMeta(
    'repartoId',
  );
  @override
  late final GeneratedColumn<int> repartoId = GeneratedColumn<int>(
    'reparto_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _productoIdMeta = const VerificationMeta(
    'productoId',
  );
  @override
  late final GeneratedColumn<int> productoId = GeneratedColumn<int>(
    'producto_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES productos (id)',
    ),
  );
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _precioMeta = const VerificationMeta('precio');
  @override
  late final GeneratedColumn<double> precio = GeneratedColumn<double>(
    'precio',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordenMeta = const VerificationMeta('orden');
  @override
  late final GeneratedColumn<int> orden = GeneratedColumn<int>(
    'orden',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    repartoId,
    productoId,
    nombre,
    precio,
    orden,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'producto_precios';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProductoPrecio> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('reparto_id')) {
      context.handle(
        _repartoIdMeta,
        repartoId.isAcceptableOrUnknown(data['reparto_id']!, _repartoIdMeta),
      );
    }
    if (data.containsKey('producto_id')) {
      context.handle(
        _productoIdMeta,
        productoId.isAcceptableOrUnknown(data['producto_id']!, _productoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productoIdMeta);
    }
    if (data.containsKey('nombre')) {
      context.handle(
        _nombreMeta,
        nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta),
      );
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('precio')) {
      context.handle(
        _precioMeta,
        precio.isAcceptableOrUnknown(data['precio']!, _precioMeta),
      );
    } else if (isInserting) {
      context.missing(_precioMeta);
    }
    if (data.containsKey('orden')) {
      context.handle(
        _ordenMeta,
        orden.isAcceptableOrUnknown(data['orden']!, _ordenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProductoPrecio map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductoPrecio(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      repartoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reparto_id'],
      ),
      productoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}producto_id'],
      )!,
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      precio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}precio'],
      )!,
      orden: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}orden'],
      )!,
    );
  }

  @override
  $ProductoPreciosTable createAlias(String alias) {
    return $ProductoPreciosTable(attachedDatabase, alias);
  }
}

class ProductoPrecio extends DataClass implements Insertable<ProductoPrecio> {
  final int id;
  final int? repartoId;
  final int productoId;
  final String nombre;
  final double precio;
  final int orden;
  const ProductoPrecio({
    required this.id,
    this.repartoId,
    required this.productoId,
    required this.nombre,
    required this.precio,
    required this.orden,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || repartoId != null) {
      map['reparto_id'] = Variable<int>(repartoId);
    }
    map['producto_id'] = Variable<int>(productoId);
    map['nombre'] = Variable<String>(nombre);
    map['precio'] = Variable<double>(precio);
    map['orden'] = Variable<int>(orden);
    return map;
  }

  ProductoPreciosCompanion toCompanion(bool nullToAbsent) {
    return ProductoPreciosCompanion(
      id: Value(id),
      repartoId: repartoId == null && nullToAbsent
          ? const Value.absent()
          : Value(repartoId),
      productoId: Value(productoId),
      nombre: Value(nombre),
      precio: Value(precio),
      orden: Value(orden),
    );
  }

  factory ProductoPrecio.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductoPrecio(
      id: serializer.fromJson<int>(json['id']),
      repartoId: serializer.fromJson<int?>(json['repartoId']),
      productoId: serializer.fromJson<int>(json['productoId']),
      nombre: serializer.fromJson<String>(json['nombre']),
      precio: serializer.fromJson<double>(json['precio']),
      orden: serializer.fromJson<int>(json['orden']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'repartoId': serializer.toJson<int?>(repartoId),
      'productoId': serializer.toJson<int>(productoId),
      'nombre': serializer.toJson<String>(nombre),
      'precio': serializer.toJson<double>(precio),
      'orden': serializer.toJson<int>(orden),
    };
  }

  ProductoPrecio copyWith({
    int? id,
    Value<int?> repartoId = const Value.absent(),
    int? productoId,
    String? nombre,
    double? precio,
    int? orden,
  }) => ProductoPrecio(
    id: id ?? this.id,
    repartoId: repartoId.present ? repartoId.value : this.repartoId,
    productoId: productoId ?? this.productoId,
    nombre: nombre ?? this.nombre,
    precio: precio ?? this.precio,
    orden: orden ?? this.orden,
  );
  ProductoPrecio copyWithCompanion(ProductoPreciosCompanion data) {
    return ProductoPrecio(
      id: data.id.present ? data.id.value : this.id,
      repartoId: data.repartoId.present ? data.repartoId.value : this.repartoId,
      productoId: data.productoId.present
          ? data.productoId.value
          : this.productoId,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      precio: data.precio.present ? data.precio.value : this.precio,
      orden: data.orden.present ? data.orden.value : this.orden,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductoPrecio(')
          ..write('id: $id, ')
          ..write('repartoId: $repartoId, ')
          ..write('productoId: $productoId, ')
          ..write('nombre: $nombre, ')
          ..write('precio: $precio, ')
          ..write('orden: $orden')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, repartoId, productoId, nombre, precio, orden);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductoPrecio &&
          other.id == this.id &&
          other.repartoId == this.repartoId &&
          other.productoId == this.productoId &&
          other.nombre == this.nombre &&
          other.precio == this.precio &&
          other.orden == this.orden);
}

class ProductoPreciosCompanion extends UpdateCompanion<ProductoPrecio> {
  final Value<int> id;
  final Value<int?> repartoId;
  final Value<int> productoId;
  final Value<String> nombre;
  final Value<double> precio;
  final Value<int> orden;
  const ProductoPreciosCompanion({
    this.id = const Value.absent(),
    this.repartoId = const Value.absent(),
    this.productoId = const Value.absent(),
    this.nombre = const Value.absent(),
    this.precio = const Value.absent(),
    this.orden = const Value.absent(),
  });
  ProductoPreciosCompanion.insert({
    this.id = const Value.absent(),
    this.repartoId = const Value.absent(),
    required int productoId,
    required String nombre,
    required double precio,
    this.orden = const Value.absent(),
  }) : productoId = Value(productoId),
       nombre = Value(nombre),
       precio = Value(precio);
  static Insertable<ProductoPrecio> custom({
    Expression<int>? id,
    Expression<int>? repartoId,
    Expression<int>? productoId,
    Expression<String>? nombre,
    Expression<double>? precio,
    Expression<int>? orden,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (repartoId != null) 'reparto_id': repartoId,
      if (productoId != null) 'producto_id': productoId,
      if (nombre != null) 'nombre': nombre,
      if (precio != null) 'precio': precio,
      if (orden != null) 'orden': orden,
    });
  }

  ProductoPreciosCompanion copyWith({
    Value<int>? id,
    Value<int?>? repartoId,
    Value<int>? productoId,
    Value<String>? nombre,
    Value<double>? precio,
    Value<int>? orden,
  }) {
    return ProductoPreciosCompanion(
      id: id ?? this.id,
      repartoId: repartoId ?? this.repartoId,
      productoId: productoId ?? this.productoId,
      nombre: nombre ?? this.nombre,
      precio: precio ?? this.precio,
      orden: orden ?? this.orden,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (repartoId.present) {
      map['reparto_id'] = Variable<int>(repartoId.value);
    }
    if (productoId.present) {
      map['producto_id'] = Variable<int>(productoId.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (precio.present) {
      map['precio'] = Variable<double>(precio.value);
    }
    if (orden.present) {
      map['orden'] = Variable<int>(orden.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductoPreciosCompanion(')
          ..write('id: $id, ')
          ..write('repartoId: $repartoId, ')
          ..write('productoId: $productoId, ')
          ..write('nombre: $nombre, ')
          ..write('precio: $precio, ')
          ..write('orden: $orden')
          ..write(')'))
        .toString();
  }
}

class $CargaDiariaTable extends CargaDiaria
    with TableInfo<$CargaDiariaTable, CargaDiariaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CargaDiariaTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _productoIdMeta = const VerificationMeta(
    'productoId',
  );
  @override
  late final GeneratedColumn<int> productoId = GeneratedColumn<int>(
    'producto_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES productos (id)',
    ),
  );
  static const VerificationMeta _repartoIdMeta = const VerificationMeta(
    'repartoId',
  );
  @override
  late final GeneratedColumn<int> repartoId = GeneratedColumn<int>(
    'reparto_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES repartos (id)',
    ),
  );
  static const VerificationMeta _diaSemanaMeta = const VerificationMeta(
    'diaSemana',
  );
  @override
  late final GeneratedColumn<int> diaSemana = GeneratedColumn<int>(
    'dia_semana',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _semanaMeta = const VerificationMeta('semana');
  @override
  late final GeneratedColumn<String> semana = GeneratedColumn<String>(
    'semana',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cantidadMeta = const VerificationMeta(
    'cantidad',
  );
  @override
  late final GeneratedColumn<int> cantidad = GeneratedColumn<int>(
    'cantidad',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    productoId,
    repartoId,
    diaSemana,
    semana,
    cantidad,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'carga_diaria';
  @override
  VerificationContext validateIntegrity(
    Insertable<CargaDiariaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('producto_id')) {
      context.handle(
        _productoIdMeta,
        productoId.isAcceptableOrUnknown(data['producto_id']!, _productoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productoIdMeta);
    }
    if (data.containsKey('reparto_id')) {
      context.handle(
        _repartoIdMeta,
        repartoId.isAcceptableOrUnknown(data['reparto_id']!, _repartoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_repartoIdMeta);
    }
    if (data.containsKey('dia_semana')) {
      context.handle(
        _diaSemanaMeta,
        diaSemana.isAcceptableOrUnknown(data['dia_semana']!, _diaSemanaMeta),
      );
    } else if (isInserting) {
      context.missing(_diaSemanaMeta);
    }
    if (data.containsKey('semana')) {
      context.handle(
        _semanaMeta,
        semana.isAcceptableOrUnknown(data['semana']!, _semanaMeta),
      );
    } else if (isInserting) {
      context.missing(_semanaMeta);
    }
    if (data.containsKey('cantidad')) {
      context.handle(
        _cantidadMeta,
        cantidad.isAcceptableOrUnknown(data['cantidad']!, _cantidadMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CargaDiariaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CargaDiariaData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      productoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}producto_id'],
      )!,
      repartoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reparto_id'],
      )!,
      diaSemana: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dia_semana'],
      )!,
      semana: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semana'],
      )!,
      cantidad: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cantidad'],
      )!,
    );
  }

  @override
  $CargaDiariaTable createAlias(String alias) {
    return $CargaDiariaTable(attachedDatabase, alias);
  }
}

class CargaDiariaData extends DataClass implements Insertable<CargaDiariaData> {
  final int id;
  final int productoId;
  final int repartoId;
  final int diaSemana;
  final String semana;
  final int cantidad;
  const CargaDiariaData({
    required this.id,
    required this.productoId,
    required this.repartoId,
    required this.diaSemana,
    required this.semana,
    required this.cantidad,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['producto_id'] = Variable<int>(productoId);
    map['reparto_id'] = Variable<int>(repartoId);
    map['dia_semana'] = Variable<int>(diaSemana);
    map['semana'] = Variable<String>(semana);
    map['cantidad'] = Variable<int>(cantidad);
    return map;
  }

  CargaDiariaCompanion toCompanion(bool nullToAbsent) {
    return CargaDiariaCompanion(
      id: Value(id),
      productoId: Value(productoId),
      repartoId: Value(repartoId),
      diaSemana: Value(diaSemana),
      semana: Value(semana),
      cantidad: Value(cantidad),
    );
  }

  factory CargaDiariaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CargaDiariaData(
      id: serializer.fromJson<int>(json['id']),
      productoId: serializer.fromJson<int>(json['productoId']),
      repartoId: serializer.fromJson<int>(json['repartoId']),
      diaSemana: serializer.fromJson<int>(json['diaSemana']),
      semana: serializer.fromJson<String>(json['semana']),
      cantidad: serializer.fromJson<int>(json['cantidad']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'productoId': serializer.toJson<int>(productoId),
      'repartoId': serializer.toJson<int>(repartoId),
      'diaSemana': serializer.toJson<int>(diaSemana),
      'semana': serializer.toJson<String>(semana),
      'cantidad': serializer.toJson<int>(cantidad),
    };
  }

  CargaDiariaData copyWith({
    int? id,
    int? productoId,
    int? repartoId,
    int? diaSemana,
    String? semana,
    int? cantidad,
  }) => CargaDiariaData(
    id: id ?? this.id,
    productoId: productoId ?? this.productoId,
    repartoId: repartoId ?? this.repartoId,
    diaSemana: diaSemana ?? this.diaSemana,
    semana: semana ?? this.semana,
    cantidad: cantidad ?? this.cantidad,
  );
  CargaDiariaData copyWithCompanion(CargaDiariaCompanion data) {
    return CargaDiariaData(
      id: data.id.present ? data.id.value : this.id,
      productoId: data.productoId.present
          ? data.productoId.value
          : this.productoId,
      repartoId: data.repartoId.present ? data.repartoId.value : this.repartoId,
      diaSemana: data.diaSemana.present ? data.diaSemana.value : this.diaSemana,
      semana: data.semana.present ? data.semana.value : this.semana,
      cantidad: data.cantidad.present ? data.cantidad.value : this.cantidad,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CargaDiariaData(')
          ..write('id: $id, ')
          ..write('productoId: $productoId, ')
          ..write('repartoId: $repartoId, ')
          ..write('diaSemana: $diaSemana, ')
          ..write('semana: $semana, ')
          ..write('cantidad: $cantidad')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, productoId, repartoId, diaSemana, semana, cantidad);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CargaDiariaData &&
          other.id == this.id &&
          other.productoId == this.productoId &&
          other.repartoId == this.repartoId &&
          other.diaSemana == this.diaSemana &&
          other.semana == this.semana &&
          other.cantidad == this.cantidad);
}

class CargaDiariaCompanion extends UpdateCompanion<CargaDiariaData> {
  final Value<int> id;
  final Value<int> productoId;
  final Value<int> repartoId;
  final Value<int> diaSemana;
  final Value<String> semana;
  final Value<int> cantidad;
  const CargaDiariaCompanion({
    this.id = const Value.absent(),
    this.productoId = const Value.absent(),
    this.repartoId = const Value.absent(),
    this.diaSemana = const Value.absent(),
    this.semana = const Value.absent(),
    this.cantidad = const Value.absent(),
  });
  CargaDiariaCompanion.insert({
    this.id = const Value.absent(),
    required int productoId,
    required int repartoId,
    required int diaSemana,
    required String semana,
    this.cantidad = const Value.absent(),
  }) : productoId = Value(productoId),
       repartoId = Value(repartoId),
       diaSemana = Value(diaSemana),
       semana = Value(semana);
  static Insertable<CargaDiariaData> custom({
    Expression<int>? id,
    Expression<int>? productoId,
    Expression<int>? repartoId,
    Expression<int>? diaSemana,
    Expression<String>? semana,
    Expression<int>? cantidad,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productoId != null) 'producto_id': productoId,
      if (repartoId != null) 'reparto_id': repartoId,
      if (diaSemana != null) 'dia_semana': diaSemana,
      if (semana != null) 'semana': semana,
      if (cantidad != null) 'cantidad': cantidad,
    });
  }

  CargaDiariaCompanion copyWith({
    Value<int>? id,
    Value<int>? productoId,
    Value<int>? repartoId,
    Value<int>? diaSemana,
    Value<String>? semana,
    Value<int>? cantidad,
  }) {
    return CargaDiariaCompanion(
      id: id ?? this.id,
      productoId: productoId ?? this.productoId,
      repartoId: repartoId ?? this.repartoId,
      diaSemana: diaSemana ?? this.diaSemana,
      semana: semana ?? this.semana,
      cantidad: cantidad ?? this.cantidad,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (productoId.present) {
      map['producto_id'] = Variable<int>(productoId.value);
    }
    if (repartoId.present) {
      map['reparto_id'] = Variable<int>(repartoId.value);
    }
    if (diaSemana.present) {
      map['dia_semana'] = Variable<int>(diaSemana.value);
    }
    if (semana.present) {
      map['semana'] = Variable<String>(semana.value);
    }
    if (cantidad.present) {
      map['cantidad'] = Variable<int>(cantidad.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CargaDiariaCompanion(')
          ..write('id: $id, ')
          ..write('productoId: $productoId, ')
          ..write('repartoId: $repartoId, ')
          ..write('diaSemana: $diaSemana, ')
          ..write('semana: $semana, ')
          ..write('cantidad: $cantidad')
          ..write(')'))
        .toString();
  }
}

class $ClientesTable extends Clientes with TableInfo<$ClientesTable, Cliente> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClientesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _repartoIdMeta = const VerificationMeta(
    'repartoId',
  );
  @override
  late final GeneratedColumn<int> repartoId = GeneratedColumn<int>(
    'reparto_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES repartos (id)',
    ),
  );
  static const VerificationMeta _diaSemanaMeta = const VerificationMeta(
    'diaSemana',
  );
  @override
  late final GeneratedColumn<int> diaSemana = GeneratedColumn<int>(
    'dia_semana',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _direccionMeta = const VerificationMeta(
    'direccion',
  );
  @override
  late final GeneratedColumn<String> direccion = GeneratedColumn<String>(
    'direccion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _telefonoMeta = const VerificationMeta(
    'telefono',
  );
  @override
  late final GeneratedColumn<String> telefono = GeneratedColumn<String>(
    'telefono',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _frecuenciaMeta = const VerificationMeta(
    'frecuencia',
  );
  @override
  late final GeneratedColumn<String> frecuencia = GeneratedColumn<String>(
    'frecuencia',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('semanal'),
  );
  static const VerificationMeta _etiquetaMeta = const VerificationMeta(
    'etiqueta',
  );
  @override
  late final GeneratedColumn<String> etiqueta = GeneratedColumn<String>(
    'etiqueta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _notasMeta = const VerificationMeta('notas');
  @override
  late final GeneratedColumn<String> notas = GeneratedColumn<String>(
    'notas',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _ordenMeta = const VerificationMeta('orden');
  @override
  late final GeneratedColumn<int> orden = GeneratedColumn<int>(
    'orden',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cuentaCorrienteMeta = const VerificationMeta(
    'cuentaCorriente',
  );
  @override
  late final GeneratedColumn<double> cuentaCorriente = GeneratedColumn<double>(
    'cuenta_corriente',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _showOnMapMeta = const VerificationMeta(
    'showOnMap',
  );
  @override
  late final GeneratedColumn<bool> showOnMap = GeneratedColumn<bool>(
    'show_on_map',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_on_map" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _docTipoMeta = const VerificationMeta(
    'docTipo',
  );
  @override
  late final GeneratedColumn<int> docTipo = GeneratedColumn<int>(
    'doc_tipo',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(99),
  );
  static const VerificationMeta _docNroMeta = const VerificationMeta('docNro');
  @override
  late final GeneratedColumn<String> docNro = GeneratedColumn<String>(
    'doc_nro',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    repartoId,
    diaSemana,
    nombre,
    direccion,
    telefono,
    frecuencia,
    etiqueta,
    notas,
    orden,
    cuentaCorriente,
    showOnMap,
    docTipo,
    docNro,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clientes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Cliente> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('reparto_id')) {
      context.handle(
        _repartoIdMeta,
        repartoId.isAcceptableOrUnknown(data['reparto_id']!, _repartoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_repartoIdMeta);
    }
    if (data.containsKey('dia_semana')) {
      context.handle(
        _diaSemanaMeta,
        diaSemana.isAcceptableOrUnknown(data['dia_semana']!, _diaSemanaMeta),
      );
    } else if (isInserting) {
      context.missing(_diaSemanaMeta);
    }
    if (data.containsKey('nombre')) {
      context.handle(
        _nombreMeta,
        nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta),
      );
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('direccion')) {
      context.handle(
        _direccionMeta,
        direccion.isAcceptableOrUnknown(data['direccion']!, _direccionMeta),
      );
    }
    if (data.containsKey('telefono')) {
      context.handle(
        _telefonoMeta,
        telefono.isAcceptableOrUnknown(data['telefono']!, _telefonoMeta),
      );
    }
    if (data.containsKey('frecuencia')) {
      context.handle(
        _frecuenciaMeta,
        frecuencia.isAcceptableOrUnknown(data['frecuencia']!, _frecuenciaMeta),
      );
    }
    if (data.containsKey('etiqueta')) {
      context.handle(
        _etiquetaMeta,
        etiqueta.isAcceptableOrUnknown(data['etiqueta']!, _etiquetaMeta),
      );
    }
    if (data.containsKey('notas')) {
      context.handle(
        _notasMeta,
        notas.isAcceptableOrUnknown(data['notas']!, _notasMeta),
      );
    }
    if (data.containsKey('orden')) {
      context.handle(
        _ordenMeta,
        orden.isAcceptableOrUnknown(data['orden']!, _ordenMeta),
      );
    }
    if (data.containsKey('cuenta_corriente')) {
      context.handle(
        _cuentaCorrienteMeta,
        cuentaCorriente.isAcceptableOrUnknown(
          data['cuenta_corriente']!,
          _cuentaCorrienteMeta,
        ),
      );
    }
    if (data.containsKey('show_on_map')) {
      context.handle(
        _showOnMapMeta,
        showOnMap.isAcceptableOrUnknown(data['show_on_map']!, _showOnMapMeta),
      );
    }
    if (data.containsKey('doc_tipo')) {
      context.handle(
        _docTipoMeta,
        docTipo.isAcceptableOrUnknown(data['doc_tipo']!, _docTipoMeta),
      );
    }
    if (data.containsKey('doc_nro')) {
      context.handle(
        _docNroMeta,
        docNro.isAcceptableOrUnknown(data['doc_nro']!, _docNroMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Cliente map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Cliente(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      repartoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reparto_id'],
      )!,
      diaSemana: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dia_semana'],
      )!,
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      direccion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direccion'],
      )!,
      telefono: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}telefono'],
      )!,
      frecuencia: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frecuencia'],
      )!,
      etiqueta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etiqueta'],
      )!,
      notas: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notas'],
      )!,
      orden: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}orden'],
      )!,
      cuentaCorriente: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cuenta_corriente'],
      )!,
      showOnMap: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_on_map'],
      )!,
      docTipo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}doc_tipo'],
      )!,
      docNro: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}doc_nro'],
      )!,
    );
  }

  @override
  $ClientesTable createAlias(String alias) {
    return $ClientesTable(attachedDatabase, alias);
  }
}

class Cliente extends DataClass implements Insertable<Cliente> {
  final int id;
  final int repartoId;
  final int diaSemana;
  final String nombre;
  final String direccion;
  final String telefono;
  final String frecuencia;
  final String etiqueta;
  final String notas;
  final int orden;
  final double cuentaCorriente;
  final bool showOnMap;
  final int docTipo;
  final String docNro;
  const Cliente({
    required this.id,
    required this.repartoId,
    required this.diaSemana,
    required this.nombre,
    required this.direccion,
    required this.telefono,
    required this.frecuencia,
    required this.etiqueta,
    required this.notas,
    required this.orden,
    required this.cuentaCorriente,
    required this.showOnMap,
    required this.docTipo,
    required this.docNro,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['reparto_id'] = Variable<int>(repartoId);
    map['dia_semana'] = Variable<int>(diaSemana);
    map['nombre'] = Variable<String>(nombre);
    map['direccion'] = Variable<String>(direccion);
    map['telefono'] = Variable<String>(telefono);
    map['frecuencia'] = Variable<String>(frecuencia);
    map['etiqueta'] = Variable<String>(etiqueta);
    map['notas'] = Variable<String>(notas);
    map['orden'] = Variable<int>(orden);
    map['cuenta_corriente'] = Variable<double>(cuentaCorriente);
    map['show_on_map'] = Variable<bool>(showOnMap);
    map['doc_tipo'] = Variable<int>(docTipo);
    map['doc_nro'] = Variable<String>(docNro);
    return map;
  }

  ClientesCompanion toCompanion(bool nullToAbsent) {
    return ClientesCompanion(
      id: Value(id),
      repartoId: Value(repartoId),
      diaSemana: Value(diaSemana),
      nombre: Value(nombre),
      direccion: Value(direccion),
      telefono: Value(telefono),
      frecuencia: Value(frecuencia),
      etiqueta: Value(etiqueta),
      notas: Value(notas),
      orden: Value(orden),
      cuentaCorriente: Value(cuentaCorriente),
      showOnMap: Value(showOnMap),
      docTipo: Value(docTipo),
      docNro: Value(docNro),
    );
  }

  factory Cliente.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Cliente(
      id: serializer.fromJson<int>(json['id']),
      repartoId: serializer.fromJson<int>(json['repartoId']),
      diaSemana: serializer.fromJson<int>(json['diaSemana']),
      nombre: serializer.fromJson<String>(json['nombre']),
      direccion: serializer.fromJson<String>(json['direccion']),
      telefono: serializer.fromJson<String>(json['telefono']),
      frecuencia: serializer.fromJson<String>(json['frecuencia']),
      etiqueta: serializer.fromJson<String>(json['etiqueta']),
      notas: serializer.fromJson<String>(json['notas']),
      orden: serializer.fromJson<int>(json['orden']),
      cuentaCorriente: serializer.fromJson<double>(json['cuentaCorriente']),
      showOnMap: serializer.fromJson<bool>(json['showOnMap']),
      docTipo: serializer.fromJson<int>(json['docTipo']),
      docNro: serializer.fromJson<String>(json['docNro']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'repartoId': serializer.toJson<int>(repartoId),
      'diaSemana': serializer.toJson<int>(diaSemana),
      'nombre': serializer.toJson<String>(nombre),
      'direccion': serializer.toJson<String>(direccion),
      'telefono': serializer.toJson<String>(telefono),
      'frecuencia': serializer.toJson<String>(frecuencia),
      'etiqueta': serializer.toJson<String>(etiqueta),
      'notas': serializer.toJson<String>(notas),
      'orden': serializer.toJson<int>(orden),
      'cuentaCorriente': serializer.toJson<double>(cuentaCorriente),
      'showOnMap': serializer.toJson<bool>(showOnMap),
      'docTipo': serializer.toJson<int>(docTipo),
      'docNro': serializer.toJson<String>(docNro),
    };
  }

  Cliente copyWith({
    int? id,
    int? repartoId,
    int? diaSemana,
    String? nombre,
    String? direccion,
    String? telefono,
    String? frecuencia,
    String? etiqueta,
    String? notas,
    int? orden,
    double? cuentaCorriente,
    bool? showOnMap,
    int? docTipo,
    String? docNro,
  }) => Cliente(
    id: id ?? this.id,
    repartoId: repartoId ?? this.repartoId,
    diaSemana: diaSemana ?? this.diaSemana,
    nombre: nombre ?? this.nombre,
    direccion: direccion ?? this.direccion,
    telefono: telefono ?? this.telefono,
    frecuencia: frecuencia ?? this.frecuencia,
    etiqueta: etiqueta ?? this.etiqueta,
    notas: notas ?? this.notas,
    orden: orden ?? this.orden,
    cuentaCorriente: cuentaCorriente ?? this.cuentaCorriente,
    showOnMap: showOnMap ?? this.showOnMap,
    docTipo: docTipo ?? this.docTipo,
    docNro: docNro ?? this.docNro,
  );
  Cliente copyWithCompanion(ClientesCompanion data) {
    return Cliente(
      id: data.id.present ? data.id.value : this.id,
      repartoId: data.repartoId.present ? data.repartoId.value : this.repartoId,
      diaSemana: data.diaSemana.present ? data.diaSemana.value : this.diaSemana,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      direccion: data.direccion.present ? data.direccion.value : this.direccion,
      telefono: data.telefono.present ? data.telefono.value : this.telefono,
      frecuencia: data.frecuencia.present
          ? data.frecuencia.value
          : this.frecuencia,
      etiqueta: data.etiqueta.present ? data.etiqueta.value : this.etiqueta,
      notas: data.notas.present ? data.notas.value : this.notas,
      orden: data.orden.present ? data.orden.value : this.orden,
      cuentaCorriente: data.cuentaCorriente.present
          ? data.cuentaCorriente.value
          : this.cuentaCorriente,
      showOnMap: data.showOnMap.present ? data.showOnMap.value : this.showOnMap,
      docTipo: data.docTipo.present ? data.docTipo.value : this.docTipo,
      docNro: data.docNro.present ? data.docNro.value : this.docNro,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cliente(')
          ..write('id: $id, ')
          ..write('repartoId: $repartoId, ')
          ..write('diaSemana: $diaSemana, ')
          ..write('nombre: $nombre, ')
          ..write('direccion: $direccion, ')
          ..write('telefono: $telefono, ')
          ..write('frecuencia: $frecuencia, ')
          ..write('etiqueta: $etiqueta, ')
          ..write('notas: $notas, ')
          ..write('orden: $orden, ')
          ..write('cuentaCorriente: $cuentaCorriente, ')
          ..write('showOnMap: $showOnMap, ')
          ..write('docTipo: $docTipo, ')
          ..write('docNro: $docNro')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    repartoId,
    diaSemana,
    nombre,
    direccion,
    telefono,
    frecuencia,
    etiqueta,
    notas,
    orden,
    cuentaCorriente,
    showOnMap,
    docTipo,
    docNro,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cliente &&
          other.id == this.id &&
          other.repartoId == this.repartoId &&
          other.diaSemana == this.diaSemana &&
          other.nombre == this.nombre &&
          other.direccion == this.direccion &&
          other.telefono == this.telefono &&
          other.frecuencia == this.frecuencia &&
          other.etiqueta == this.etiqueta &&
          other.notas == this.notas &&
          other.orden == this.orden &&
          other.cuentaCorriente == this.cuentaCorriente &&
          other.showOnMap == this.showOnMap &&
          other.docTipo == this.docTipo &&
          other.docNro == this.docNro);
}

class ClientesCompanion extends UpdateCompanion<Cliente> {
  final Value<int> id;
  final Value<int> repartoId;
  final Value<int> diaSemana;
  final Value<String> nombre;
  final Value<String> direccion;
  final Value<String> telefono;
  final Value<String> frecuencia;
  final Value<String> etiqueta;
  final Value<String> notas;
  final Value<int> orden;
  final Value<double> cuentaCorriente;
  final Value<bool> showOnMap;
  final Value<int> docTipo;
  final Value<String> docNro;
  const ClientesCompanion({
    this.id = const Value.absent(),
    this.repartoId = const Value.absent(),
    this.diaSemana = const Value.absent(),
    this.nombre = const Value.absent(),
    this.direccion = const Value.absent(),
    this.telefono = const Value.absent(),
    this.frecuencia = const Value.absent(),
    this.etiqueta = const Value.absent(),
    this.notas = const Value.absent(),
    this.orden = const Value.absent(),
    this.cuentaCorriente = const Value.absent(),
    this.showOnMap = const Value.absent(),
    this.docTipo = const Value.absent(),
    this.docNro = const Value.absent(),
  });
  ClientesCompanion.insert({
    this.id = const Value.absent(),
    required int repartoId,
    required int diaSemana,
    required String nombre,
    this.direccion = const Value.absent(),
    this.telefono = const Value.absent(),
    this.frecuencia = const Value.absent(),
    this.etiqueta = const Value.absent(),
    this.notas = const Value.absent(),
    this.orden = const Value.absent(),
    this.cuentaCorriente = const Value.absent(),
    this.showOnMap = const Value.absent(),
    this.docTipo = const Value.absent(),
    this.docNro = const Value.absent(),
  }) : repartoId = Value(repartoId),
       diaSemana = Value(diaSemana),
       nombre = Value(nombre);
  static Insertable<Cliente> custom({
    Expression<int>? id,
    Expression<int>? repartoId,
    Expression<int>? diaSemana,
    Expression<String>? nombre,
    Expression<String>? direccion,
    Expression<String>? telefono,
    Expression<String>? frecuencia,
    Expression<String>? etiqueta,
    Expression<String>? notas,
    Expression<int>? orden,
    Expression<double>? cuentaCorriente,
    Expression<bool>? showOnMap,
    Expression<int>? docTipo,
    Expression<String>? docNro,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (repartoId != null) 'reparto_id': repartoId,
      if (diaSemana != null) 'dia_semana': diaSemana,
      if (nombre != null) 'nombre': nombre,
      if (direccion != null) 'direccion': direccion,
      if (telefono != null) 'telefono': telefono,
      if (frecuencia != null) 'frecuencia': frecuencia,
      if (etiqueta != null) 'etiqueta': etiqueta,
      if (notas != null) 'notas': notas,
      if (orden != null) 'orden': orden,
      if (cuentaCorriente != null) 'cuenta_corriente': cuentaCorriente,
      if (showOnMap != null) 'show_on_map': showOnMap,
      if (docTipo != null) 'doc_tipo': docTipo,
      if (docNro != null) 'doc_nro': docNro,
    });
  }

  ClientesCompanion copyWith({
    Value<int>? id,
    Value<int>? repartoId,
    Value<int>? diaSemana,
    Value<String>? nombre,
    Value<String>? direccion,
    Value<String>? telefono,
    Value<String>? frecuencia,
    Value<String>? etiqueta,
    Value<String>? notas,
    Value<int>? orden,
    Value<double>? cuentaCorriente,
    Value<bool>? showOnMap,
    Value<int>? docTipo,
    Value<String>? docNro,
  }) {
    return ClientesCompanion(
      id: id ?? this.id,
      repartoId: repartoId ?? this.repartoId,
      diaSemana: diaSemana ?? this.diaSemana,
      nombre: nombre ?? this.nombre,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      frecuencia: frecuencia ?? this.frecuencia,
      etiqueta: etiqueta ?? this.etiqueta,
      notas: notas ?? this.notas,
      orden: orden ?? this.orden,
      cuentaCorriente: cuentaCorriente ?? this.cuentaCorriente,
      showOnMap: showOnMap ?? this.showOnMap,
      docTipo: docTipo ?? this.docTipo,
      docNro: docNro ?? this.docNro,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (repartoId.present) {
      map['reparto_id'] = Variable<int>(repartoId.value);
    }
    if (diaSemana.present) {
      map['dia_semana'] = Variable<int>(diaSemana.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (direccion.present) {
      map['direccion'] = Variable<String>(direccion.value);
    }
    if (telefono.present) {
      map['telefono'] = Variable<String>(telefono.value);
    }
    if (frecuencia.present) {
      map['frecuencia'] = Variable<String>(frecuencia.value);
    }
    if (etiqueta.present) {
      map['etiqueta'] = Variable<String>(etiqueta.value);
    }
    if (notas.present) {
      map['notas'] = Variable<String>(notas.value);
    }
    if (orden.present) {
      map['orden'] = Variable<int>(orden.value);
    }
    if (cuentaCorriente.present) {
      map['cuenta_corriente'] = Variable<double>(cuentaCorriente.value);
    }
    if (showOnMap.present) {
      map['show_on_map'] = Variable<bool>(showOnMap.value);
    }
    if (docTipo.present) {
      map['doc_tipo'] = Variable<int>(docTipo.value);
    }
    if (docNro.present) {
      map['doc_nro'] = Variable<String>(docNro.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClientesCompanion(')
          ..write('id: $id, ')
          ..write('repartoId: $repartoId, ')
          ..write('diaSemana: $diaSemana, ')
          ..write('nombre: $nombre, ')
          ..write('direccion: $direccion, ')
          ..write('telefono: $telefono, ')
          ..write('frecuencia: $frecuencia, ')
          ..write('etiqueta: $etiqueta, ')
          ..write('notas: $notas, ')
          ..write('orden: $orden, ')
          ..write('cuentaCorriente: $cuentaCorriente, ')
          ..write('showOnMap: $showOnMap, ')
          ..write('docTipo: $docTipo, ')
          ..write('docNro: $docNro')
          ..write(')'))
        .toString();
  }
}

class $ClienteProductosTable extends ClienteProductos
    with TableInfo<$ClienteProductosTable, ClienteProducto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClienteProductosTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _clienteIdMeta = const VerificationMeta(
    'clienteId',
  );
  @override
  late final GeneratedColumn<int> clienteId = GeneratedColumn<int>(
    'cliente_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES clientes (id)',
    ),
  );
  static const VerificationMeta _productoIdMeta = const VerificationMeta(
    'productoId',
  );
  @override
  late final GeneratedColumn<int> productoId = GeneratedColumn<int>(
    'producto_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES productos (id)',
    ),
  );
  static const VerificationMeta _cantidadHabitualMeta = const VerificationMeta(
    'cantidadHabitual',
  );
  @override
  late final GeneratedColumn<int> cantidadHabitual = GeneratedColumn<int>(
    'cantidad_habitual',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _precioTipoIdMeta = const VerificationMeta(
    'precioTipoId',
  );
  @override
  late final GeneratedColumn<int> precioTipoId = GeneratedColumn<int>(
    'precio_tipo_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clienteId,
    productoId,
    cantidadHabitual,
    precioTipoId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cliente_productos';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClienteProducto> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cliente_id')) {
      context.handle(
        _clienteIdMeta,
        clienteId.isAcceptableOrUnknown(data['cliente_id']!, _clienteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clienteIdMeta);
    }
    if (data.containsKey('producto_id')) {
      context.handle(
        _productoIdMeta,
        productoId.isAcceptableOrUnknown(data['producto_id']!, _productoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productoIdMeta);
    }
    if (data.containsKey('cantidad_habitual')) {
      context.handle(
        _cantidadHabitualMeta,
        cantidadHabitual.isAcceptableOrUnknown(
          data['cantidad_habitual']!,
          _cantidadHabitualMeta,
        ),
      );
    }
    if (data.containsKey('precio_tipo_id')) {
      context.handle(
        _precioTipoIdMeta,
        precioTipoId.isAcceptableOrUnknown(
          data['precio_tipo_id']!,
          _precioTipoIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClienteProducto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClienteProducto(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clienteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cliente_id'],
      )!,
      productoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}producto_id'],
      )!,
      cantidadHabitual: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cantidad_habitual'],
      )!,
      precioTipoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}precio_tipo_id'],
      ),
    );
  }

  @override
  $ClienteProductosTable createAlias(String alias) {
    return $ClienteProductosTable(attachedDatabase, alias);
  }
}

class ClienteProducto extends DataClass implements Insertable<ClienteProducto> {
  final int id;
  final int clienteId;
  final int productoId;
  final int cantidadHabitual;
  final int? precioTipoId;
  const ClienteProducto({
    required this.id,
    required this.clienteId,
    required this.productoId,
    required this.cantidadHabitual,
    this.precioTipoId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cliente_id'] = Variable<int>(clienteId);
    map['producto_id'] = Variable<int>(productoId);
    map['cantidad_habitual'] = Variable<int>(cantidadHabitual);
    if (!nullToAbsent || precioTipoId != null) {
      map['precio_tipo_id'] = Variable<int>(precioTipoId);
    }
    return map;
  }

  ClienteProductosCompanion toCompanion(bool nullToAbsent) {
    return ClienteProductosCompanion(
      id: Value(id),
      clienteId: Value(clienteId),
      productoId: Value(productoId),
      cantidadHabitual: Value(cantidadHabitual),
      precioTipoId: precioTipoId == null && nullToAbsent
          ? const Value.absent()
          : Value(precioTipoId),
    );
  }

  factory ClienteProducto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClienteProducto(
      id: serializer.fromJson<int>(json['id']),
      clienteId: serializer.fromJson<int>(json['clienteId']),
      productoId: serializer.fromJson<int>(json['productoId']),
      cantidadHabitual: serializer.fromJson<int>(json['cantidadHabitual']),
      precioTipoId: serializer.fromJson<int?>(json['precioTipoId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clienteId': serializer.toJson<int>(clienteId),
      'productoId': serializer.toJson<int>(productoId),
      'cantidadHabitual': serializer.toJson<int>(cantidadHabitual),
      'precioTipoId': serializer.toJson<int?>(precioTipoId),
    };
  }

  ClienteProducto copyWith({
    int? id,
    int? clienteId,
    int? productoId,
    int? cantidadHabitual,
    Value<int?> precioTipoId = const Value.absent(),
  }) => ClienteProducto(
    id: id ?? this.id,
    clienteId: clienteId ?? this.clienteId,
    productoId: productoId ?? this.productoId,
    cantidadHabitual: cantidadHabitual ?? this.cantidadHabitual,
    precioTipoId: precioTipoId.present ? precioTipoId.value : this.precioTipoId,
  );
  ClienteProducto copyWithCompanion(ClienteProductosCompanion data) {
    return ClienteProducto(
      id: data.id.present ? data.id.value : this.id,
      clienteId: data.clienteId.present ? data.clienteId.value : this.clienteId,
      productoId: data.productoId.present
          ? data.productoId.value
          : this.productoId,
      cantidadHabitual: data.cantidadHabitual.present
          ? data.cantidadHabitual.value
          : this.cantidadHabitual,
      precioTipoId: data.precioTipoId.present
          ? data.precioTipoId.value
          : this.precioTipoId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClienteProducto(')
          ..write('id: $id, ')
          ..write('clienteId: $clienteId, ')
          ..write('productoId: $productoId, ')
          ..write('cantidadHabitual: $cantidadHabitual, ')
          ..write('precioTipoId: $precioTipoId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, clienteId, productoId, cantidadHabitual, precioTipoId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClienteProducto &&
          other.id == this.id &&
          other.clienteId == this.clienteId &&
          other.productoId == this.productoId &&
          other.cantidadHabitual == this.cantidadHabitual &&
          other.precioTipoId == this.precioTipoId);
}

class ClienteProductosCompanion extends UpdateCompanion<ClienteProducto> {
  final Value<int> id;
  final Value<int> clienteId;
  final Value<int> productoId;
  final Value<int> cantidadHabitual;
  final Value<int?> precioTipoId;
  const ClienteProductosCompanion({
    this.id = const Value.absent(),
    this.clienteId = const Value.absent(),
    this.productoId = const Value.absent(),
    this.cantidadHabitual = const Value.absent(),
    this.precioTipoId = const Value.absent(),
  });
  ClienteProductosCompanion.insert({
    this.id = const Value.absent(),
    required int clienteId,
    required int productoId,
    this.cantidadHabitual = const Value.absent(),
    this.precioTipoId = const Value.absent(),
  }) : clienteId = Value(clienteId),
       productoId = Value(productoId);
  static Insertable<ClienteProducto> custom({
    Expression<int>? id,
    Expression<int>? clienteId,
    Expression<int>? productoId,
    Expression<int>? cantidadHabitual,
    Expression<int>? precioTipoId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clienteId != null) 'cliente_id': clienteId,
      if (productoId != null) 'producto_id': productoId,
      if (cantidadHabitual != null) 'cantidad_habitual': cantidadHabitual,
      if (precioTipoId != null) 'precio_tipo_id': precioTipoId,
    });
  }

  ClienteProductosCompanion copyWith({
    Value<int>? id,
    Value<int>? clienteId,
    Value<int>? productoId,
    Value<int>? cantidadHabitual,
    Value<int?>? precioTipoId,
  }) {
    return ClienteProductosCompanion(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      productoId: productoId ?? this.productoId,
      cantidadHabitual: cantidadHabitual ?? this.cantidadHabitual,
      precioTipoId: precioTipoId ?? this.precioTipoId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clienteId.present) {
      map['cliente_id'] = Variable<int>(clienteId.value);
    }
    if (productoId.present) {
      map['producto_id'] = Variable<int>(productoId.value);
    }
    if (cantidadHabitual.present) {
      map['cantidad_habitual'] = Variable<int>(cantidadHabitual.value);
    }
    if (precioTipoId.present) {
      map['precio_tipo_id'] = Variable<int>(precioTipoId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClienteProductosCompanion(')
          ..write('id: $id, ')
          ..write('clienteId: $clienteId, ')
          ..write('productoId: $productoId, ')
          ..write('cantidadHabitual: $cantidadHabitual, ')
          ..write('precioTipoId: $precioTipoId')
          ..write(')'))
        .toString();
  }
}

class $EntregasTable extends Entregas with TableInfo<$EntregasTable, Entrega> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntregasTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _clienteIdMeta = const VerificationMeta(
    'clienteId',
  );
  @override
  late final GeneratedColumn<int> clienteId = GeneratedColumn<int>(
    'cliente_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES clientes (id)',
    ),
  );
  static const VerificationMeta _repartoIdMeta = const VerificationMeta(
    'repartoId',
  );
  @override
  late final GeneratedColumn<int> repartoId = GeneratedColumn<int>(
    'reparto_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES repartos (id)',
    ),
  );
  static const VerificationMeta _productoIdMeta = const VerificationMeta(
    'productoId',
  );
  @override
  late final GeneratedColumn<int> productoId = GeneratedColumn<int>(
    'producto_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES productos (id)',
    ),
  );
  static const VerificationMeta _semanaMeta = const VerificationMeta('semana');
  @override
  late final GeneratedColumn<String> semana = GeneratedColumn<String>(
    'semana',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _diaSemanaMeta = const VerificationMeta(
    'diaSemana',
  );
  @override
  late final GeneratedColumn<int> diaSemana = GeneratedColumn<int>(
    'dia_semana',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entregadoMeta = const VerificationMeta(
    'entregado',
  );
  @override
  late final GeneratedColumn<int> entregado = GeneratedColumn<int>(
    'entregado',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _devueltoMeta = const VerificationMeta(
    'devuelto',
  );
  @override
  late final GeneratedColumn<int> devuelto = GeneratedColumn<int>(
    'devuelto',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _precioUnitarioMeta = const VerificationMeta(
    'precioUnitario',
  );
  @override
  late final GeneratedColumn<double> precioUnitario = GeneratedColumn<double>(
    'precio_unitario',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clienteId,
    repartoId,
    productoId,
    semana,
    diaSemana,
    entregado,
    devuelto,
    precioUnitario,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entregas';
  @override
  VerificationContext validateIntegrity(
    Insertable<Entrega> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cliente_id')) {
      context.handle(
        _clienteIdMeta,
        clienteId.isAcceptableOrUnknown(data['cliente_id']!, _clienteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clienteIdMeta);
    }
    if (data.containsKey('reparto_id')) {
      context.handle(
        _repartoIdMeta,
        repartoId.isAcceptableOrUnknown(data['reparto_id']!, _repartoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_repartoIdMeta);
    }
    if (data.containsKey('producto_id')) {
      context.handle(
        _productoIdMeta,
        productoId.isAcceptableOrUnknown(data['producto_id']!, _productoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productoIdMeta);
    }
    if (data.containsKey('semana')) {
      context.handle(
        _semanaMeta,
        semana.isAcceptableOrUnknown(data['semana']!, _semanaMeta),
      );
    } else if (isInserting) {
      context.missing(_semanaMeta);
    }
    if (data.containsKey('dia_semana')) {
      context.handle(
        _diaSemanaMeta,
        diaSemana.isAcceptableOrUnknown(data['dia_semana']!, _diaSemanaMeta),
      );
    } else if (isInserting) {
      context.missing(_diaSemanaMeta);
    }
    if (data.containsKey('entregado')) {
      context.handle(
        _entregadoMeta,
        entregado.isAcceptableOrUnknown(data['entregado']!, _entregadoMeta),
      );
    }
    if (data.containsKey('devuelto')) {
      context.handle(
        _devueltoMeta,
        devuelto.isAcceptableOrUnknown(data['devuelto']!, _devueltoMeta),
      );
    }
    if (data.containsKey('precio_unitario')) {
      context.handle(
        _precioUnitarioMeta,
        precioUnitario.isAcceptableOrUnknown(
          data['precio_unitario']!,
          _precioUnitarioMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Entrega map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entrega(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clienteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cliente_id'],
      )!,
      repartoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reparto_id'],
      )!,
      productoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}producto_id'],
      )!,
      semana: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semana'],
      )!,
      diaSemana: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dia_semana'],
      )!,
      entregado: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entregado'],
      )!,
      devuelto: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}devuelto'],
      )!,
      precioUnitario: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}precio_unitario'],
      )!,
    );
  }

  @override
  $EntregasTable createAlias(String alias) {
    return $EntregasTable(attachedDatabase, alias);
  }
}

class Entrega extends DataClass implements Insertable<Entrega> {
  final int id;
  final int clienteId;
  final int repartoId;
  final int productoId;
  final String semana;
  final int diaSemana;
  final int entregado;
  final int devuelto;
  final double precioUnitario;
  const Entrega({
    required this.id,
    required this.clienteId,
    required this.repartoId,
    required this.productoId,
    required this.semana,
    required this.diaSemana,
    required this.entregado,
    required this.devuelto,
    required this.precioUnitario,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cliente_id'] = Variable<int>(clienteId);
    map['reparto_id'] = Variable<int>(repartoId);
    map['producto_id'] = Variable<int>(productoId);
    map['semana'] = Variable<String>(semana);
    map['dia_semana'] = Variable<int>(diaSemana);
    map['entregado'] = Variable<int>(entregado);
    map['devuelto'] = Variable<int>(devuelto);
    map['precio_unitario'] = Variable<double>(precioUnitario);
    return map;
  }

  EntregasCompanion toCompanion(bool nullToAbsent) {
    return EntregasCompanion(
      id: Value(id),
      clienteId: Value(clienteId),
      repartoId: Value(repartoId),
      productoId: Value(productoId),
      semana: Value(semana),
      diaSemana: Value(diaSemana),
      entregado: Value(entregado),
      devuelto: Value(devuelto),
      precioUnitario: Value(precioUnitario),
    );
  }

  factory Entrega.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entrega(
      id: serializer.fromJson<int>(json['id']),
      clienteId: serializer.fromJson<int>(json['clienteId']),
      repartoId: serializer.fromJson<int>(json['repartoId']),
      productoId: serializer.fromJson<int>(json['productoId']),
      semana: serializer.fromJson<String>(json['semana']),
      diaSemana: serializer.fromJson<int>(json['diaSemana']),
      entregado: serializer.fromJson<int>(json['entregado']),
      devuelto: serializer.fromJson<int>(json['devuelto']),
      precioUnitario: serializer.fromJson<double>(json['precioUnitario']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clienteId': serializer.toJson<int>(clienteId),
      'repartoId': serializer.toJson<int>(repartoId),
      'productoId': serializer.toJson<int>(productoId),
      'semana': serializer.toJson<String>(semana),
      'diaSemana': serializer.toJson<int>(diaSemana),
      'entregado': serializer.toJson<int>(entregado),
      'devuelto': serializer.toJson<int>(devuelto),
      'precioUnitario': serializer.toJson<double>(precioUnitario),
    };
  }

  Entrega copyWith({
    int? id,
    int? clienteId,
    int? repartoId,
    int? productoId,
    String? semana,
    int? diaSemana,
    int? entregado,
    int? devuelto,
    double? precioUnitario,
  }) => Entrega(
    id: id ?? this.id,
    clienteId: clienteId ?? this.clienteId,
    repartoId: repartoId ?? this.repartoId,
    productoId: productoId ?? this.productoId,
    semana: semana ?? this.semana,
    diaSemana: diaSemana ?? this.diaSemana,
    entregado: entregado ?? this.entregado,
    devuelto: devuelto ?? this.devuelto,
    precioUnitario: precioUnitario ?? this.precioUnitario,
  );
  Entrega copyWithCompanion(EntregasCompanion data) {
    return Entrega(
      id: data.id.present ? data.id.value : this.id,
      clienteId: data.clienteId.present ? data.clienteId.value : this.clienteId,
      repartoId: data.repartoId.present ? data.repartoId.value : this.repartoId,
      productoId: data.productoId.present
          ? data.productoId.value
          : this.productoId,
      semana: data.semana.present ? data.semana.value : this.semana,
      diaSemana: data.diaSemana.present ? data.diaSemana.value : this.diaSemana,
      entregado: data.entregado.present ? data.entregado.value : this.entregado,
      devuelto: data.devuelto.present ? data.devuelto.value : this.devuelto,
      precioUnitario: data.precioUnitario.present
          ? data.precioUnitario.value
          : this.precioUnitario,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entrega(')
          ..write('id: $id, ')
          ..write('clienteId: $clienteId, ')
          ..write('repartoId: $repartoId, ')
          ..write('productoId: $productoId, ')
          ..write('semana: $semana, ')
          ..write('diaSemana: $diaSemana, ')
          ..write('entregado: $entregado, ')
          ..write('devuelto: $devuelto, ')
          ..write('precioUnitario: $precioUnitario')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clienteId,
    repartoId,
    productoId,
    semana,
    diaSemana,
    entregado,
    devuelto,
    precioUnitario,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entrega &&
          other.id == this.id &&
          other.clienteId == this.clienteId &&
          other.repartoId == this.repartoId &&
          other.productoId == this.productoId &&
          other.semana == this.semana &&
          other.diaSemana == this.diaSemana &&
          other.entregado == this.entregado &&
          other.devuelto == this.devuelto &&
          other.precioUnitario == this.precioUnitario);
}

class EntregasCompanion extends UpdateCompanion<Entrega> {
  final Value<int> id;
  final Value<int> clienteId;
  final Value<int> repartoId;
  final Value<int> productoId;
  final Value<String> semana;
  final Value<int> diaSemana;
  final Value<int> entregado;
  final Value<int> devuelto;
  final Value<double> precioUnitario;
  const EntregasCompanion({
    this.id = const Value.absent(),
    this.clienteId = const Value.absent(),
    this.repartoId = const Value.absent(),
    this.productoId = const Value.absent(),
    this.semana = const Value.absent(),
    this.diaSemana = const Value.absent(),
    this.entregado = const Value.absent(),
    this.devuelto = const Value.absent(),
    this.precioUnitario = const Value.absent(),
  });
  EntregasCompanion.insert({
    this.id = const Value.absent(),
    required int clienteId,
    required int repartoId,
    required int productoId,
    required String semana,
    required int diaSemana,
    this.entregado = const Value.absent(),
    this.devuelto = const Value.absent(),
    this.precioUnitario = const Value.absent(),
  }) : clienteId = Value(clienteId),
       repartoId = Value(repartoId),
       productoId = Value(productoId),
       semana = Value(semana),
       diaSemana = Value(diaSemana);
  static Insertable<Entrega> custom({
    Expression<int>? id,
    Expression<int>? clienteId,
    Expression<int>? repartoId,
    Expression<int>? productoId,
    Expression<String>? semana,
    Expression<int>? diaSemana,
    Expression<int>? entregado,
    Expression<int>? devuelto,
    Expression<double>? precioUnitario,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clienteId != null) 'cliente_id': clienteId,
      if (repartoId != null) 'reparto_id': repartoId,
      if (productoId != null) 'producto_id': productoId,
      if (semana != null) 'semana': semana,
      if (diaSemana != null) 'dia_semana': diaSemana,
      if (entregado != null) 'entregado': entregado,
      if (devuelto != null) 'devuelto': devuelto,
      if (precioUnitario != null) 'precio_unitario': precioUnitario,
    });
  }

  EntregasCompanion copyWith({
    Value<int>? id,
    Value<int>? clienteId,
    Value<int>? repartoId,
    Value<int>? productoId,
    Value<String>? semana,
    Value<int>? diaSemana,
    Value<int>? entregado,
    Value<int>? devuelto,
    Value<double>? precioUnitario,
  }) {
    return EntregasCompanion(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      repartoId: repartoId ?? this.repartoId,
      productoId: productoId ?? this.productoId,
      semana: semana ?? this.semana,
      diaSemana: diaSemana ?? this.diaSemana,
      entregado: entregado ?? this.entregado,
      devuelto: devuelto ?? this.devuelto,
      precioUnitario: precioUnitario ?? this.precioUnitario,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clienteId.present) {
      map['cliente_id'] = Variable<int>(clienteId.value);
    }
    if (repartoId.present) {
      map['reparto_id'] = Variable<int>(repartoId.value);
    }
    if (productoId.present) {
      map['producto_id'] = Variable<int>(productoId.value);
    }
    if (semana.present) {
      map['semana'] = Variable<String>(semana.value);
    }
    if (diaSemana.present) {
      map['dia_semana'] = Variable<int>(diaSemana.value);
    }
    if (entregado.present) {
      map['entregado'] = Variable<int>(entregado.value);
    }
    if (devuelto.present) {
      map['devuelto'] = Variable<int>(devuelto.value);
    }
    if (precioUnitario.present) {
      map['precio_unitario'] = Variable<double>(precioUnitario.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntregasCompanion(')
          ..write('id: $id, ')
          ..write('clienteId: $clienteId, ')
          ..write('repartoId: $repartoId, ')
          ..write('productoId: $productoId, ')
          ..write('semana: $semana, ')
          ..write('diaSemana: $diaSemana, ')
          ..write('entregado: $entregado, ')
          ..write('devuelto: $devuelto, ')
          ..write('precioUnitario: $precioUnitario')
          ..write(')'))
        .toString();
  }
}

class $PagosTable extends Pagos with TableInfo<$PagosTable, Pago> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PagosTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _clienteIdMeta = const VerificationMeta(
    'clienteId',
  );
  @override
  late final GeneratedColumn<int> clienteId = GeneratedColumn<int>(
    'cliente_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES clientes (id)',
    ),
  );
  static const VerificationMeta _repartoIdMeta = const VerificationMeta(
    'repartoId',
  );
  @override
  late final GeneratedColumn<int> repartoId = GeneratedColumn<int>(
    'reparto_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES repartos (id)',
    ),
  );
  static const VerificationMeta _semanaMeta = const VerificationMeta('semana');
  @override
  late final GeneratedColumn<String> semana = GeneratedColumn<String>(
    'semana',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _diaSemanaMeta = const VerificationMeta(
    'diaSemana',
  );
  @override
  late final GeneratedColumn<int> diaSemana = GeneratedColumn<int>(
    'dia_semana',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metodoPagoMeta = const VerificationMeta(
    'metodoPago',
  );
  @override
  late final GeneratedColumn<String> metodoPago = GeneratedColumn<String>(
    'metodo_pago',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _montoMeta = const VerificationMeta('monto');
  @override
  late final GeneratedColumn<double> monto = GeneratedColumn<double>(
    'monto',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clienteId,
    repartoId,
    semana,
    diaSemana,
    metodoPago,
    monto,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pagos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Pago> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cliente_id')) {
      context.handle(
        _clienteIdMeta,
        clienteId.isAcceptableOrUnknown(data['cliente_id']!, _clienteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clienteIdMeta);
    }
    if (data.containsKey('reparto_id')) {
      context.handle(
        _repartoIdMeta,
        repartoId.isAcceptableOrUnknown(data['reparto_id']!, _repartoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_repartoIdMeta);
    }
    if (data.containsKey('semana')) {
      context.handle(
        _semanaMeta,
        semana.isAcceptableOrUnknown(data['semana']!, _semanaMeta),
      );
    } else if (isInserting) {
      context.missing(_semanaMeta);
    }
    if (data.containsKey('dia_semana')) {
      context.handle(
        _diaSemanaMeta,
        diaSemana.isAcceptableOrUnknown(data['dia_semana']!, _diaSemanaMeta),
      );
    } else if (isInserting) {
      context.missing(_diaSemanaMeta);
    }
    if (data.containsKey('metodo_pago')) {
      context.handle(
        _metodoPagoMeta,
        metodoPago.isAcceptableOrUnknown(data['metodo_pago']!, _metodoPagoMeta),
      );
    } else if (isInserting) {
      context.missing(_metodoPagoMeta);
    }
    if (data.containsKey('monto')) {
      context.handle(
        _montoMeta,
        monto.isAcceptableOrUnknown(data['monto']!, _montoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Pago map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pago(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clienteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cliente_id'],
      )!,
      repartoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reparto_id'],
      )!,
      semana: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semana'],
      )!,
      diaSemana: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dia_semana'],
      )!,
      metodoPago: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metodo_pago'],
      )!,
      monto: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto'],
      )!,
    );
  }

  @override
  $PagosTable createAlias(String alias) {
    return $PagosTable(attachedDatabase, alias);
  }
}

class Pago extends DataClass implements Insertable<Pago> {
  final int id;
  final int clienteId;
  final int repartoId;
  final String semana;
  final int diaSemana;
  final String metodoPago;
  final double monto;
  const Pago({
    required this.id,
    required this.clienteId,
    required this.repartoId,
    required this.semana,
    required this.diaSemana,
    required this.metodoPago,
    required this.monto,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cliente_id'] = Variable<int>(clienteId);
    map['reparto_id'] = Variable<int>(repartoId);
    map['semana'] = Variable<String>(semana);
    map['dia_semana'] = Variable<int>(diaSemana);
    map['metodo_pago'] = Variable<String>(metodoPago);
    map['monto'] = Variable<double>(monto);
    return map;
  }

  PagosCompanion toCompanion(bool nullToAbsent) {
    return PagosCompanion(
      id: Value(id),
      clienteId: Value(clienteId),
      repartoId: Value(repartoId),
      semana: Value(semana),
      diaSemana: Value(diaSemana),
      metodoPago: Value(metodoPago),
      monto: Value(monto),
    );
  }

  factory Pago.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pago(
      id: serializer.fromJson<int>(json['id']),
      clienteId: serializer.fromJson<int>(json['clienteId']),
      repartoId: serializer.fromJson<int>(json['repartoId']),
      semana: serializer.fromJson<String>(json['semana']),
      diaSemana: serializer.fromJson<int>(json['diaSemana']),
      metodoPago: serializer.fromJson<String>(json['metodoPago']),
      monto: serializer.fromJson<double>(json['monto']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clienteId': serializer.toJson<int>(clienteId),
      'repartoId': serializer.toJson<int>(repartoId),
      'semana': serializer.toJson<String>(semana),
      'diaSemana': serializer.toJson<int>(diaSemana),
      'metodoPago': serializer.toJson<String>(metodoPago),
      'monto': serializer.toJson<double>(monto),
    };
  }

  Pago copyWith({
    int? id,
    int? clienteId,
    int? repartoId,
    String? semana,
    int? diaSemana,
    String? metodoPago,
    double? monto,
  }) => Pago(
    id: id ?? this.id,
    clienteId: clienteId ?? this.clienteId,
    repartoId: repartoId ?? this.repartoId,
    semana: semana ?? this.semana,
    diaSemana: diaSemana ?? this.diaSemana,
    metodoPago: metodoPago ?? this.metodoPago,
    monto: monto ?? this.monto,
  );
  Pago copyWithCompanion(PagosCompanion data) {
    return Pago(
      id: data.id.present ? data.id.value : this.id,
      clienteId: data.clienteId.present ? data.clienteId.value : this.clienteId,
      repartoId: data.repartoId.present ? data.repartoId.value : this.repartoId,
      semana: data.semana.present ? data.semana.value : this.semana,
      diaSemana: data.diaSemana.present ? data.diaSemana.value : this.diaSemana,
      metodoPago: data.metodoPago.present
          ? data.metodoPago.value
          : this.metodoPago,
      monto: data.monto.present ? data.monto.value : this.monto,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pago(')
          ..write('id: $id, ')
          ..write('clienteId: $clienteId, ')
          ..write('repartoId: $repartoId, ')
          ..write('semana: $semana, ')
          ..write('diaSemana: $diaSemana, ')
          ..write('metodoPago: $metodoPago, ')
          ..write('monto: $monto')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clienteId,
    repartoId,
    semana,
    diaSemana,
    metodoPago,
    monto,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pago &&
          other.id == this.id &&
          other.clienteId == this.clienteId &&
          other.repartoId == this.repartoId &&
          other.semana == this.semana &&
          other.diaSemana == this.diaSemana &&
          other.metodoPago == this.metodoPago &&
          other.monto == this.monto);
}

class PagosCompanion extends UpdateCompanion<Pago> {
  final Value<int> id;
  final Value<int> clienteId;
  final Value<int> repartoId;
  final Value<String> semana;
  final Value<int> diaSemana;
  final Value<String> metodoPago;
  final Value<double> monto;
  const PagosCompanion({
    this.id = const Value.absent(),
    this.clienteId = const Value.absent(),
    this.repartoId = const Value.absent(),
    this.semana = const Value.absent(),
    this.diaSemana = const Value.absent(),
    this.metodoPago = const Value.absent(),
    this.monto = const Value.absent(),
  });
  PagosCompanion.insert({
    this.id = const Value.absent(),
    required int clienteId,
    required int repartoId,
    required String semana,
    required int diaSemana,
    required String metodoPago,
    this.monto = const Value.absent(),
  }) : clienteId = Value(clienteId),
       repartoId = Value(repartoId),
       semana = Value(semana),
       diaSemana = Value(diaSemana),
       metodoPago = Value(metodoPago);
  static Insertable<Pago> custom({
    Expression<int>? id,
    Expression<int>? clienteId,
    Expression<int>? repartoId,
    Expression<String>? semana,
    Expression<int>? diaSemana,
    Expression<String>? metodoPago,
    Expression<double>? monto,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clienteId != null) 'cliente_id': clienteId,
      if (repartoId != null) 'reparto_id': repartoId,
      if (semana != null) 'semana': semana,
      if (diaSemana != null) 'dia_semana': diaSemana,
      if (metodoPago != null) 'metodo_pago': metodoPago,
      if (monto != null) 'monto': monto,
    });
  }

  PagosCompanion copyWith({
    Value<int>? id,
    Value<int>? clienteId,
    Value<int>? repartoId,
    Value<String>? semana,
    Value<int>? diaSemana,
    Value<String>? metodoPago,
    Value<double>? monto,
  }) {
    return PagosCompanion(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      repartoId: repartoId ?? this.repartoId,
      semana: semana ?? this.semana,
      diaSemana: diaSemana ?? this.diaSemana,
      metodoPago: metodoPago ?? this.metodoPago,
      monto: monto ?? this.monto,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clienteId.present) {
      map['cliente_id'] = Variable<int>(clienteId.value);
    }
    if (repartoId.present) {
      map['reparto_id'] = Variable<int>(repartoId.value);
    }
    if (semana.present) {
      map['semana'] = Variable<String>(semana.value);
    }
    if (diaSemana.present) {
      map['dia_semana'] = Variable<int>(diaSemana.value);
    }
    if (metodoPago.present) {
      map['metodo_pago'] = Variable<String>(metodoPago.value);
    }
    if (monto.present) {
      map['monto'] = Variable<double>(monto.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PagosCompanion(')
          ..write('id: $id, ')
          ..write('clienteId: $clienteId, ')
          ..write('repartoId: $repartoId, ')
          ..write('semana: $semana, ')
          ..write('diaSemana: $diaSemana, ')
          ..write('metodoPago: $metodoPago, ')
          ..write('monto: $monto')
          ..write(')'))
        .toString();
  }
}

class $ResumenesTable extends Resumenes
    with TableInfo<$ResumenesTable, Resumene> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResumenesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _repartoIdMeta = const VerificationMeta(
    'repartoId',
  );
  @override
  late final GeneratedColumn<int> repartoId = GeneratedColumn<int>(
    'reparto_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES repartos (id)',
    ),
  );
  static const VerificationMeta _fechaMeta = const VerificationMeta('fecha');
  @override
  late final GeneratedColumn<String> fecha = GeneratedColumn<String>(
    'fecha',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _semanaMeta = const VerificationMeta('semana');
  @override
  late final GeneratedColumn<String> semana = GeneratedColumn<String>(
    'semana',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _diaSemanaMeta = const VerificationMeta(
    'diaSemana',
  );
  @override
  late final GeneratedColumn<int> diaSemana = GeneratedColumn<int>(
    'dia_semana',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _duracionSegundosMeta = const VerificationMeta(
    'duracionSegundos',
  );
  @override
  late final GeneratedColumn<int> duracionSegundos = GeneratedColumn<int>(
    'duracion_segundos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _efectivoMeta = const VerificationMeta(
    'efectivo',
  );
  @override
  late final GeneratedColumn<double> efectivo = GeneratedColumn<double>(
    'efectivo',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _transferenciaMeta = const VerificationMeta(
    'transferencia',
  );
  @override
  late final GeneratedColumn<double> transferencia = GeneratedColumn<double>(
    'transferencia',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _cuentaCorrienteMeta = const VerificationMeta(
    'cuentaCorriente',
  );
  @override
  late final GeneratedColumn<double> cuentaCorriente = GeneratedColumn<double>(
    'cuenta_corriente',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _gastosMeta = const VerificationMeta('gastos');
  @override
  late final GeneratedColumn<double> gastos = GeneratedColumn<double>(
    'gastos',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _sueldoBrutoMeta = const VerificationMeta(
    'sueldoBruto',
  );
  @override
  late final GeneratedColumn<double> sueldoBruto = GeneratedColumn<double>(
    'sueldo_bruto',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _sueldoNetoMeta = const VerificationMeta(
    'sueldoNeto',
  );
  @override
  late final GeneratedColumn<double> sueldoNeto = GeneratedColumn<double>(
    'sueldo_neto',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _productosJsonMeta = const VerificationMeta(
    'productosJson',
  );
  @override
  late final GeneratedColumn<String> productosJson = GeneratedColumn<String>(
    'productos_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _gastosJsonMeta = const VerificationMeta(
    'gastosJson',
  );
  @override
  late final GeneratedColumn<String> gastosJson = GeneratedColumn<String>(
    'gastos_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    repartoId,
    fecha,
    semana,
    diaSemana,
    duracionSegundos,
    efectivo,
    transferencia,
    cuentaCorriente,
    gastos,
    sueldoBruto,
    sueldoNeto,
    createdAt,
    productosJson,
    gastosJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'resumenes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Resumene> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('reparto_id')) {
      context.handle(
        _repartoIdMeta,
        repartoId.isAcceptableOrUnknown(data['reparto_id']!, _repartoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_repartoIdMeta);
    }
    if (data.containsKey('fecha')) {
      context.handle(
        _fechaMeta,
        fecha.isAcceptableOrUnknown(data['fecha']!, _fechaMeta),
      );
    } else if (isInserting) {
      context.missing(_fechaMeta);
    }
    if (data.containsKey('semana')) {
      context.handle(
        _semanaMeta,
        semana.isAcceptableOrUnknown(data['semana']!, _semanaMeta),
      );
    } else if (isInserting) {
      context.missing(_semanaMeta);
    }
    if (data.containsKey('dia_semana')) {
      context.handle(
        _diaSemanaMeta,
        diaSemana.isAcceptableOrUnknown(data['dia_semana']!, _diaSemanaMeta),
      );
    } else if (isInserting) {
      context.missing(_diaSemanaMeta);
    }
    if (data.containsKey('duracion_segundos')) {
      context.handle(
        _duracionSegundosMeta,
        duracionSegundos.isAcceptableOrUnknown(
          data['duracion_segundos']!,
          _duracionSegundosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_duracionSegundosMeta);
    }
    if (data.containsKey('efectivo')) {
      context.handle(
        _efectivoMeta,
        efectivo.isAcceptableOrUnknown(data['efectivo']!, _efectivoMeta),
      );
    }
    if (data.containsKey('transferencia')) {
      context.handle(
        _transferenciaMeta,
        transferencia.isAcceptableOrUnknown(
          data['transferencia']!,
          _transferenciaMeta,
        ),
      );
    }
    if (data.containsKey('cuenta_corriente')) {
      context.handle(
        _cuentaCorrienteMeta,
        cuentaCorriente.isAcceptableOrUnknown(
          data['cuenta_corriente']!,
          _cuentaCorrienteMeta,
        ),
      );
    }
    if (data.containsKey('gastos')) {
      context.handle(
        _gastosMeta,
        gastos.isAcceptableOrUnknown(data['gastos']!, _gastosMeta),
      );
    }
    if (data.containsKey('sueldo_bruto')) {
      context.handle(
        _sueldoBrutoMeta,
        sueldoBruto.isAcceptableOrUnknown(
          data['sueldo_bruto']!,
          _sueldoBrutoMeta,
        ),
      );
    }
    if (data.containsKey('sueldo_neto')) {
      context.handle(
        _sueldoNetoMeta,
        sueldoNeto.isAcceptableOrUnknown(data['sueldo_neto']!, _sueldoNetoMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('productos_json')) {
      context.handle(
        _productosJsonMeta,
        productosJson.isAcceptableOrUnknown(
          data['productos_json']!,
          _productosJsonMeta,
        ),
      );
    }
    if (data.containsKey('gastos_json')) {
      context.handle(
        _gastosJsonMeta,
        gastosJson.isAcceptableOrUnknown(data['gastos_json']!, _gastosJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Resumene map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Resumene(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      repartoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reparto_id'],
      )!,
      fecha: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fecha'],
      )!,
      semana: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semana'],
      )!,
      diaSemana: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dia_semana'],
      )!,
      duracionSegundos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duracion_segundos'],
      )!,
      efectivo: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}efectivo'],
      )!,
      transferencia: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}transferencia'],
      )!,
      cuentaCorriente: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cuenta_corriente'],
      )!,
      gastos: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gastos'],
      )!,
      sueldoBruto: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sueldo_bruto'],
      )!,
      sueldoNeto: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sueldo_neto'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      productosJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}productos_json'],
      )!,
      gastosJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gastos_json'],
      )!,
    );
  }

  @override
  $ResumenesTable createAlias(String alias) {
    return $ResumenesTable(attachedDatabase, alias);
  }
}

class Resumene extends DataClass implements Insertable<Resumene> {
  final int id;
  final int repartoId;
  final String fecha;
  final String semana;
  final int diaSemana;
  final int duracionSegundos;
  final double efectivo;
  final double transferencia;
  final double cuentaCorriente;
  final double gastos;
  final double sueldoBruto;
  final double sueldoNeto;
  final String createdAt;
  final String productosJson;
  final String gastosJson;
  const Resumene({
    required this.id,
    required this.repartoId,
    required this.fecha,
    required this.semana,
    required this.diaSemana,
    required this.duracionSegundos,
    required this.efectivo,
    required this.transferencia,
    required this.cuentaCorriente,
    required this.gastos,
    required this.sueldoBruto,
    required this.sueldoNeto,
    required this.createdAt,
    required this.productosJson,
    required this.gastosJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['reparto_id'] = Variable<int>(repartoId);
    map['fecha'] = Variable<String>(fecha);
    map['semana'] = Variable<String>(semana);
    map['dia_semana'] = Variable<int>(diaSemana);
    map['duracion_segundos'] = Variable<int>(duracionSegundos);
    map['efectivo'] = Variable<double>(efectivo);
    map['transferencia'] = Variable<double>(transferencia);
    map['cuenta_corriente'] = Variable<double>(cuentaCorriente);
    map['gastos'] = Variable<double>(gastos);
    map['sueldo_bruto'] = Variable<double>(sueldoBruto);
    map['sueldo_neto'] = Variable<double>(sueldoNeto);
    map['created_at'] = Variable<String>(createdAt);
    map['productos_json'] = Variable<String>(productosJson);
    map['gastos_json'] = Variable<String>(gastosJson);
    return map;
  }

  ResumenesCompanion toCompanion(bool nullToAbsent) {
    return ResumenesCompanion(
      id: Value(id),
      repartoId: Value(repartoId),
      fecha: Value(fecha),
      semana: Value(semana),
      diaSemana: Value(diaSemana),
      duracionSegundos: Value(duracionSegundos),
      efectivo: Value(efectivo),
      transferencia: Value(transferencia),
      cuentaCorriente: Value(cuentaCorriente),
      gastos: Value(gastos),
      sueldoBruto: Value(sueldoBruto),
      sueldoNeto: Value(sueldoNeto),
      createdAt: Value(createdAt),
      productosJson: Value(productosJson),
      gastosJson: Value(gastosJson),
    );
  }

  factory Resumene.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Resumene(
      id: serializer.fromJson<int>(json['id']),
      repartoId: serializer.fromJson<int>(json['repartoId']),
      fecha: serializer.fromJson<String>(json['fecha']),
      semana: serializer.fromJson<String>(json['semana']),
      diaSemana: serializer.fromJson<int>(json['diaSemana']),
      duracionSegundos: serializer.fromJson<int>(json['duracionSegundos']),
      efectivo: serializer.fromJson<double>(json['efectivo']),
      transferencia: serializer.fromJson<double>(json['transferencia']),
      cuentaCorriente: serializer.fromJson<double>(json['cuentaCorriente']),
      gastos: serializer.fromJson<double>(json['gastos']),
      sueldoBruto: serializer.fromJson<double>(json['sueldoBruto']),
      sueldoNeto: serializer.fromJson<double>(json['sueldoNeto']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      productosJson: serializer.fromJson<String>(json['productosJson']),
      gastosJson: serializer.fromJson<String>(json['gastosJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'repartoId': serializer.toJson<int>(repartoId),
      'fecha': serializer.toJson<String>(fecha),
      'semana': serializer.toJson<String>(semana),
      'diaSemana': serializer.toJson<int>(diaSemana),
      'duracionSegundos': serializer.toJson<int>(duracionSegundos),
      'efectivo': serializer.toJson<double>(efectivo),
      'transferencia': serializer.toJson<double>(transferencia),
      'cuentaCorriente': serializer.toJson<double>(cuentaCorriente),
      'gastos': serializer.toJson<double>(gastos),
      'sueldoBruto': serializer.toJson<double>(sueldoBruto),
      'sueldoNeto': serializer.toJson<double>(sueldoNeto),
      'createdAt': serializer.toJson<String>(createdAt),
      'productosJson': serializer.toJson<String>(productosJson),
      'gastosJson': serializer.toJson<String>(gastosJson),
    };
  }

  Resumene copyWith({
    int? id,
    int? repartoId,
    String? fecha,
    String? semana,
    int? diaSemana,
    int? duracionSegundos,
    double? efectivo,
    double? transferencia,
    double? cuentaCorriente,
    double? gastos,
    double? sueldoBruto,
    double? sueldoNeto,
    String? createdAt,
    String? productosJson,
    String? gastosJson,
  }) => Resumene(
    id: id ?? this.id,
    repartoId: repartoId ?? this.repartoId,
    fecha: fecha ?? this.fecha,
    semana: semana ?? this.semana,
    diaSemana: diaSemana ?? this.diaSemana,
    duracionSegundos: duracionSegundos ?? this.duracionSegundos,
    efectivo: efectivo ?? this.efectivo,
    transferencia: transferencia ?? this.transferencia,
    cuentaCorriente: cuentaCorriente ?? this.cuentaCorriente,
    gastos: gastos ?? this.gastos,
    sueldoBruto: sueldoBruto ?? this.sueldoBruto,
    sueldoNeto: sueldoNeto ?? this.sueldoNeto,
    createdAt: createdAt ?? this.createdAt,
    productosJson: productosJson ?? this.productosJson,
    gastosJson: gastosJson ?? this.gastosJson,
  );
  Resumene copyWithCompanion(ResumenesCompanion data) {
    return Resumene(
      id: data.id.present ? data.id.value : this.id,
      repartoId: data.repartoId.present ? data.repartoId.value : this.repartoId,
      fecha: data.fecha.present ? data.fecha.value : this.fecha,
      semana: data.semana.present ? data.semana.value : this.semana,
      diaSemana: data.diaSemana.present ? data.diaSemana.value : this.diaSemana,
      duracionSegundos: data.duracionSegundos.present
          ? data.duracionSegundos.value
          : this.duracionSegundos,
      efectivo: data.efectivo.present ? data.efectivo.value : this.efectivo,
      transferencia: data.transferencia.present
          ? data.transferencia.value
          : this.transferencia,
      cuentaCorriente: data.cuentaCorriente.present
          ? data.cuentaCorriente.value
          : this.cuentaCorriente,
      gastos: data.gastos.present ? data.gastos.value : this.gastos,
      sueldoBruto: data.sueldoBruto.present
          ? data.sueldoBruto.value
          : this.sueldoBruto,
      sueldoNeto: data.sueldoNeto.present
          ? data.sueldoNeto.value
          : this.sueldoNeto,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      productosJson: data.productosJson.present
          ? data.productosJson.value
          : this.productosJson,
      gastosJson: data.gastosJson.present
          ? data.gastosJson.value
          : this.gastosJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Resumene(')
          ..write('id: $id, ')
          ..write('repartoId: $repartoId, ')
          ..write('fecha: $fecha, ')
          ..write('semana: $semana, ')
          ..write('diaSemana: $diaSemana, ')
          ..write('duracionSegundos: $duracionSegundos, ')
          ..write('efectivo: $efectivo, ')
          ..write('transferencia: $transferencia, ')
          ..write('cuentaCorriente: $cuentaCorriente, ')
          ..write('gastos: $gastos, ')
          ..write('sueldoBruto: $sueldoBruto, ')
          ..write('sueldoNeto: $sueldoNeto, ')
          ..write('createdAt: $createdAt, ')
          ..write('productosJson: $productosJson, ')
          ..write('gastosJson: $gastosJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    repartoId,
    fecha,
    semana,
    diaSemana,
    duracionSegundos,
    efectivo,
    transferencia,
    cuentaCorriente,
    gastos,
    sueldoBruto,
    sueldoNeto,
    createdAt,
    productosJson,
    gastosJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Resumene &&
          other.id == this.id &&
          other.repartoId == this.repartoId &&
          other.fecha == this.fecha &&
          other.semana == this.semana &&
          other.diaSemana == this.diaSemana &&
          other.duracionSegundos == this.duracionSegundos &&
          other.efectivo == this.efectivo &&
          other.transferencia == this.transferencia &&
          other.cuentaCorriente == this.cuentaCorriente &&
          other.gastos == this.gastos &&
          other.sueldoBruto == this.sueldoBruto &&
          other.sueldoNeto == this.sueldoNeto &&
          other.createdAt == this.createdAt &&
          other.productosJson == this.productosJson &&
          other.gastosJson == this.gastosJson);
}

class ResumenesCompanion extends UpdateCompanion<Resumene> {
  final Value<int> id;
  final Value<int> repartoId;
  final Value<String> fecha;
  final Value<String> semana;
  final Value<int> diaSemana;
  final Value<int> duracionSegundos;
  final Value<double> efectivo;
  final Value<double> transferencia;
  final Value<double> cuentaCorriente;
  final Value<double> gastos;
  final Value<double> sueldoBruto;
  final Value<double> sueldoNeto;
  final Value<String> createdAt;
  final Value<String> productosJson;
  final Value<String> gastosJson;
  const ResumenesCompanion({
    this.id = const Value.absent(),
    this.repartoId = const Value.absent(),
    this.fecha = const Value.absent(),
    this.semana = const Value.absent(),
    this.diaSemana = const Value.absent(),
    this.duracionSegundos = const Value.absent(),
    this.efectivo = const Value.absent(),
    this.transferencia = const Value.absent(),
    this.cuentaCorriente = const Value.absent(),
    this.gastos = const Value.absent(),
    this.sueldoBruto = const Value.absent(),
    this.sueldoNeto = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.productosJson = const Value.absent(),
    this.gastosJson = const Value.absent(),
  });
  ResumenesCompanion.insert({
    this.id = const Value.absent(),
    required int repartoId,
    required String fecha,
    required String semana,
    required int diaSemana,
    required int duracionSegundos,
    this.efectivo = const Value.absent(),
    this.transferencia = const Value.absent(),
    this.cuentaCorriente = const Value.absent(),
    this.gastos = const Value.absent(),
    this.sueldoBruto = const Value.absent(),
    this.sueldoNeto = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.productosJson = const Value.absent(),
    this.gastosJson = const Value.absent(),
  }) : repartoId = Value(repartoId),
       fecha = Value(fecha),
       semana = Value(semana),
       diaSemana = Value(diaSemana),
       duracionSegundos = Value(duracionSegundos);
  static Insertable<Resumene> custom({
    Expression<int>? id,
    Expression<int>? repartoId,
    Expression<String>? fecha,
    Expression<String>? semana,
    Expression<int>? diaSemana,
    Expression<int>? duracionSegundos,
    Expression<double>? efectivo,
    Expression<double>? transferencia,
    Expression<double>? cuentaCorriente,
    Expression<double>? gastos,
    Expression<double>? sueldoBruto,
    Expression<double>? sueldoNeto,
    Expression<String>? createdAt,
    Expression<String>? productosJson,
    Expression<String>? gastosJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (repartoId != null) 'reparto_id': repartoId,
      if (fecha != null) 'fecha': fecha,
      if (semana != null) 'semana': semana,
      if (diaSemana != null) 'dia_semana': diaSemana,
      if (duracionSegundos != null) 'duracion_segundos': duracionSegundos,
      if (efectivo != null) 'efectivo': efectivo,
      if (transferencia != null) 'transferencia': transferencia,
      if (cuentaCorriente != null) 'cuenta_corriente': cuentaCorriente,
      if (gastos != null) 'gastos': gastos,
      if (sueldoBruto != null) 'sueldo_bruto': sueldoBruto,
      if (sueldoNeto != null) 'sueldo_neto': sueldoNeto,
      if (createdAt != null) 'created_at': createdAt,
      if (productosJson != null) 'productos_json': productosJson,
      if (gastosJson != null) 'gastos_json': gastosJson,
    });
  }

  ResumenesCompanion copyWith({
    Value<int>? id,
    Value<int>? repartoId,
    Value<String>? fecha,
    Value<String>? semana,
    Value<int>? diaSemana,
    Value<int>? duracionSegundos,
    Value<double>? efectivo,
    Value<double>? transferencia,
    Value<double>? cuentaCorriente,
    Value<double>? gastos,
    Value<double>? sueldoBruto,
    Value<double>? sueldoNeto,
    Value<String>? createdAt,
    Value<String>? productosJson,
    Value<String>? gastosJson,
  }) {
    return ResumenesCompanion(
      id: id ?? this.id,
      repartoId: repartoId ?? this.repartoId,
      fecha: fecha ?? this.fecha,
      semana: semana ?? this.semana,
      diaSemana: diaSemana ?? this.diaSemana,
      duracionSegundos: duracionSegundos ?? this.duracionSegundos,
      efectivo: efectivo ?? this.efectivo,
      transferencia: transferencia ?? this.transferencia,
      cuentaCorriente: cuentaCorriente ?? this.cuentaCorriente,
      gastos: gastos ?? this.gastos,
      sueldoBruto: sueldoBruto ?? this.sueldoBruto,
      sueldoNeto: sueldoNeto ?? this.sueldoNeto,
      createdAt: createdAt ?? this.createdAt,
      productosJson: productosJson ?? this.productosJson,
      gastosJson: gastosJson ?? this.gastosJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (repartoId.present) {
      map['reparto_id'] = Variable<int>(repartoId.value);
    }
    if (fecha.present) {
      map['fecha'] = Variable<String>(fecha.value);
    }
    if (semana.present) {
      map['semana'] = Variable<String>(semana.value);
    }
    if (diaSemana.present) {
      map['dia_semana'] = Variable<int>(diaSemana.value);
    }
    if (duracionSegundos.present) {
      map['duracion_segundos'] = Variable<int>(duracionSegundos.value);
    }
    if (efectivo.present) {
      map['efectivo'] = Variable<double>(efectivo.value);
    }
    if (transferencia.present) {
      map['transferencia'] = Variable<double>(transferencia.value);
    }
    if (cuentaCorriente.present) {
      map['cuenta_corriente'] = Variable<double>(cuentaCorriente.value);
    }
    if (gastos.present) {
      map['gastos'] = Variable<double>(gastos.value);
    }
    if (sueldoBruto.present) {
      map['sueldo_bruto'] = Variable<double>(sueldoBruto.value);
    }
    if (sueldoNeto.present) {
      map['sueldo_neto'] = Variable<double>(sueldoNeto.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (productosJson.present) {
      map['productos_json'] = Variable<String>(productosJson.value);
    }
    if (gastosJson.present) {
      map['gastos_json'] = Variable<String>(gastosJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResumenesCompanion(')
          ..write('id: $id, ')
          ..write('repartoId: $repartoId, ')
          ..write('fecha: $fecha, ')
          ..write('semana: $semana, ')
          ..write('diaSemana: $diaSemana, ')
          ..write('duracionSegundos: $duracionSegundos, ')
          ..write('efectivo: $efectivo, ')
          ..write('transferencia: $transferencia, ')
          ..write('cuentaCorriente: $cuentaCorriente, ')
          ..write('gastos: $gastos, ')
          ..write('sueldoBruto: $sueldoBruto, ')
          ..write('sueldoNeto: $sueldoNeto, ')
          ..write('createdAt: $createdAt, ')
          ..write('productosJson: $productosJson, ')
          ..write('gastosJson: $gastosJson')
          ..write(')'))
        .toString();
  }
}

class $UserSettingsTable extends UserSettings
    with TableInfo<$UserSettingsTable, UserSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserSettingsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _workDaysMeta = const VerificationMeta(
    'workDays',
  );
  @override
  late final GeneratedColumn<String> workDays = GeneratedColumn<String>(
    'work_days',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('0,1,2,3,4,5'),
  );
  static const VerificationMeta _qrEnabledMeta = const VerificationMeta(
    'qrEnabled',
  );
  @override
  late final GeneratedColumn<bool> qrEnabled = GeneratedColumn<bool>(
    'qr_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("qr_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _mapEnabledMeta = const VerificationMeta(
    'mapEnabled',
  );
  @override
  late final GeneratedColumn<bool> mapEnabled = GeneratedColumn<bool>(
    'map_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("map_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _deudaNotifEnabledMeta = const VerificationMeta(
    'deudaNotifEnabled',
  );
  @override
  late final GeneratedColumn<bool> deudaNotifEnabled = GeneratedColumn<bool>(
    'deuda_notif_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deuda_notif_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _deudaNotifWeeksMeta = const VerificationMeta(
    'deudaNotifWeeks',
  );
  @override
  late final GeneratedColumn<int> deudaNotifWeeks = GeneratedColumn<int>(
    'deuda_notif_weeks',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _inactiveNotifEnabledMeta =
      const VerificationMeta('inactiveNotifEnabled');
  @override
  late final GeneratedColumn<bool> inactiveNotifEnabled = GeneratedColumn<bool>(
    'inactive_notif_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("inactive_notif_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _inactiveNotifWeeksMeta =
      const VerificationMeta('inactiveNotifWeeks');
  @override
  late final GeneratedColumn<int> inactiveNotifWeeks = GeneratedColumn<int>(
    'inactive_notif_weeks',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
  );
  static const VerificationMeta _stockNotifMasterEnabledMeta =
      const VerificationMeta('stockNotifMasterEnabled');
  @override
  late final GeneratedColumn<bool> stockNotifMasterEnabled =
      GeneratedColumn<bool>(
        'stock_notif_master_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("stock_notif_master_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
      );
  static const VerificationMeta _lastRepartoIdMeta = const VerificationMeta(
    'lastRepartoId',
  );
  @override
  late final GeneratedColumn<int> lastRepartoId = GeneratedColumn<int>(
    'last_reparto_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _afipTokenMeta = const VerificationMeta(
    'afipToken',
  );
  @override
  late final GeneratedColumn<String> afipToken = GeneratedColumn<String>(
    'afip_token',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _afipCuitMeta = const VerificationMeta(
    'afipCuit',
  );
  @override
  late final GeneratedColumn<String> afipCuit = GeneratedColumn<String>(
    'afip_cuit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _afipPtoVtaMeta = const VerificationMeta(
    'afipPtoVta',
  );
  @override
  late final GeneratedColumn<int> afipPtoVta = GeneratedColumn<int>(
    'afip_pto_vta',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _afipRazonSocialMeta = const VerificationMeta(
    'afipRazonSocial',
  );
  @override
  late final GeneratedColumn<String> afipRazonSocial = GeneratedColumn<String>(
    'afip_razon_social',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _afipDomicilioMeta = const VerificationMeta(
    'afipDomicilio',
  );
  @override
  late final GeneratedColumn<String> afipDomicilio = GeneratedColumn<String>(
    'afip_domicilio',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _afipCondicionIvaMeta = const VerificationMeta(
    'afipCondicionIva',
  );
  @override
  late final GeneratedColumn<String> afipCondicionIva = GeneratedColumn<String>(
    'afip_condicion_iva',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Monotributista'),
  );
  static const VerificationMeta _afipProductionMeta = const VerificationMeta(
    'afipProduction',
  );
  @override
  late final GeneratedColumn<bool> afipProduction = GeneratedColumn<bool>(
    'afip_production',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("afip_production" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _mpAccessTokenMeta = const VerificationMeta(
    'mpAccessToken',
  );
  @override
  late final GeneratedColumn<String> mpAccessToken = GeneratedColumn<String>(
    'mp_access_token',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workDays,
    qrEnabled,
    mapEnabled,
    deudaNotifEnabled,
    deudaNotifWeeks,
    inactiveNotifEnabled,
    inactiveNotifWeeks,
    stockNotifMasterEnabled,
    lastRepartoId,
    afipToken,
    afipCuit,
    afipPtoVta,
    afipRazonSocial,
    afipDomicilio,
    afipCondicionIva,
    afipProduction,
    mpAccessToken,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('work_days')) {
      context.handle(
        _workDaysMeta,
        workDays.isAcceptableOrUnknown(data['work_days']!, _workDaysMeta),
      );
    }
    if (data.containsKey('qr_enabled')) {
      context.handle(
        _qrEnabledMeta,
        qrEnabled.isAcceptableOrUnknown(data['qr_enabled']!, _qrEnabledMeta),
      );
    }
    if (data.containsKey('map_enabled')) {
      context.handle(
        _mapEnabledMeta,
        mapEnabled.isAcceptableOrUnknown(data['map_enabled']!, _mapEnabledMeta),
      );
    }
    if (data.containsKey('deuda_notif_enabled')) {
      context.handle(
        _deudaNotifEnabledMeta,
        deudaNotifEnabled.isAcceptableOrUnknown(
          data['deuda_notif_enabled']!,
          _deudaNotifEnabledMeta,
        ),
      );
    }
    if (data.containsKey('deuda_notif_weeks')) {
      context.handle(
        _deudaNotifWeeksMeta,
        deudaNotifWeeks.isAcceptableOrUnknown(
          data['deuda_notif_weeks']!,
          _deudaNotifWeeksMeta,
        ),
      );
    }
    if (data.containsKey('inactive_notif_enabled')) {
      context.handle(
        _inactiveNotifEnabledMeta,
        inactiveNotifEnabled.isAcceptableOrUnknown(
          data['inactive_notif_enabled']!,
          _inactiveNotifEnabledMeta,
        ),
      );
    }
    if (data.containsKey('inactive_notif_weeks')) {
      context.handle(
        _inactiveNotifWeeksMeta,
        inactiveNotifWeeks.isAcceptableOrUnknown(
          data['inactive_notif_weeks']!,
          _inactiveNotifWeeksMeta,
        ),
      );
    }
    if (data.containsKey('stock_notif_master_enabled')) {
      context.handle(
        _stockNotifMasterEnabledMeta,
        stockNotifMasterEnabled.isAcceptableOrUnknown(
          data['stock_notif_master_enabled']!,
          _stockNotifMasterEnabledMeta,
        ),
      );
    }
    if (data.containsKey('last_reparto_id')) {
      context.handle(
        _lastRepartoIdMeta,
        lastRepartoId.isAcceptableOrUnknown(
          data['last_reparto_id']!,
          _lastRepartoIdMeta,
        ),
      );
    }
    if (data.containsKey('afip_token')) {
      context.handle(
        _afipTokenMeta,
        afipToken.isAcceptableOrUnknown(data['afip_token']!, _afipTokenMeta),
      );
    }
    if (data.containsKey('afip_cuit')) {
      context.handle(
        _afipCuitMeta,
        afipCuit.isAcceptableOrUnknown(data['afip_cuit']!, _afipCuitMeta),
      );
    }
    if (data.containsKey('afip_pto_vta')) {
      context.handle(
        _afipPtoVtaMeta,
        afipPtoVta.isAcceptableOrUnknown(
          data['afip_pto_vta']!,
          _afipPtoVtaMeta,
        ),
      );
    }
    if (data.containsKey('afip_razon_social')) {
      context.handle(
        _afipRazonSocialMeta,
        afipRazonSocial.isAcceptableOrUnknown(
          data['afip_razon_social']!,
          _afipRazonSocialMeta,
        ),
      );
    }
    if (data.containsKey('afip_domicilio')) {
      context.handle(
        _afipDomicilioMeta,
        afipDomicilio.isAcceptableOrUnknown(
          data['afip_domicilio']!,
          _afipDomicilioMeta,
        ),
      );
    }
    if (data.containsKey('afip_condicion_iva')) {
      context.handle(
        _afipCondicionIvaMeta,
        afipCondicionIva.isAcceptableOrUnknown(
          data['afip_condicion_iva']!,
          _afipCondicionIvaMeta,
        ),
      );
    }
    if (data.containsKey('afip_production')) {
      context.handle(
        _afipProductionMeta,
        afipProduction.isAcceptableOrUnknown(
          data['afip_production']!,
          _afipProductionMeta,
        ),
      );
    }
    if (data.containsKey('mp_access_token')) {
      context.handle(
        _mpAccessTokenMeta,
        mpAccessToken.isAcceptableOrUnknown(
          data['mp_access_token']!,
          _mpAccessTokenMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      workDays: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_days'],
      )!,
      qrEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}qr_enabled'],
      )!,
      mapEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}map_enabled'],
      )!,
      deudaNotifEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deuda_notif_enabled'],
      )!,
      deudaNotifWeeks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deuda_notif_weeks'],
      )!,
      inactiveNotifEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}inactive_notif_enabled'],
      )!,
      inactiveNotifWeeks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}inactive_notif_weeks'],
      )!,
      stockNotifMasterEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}stock_notif_master_enabled'],
      )!,
      lastRepartoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_reparto_id'],
      ),
      afipToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}afip_token'],
      )!,
      afipCuit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}afip_cuit'],
      )!,
      afipPtoVta: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}afip_pto_vta'],
      )!,
      afipRazonSocial: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}afip_razon_social'],
      )!,
      afipDomicilio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}afip_domicilio'],
      )!,
      afipCondicionIva: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}afip_condicion_iva'],
      )!,
      afipProduction: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}afip_production'],
      )!,
      mpAccessToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mp_access_token'],
      )!,
    );
  }

  @override
  $UserSettingsTable createAlias(String alias) {
    return $UserSettingsTable(attachedDatabase, alias);
  }
}

class UserSetting extends DataClass implements Insertable<UserSetting> {
  final int id;
  final String workDays;
  final bool qrEnabled;
  final bool mapEnabled;
  final bool deudaNotifEnabled;
  final int deudaNotifWeeks;
  final bool inactiveNotifEnabled;
  final int inactiveNotifWeeks;
  final bool stockNotifMasterEnabled;
  final int? lastRepartoId;
  final String afipToken;
  final String afipCuit;
  final int afipPtoVta;
  final String afipRazonSocial;
  final String afipDomicilio;
  final String afipCondicionIva;
  final bool afipProduction;
  final String mpAccessToken;
  const UserSetting({
    required this.id,
    required this.workDays,
    required this.qrEnabled,
    required this.mapEnabled,
    required this.deudaNotifEnabled,
    required this.deudaNotifWeeks,
    required this.inactiveNotifEnabled,
    required this.inactiveNotifWeeks,
    required this.stockNotifMasterEnabled,
    this.lastRepartoId,
    required this.afipToken,
    required this.afipCuit,
    required this.afipPtoVta,
    required this.afipRazonSocial,
    required this.afipDomicilio,
    required this.afipCondicionIva,
    required this.afipProduction,
    required this.mpAccessToken,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['work_days'] = Variable<String>(workDays);
    map['qr_enabled'] = Variable<bool>(qrEnabled);
    map['map_enabled'] = Variable<bool>(mapEnabled);
    map['deuda_notif_enabled'] = Variable<bool>(deudaNotifEnabled);
    map['deuda_notif_weeks'] = Variable<int>(deudaNotifWeeks);
    map['inactive_notif_enabled'] = Variable<bool>(inactiveNotifEnabled);
    map['inactive_notif_weeks'] = Variable<int>(inactiveNotifWeeks);
    map['stock_notif_master_enabled'] = Variable<bool>(stockNotifMasterEnabled);
    if (!nullToAbsent || lastRepartoId != null) {
      map['last_reparto_id'] = Variable<int>(lastRepartoId);
    }
    map['afip_token'] = Variable<String>(afipToken);
    map['afip_cuit'] = Variable<String>(afipCuit);
    map['afip_pto_vta'] = Variable<int>(afipPtoVta);
    map['afip_razon_social'] = Variable<String>(afipRazonSocial);
    map['afip_domicilio'] = Variable<String>(afipDomicilio);
    map['afip_condicion_iva'] = Variable<String>(afipCondicionIva);
    map['afip_production'] = Variable<bool>(afipProduction);
    map['mp_access_token'] = Variable<String>(mpAccessToken);
    return map;
  }

  UserSettingsCompanion toCompanion(bool nullToAbsent) {
    return UserSettingsCompanion(
      id: Value(id),
      workDays: Value(workDays),
      qrEnabled: Value(qrEnabled),
      mapEnabled: Value(mapEnabled),
      deudaNotifEnabled: Value(deudaNotifEnabled),
      deudaNotifWeeks: Value(deudaNotifWeeks),
      inactiveNotifEnabled: Value(inactiveNotifEnabled),
      inactiveNotifWeeks: Value(inactiveNotifWeeks),
      stockNotifMasterEnabled: Value(stockNotifMasterEnabled),
      lastRepartoId: lastRepartoId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRepartoId),
      afipToken: Value(afipToken),
      afipCuit: Value(afipCuit),
      afipPtoVta: Value(afipPtoVta),
      afipRazonSocial: Value(afipRazonSocial),
      afipDomicilio: Value(afipDomicilio),
      afipCondicionIva: Value(afipCondicionIva),
      afipProduction: Value(afipProduction),
      mpAccessToken: Value(mpAccessToken),
    );
  }

  factory UserSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserSetting(
      id: serializer.fromJson<int>(json['id']),
      workDays: serializer.fromJson<String>(json['workDays']),
      qrEnabled: serializer.fromJson<bool>(json['qrEnabled']),
      mapEnabled: serializer.fromJson<bool>(json['mapEnabled']),
      deudaNotifEnabled: serializer.fromJson<bool>(json['deudaNotifEnabled']),
      deudaNotifWeeks: serializer.fromJson<int>(json['deudaNotifWeeks']),
      inactiveNotifEnabled: serializer.fromJson<bool>(
        json['inactiveNotifEnabled'],
      ),
      inactiveNotifWeeks: serializer.fromJson<int>(json['inactiveNotifWeeks']),
      stockNotifMasterEnabled: serializer.fromJson<bool>(
        json['stockNotifMasterEnabled'],
      ),
      lastRepartoId: serializer.fromJson<int?>(json['lastRepartoId']),
      afipToken: serializer.fromJson<String>(json['afipToken']),
      afipCuit: serializer.fromJson<String>(json['afipCuit']),
      afipPtoVta: serializer.fromJson<int>(json['afipPtoVta']),
      afipRazonSocial: serializer.fromJson<String>(json['afipRazonSocial']),
      afipDomicilio: serializer.fromJson<String>(json['afipDomicilio']),
      afipCondicionIva: serializer.fromJson<String>(json['afipCondicionIva']),
      afipProduction: serializer.fromJson<bool>(json['afipProduction']),
      mpAccessToken: serializer.fromJson<String>(json['mpAccessToken']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'workDays': serializer.toJson<String>(workDays),
      'qrEnabled': serializer.toJson<bool>(qrEnabled),
      'mapEnabled': serializer.toJson<bool>(mapEnabled),
      'deudaNotifEnabled': serializer.toJson<bool>(deudaNotifEnabled),
      'deudaNotifWeeks': serializer.toJson<int>(deudaNotifWeeks),
      'inactiveNotifEnabled': serializer.toJson<bool>(inactiveNotifEnabled),
      'inactiveNotifWeeks': serializer.toJson<int>(inactiveNotifWeeks),
      'stockNotifMasterEnabled': serializer.toJson<bool>(
        stockNotifMasterEnabled,
      ),
      'lastRepartoId': serializer.toJson<int?>(lastRepartoId),
      'afipToken': serializer.toJson<String>(afipToken),
      'afipCuit': serializer.toJson<String>(afipCuit),
      'afipPtoVta': serializer.toJson<int>(afipPtoVta),
      'afipRazonSocial': serializer.toJson<String>(afipRazonSocial),
      'afipDomicilio': serializer.toJson<String>(afipDomicilio),
      'afipCondicionIva': serializer.toJson<String>(afipCondicionIva),
      'afipProduction': serializer.toJson<bool>(afipProduction),
      'mpAccessToken': serializer.toJson<String>(mpAccessToken),
    };
  }

  UserSetting copyWith({
    int? id,
    String? workDays,
    bool? qrEnabled,
    bool? mapEnabled,
    bool? deudaNotifEnabled,
    int? deudaNotifWeeks,
    bool? inactiveNotifEnabled,
    int? inactiveNotifWeeks,
    bool? stockNotifMasterEnabled,
    Value<int?> lastRepartoId = const Value.absent(),
    String? afipToken,
    String? afipCuit,
    int? afipPtoVta,
    String? afipRazonSocial,
    String? afipDomicilio,
    String? afipCondicionIva,
    bool? afipProduction,
    String? mpAccessToken,
  }) => UserSetting(
    id: id ?? this.id,
    workDays: workDays ?? this.workDays,
    qrEnabled: qrEnabled ?? this.qrEnabled,
    mapEnabled: mapEnabled ?? this.mapEnabled,
    deudaNotifEnabled: deudaNotifEnabled ?? this.deudaNotifEnabled,
    deudaNotifWeeks: deudaNotifWeeks ?? this.deudaNotifWeeks,
    inactiveNotifEnabled: inactiveNotifEnabled ?? this.inactiveNotifEnabled,
    inactiveNotifWeeks: inactiveNotifWeeks ?? this.inactiveNotifWeeks,
    stockNotifMasterEnabled:
        stockNotifMasterEnabled ?? this.stockNotifMasterEnabled,
    lastRepartoId: lastRepartoId.present
        ? lastRepartoId.value
        : this.lastRepartoId,
    afipToken: afipToken ?? this.afipToken,
    afipCuit: afipCuit ?? this.afipCuit,
    afipPtoVta: afipPtoVta ?? this.afipPtoVta,
    afipRazonSocial: afipRazonSocial ?? this.afipRazonSocial,
    afipDomicilio: afipDomicilio ?? this.afipDomicilio,
    afipCondicionIva: afipCondicionIva ?? this.afipCondicionIva,
    afipProduction: afipProduction ?? this.afipProduction,
    mpAccessToken: mpAccessToken ?? this.mpAccessToken,
  );
  UserSetting copyWithCompanion(UserSettingsCompanion data) {
    return UserSetting(
      id: data.id.present ? data.id.value : this.id,
      workDays: data.workDays.present ? data.workDays.value : this.workDays,
      qrEnabled: data.qrEnabled.present ? data.qrEnabled.value : this.qrEnabled,
      mapEnabled: data.mapEnabled.present
          ? data.mapEnabled.value
          : this.mapEnabled,
      deudaNotifEnabled: data.deudaNotifEnabled.present
          ? data.deudaNotifEnabled.value
          : this.deudaNotifEnabled,
      deudaNotifWeeks: data.deudaNotifWeeks.present
          ? data.deudaNotifWeeks.value
          : this.deudaNotifWeeks,
      inactiveNotifEnabled: data.inactiveNotifEnabled.present
          ? data.inactiveNotifEnabled.value
          : this.inactiveNotifEnabled,
      inactiveNotifWeeks: data.inactiveNotifWeeks.present
          ? data.inactiveNotifWeeks.value
          : this.inactiveNotifWeeks,
      stockNotifMasterEnabled: data.stockNotifMasterEnabled.present
          ? data.stockNotifMasterEnabled.value
          : this.stockNotifMasterEnabled,
      lastRepartoId: data.lastRepartoId.present
          ? data.lastRepartoId.value
          : this.lastRepartoId,
      afipToken: data.afipToken.present ? data.afipToken.value : this.afipToken,
      afipCuit: data.afipCuit.present ? data.afipCuit.value : this.afipCuit,
      afipPtoVta: data.afipPtoVta.present
          ? data.afipPtoVta.value
          : this.afipPtoVta,
      afipRazonSocial: data.afipRazonSocial.present
          ? data.afipRazonSocial.value
          : this.afipRazonSocial,
      afipDomicilio: data.afipDomicilio.present
          ? data.afipDomicilio.value
          : this.afipDomicilio,
      afipCondicionIva: data.afipCondicionIva.present
          ? data.afipCondicionIva.value
          : this.afipCondicionIva,
      afipProduction: data.afipProduction.present
          ? data.afipProduction.value
          : this.afipProduction,
      mpAccessToken: data.mpAccessToken.present
          ? data.mpAccessToken.value
          : this.mpAccessToken,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserSetting(')
          ..write('id: $id, ')
          ..write('workDays: $workDays, ')
          ..write('qrEnabled: $qrEnabled, ')
          ..write('mapEnabled: $mapEnabled, ')
          ..write('deudaNotifEnabled: $deudaNotifEnabled, ')
          ..write('deudaNotifWeeks: $deudaNotifWeeks, ')
          ..write('inactiveNotifEnabled: $inactiveNotifEnabled, ')
          ..write('inactiveNotifWeeks: $inactiveNotifWeeks, ')
          ..write('stockNotifMasterEnabled: $stockNotifMasterEnabled, ')
          ..write('lastRepartoId: $lastRepartoId, ')
          ..write('afipToken: $afipToken, ')
          ..write('afipCuit: $afipCuit, ')
          ..write('afipPtoVta: $afipPtoVta, ')
          ..write('afipRazonSocial: $afipRazonSocial, ')
          ..write('afipDomicilio: $afipDomicilio, ')
          ..write('afipCondicionIva: $afipCondicionIva, ')
          ..write('afipProduction: $afipProduction, ')
          ..write('mpAccessToken: $mpAccessToken')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workDays,
    qrEnabled,
    mapEnabled,
    deudaNotifEnabled,
    deudaNotifWeeks,
    inactiveNotifEnabled,
    inactiveNotifWeeks,
    stockNotifMasterEnabled,
    lastRepartoId,
    afipToken,
    afipCuit,
    afipPtoVta,
    afipRazonSocial,
    afipDomicilio,
    afipCondicionIva,
    afipProduction,
    mpAccessToken,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserSetting &&
          other.id == this.id &&
          other.workDays == this.workDays &&
          other.qrEnabled == this.qrEnabled &&
          other.mapEnabled == this.mapEnabled &&
          other.deudaNotifEnabled == this.deudaNotifEnabled &&
          other.deudaNotifWeeks == this.deudaNotifWeeks &&
          other.inactiveNotifEnabled == this.inactiveNotifEnabled &&
          other.inactiveNotifWeeks == this.inactiveNotifWeeks &&
          other.stockNotifMasterEnabled == this.stockNotifMasterEnabled &&
          other.lastRepartoId == this.lastRepartoId &&
          other.afipToken == this.afipToken &&
          other.afipCuit == this.afipCuit &&
          other.afipPtoVta == this.afipPtoVta &&
          other.afipRazonSocial == this.afipRazonSocial &&
          other.afipDomicilio == this.afipDomicilio &&
          other.afipCondicionIva == this.afipCondicionIva &&
          other.afipProduction == this.afipProduction &&
          other.mpAccessToken == this.mpAccessToken);
}

class UserSettingsCompanion extends UpdateCompanion<UserSetting> {
  final Value<int> id;
  final Value<String> workDays;
  final Value<bool> qrEnabled;
  final Value<bool> mapEnabled;
  final Value<bool> deudaNotifEnabled;
  final Value<int> deudaNotifWeeks;
  final Value<bool> inactiveNotifEnabled;
  final Value<int> inactiveNotifWeeks;
  final Value<bool> stockNotifMasterEnabled;
  final Value<int?> lastRepartoId;
  final Value<String> afipToken;
  final Value<String> afipCuit;
  final Value<int> afipPtoVta;
  final Value<String> afipRazonSocial;
  final Value<String> afipDomicilio;
  final Value<String> afipCondicionIva;
  final Value<bool> afipProduction;
  final Value<String> mpAccessToken;
  const UserSettingsCompanion({
    this.id = const Value.absent(),
    this.workDays = const Value.absent(),
    this.qrEnabled = const Value.absent(),
    this.mapEnabled = const Value.absent(),
    this.deudaNotifEnabled = const Value.absent(),
    this.deudaNotifWeeks = const Value.absent(),
    this.inactiveNotifEnabled = const Value.absent(),
    this.inactiveNotifWeeks = const Value.absent(),
    this.stockNotifMasterEnabled = const Value.absent(),
    this.lastRepartoId = const Value.absent(),
    this.afipToken = const Value.absent(),
    this.afipCuit = const Value.absent(),
    this.afipPtoVta = const Value.absent(),
    this.afipRazonSocial = const Value.absent(),
    this.afipDomicilio = const Value.absent(),
    this.afipCondicionIva = const Value.absent(),
    this.afipProduction = const Value.absent(),
    this.mpAccessToken = const Value.absent(),
  });
  UserSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.workDays = const Value.absent(),
    this.qrEnabled = const Value.absent(),
    this.mapEnabled = const Value.absent(),
    this.deudaNotifEnabled = const Value.absent(),
    this.deudaNotifWeeks = const Value.absent(),
    this.inactiveNotifEnabled = const Value.absent(),
    this.inactiveNotifWeeks = const Value.absent(),
    this.stockNotifMasterEnabled = const Value.absent(),
    this.lastRepartoId = const Value.absent(),
    this.afipToken = const Value.absent(),
    this.afipCuit = const Value.absent(),
    this.afipPtoVta = const Value.absent(),
    this.afipRazonSocial = const Value.absent(),
    this.afipDomicilio = const Value.absent(),
    this.afipCondicionIva = const Value.absent(),
    this.afipProduction = const Value.absent(),
    this.mpAccessToken = const Value.absent(),
  });
  static Insertable<UserSetting> custom({
    Expression<int>? id,
    Expression<String>? workDays,
    Expression<bool>? qrEnabled,
    Expression<bool>? mapEnabled,
    Expression<bool>? deudaNotifEnabled,
    Expression<int>? deudaNotifWeeks,
    Expression<bool>? inactiveNotifEnabled,
    Expression<int>? inactiveNotifWeeks,
    Expression<bool>? stockNotifMasterEnabled,
    Expression<int>? lastRepartoId,
    Expression<String>? afipToken,
    Expression<String>? afipCuit,
    Expression<int>? afipPtoVta,
    Expression<String>? afipRazonSocial,
    Expression<String>? afipDomicilio,
    Expression<String>? afipCondicionIva,
    Expression<bool>? afipProduction,
    Expression<String>? mpAccessToken,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workDays != null) 'work_days': workDays,
      if (qrEnabled != null) 'qr_enabled': qrEnabled,
      if (mapEnabled != null) 'map_enabled': mapEnabled,
      if (deudaNotifEnabled != null) 'deuda_notif_enabled': deudaNotifEnabled,
      if (deudaNotifWeeks != null) 'deuda_notif_weeks': deudaNotifWeeks,
      if (inactiveNotifEnabled != null)
        'inactive_notif_enabled': inactiveNotifEnabled,
      if (inactiveNotifWeeks != null)
        'inactive_notif_weeks': inactiveNotifWeeks,
      if (stockNotifMasterEnabled != null)
        'stock_notif_master_enabled': stockNotifMasterEnabled,
      if (lastRepartoId != null) 'last_reparto_id': lastRepartoId,
      if (afipToken != null) 'afip_token': afipToken,
      if (afipCuit != null) 'afip_cuit': afipCuit,
      if (afipPtoVta != null) 'afip_pto_vta': afipPtoVta,
      if (afipRazonSocial != null) 'afip_razon_social': afipRazonSocial,
      if (afipDomicilio != null) 'afip_domicilio': afipDomicilio,
      if (afipCondicionIva != null) 'afip_condicion_iva': afipCondicionIva,
      if (afipProduction != null) 'afip_production': afipProduction,
      if (mpAccessToken != null) 'mp_access_token': mpAccessToken,
    });
  }

  UserSettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? workDays,
    Value<bool>? qrEnabled,
    Value<bool>? mapEnabled,
    Value<bool>? deudaNotifEnabled,
    Value<int>? deudaNotifWeeks,
    Value<bool>? inactiveNotifEnabled,
    Value<int>? inactiveNotifWeeks,
    Value<bool>? stockNotifMasterEnabled,
    Value<int?>? lastRepartoId,
    Value<String>? afipToken,
    Value<String>? afipCuit,
    Value<int>? afipPtoVta,
    Value<String>? afipRazonSocial,
    Value<String>? afipDomicilio,
    Value<String>? afipCondicionIva,
    Value<bool>? afipProduction,
    Value<String>? mpAccessToken,
  }) {
    return UserSettingsCompanion(
      id: id ?? this.id,
      workDays: workDays ?? this.workDays,
      qrEnabled: qrEnabled ?? this.qrEnabled,
      mapEnabled: mapEnabled ?? this.mapEnabled,
      deudaNotifEnabled: deudaNotifEnabled ?? this.deudaNotifEnabled,
      deudaNotifWeeks: deudaNotifWeeks ?? this.deudaNotifWeeks,
      inactiveNotifEnabled: inactiveNotifEnabled ?? this.inactiveNotifEnabled,
      inactiveNotifWeeks: inactiveNotifWeeks ?? this.inactiveNotifWeeks,
      stockNotifMasterEnabled:
          stockNotifMasterEnabled ?? this.stockNotifMasterEnabled,
      lastRepartoId: lastRepartoId ?? this.lastRepartoId,
      afipToken: afipToken ?? this.afipToken,
      afipCuit: afipCuit ?? this.afipCuit,
      afipPtoVta: afipPtoVta ?? this.afipPtoVta,
      afipRazonSocial: afipRazonSocial ?? this.afipRazonSocial,
      afipDomicilio: afipDomicilio ?? this.afipDomicilio,
      afipCondicionIva: afipCondicionIva ?? this.afipCondicionIva,
      afipProduction: afipProduction ?? this.afipProduction,
      mpAccessToken: mpAccessToken ?? this.mpAccessToken,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (workDays.present) {
      map['work_days'] = Variable<String>(workDays.value);
    }
    if (qrEnabled.present) {
      map['qr_enabled'] = Variable<bool>(qrEnabled.value);
    }
    if (mapEnabled.present) {
      map['map_enabled'] = Variable<bool>(mapEnabled.value);
    }
    if (deudaNotifEnabled.present) {
      map['deuda_notif_enabled'] = Variable<bool>(deudaNotifEnabled.value);
    }
    if (deudaNotifWeeks.present) {
      map['deuda_notif_weeks'] = Variable<int>(deudaNotifWeeks.value);
    }
    if (inactiveNotifEnabled.present) {
      map['inactive_notif_enabled'] = Variable<bool>(
        inactiveNotifEnabled.value,
      );
    }
    if (inactiveNotifWeeks.present) {
      map['inactive_notif_weeks'] = Variable<int>(inactiveNotifWeeks.value);
    }
    if (stockNotifMasterEnabled.present) {
      map['stock_notif_master_enabled'] = Variable<bool>(
        stockNotifMasterEnabled.value,
      );
    }
    if (lastRepartoId.present) {
      map['last_reparto_id'] = Variable<int>(lastRepartoId.value);
    }
    if (afipToken.present) {
      map['afip_token'] = Variable<String>(afipToken.value);
    }
    if (afipCuit.present) {
      map['afip_cuit'] = Variable<String>(afipCuit.value);
    }
    if (afipPtoVta.present) {
      map['afip_pto_vta'] = Variable<int>(afipPtoVta.value);
    }
    if (afipRazonSocial.present) {
      map['afip_razon_social'] = Variable<String>(afipRazonSocial.value);
    }
    if (afipDomicilio.present) {
      map['afip_domicilio'] = Variable<String>(afipDomicilio.value);
    }
    if (afipCondicionIva.present) {
      map['afip_condicion_iva'] = Variable<String>(afipCondicionIva.value);
    }
    if (afipProduction.present) {
      map['afip_production'] = Variable<bool>(afipProduction.value);
    }
    if (mpAccessToken.present) {
      map['mp_access_token'] = Variable<String>(mpAccessToken.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserSettingsCompanion(')
          ..write('id: $id, ')
          ..write('workDays: $workDays, ')
          ..write('qrEnabled: $qrEnabled, ')
          ..write('mapEnabled: $mapEnabled, ')
          ..write('deudaNotifEnabled: $deudaNotifEnabled, ')
          ..write('deudaNotifWeeks: $deudaNotifWeeks, ')
          ..write('inactiveNotifEnabled: $inactiveNotifEnabled, ')
          ..write('inactiveNotifWeeks: $inactiveNotifWeeks, ')
          ..write('stockNotifMasterEnabled: $stockNotifMasterEnabled, ')
          ..write('lastRepartoId: $lastRepartoId, ')
          ..write('afipToken: $afipToken, ')
          ..write('afipCuit: $afipCuit, ')
          ..write('afipPtoVta: $afipPtoVta, ')
          ..write('afipRazonSocial: $afipRazonSocial, ')
          ..write('afipDomicilio: $afipDomicilio, ')
          ..write('afipCondicionIva: $afipCondicionIva, ')
          ..write('afipProduction: $afipProduction, ')
          ..write('mpAccessToken: $mpAccessToken')
          ..write(')'))
        .toString();
  }
}

class $EtiquetaColorsTable extends EtiquetaColors
    with TableInfo<$EtiquetaColorsTable, EtiquetaColor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EtiquetaColorsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _repartoIdMeta = const VerificationMeta(
    'repartoId',
  );
  @override
  late final GeneratedColumn<int> repartoId = GeneratedColumn<int>(
    'reparto_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES repartos (id)',
    ),
  );
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, repartoId, nombre, colorHex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'etiqueta_colors';
  @override
  VerificationContext validateIntegrity(
    Insertable<EtiquetaColor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('reparto_id')) {
      context.handle(
        _repartoIdMeta,
        repartoId.isAcceptableOrUnknown(data['reparto_id']!, _repartoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_repartoIdMeta);
    }
    if (data.containsKey('nombre')) {
      context.handle(
        _nombreMeta,
        nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta),
      );
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    } else if (isInserting) {
      context.missing(_colorHexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EtiquetaColor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EtiquetaColor(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      repartoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reparto_id'],
      )!,
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      )!,
    );
  }

  @override
  $EtiquetaColorsTable createAlias(String alias) {
    return $EtiquetaColorsTable(attachedDatabase, alias);
  }
}

class EtiquetaColor extends DataClass implements Insertable<EtiquetaColor> {
  final int id;
  final int repartoId;
  final String nombre;
  final String colorHex;
  const EtiquetaColor({
    required this.id,
    required this.repartoId,
    required this.nombre,
    required this.colorHex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['reparto_id'] = Variable<int>(repartoId);
    map['nombre'] = Variable<String>(nombre);
    map['color_hex'] = Variable<String>(colorHex);
    return map;
  }

  EtiquetaColorsCompanion toCompanion(bool nullToAbsent) {
    return EtiquetaColorsCompanion(
      id: Value(id),
      repartoId: Value(repartoId),
      nombre: Value(nombre),
      colorHex: Value(colorHex),
    );
  }

  factory EtiquetaColor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EtiquetaColor(
      id: serializer.fromJson<int>(json['id']),
      repartoId: serializer.fromJson<int>(json['repartoId']),
      nombre: serializer.fromJson<String>(json['nombre']),
      colorHex: serializer.fromJson<String>(json['colorHex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'repartoId': serializer.toJson<int>(repartoId),
      'nombre': serializer.toJson<String>(nombre),
      'colorHex': serializer.toJson<String>(colorHex),
    };
  }

  EtiquetaColor copyWith({
    int? id,
    int? repartoId,
    String? nombre,
    String? colorHex,
  }) => EtiquetaColor(
    id: id ?? this.id,
    repartoId: repartoId ?? this.repartoId,
    nombre: nombre ?? this.nombre,
    colorHex: colorHex ?? this.colorHex,
  );
  EtiquetaColor copyWithCompanion(EtiquetaColorsCompanion data) {
    return EtiquetaColor(
      id: data.id.present ? data.id.value : this.id,
      repartoId: data.repartoId.present ? data.repartoId.value : this.repartoId,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EtiquetaColor(')
          ..write('id: $id, ')
          ..write('repartoId: $repartoId, ')
          ..write('nombre: $nombre, ')
          ..write('colorHex: $colorHex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, repartoId, nombre, colorHex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EtiquetaColor &&
          other.id == this.id &&
          other.repartoId == this.repartoId &&
          other.nombre == this.nombre &&
          other.colorHex == this.colorHex);
}

class EtiquetaColorsCompanion extends UpdateCompanion<EtiquetaColor> {
  final Value<int> id;
  final Value<int> repartoId;
  final Value<String> nombre;
  final Value<String> colorHex;
  const EtiquetaColorsCompanion({
    this.id = const Value.absent(),
    this.repartoId = const Value.absent(),
    this.nombre = const Value.absent(),
    this.colorHex = const Value.absent(),
  });
  EtiquetaColorsCompanion.insert({
    this.id = const Value.absent(),
    required int repartoId,
    required String nombre,
    required String colorHex,
  }) : repartoId = Value(repartoId),
       nombre = Value(nombre),
       colorHex = Value(colorHex);
  static Insertable<EtiquetaColor> custom({
    Expression<int>? id,
    Expression<int>? repartoId,
    Expression<String>? nombre,
    Expression<String>? colorHex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (repartoId != null) 'reparto_id': repartoId,
      if (nombre != null) 'nombre': nombre,
      if (colorHex != null) 'color_hex': colorHex,
    });
  }

  EtiquetaColorsCompanion copyWith({
    Value<int>? id,
    Value<int>? repartoId,
    Value<String>? nombre,
    Value<String>? colorHex,
  }) {
    return EtiquetaColorsCompanion(
      id: id ?? this.id,
      repartoId: repartoId ?? this.repartoId,
      nombre: nombre ?? this.nombre,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (repartoId.present) {
      map['reparto_id'] = Variable<int>(repartoId.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EtiquetaColorsCompanion(')
          ..write('id: $id, ')
          ..write('repartoId: $repartoId, ')
          ..write('nombre: $nombre, ')
          ..write('colorHex: $colorHex')
          ..write(')'))
        .toString();
  }
}

class $AppNotificationsTable extends AppNotifications
    with TableInfo<$AppNotificationsTable, AppNotification> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppNotificationsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clienteIdMeta = const VerificationMeta(
    'clienteId',
  );
  @override
  late final GeneratedColumn<int> clienteId = GeneratedColumn<int>(
    'cliente_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readMeta = const VerificationMeta('read');
  @override
  late final GeneratedColumn<bool> read = GeneratedColumn<bool>(
    'read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    title,
    body,
    clienteId,
    createdAt,
    read,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_notifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppNotification> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
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
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('cliente_id')) {
      context.handle(
        _clienteIdMeta,
        clienteId.isAcceptableOrUnknown(data['cliente_id']!, _clienteIdMeta),
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
    if (data.containsKey('read')) {
      context.handle(
        _readMeta,
        read.isAcceptableOrUnknown(data['read']!, _readMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppNotification map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppNotification(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
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
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      clienteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cliente_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      read: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}read'],
      )!,
    );
  }

  @override
  $AppNotificationsTable createAlias(String alias) {
    return $AppNotificationsTable(attachedDatabase, alias);
  }
}

class AppNotification extends DataClass implements Insertable<AppNotification> {
  final int id;
  final String type;
  final String title;
  final String body;
  final int? clienteId;
  final String createdAt;
  final bool read;
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.clienteId,
    required this.createdAt,
    required this.read,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || clienteId != null) {
      map['cliente_id'] = Variable<int>(clienteId);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['read'] = Variable<bool>(read);
    return map;
  }

  AppNotificationsCompanion toCompanion(bool nullToAbsent) {
    return AppNotificationsCompanion(
      id: Value(id),
      type: Value(type),
      title: Value(title),
      body: Value(body),
      clienteId: clienteId == null && nullToAbsent
          ? const Value.absent()
          : Value(clienteId),
      createdAt: Value(createdAt),
      read: Value(read),
    );
  }

  factory AppNotification.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppNotification(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      clienteId: serializer.fromJson<int?>(json['clienteId']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      read: serializer.fromJson<bool>(json['read']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'clienteId': serializer.toJson<int?>(clienteId),
      'createdAt': serializer.toJson<String>(createdAt),
      'read': serializer.toJson<bool>(read),
    };
  }

  AppNotification copyWith({
    int? id,
    String? type,
    String? title,
    String? body,
    Value<int?> clienteId = const Value.absent(),
    String? createdAt,
    bool? read,
  }) => AppNotification(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title ?? this.title,
    body: body ?? this.body,
    clienteId: clienteId.present ? clienteId.value : this.clienteId,
    createdAt: createdAt ?? this.createdAt,
    read: read ?? this.read,
  );
  AppNotification copyWithCompanion(AppNotificationsCompanion data) {
    return AppNotification(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      clienteId: data.clienteId.present ? data.clienteId.value : this.clienteId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      read: data.read.present ? data.read.value : this.read,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppNotification(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('clienteId: $clienteId, ')
          ..write('createdAt: $createdAt, ')
          ..write('read: $read')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, type, title, body, clienteId, createdAt, read);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppNotification &&
          other.id == this.id &&
          other.type == this.type &&
          other.title == this.title &&
          other.body == this.body &&
          other.clienteId == this.clienteId &&
          other.createdAt == this.createdAt &&
          other.read == this.read);
}

class AppNotificationsCompanion extends UpdateCompanion<AppNotification> {
  final Value<int> id;
  final Value<String> type;
  final Value<String> title;
  final Value<String> body;
  final Value<int?> clienteId;
  final Value<String> createdAt;
  final Value<bool> read;
  const AppNotificationsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.clienteId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.read = const Value.absent(),
  });
  AppNotificationsCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    required String title,
    required String body,
    this.clienteId = const Value.absent(),
    required String createdAt,
    this.read = const Value.absent(),
  }) : type = Value(type),
       title = Value(title),
       body = Value(body),
       createdAt = Value(createdAt);
  static Insertable<AppNotification> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? body,
    Expression<int>? clienteId,
    Expression<String>? createdAt,
    Expression<bool>? read,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (clienteId != null) 'cliente_id': clienteId,
      if (createdAt != null) 'created_at': createdAt,
      if (read != null) 'read': read,
    });
  }

  AppNotificationsCompanion copyWith({
    Value<int>? id,
    Value<String>? type,
    Value<String>? title,
    Value<String>? body,
    Value<int?>? clienteId,
    Value<String>? createdAt,
    Value<bool>? read,
  }) {
    return AppNotificationsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      clienteId: clienteId ?? this.clienteId,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (clienteId.present) {
      map['cliente_id'] = Variable<int>(clienteId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (read.present) {
      map['read'] = Variable<bool>(read.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppNotificationsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('clienteId: $clienteId, ')
          ..write('createdAt: $createdAt, ')
          ..write('read: $read')
          ..write(')'))
        .toString();
  }
}

class $NotifDismissalsTable extends NotifDismissals
    with TableInfo<$NotifDismissalsTable, NotifDismissal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotifDismissalsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _clienteIdMeta = const VerificationMeta(
    'clienteId',
  );
  @override
  late final GeneratedColumn<int> clienteId = GeneratedColumn<int>(
    'cliente_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  @override
  List<GeneratedColumn> get $columns => [id, clienteId, type];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notif_dismissals';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotifDismissal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cliente_id')) {
      context.handle(
        _clienteIdMeta,
        clienteId.isAcceptableOrUnknown(data['cliente_id']!, _clienteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clienteIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotifDismissal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotifDismissal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clienteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cliente_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
    );
  }

  @override
  $NotifDismissalsTable createAlias(String alias) {
    return $NotifDismissalsTable(attachedDatabase, alias);
  }
}

class NotifDismissal extends DataClass implements Insertable<NotifDismissal> {
  final int id;
  final int clienteId;
  final String type;
  const NotifDismissal({
    required this.id,
    required this.clienteId,
    required this.type,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cliente_id'] = Variable<int>(clienteId);
    map['type'] = Variable<String>(type);
    return map;
  }

  NotifDismissalsCompanion toCompanion(bool nullToAbsent) {
    return NotifDismissalsCompanion(
      id: Value(id),
      clienteId: Value(clienteId),
      type: Value(type),
    );
  }

  factory NotifDismissal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotifDismissal(
      id: serializer.fromJson<int>(json['id']),
      clienteId: serializer.fromJson<int>(json['clienteId']),
      type: serializer.fromJson<String>(json['type']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clienteId': serializer.toJson<int>(clienteId),
      'type': serializer.toJson<String>(type),
    };
  }

  NotifDismissal copyWith({int? id, int? clienteId, String? type}) =>
      NotifDismissal(
        id: id ?? this.id,
        clienteId: clienteId ?? this.clienteId,
        type: type ?? this.type,
      );
  NotifDismissal copyWithCompanion(NotifDismissalsCompanion data) {
    return NotifDismissal(
      id: data.id.present ? data.id.value : this.id,
      clienteId: data.clienteId.present ? data.clienteId.value : this.clienteId,
      type: data.type.present ? data.type.value : this.type,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotifDismissal(')
          ..write('id: $id, ')
          ..write('clienteId: $clienteId, ')
          ..write('type: $type')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, clienteId, type);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotifDismissal &&
          other.id == this.id &&
          other.clienteId == this.clienteId &&
          other.type == this.type);
}

class NotifDismissalsCompanion extends UpdateCompanion<NotifDismissal> {
  final Value<int> id;
  final Value<int> clienteId;
  final Value<String> type;
  const NotifDismissalsCompanion({
    this.id = const Value.absent(),
    this.clienteId = const Value.absent(),
    this.type = const Value.absent(),
  });
  NotifDismissalsCompanion.insert({
    this.id = const Value.absent(),
    required int clienteId,
    required String type,
  }) : clienteId = Value(clienteId),
       type = Value(type);
  static Insertable<NotifDismissal> custom({
    Expression<int>? id,
    Expression<int>? clienteId,
    Expression<String>? type,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clienteId != null) 'cliente_id': clienteId,
      if (type != null) 'type': type,
    });
  }

  NotifDismissalsCompanion copyWith({
    Value<int>? id,
    Value<int>? clienteId,
    Value<String>? type,
  }) {
    return NotifDismissalsCompanion(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      type: type ?? this.type,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clienteId.present) {
      map['cliente_id'] = Variable<int>(clienteId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotifDismissalsCompanion(')
          ..write('id: $id, ')
          ..write('clienteId: $clienteId, ')
          ..write('type: $type')
          ..write(')'))
        .toString();
  }
}

class $StockNotifSettingsTable extends StockNotifSettings
    with TableInfo<$StockNotifSettingsTable, StockNotifSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockNotifSettingsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _repartoIdMeta = const VerificationMeta(
    'repartoId',
  );
  @override
  late final GeneratedColumn<int> repartoId = GeneratedColumn<int>(
    'reparto_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _productoIdMeta = const VerificationMeta(
    'productoId',
  );
  @override
  late final GeneratedColumn<int> productoId = GeneratedColumn<int>(
    'producto_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES productos (id)',
    ),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _thresholdMeta = const VerificationMeta(
    'threshold',
  );
  @override
  late final GeneratedColumn<int> threshold = GeneratedColumn<int>(
    'threshold',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    repartoId,
    productoId,
    enabled,
    threshold,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_notif_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockNotifSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('reparto_id')) {
      context.handle(
        _repartoIdMeta,
        repartoId.isAcceptableOrUnknown(data['reparto_id']!, _repartoIdMeta),
      );
    }
    if (data.containsKey('producto_id')) {
      context.handle(
        _productoIdMeta,
        productoId.isAcceptableOrUnknown(data['producto_id']!, _productoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productoIdMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('threshold')) {
      context.handle(
        _thresholdMeta,
        threshold.isAcceptableOrUnknown(data['threshold']!, _thresholdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockNotifSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockNotifSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      repartoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reparto_id'],
      ),
      productoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}producto_id'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      threshold: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}threshold'],
      )!,
    );
  }

  @override
  $StockNotifSettingsTable createAlias(String alias) {
    return $StockNotifSettingsTable(attachedDatabase, alias);
  }
}

class StockNotifSetting extends DataClass
    implements Insertable<StockNotifSetting> {
  final int id;
  final int? repartoId;
  final int productoId;
  final bool enabled;
  final int threshold;
  const StockNotifSetting({
    required this.id,
    this.repartoId,
    required this.productoId,
    required this.enabled,
    required this.threshold,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || repartoId != null) {
      map['reparto_id'] = Variable<int>(repartoId);
    }
    map['producto_id'] = Variable<int>(productoId);
    map['enabled'] = Variable<bool>(enabled);
    map['threshold'] = Variable<int>(threshold);
    return map;
  }

  StockNotifSettingsCompanion toCompanion(bool nullToAbsent) {
    return StockNotifSettingsCompanion(
      id: Value(id),
      repartoId: repartoId == null && nullToAbsent
          ? const Value.absent()
          : Value(repartoId),
      productoId: Value(productoId),
      enabled: Value(enabled),
      threshold: Value(threshold),
    );
  }

  factory StockNotifSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockNotifSetting(
      id: serializer.fromJson<int>(json['id']),
      repartoId: serializer.fromJson<int?>(json['repartoId']),
      productoId: serializer.fromJson<int>(json['productoId']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      threshold: serializer.fromJson<int>(json['threshold']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'repartoId': serializer.toJson<int?>(repartoId),
      'productoId': serializer.toJson<int>(productoId),
      'enabled': serializer.toJson<bool>(enabled),
      'threshold': serializer.toJson<int>(threshold),
    };
  }

  StockNotifSetting copyWith({
    int? id,
    Value<int?> repartoId = const Value.absent(),
    int? productoId,
    bool? enabled,
    int? threshold,
  }) => StockNotifSetting(
    id: id ?? this.id,
    repartoId: repartoId.present ? repartoId.value : this.repartoId,
    productoId: productoId ?? this.productoId,
    enabled: enabled ?? this.enabled,
    threshold: threshold ?? this.threshold,
  );
  StockNotifSetting copyWithCompanion(StockNotifSettingsCompanion data) {
    return StockNotifSetting(
      id: data.id.present ? data.id.value : this.id,
      repartoId: data.repartoId.present ? data.repartoId.value : this.repartoId,
      productoId: data.productoId.present
          ? data.productoId.value
          : this.productoId,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      threshold: data.threshold.present ? data.threshold.value : this.threshold,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockNotifSetting(')
          ..write('id: $id, ')
          ..write('repartoId: $repartoId, ')
          ..write('productoId: $productoId, ')
          ..write('enabled: $enabled, ')
          ..write('threshold: $threshold')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, repartoId, productoId, enabled, threshold);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockNotifSetting &&
          other.id == this.id &&
          other.repartoId == this.repartoId &&
          other.productoId == this.productoId &&
          other.enabled == this.enabled &&
          other.threshold == this.threshold);
}

class StockNotifSettingsCompanion extends UpdateCompanion<StockNotifSetting> {
  final Value<int> id;
  final Value<int?> repartoId;
  final Value<int> productoId;
  final Value<bool> enabled;
  final Value<int> threshold;
  const StockNotifSettingsCompanion({
    this.id = const Value.absent(),
    this.repartoId = const Value.absent(),
    this.productoId = const Value.absent(),
    this.enabled = const Value.absent(),
    this.threshold = const Value.absent(),
  });
  StockNotifSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.repartoId = const Value.absent(),
    required int productoId,
    this.enabled = const Value.absent(),
    this.threshold = const Value.absent(),
  }) : productoId = Value(productoId);
  static Insertable<StockNotifSetting> custom({
    Expression<int>? id,
    Expression<int>? repartoId,
    Expression<int>? productoId,
    Expression<bool>? enabled,
    Expression<int>? threshold,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (repartoId != null) 'reparto_id': repartoId,
      if (productoId != null) 'producto_id': productoId,
      if (enabled != null) 'enabled': enabled,
      if (threshold != null) 'threshold': threshold,
    });
  }

  StockNotifSettingsCompanion copyWith({
    Value<int>? id,
    Value<int?>? repartoId,
    Value<int>? productoId,
    Value<bool>? enabled,
    Value<int>? threshold,
  }) {
    return StockNotifSettingsCompanion(
      id: id ?? this.id,
      repartoId: repartoId ?? this.repartoId,
      productoId: productoId ?? this.productoId,
      enabled: enabled ?? this.enabled,
      threshold: threshold ?? this.threshold,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (repartoId.present) {
      map['reparto_id'] = Variable<int>(repartoId.value);
    }
    if (productoId.present) {
      map['producto_id'] = Variable<int>(productoId.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (threshold.present) {
      map['threshold'] = Variable<int>(threshold.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockNotifSettingsCompanion(')
          ..write('id: $id, ')
          ..write('repartoId: $repartoId, ')
          ..write('productoId: $productoId, ')
          ..write('enabled: $enabled, ')
          ..write('threshold: $threshold')
          ..write(')'))
        .toString();
  }
}

class $FacturasTable extends Facturas with TableInfo<$FacturasTable, Factura> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FacturasTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _clienteIdMeta = const VerificationMeta(
    'clienteId',
  );
  @override
  late final GeneratedColumn<int> clienteId = GeneratedColumn<int>(
    'cliente_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES clientes (id)',
    ),
  );
  static const VerificationMeta _repartoIdMeta = const VerificationMeta(
    'repartoId',
  );
  @override
  late final GeneratedColumn<int> repartoId = GeneratedColumn<int>(
    'reparto_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES repartos (id)',
    ),
  );
  static const VerificationMeta _cbteTipoMeta = const VerificationMeta(
    'cbteTipo',
  );
  @override
  late final GeneratedColumn<int> cbteTipo = GeneratedColumn<int>(
    'cbte_tipo',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(11),
  );
  static const VerificationMeta _ptoVtaMeta = const VerificationMeta('ptoVta');
  @override
  late final GeneratedColumn<int> ptoVta = GeneratedColumn<int>(
    'pto_vta',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cbteNroMeta = const VerificationMeta(
    'cbteNro',
  );
  @override
  late final GeneratedColumn<int> cbteNro = GeneratedColumn<int>(
    'cbte_nro',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fechaMeta = const VerificationMeta('fecha');
  @override
  late final GeneratedColumn<String> fecha = GeneratedColumn<String>(
    'fecha',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importeTotalMeta = const VerificationMeta(
    'importeTotal',
  );
  @override
  late final GeneratedColumn<double> importeTotal = GeneratedColumn<double>(
    'importe_total',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caeMeta = const VerificationMeta('cae');
  @override
  late final GeneratedColumn<String> cae = GeneratedColumn<String>(
    'cae',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caeFchVtoMeta = const VerificationMeta(
    'caeFchVto',
  );
  @override
  late final GeneratedColumn<String> caeFchVto = GeneratedColumn<String>(
    'cae_fch_vto',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemsJsonMeta = const VerificationMeta(
    'itemsJson',
  );
  @override
  late final GeneratedColumn<String> itemsJson = GeneratedColumn<String>(
    'items_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _receptorNombreMeta = const VerificationMeta(
    'receptorNombre',
  );
  @override
  late final GeneratedColumn<String> receptorNombre = GeneratedColumn<String>(
    'receptor_nombre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _receptorDocTipoMeta = const VerificationMeta(
    'receptorDocTipo',
  );
  @override
  late final GeneratedColumn<int> receptorDocTipo = GeneratedColumn<int>(
    'receptor_doc_tipo',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(99),
  );
  static const VerificationMeta _receptorDocNroMeta = const VerificationMeta(
    'receptorDocNro',
  );
  @override
  late final GeneratedColumn<String> receptorDocNro = GeneratedColumn<String>(
    'receptor_doc_nro',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('0'),
  );
  static const VerificationMeta _pdfPathMeta = const VerificationMeta(
    'pdfPath',
  );
  @override
  late final GeneratedColumn<String> pdfPath = GeneratedColumn<String>(
    'pdf_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clienteId,
    repartoId,
    cbteTipo,
    ptoVta,
    cbteNro,
    fecha,
    importeTotal,
    cae,
    caeFchVto,
    itemsJson,
    receptorNombre,
    receptorDocTipo,
    receptorDocNro,
    pdfPath,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'facturas';
  @override
  VerificationContext validateIntegrity(
    Insertable<Factura> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cliente_id')) {
      context.handle(
        _clienteIdMeta,
        clienteId.isAcceptableOrUnknown(data['cliente_id']!, _clienteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clienteIdMeta);
    }
    if (data.containsKey('reparto_id')) {
      context.handle(
        _repartoIdMeta,
        repartoId.isAcceptableOrUnknown(data['reparto_id']!, _repartoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_repartoIdMeta);
    }
    if (data.containsKey('cbte_tipo')) {
      context.handle(
        _cbteTipoMeta,
        cbteTipo.isAcceptableOrUnknown(data['cbte_tipo']!, _cbteTipoMeta),
      );
    }
    if (data.containsKey('pto_vta')) {
      context.handle(
        _ptoVtaMeta,
        ptoVta.isAcceptableOrUnknown(data['pto_vta']!, _ptoVtaMeta),
      );
    } else if (isInserting) {
      context.missing(_ptoVtaMeta);
    }
    if (data.containsKey('cbte_nro')) {
      context.handle(
        _cbteNroMeta,
        cbteNro.isAcceptableOrUnknown(data['cbte_nro']!, _cbteNroMeta),
      );
    } else if (isInserting) {
      context.missing(_cbteNroMeta);
    }
    if (data.containsKey('fecha')) {
      context.handle(
        _fechaMeta,
        fecha.isAcceptableOrUnknown(data['fecha']!, _fechaMeta),
      );
    } else if (isInserting) {
      context.missing(_fechaMeta);
    }
    if (data.containsKey('importe_total')) {
      context.handle(
        _importeTotalMeta,
        importeTotal.isAcceptableOrUnknown(
          data['importe_total']!,
          _importeTotalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_importeTotalMeta);
    }
    if (data.containsKey('cae')) {
      context.handle(
        _caeMeta,
        cae.isAcceptableOrUnknown(data['cae']!, _caeMeta),
      );
    } else if (isInserting) {
      context.missing(_caeMeta);
    }
    if (data.containsKey('cae_fch_vto')) {
      context.handle(
        _caeFchVtoMeta,
        caeFchVto.isAcceptableOrUnknown(data['cae_fch_vto']!, _caeFchVtoMeta),
      );
    } else if (isInserting) {
      context.missing(_caeFchVtoMeta);
    }
    if (data.containsKey('items_json')) {
      context.handle(
        _itemsJsonMeta,
        itemsJson.isAcceptableOrUnknown(data['items_json']!, _itemsJsonMeta),
      );
    }
    if (data.containsKey('receptor_nombre')) {
      context.handle(
        _receptorNombreMeta,
        receptorNombre.isAcceptableOrUnknown(
          data['receptor_nombre']!,
          _receptorNombreMeta,
        ),
      );
    }
    if (data.containsKey('receptor_doc_tipo')) {
      context.handle(
        _receptorDocTipoMeta,
        receptorDocTipo.isAcceptableOrUnknown(
          data['receptor_doc_tipo']!,
          _receptorDocTipoMeta,
        ),
      );
    }
    if (data.containsKey('receptor_doc_nro')) {
      context.handle(
        _receptorDocNroMeta,
        receptorDocNro.isAcceptableOrUnknown(
          data['receptor_doc_nro']!,
          _receptorDocNroMeta,
        ),
      );
    }
    if (data.containsKey('pdf_path')) {
      context.handle(
        _pdfPathMeta,
        pdfPath.isAcceptableOrUnknown(data['pdf_path']!, _pdfPathMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Factura map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Factura(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clienteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cliente_id'],
      )!,
      repartoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reparto_id'],
      )!,
      cbteTipo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cbte_tipo'],
      )!,
      ptoVta: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pto_vta'],
      )!,
      cbteNro: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cbte_nro'],
      )!,
      fecha: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fecha'],
      )!,
      importeTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}importe_total'],
      )!,
      cae: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cae'],
      )!,
      caeFchVto: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cae_fch_vto'],
      )!,
      itemsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items_json'],
      )!,
      receptorNombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receptor_nombre'],
      )!,
      receptorDocTipo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}receptor_doc_tipo'],
      )!,
      receptorDocNro: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receptor_doc_nro'],
      )!,
      pdfPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_path'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FacturasTable createAlias(String alias) {
    return $FacturasTable(attachedDatabase, alias);
  }
}

class Factura extends DataClass implements Insertable<Factura> {
  final int id;
  final int clienteId;
  final int repartoId;
  final int cbteTipo;
  final int ptoVta;
  final int cbteNro;
  final String fecha;
  final double importeTotal;
  final String cae;
  final String caeFchVto;
  final String itemsJson;
  final String receptorNombre;
  final int receptorDocTipo;
  final String receptorDocNro;
  final String pdfPath;
  final String createdAt;
  const Factura({
    required this.id,
    required this.clienteId,
    required this.repartoId,
    required this.cbteTipo,
    required this.ptoVta,
    required this.cbteNro,
    required this.fecha,
    required this.importeTotal,
    required this.cae,
    required this.caeFchVto,
    required this.itemsJson,
    required this.receptorNombre,
    required this.receptorDocTipo,
    required this.receptorDocNro,
    required this.pdfPath,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cliente_id'] = Variable<int>(clienteId);
    map['reparto_id'] = Variable<int>(repartoId);
    map['cbte_tipo'] = Variable<int>(cbteTipo);
    map['pto_vta'] = Variable<int>(ptoVta);
    map['cbte_nro'] = Variable<int>(cbteNro);
    map['fecha'] = Variable<String>(fecha);
    map['importe_total'] = Variable<double>(importeTotal);
    map['cae'] = Variable<String>(cae);
    map['cae_fch_vto'] = Variable<String>(caeFchVto);
    map['items_json'] = Variable<String>(itemsJson);
    map['receptor_nombre'] = Variable<String>(receptorNombre);
    map['receptor_doc_tipo'] = Variable<int>(receptorDocTipo);
    map['receptor_doc_nro'] = Variable<String>(receptorDocNro);
    map['pdf_path'] = Variable<String>(pdfPath);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  FacturasCompanion toCompanion(bool nullToAbsent) {
    return FacturasCompanion(
      id: Value(id),
      clienteId: Value(clienteId),
      repartoId: Value(repartoId),
      cbteTipo: Value(cbteTipo),
      ptoVta: Value(ptoVta),
      cbteNro: Value(cbteNro),
      fecha: Value(fecha),
      importeTotal: Value(importeTotal),
      cae: Value(cae),
      caeFchVto: Value(caeFchVto),
      itemsJson: Value(itemsJson),
      receptorNombre: Value(receptorNombre),
      receptorDocTipo: Value(receptorDocTipo),
      receptorDocNro: Value(receptorDocNro),
      pdfPath: Value(pdfPath),
      createdAt: Value(createdAt),
    );
  }

  factory Factura.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Factura(
      id: serializer.fromJson<int>(json['id']),
      clienteId: serializer.fromJson<int>(json['clienteId']),
      repartoId: serializer.fromJson<int>(json['repartoId']),
      cbteTipo: serializer.fromJson<int>(json['cbteTipo']),
      ptoVta: serializer.fromJson<int>(json['ptoVta']),
      cbteNro: serializer.fromJson<int>(json['cbteNro']),
      fecha: serializer.fromJson<String>(json['fecha']),
      importeTotal: serializer.fromJson<double>(json['importeTotal']),
      cae: serializer.fromJson<String>(json['cae']),
      caeFchVto: serializer.fromJson<String>(json['caeFchVto']),
      itemsJson: serializer.fromJson<String>(json['itemsJson']),
      receptorNombre: serializer.fromJson<String>(json['receptorNombre']),
      receptorDocTipo: serializer.fromJson<int>(json['receptorDocTipo']),
      receptorDocNro: serializer.fromJson<String>(json['receptorDocNro']),
      pdfPath: serializer.fromJson<String>(json['pdfPath']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clienteId': serializer.toJson<int>(clienteId),
      'repartoId': serializer.toJson<int>(repartoId),
      'cbteTipo': serializer.toJson<int>(cbteTipo),
      'ptoVta': serializer.toJson<int>(ptoVta),
      'cbteNro': serializer.toJson<int>(cbteNro),
      'fecha': serializer.toJson<String>(fecha),
      'importeTotal': serializer.toJson<double>(importeTotal),
      'cae': serializer.toJson<String>(cae),
      'caeFchVto': serializer.toJson<String>(caeFchVto),
      'itemsJson': serializer.toJson<String>(itemsJson),
      'receptorNombre': serializer.toJson<String>(receptorNombre),
      'receptorDocTipo': serializer.toJson<int>(receptorDocTipo),
      'receptorDocNro': serializer.toJson<String>(receptorDocNro),
      'pdfPath': serializer.toJson<String>(pdfPath),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  Factura copyWith({
    int? id,
    int? clienteId,
    int? repartoId,
    int? cbteTipo,
    int? ptoVta,
    int? cbteNro,
    String? fecha,
    double? importeTotal,
    String? cae,
    String? caeFchVto,
    String? itemsJson,
    String? receptorNombre,
    int? receptorDocTipo,
    String? receptorDocNro,
    String? pdfPath,
    String? createdAt,
  }) => Factura(
    id: id ?? this.id,
    clienteId: clienteId ?? this.clienteId,
    repartoId: repartoId ?? this.repartoId,
    cbteTipo: cbteTipo ?? this.cbteTipo,
    ptoVta: ptoVta ?? this.ptoVta,
    cbteNro: cbteNro ?? this.cbteNro,
    fecha: fecha ?? this.fecha,
    importeTotal: importeTotal ?? this.importeTotal,
    cae: cae ?? this.cae,
    caeFchVto: caeFchVto ?? this.caeFchVto,
    itemsJson: itemsJson ?? this.itemsJson,
    receptorNombre: receptorNombre ?? this.receptorNombre,
    receptorDocTipo: receptorDocTipo ?? this.receptorDocTipo,
    receptorDocNro: receptorDocNro ?? this.receptorDocNro,
    pdfPath: pdfPath ?? this.pdfPath,
    createdAt: createdAt ?? this.createdAt,
  );
  Factura copyWithCompanion(FacturasCompanion data) {
    return Factura(
      id: data.id.present ? data.id.value : this.id,
      clienteId: data.clienteId.present ? data.clienteId.value : this.clienteId,
      repartoId: data.repartoId.present ? data.repartoId.value : this.repartoId,
      cbteTipo: data.cbteTipo.present ? data.cbteTipo.value : this.cbteTipo,
      ptoVta: data.ptoVta.present ? data.ptoVta.value : this.ptoVta,
      cbteNro: data.cbteNro.present ? data.cbteNro.value : this.cbteNro,
      fecha: data.fecha.present ? data.fecha.value : this.fecha,
      importeTotal: data.importeTotal.present
          ? data.importeTotal.value
          : this.importeTotal,
      cae: data.cae.present ? data.cae.value : this.cae,
      caeFchVto: data.caeFchVto.present ? data.caeFchVto.value : this.caeFchVto,
      itemsJson: data.itemsJson.present ? data.itemsJson.value : this.itemsJson,
      receptorNombre: data.receptorNombre.present
          ? data.receptorNombre.value
          : this.receptorNombre,
      receptorDocTipo: data.receptorDocTipo.present
          ? data.receptorDocTipo.value
          : this.receptorDocTipo,
      receptorDocNro: data.receptorDocNro.present
          ? data.receptorDocNro.value
          : this.receptorDocNro,
      pdfPath: data.pdfPath.present ? data.pdfPath.value : this.pdfPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Factura(')
          ..write('id: $id, ')
          ..write('clienteId: $clienteId, ')
          ..write('repartoId: $repartoId, ')
          ..write('cbteTipo: $cbteTipo, ')
          ..write('ptoVta: $ptoVta, ')
          ..write('cbteNro: $cbteNro, ')
          ..write('fecha: $fecha, ')
          ..write('importeTotal: $importeTotal, ')
          ..write('cae: $cae, ')
          ..write('caeFchVto: $caeFchVto, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('receptorNombre: $receptorNombre, ')
          ..write('receptorDocTipo: $receptorDocTipo, ')
          ..write('receptorDocNro: $receptorDocNro, ')
          ..write('pdfPath: $pdfPath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clienteId,
    repartoId,
    cbteTipo,
    ptoVta,
    cbteNro,
    fecha,
    importeTotal,
    cae,
    caeFchVto,
    itemsJson,
    receptorNombre,
    receptorDocTipo,
    receptorDocNro,
    pdfPath,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Factura &&
          other.id == this.id &&
          other.clienteId == this.clienteId &&
          other.repartoId == this.repartoId &&
          other.cbteTipo == this.cbteTipo &&
          other.ptoVta == this.ptoVta &&
          other.cbteNro == this.cbteNro &&
          other.fecha == this.fecha &&
          other.importeTotal == this.importeTotal &&
          other.cae == this.cae &&
          other.caeFchVto == this.caeFchVto &&
          other.itemsJson == this.itemsJson &&
          other.receptorNombre == this.receptorNombre &&
          other.receptorDocTipo == this.receptorDocTipo &&
          other.receptorDocNro == this.receptorDocNro &&
          other.pdfPath == this.pdfPath &&
          other.createdAt == this.createdAt);
}

class FacturasCompanion extends UpdateCompanion<Factura> {
  final Value<int> id;
  final Value<int> clienteId;
  final Value<int> repartoId;
  final Value<int> cbteTipo;
  final Value<int> ptoVta;
  final Value<int> cbteNro;
  final Value<String> fecha;
  final Value<double> importeTotal;
  final Value<String> cae;
  final Value<String> caeFchVto;
  final Value<String> itemsJson;
  final Value<String> receptorNombre;
  final Value<int> receptorDocTipo;
  final Value<String> receptorDocNro;
  final Value<String> pdfPath;
  final Value<String> createdAt;
  const FacturasCompanion({
    this.id = const Value.absent(),
    this.clienteId = const Value.absent(),
    this.repartoId = const Value.absent(),
    this.cbteTipo = const Value.absent(),
    this.ptoVta = const Value.absent(),
    this.cbteNro = const Value.absent(),
    this.fecha = const Value.absent(),
    this.importeTotal = const Value.absent(),
    this.cae = const Value.absent(),
    this.caeFchVto = const Value.absent(),
    this.itemsJson = const Value.absent(),
    this.receptorNombre = const Value.absent(),
    this.receptorDocTipo = const Value.absent(),
    this.receptorDocNro = const Value.absent(),
    this.pdfPath = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  FacturasCompanion.insert({
    this.id = const Value.absent(),
    required int clienteId,
    required int repartoId,
    this.cbteTipo = const Value.absent(),
    required int ptoVta,
    required int cbteNro,
    required String fecha,
    required double importeTotal,
    required String cae,
    required String caeFchVto,
    this.itemsJson = const Value.absent(),
    this.receptorNombre = const Value.absent(),
    this.receptorDocTipo = const Value.absent(),
    this.receptorDocNro = const Value.absent(),
    this.pdfPath = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : clienteId = Value(clienteId),
       repartoId = Value(repartoId),
       ptoVta = Value(ptoVta),
       cbteNro = Value(cbteNro),
       fecha = Value(fecha),
       importeTotal = Value(importeTotal),
       cae = Value(cae),
       caeFchVto = Value(caeFchVto);
  static Insertable<Factura> custom({
    Expression<int>? id,
    Expression<int>? clienteId,
    Expression<int>? repartoId,
    Expression<int>? cbteTipo,
    Expression<int>? ptoVta,
    Expression<int>? cbteNro,
    Expression<String>? fecha,
    Expression<double>? importeTotal,
    Expression<String>? cae,
    Expression<String>? caeFchVto,
    Expression<String>? itemsJson,
    Expression<String>? receptorNombre,
    Expression<int>? receptorDocTipo,
    Expression<String>? receptorDocNro,
    Expression<String>? pdfPath,
    Expression<String>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clienteId != null) 'cliente_id': clienteId,
      if (repartoId != null) 'reparto_id': repartoId,
      if (cbteTipo != null) 'cbte_tipo': cbteTipo,
      if (ptoVta != null) 'pto_vta': ptoVta,
      if (cbteNro != null) 'cbte_nro': cbteNro,
      if (fecha != null) 'fecha': fecha,
      if (importeTotal != null) 'importe_total': importeTotal,
      if (cae != null) 'cae': cae,
      if (caeFchVto != null) 'cae_fch_vto': caeFchVto,
      if (itemsJson != null) 'items_json': itemsJson,
      if (receptorNombre != null) 'receptor_nombre': receptorNombre,
      if (receptorDocTipo != null) 'receptor_doc_tipo': receptorDocTipo,
      if (receptorDocNro != null) 'receptor_doc_nro': receptorDocNro,
      if (pdfPath != null) 'pdf_path': pdfPath,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  FacturasCompanion copyWith({
    Value<int>? id,
    Value<int>? clienteId,
    Value<int>? repartoId,
    Value<int>? cbteTipo,
    Value<int>? ptoVta,
    Value<int>? cbteNro,
    Value<String>? fecha,
    Value<double>? importeTotal,
    Value<String>? cae,
    Value<String>? caeFchVto,
    Value<String>? itemsJson,
    Value<String>? receptorNombre,
    Value<int>? receptorDocTipo,
    Value<String>? receptorDocNro,
    Value<String>? pdfPath,
    Value<String>? createdAt,
  }) {
    return FacturasCompanion(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      repartoId: repartoId ?? this.repartoId,
      cbteTipo: cbteTipo ?? this.cbteTipo,
      ptoVta: ptoVta ?? this.ptoVta,
      cbteNro: cbteNro ?? this.cbteNro,
      fecha: fecha ?? this.fecha,
      importeTotal: importeTotal ?? this.importeTotal,
      cae: cae ?? this.cae,
      caeFchVto: caeFchVto ?? this.caeFchVto,
      itemsJson: itemsJson ?? this.itemsJson,
      receptorNombre: receptorNombre ?? this.receptorNombre,
      receptorDocTipo: receptorDocTipo ?? this.receptorDocTipo,
      receptorDocNro: receptorDocNro ?? this.receptorDocNro,
      pdfPath: pdfPath ?? this.pdfPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clienteId.present) {
      map['cliente_id'] = Variable<int>(clienteId.value);
    }
    if (repartoId.present) {
      map['reparto_id'] = Variable<int>(repartoId.value);
    }
    if (cbteTipo.present) {
      map['cbte_tipo'] = Variable<int>(cbteTipo.value);
    }
    if (ptoVta.present) {
      map['pto_vta'] = Variable<int>(ptoVta.value);
    }
    if (cbteNro.present) {
      map['cbte_nro'] = Variable<int>(cbteNro.value);
    }
    if (fecha.present) {
      map['fecha'] = Variable<String>(fecha.value);
    }
    if (importeTotal.present) {
      map['importe_total'] = Variable<double>(importeTotal.value);
    }
    if (cae.present) {
      map['cae'] = Variable<String>(cae.value);
    }
    if (caeFchVto.present) {
      map['cae_fch_vto'] = Variable<String>(caeFchVto.value);
    }
    if (itemsJson.present) {
      map['items_json'] = Variable<String>(itemsJson.value);
    }
    if (receptorNombre.present) {
      map['receptor_nombre'] = Variable<String>(receptorNombre.value);
    }
    if (receptorDocTipo.present) {
      map['receptor_doc_tipo'] = Variable<int>(receptorDocTipo.value);
    }
    if (receptorDocNro.present) {
      map['receptor_doc_nro'] = Variable<String>(receptorDocNro.value);
    }
    if (pdfPath.present) {
      map['pdf_path'] = Variable<String>(pdfPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FacturasCompanion(')
          ..write('id: $id, ')
          ..write('clienteId: $clienteId, ')
          ..write('repartoId: $repartoId, ')
          ..write('cbteTipo: $cbteTipo, ')
          ..write('ptoVta: $ptoVta, ')
          ..write('cbteNro: $cbteNro, ')
          ..write('fecha: $fecha, ')
          ..write('importeTotal: $importeTotal, ')
          ..write('cae: $cae, ')
          ..write('caeFchVto: $caeFchVto, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('receptorNombre: $receptorNombre, ')
          ..write('receptorDocTipo: $receptorDocTipo, ')
          ..write('receptorDocNro: $receptorDocNro, ')
          ..write('pdfPath: $pdfPath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RepartosTable repartos = $RepartosTable(this);
  late final $ProductosTable productos = $ProductosTable(this);
  late final $ProductoPreciosTable productoPrecios = $ProductoPreciosTable(
    this,
  );
  late final $CargaDiariaTable cargaDiaria = $CargaDiariaTable(this);
  late final $ClientesTable clientes = $ClientesTable(this);
  late final $ClienteProductosTable clienteProductos = $ClienteProductosTable(
    this,
  );
  late final $EntregasTable entregas = $EntregasTable(this);
  late final $PagosTable pagos = $PagosTable(this);
  late final $ResumenesTable resumenes = $ResumenesTable(this);
  late final $UserSettingsTable userSettings = $UserSettingsTable(this);
  late final $EtiquetaColorsTable etiquetaColors = $EtiquetaColorsTable(this);
  late final $AppNotificationsTable appNotifications = $AppNotificationsTable(
    this,
  );
  late final $NotifDismissalsTable notifDismissals = $NotifDismissalsTable(
    this,
  );
  late final $StockNotifSettingsTable stockNotifSettings =
      $StockNotifSettingsTable(this);
  late final $FacturasTable facturas = $FacturasTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    repartos,
    productos,
    productoPrecios,
    cargaDiaria,
    clientes,
    clienteProductos,
    entregas,
    pagos,
    resumenes,
    userSettings,
    etiquetaColors,
    appNotifications,
    notifDismissals,
    stockNotifSettings,
    facturas,
  ];
}

typedef $$RepartosTableCreateCompanionBuilder =
    RepartosCompanion Function({
      Value<int> id,
      required String nombre,
      required String userId,
      Value<int> orden,
    });
typedef $$RepartosTableUpdateCompanionBuilder =
    RepartosCompanion Function({
      Value<int> id,
      Value<String> nombre,
      Value<String> userId,
      Value<int> orden,
    });

final class $$RepartosTableReferences
    extends BaseReferences<_$AppDatabase, $RepartosTable, Reparto> {
  $$RepartosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CargaDiariaTable, List<CargaDiariaData>>
  _cargaDiariaRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cargaDiaria,
    aliasName: $_aliasNameGenerator(db.repartos.id, db.cargaDiaria.repartoId),
  );

  $$CargaDiariaTableProcessedTableManager get cargaDiariaRefs {
    final manager = $$CargaDiariaTableTableManager(
      $_db,
      $_db.cargaDiaria,
    ).filter((f) => f.repartoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cargaDiariaRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ClientesTable, List<Cliente>> _clientesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.clientes,
    aliasName: $_aliasNameGenerator(db.repartos.id, db.clientes.repartoId),
  );

  $$ClientesTableProcessedTableManager get clientesRefs {
    final manager = $$ClientesTableTableManager(
      $_db,
      $_db.clientes,
    ).filter((f) => f.repartoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_clientesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EntregasTable, List<Entrega>> _entregasRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.entregas,
    aliasName: $_aliasNameGenerator(db.repartos.id, db.entregas.repartoId),
  );

  $$EntregasTableProcessedTableManager get entregasRefs {
    final manager = $$EntregasTableTableManager(
      $_db,
      $_db.entregas,
    ).filter((f) => f.repartoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_entregasRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PagosTable, List<Pago>> _pagosRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.pagos,
    aliasName: $_aliasNameGenerator(db.repartos.id, db.pagos.repartoId),
  );

  $$PagosTableProcessedTableManager get pagosRefs {
    final manager = $$PagosTableTableManager(
      $_db,
      $_db.pagos,
    ).filter((f) => f.repartoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_pagosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ResumenesTable, List<Resumene>>
  _resumenesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.resumenes,
    aliasName: $_aliasNameGenerator(db.repartos.id, db.resumenes.repartoId),
  );

  $$ResumenesTableProcessedTableManager get resumenesRefs {
    final manager = $$ResumenesTableTableManager(
      $_db,
      $_db.resumenes,
    ).filter((f) => f.repartoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_resumenesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EtiquetaColorsTable, List<EtiquetaColor>>
  _etiquetaColorsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.etiquetaColors,
    aliasName: $_aliasNameGenerator(
      db.repartos.id,
      db.etiquetaColors.repartoId,
    ),
  );

  $$EtiquetaColorsTableProcessedTableManager get etiquetaColorsRefs {
    final manager = $$EtiquetaColorsTableTableManager(
      $_db,
      $_db.etiquetaColors,
    ).filter((f) => f.repartoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_etiquetaColorsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FacturasTable, List<Factura>> _facturasRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.facturas,
    aliasName: $_aliasNameGenerator(db.repartos.id, db.facturas.repartoId),
  );

  $$FacturasTableProcessedTableManager get facturasRefs {
    final manager = $$FacturasTableTableManager(
      $_db,
      $_db.facturas,
    ).filter((f) => f.repartoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_facturasRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RepartosTableFilterComposer
    extends Composer<_$AppDatabase, $RepartosTable> {
  $$RepartosTableFilterComposer({
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

  ColumnFilters<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orden => $composableBuilder(
    column: $table.orden,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> cargaDiariaRefs(
    Expression<bool> Function($$CargaDiariaTableFilterComposer f) f,
  ) {
    final $$CargaDiariaTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cargaDiaria,
      getReferencedColumn: (t) => t.repartoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CargaDiariaTableFilterComposer(
            $db: $db,
            $table: $db.cargaDiaria,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> clientesRefs(
    Expression<bool> Function($$ClientesTableFilterComposer f) f,
  ) {
    final $$ClientesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.clientes,
      getReferencedColumn: (t) => t.repartoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientesTableFilterComposer(
            $db: $db,
            $table: $db.clientes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> entregasRefs(
    Expression<bool> Function($$EntregasTableFilterComposer f) f,
  ) {
    final $$EntregasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entregas,
      getReferencedColumn: (t) => t.repartoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntregasTableFilterComposer(
            $db: $db,
            $table: $db.entregas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> pagosRefs(
    Expression<bool> Function($$PagosTableFilterComposer f) f,
  ) {
    final $$PagosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pagos,
      getReferencedColumn: (t) => t.repartoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PagosTableFilterComposer(
            $db: $db,
            $table: $db.pagos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> resumenesRefs(
    Expression<bool> Function($$ResumenesTableFilterComposer f) f,
  ) {
    final $$ResumenesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.resumenes,
      getReferencedColumn: (t) => t.repartoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ResumenesTableFilterComposer(
            $db: $db,
            $table: $db.resumenes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> etiquetaColorsRefs(
    Expression<bool> Function($$EtiquetaColorsTableFilterComposer f) f,
  ) {
    final $$EtiquetaColorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.etiquetaColors,
      getReferencedColumn: (t) => t.repartoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EtiquetaColorsTableFilterComposer(
            $db: $db,
            $table: $db.etiquetaColors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> facturasRefs(
    Expression<bool> Function($$FacturasTableFilterComposer f) f,
  ) {
    final $$FacturasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.facturas,
      getReferencedColumn: (t) => t.repartoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FacturasTableFilterComposer(
            $db: $db,
            $table: $db.facturas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RepartosTableOrderingComposer
    extends Composer<_$AppDatabase, $RepartosTable> {
  $$RepartosTableOrderingComposer({
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

  ColumnOrderings<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orden => $composableBuilder(
    column: $table.orden,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RepartosTableAnnotationComposer
    extends Composer<_$AppDatabase, $RepartosTable> {
  $$RepartosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get orden =>
      $composableBuilder(column: $table.orden, builder: (column) => column);

  Expression<T> cargaDiariaRefs<T extends Object>(
    Expression<T> Function($$CargaDiariaTableAnnotationComposer a) f,
  ) {
    final $$CargaDiariaTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cargaDiaria,
      getReferencedColumn: (t) => t.repartoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CargaDiariaTableAnnotationComposer(
            $db: $db,
            $table: $db.cargaDiaria,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> clientesRefs<T extends Object>(
    Expression<T> Function($$ClientesTableAnnotationComposer a) f,
  ) {
    final $$ClientesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.clientes,
      getReferencedColumn: (t) => t.repartoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientesTableAnnotationComposer(
            $db: $db,
            $table: $db.clientes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> entregasRefs<T extends Object>(
    Expression<T> Function($$EntregasTableAnnotationComposer a) f,
  ) {
    final $$EntregasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entregas,
      getReferencedColumn: (t) => t.repartoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntregasTableAnnotationComposer(
            $db: $db,
            $table: $db.entregas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> pagosRefs<T extends Object>(
    Expression<T> Function($$PagosTableAnnotationComposer a) f,
  ) {
    final $$PagosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pagos,
      getReferencedColumn: (t) => t.repartoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PagosTableAnnotationComposer(
            $db: $db,
            $table: $db.pagos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> resumenesRefs<T extends Object>(
    Expression<T> Function($$ResumenesTableAnnotationComposer a) f,
  ) {
    final $$ResumenesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.resumenes,
      getReferencedColumn: (t) => t.repartoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ResumenesTableAnnotationComposer(
            $db: $db,
            $table: $db.resumenes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> etiquetaColorsRefs<T extends Object>(
    Expression<T> Function($$EtiquetaColorsTableAnnotationComposer a) f,
  ) {
    final $$EtiquetaColorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.etiquetaColors,
      getReferencedColumn: (t) => t.repartoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EtiquetaColorsTableAnnotationComposer(
            $db: $db,
            $table: $db.etiquetaColors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> facturasRefs<T extends Object>(
    Expression<T> Function($$FacturasTableAnnotationComposer a) f,
  ) {
    final $$FacturasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.facturas,
      getReferencedColumn: (t) => t.repartoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FacturasTableAnnotationComposer(
            $db: $db,
            $table: $db.facturas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RepartosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RepartosTable,
          Reparto,
          $$RepartosTableFilterComposer,
          $$RepartosTableOrderingComposer,
          $$RepartosTableAnnotationComposer,
          $$RepartosTableCreateCompanionBuilder,
          $$RepartosTableUpdateCompanionBuilder,
          (Reparto, $$RepartosTableReferences),
          Reparto,
          PrefetchHooks Function({
            bool cargaDiariaRefs,
            bool clientesRefs,
            bool entregasRefs,
            bool pagosRefs,
            bool resumenesRefs,
            bool etiquetaColorsRefs,
            bool facturasRefs,
          })
        > {
  $$RepartosTableTableManager(_$AppDatabase db, $RepartosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RepartosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RepartosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RepartosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<int> orden = const Value.absent(),
              }) => RepartosCompanion(
                id: id,
                nombre: nombre,
                userId: userId,
                orden: orden,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String nombre,
                required String userId,
                Value<int> orden = const Value.absent(),
              }) => RepartosCompanion.insert(
                id: id,
                nombre: nombre,
                userId: userId,
                orden: orden,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RepartosTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                cargaDiariaRefs = false,
                clientesRefs = false,
                entregasRefs = false,
                pagosRefs = false,
                resumenesRefs = false,
                etiquetaColorsRefs = false,
                facturasRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (cargaDiariaRefs) db.cargaDiaria,
                    if (clientesRefs) db.clientes,
                    if (entregasRefs) db.entregas,
                    if (pagosRefs) db.pagos,
                    if (resumenesRefs) db.resumenes,
                    if (etiquetaColorsRefs) db.etiquetaColors,
                    if (facturasRefs) db.facturas,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (cargaDiariaRefs)
                        await $_getPrefetchedData<
                          Reparto,
                          $RepartosTable,
                          CargaDiariaData
                        >(
                          currentTable: table,
                          referencedTable: $$RepartosTableReferences
                              ._cargaDiariaRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RepartosTableReferences(
                                db,
                                table,
                                p0,
                              ).cargaDiariaRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.repartoId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (clientesRefs)
                        await $_getPrefetchedData<
                          Reparto,
                          $RepartosTable,
                          Cliente
                        >(
                          currentTable: table,
                          referencedTable: $$RepartosTableReferences
                              ._clientesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RepartosTableReferences(
                                db,
                                table,
                                p0,
                              ).clientesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.repartoId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (entregasRefs)
                        await $_getPrefetchedData<
                          Reparto,
                          $RepartosTable,
                          Entrega
                        >(
                          currentTable: table,
                          referencedTable: $$RepartosTableReferences
                              ._entregasRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RepartosTableReferences(
                                db,
                                table,
                                p0,
                              ).entregasRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.repartoId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (pagosRefs)
                        await $_getPrefetchedData<
                          Reparto,
                          $RepartosTable,
                          Pago
                        >(
                          currentTable: table,
                          referencedTable: $$RepartosTableReferences
                              ._pagosRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RepartosTableReferences(
                                db,
                                table,
                                p0,
                              ).pagosRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.repartoId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (resumenesRefs)
                        await $_getPrefetchedData<
                          Reparto,
                          $RepartosTable,
                          Resumene
                        >(
                          currentTable: table,
                          referencedTable: $$RepartosTableReferences
                              ._resumenesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RepartosTableReferences(
                                db,
                                table,
                                p0,
                              ).resumenesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.repartoId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (etiquetaColorsRefs)
                        await $_getPrefetchedData<
                          Reparto,
                          $RepartosTable,
                          EtiquetaColor
                        >(
                          currentTable: table,
                          referencedTable: $$RepartosTableReferences
                              ._etiquetaColorsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RepartosTableReferences(
                                db,
                                table,
                                p0,
                              ).etiquetaColorsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.repartoId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (facturasRefs)
                        await $_getPrefetchedData<
                          Reparto,
                          $RepartosTable,
                          Factura
                        >(
                          currentTable: table,
                          referencedTable: $$RepartosTableReferences
                              ._facturasRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RepartosTableReferences(
                                db,
                                table,
                                p0,
                              ).facturasRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.repartoId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RepartosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RepartosTable,
      Reparto,
      $$RepartosTableFilterComposer,
      $$RepartosTableOrderingComposer,
      $$RepartosTableAnnotationComposer,
      $$RepartosTableCreateCompanionBuilder,
      $$RepartosTableUpdateCompanionBuilder,
      (Reparto, $$RepartosTableReferences),
      Reparto,
      PrefetchHooks Function({
        bool cargaDiariaRefs,
        bool clientesRefs,
        bool entregasRefs,
        bool pagosRefs,
        bool resumenesRefs,
        bool etiquetaColorsRefs,
        bool facturasRefs,
      })
    >;
typedef $$ProductosTableCreateCompanionBuilder =
    ProductosCompanion Function({
      Value<int> id,
      Value<int?> repartoId,
      required String nombre,
      Value<int> orden,
      Value<double> precio,
      Value<bool> deleted,
    });
typedef $$ProductosTableUpdateCompanionBuilder =
    ProductosCompanion Function({
      Value<int> id,
      Value<int?> repartoId,
      Value<String> nombre,
      Value<int> orden,
      Value<double> precio,
      Value<bool> deleted,
    });

final class $$ProductosTableReferences
    extends BaseReferences<_$AppDatabase, $ProductosTable, Producto> {
  $$ProductosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ProductoPreciosTable, List<ProductoPrecio>>
  _productoPreciosRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.productoPrecios,
    aliasName: $_aliasNameGenerator(
      db.productos.id,
      db.productoPrecios.productoId,
    ),
  );

  $$ProductoPreciosTableProcessedTableManager get productoPreciosRefs {
    final manager = $$ProductoPreciosTableTableManager(
      $_db,
      $_db.productoPrecios,
    ).filter((f) => f.productoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _productoPreciosRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CargaDiariaTable, List<CargaDiariaData>>
  _cargaDiariaRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cargaDiaria,
    aliasName: $_aliasNameGenerator(db.productos.id, db.cargaDiaria.productoId),
  );

  $$CargaDiariaTableProcessedTableManager get cargaDiariaRefs {
    final manager = $$CargaDiariaTableTableManager(
      $_db,
      $_db.cargaDiaria,
    ).filter((f) => f.productoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cargaDiariaRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ClienteProductosTable, List<ClienteProducto>>
  _clienteProductosRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.clienteProductos,
    aliasName: $_aliasNameGenerator(
      db.productos.id,
      db.clienteProductos.productoId,
    ),
  );

  $$ClienteProductosTableProcessedTableManager get clienteProductosRefs {
    final manager = $$ClienteProductosTableTableManager(
      $_db,
      $_db.clienteProductos,
    ).filter((f) => f.productoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _clienteProductosRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EntregasTable, List<Entrega>> _entregasRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.entregas,
    aliasName: $_aliasNameGenerator(db.productos.id, db.entregas.productoId),
  );

  $$EntregasTableProcessedTableManager get entregasRefs {
    final manager = $$EntregasTableTableManager(
      $_db,
      $_db.entregas,
    ).filter((f) => f.productoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_entregasRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StockNotifSettingsTable, List<StockNotifSetting>>
  _stockNotifSettingsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.stockNotifSettings,
        aliasName: $_aliasNameGenerator(
          db.productos.id,
          db.stockNotifSettings.productoId,
        ),
      );

  $$StockNotifSettingsTableProcessedTableManager get stockNotifSettingsRefs {
    final manager = $$StockNotifSettingsTableTableManager(
      $_db,
      $_db.stockNotifSettings,
    ).filter((f) => f.productoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _stockNotifSettingsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProductosTableFilterComposer
    extends Composer<_$AppDatabase, $ProductosTable> {
  $$ProductosTableFilterComposer({
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

  ColumnFilters<int> get repartoId => $composableBuilder(
    column: $table.repartoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orden => $composableBuilder(
    column: $table.orden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get precio => $composableBuilder(
    column: $table.precio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> productoPreciosRefs(
    Expression<bool> Function($$ProductoPreciosTableFilterComposer f) f,
  ) {
    final $$ProductoPreciosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productoPrecios,
      getReferencedColumn: (t) => t.productoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductoPreciosTableFilterComposer(
            $db: $db,
            $table: $db.productoPrecios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cargaDiariaRefs(
    Expression<bool> Function($$CargaDiariaTableFilterComposer f) f,
  ) {
    final $$CargaDiariaTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cargaDiaria,
      getReferencedColumn: (t) => t.productoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CargaDiariaTableFilterComposer(
            $db: $db,
            $table: $db.cargaDiaria,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> clienteProductosRefs(
    Expression<bool> Function($$ClienteProductosTableFilterComposer f) f,
  ) {
    final $$ClienteProductosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.clienteProductos,
      getReferencedColumn: (t) => t.productoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClienteProductosTableFilterComposer(
            $db: $db,
            $table: $db.clienteProductos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> entregasRefs(
    Expression<bool> Function($$EntregasTableFilterComposer f) f,
  ) {
    final $$EntregasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entregas,
      getReferencedColumn: (t) => t.productoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntregasTableFilterComposer(
            $db: $db,
            $table: $db.entregas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stockNotifSettingsRefs(
    Expression<bool> Function($$StockNotifSettingsTableFilterComposer f) f,
  ) {
    final $$StockNotifSettingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockNotifSettings,
      getReferencedColumn: (t) => t.productoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockNotifSettingsTableFilterComposer(
            $db: $db,
            $table: $db.stockNotifSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProductosTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductosTable> {
  $$ProductosTableOrderingComposer({
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

  ColumnOrderings<int> get repartoId => $composableBuilder(
    column: $table.repartoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orden => $composableBuilder(
    column: $table.orden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get precio => $composableBuilder(
    column: $table.precio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProductosTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductosTable> {
  $$ProductosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get repartoId =>
      $composableBuilder(column: $table.repartoId, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<int> get orden =>
      $composableBuilder(column: $table.orden, builder: (column) => column);

  GeneratedColumn<double> get precio =>
      $composableBuilder(column: $table.precio, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  Expression<T> productoPreciosRefs<T extends Object>(
    Expression<T> Function($$ProductoPreciosTableAnnotationComposer a) f,
  ) {
    final $$ProductoPreciosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productoPrecios,
      getReferencedColumn: (t) => t.productoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductoPreciosTableAnnotationComposer(
            $db: $db,
            $table: $db.productoPrecios,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cargaDiariaRefs<T extends Object>(
    Expression<T> Function($$CargaDiariaTableAnnotationComposer a) f,
  ) {
    final $$CargaDiariaTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cargaDiaria,
      getReferencedColumn: (t) => t.productoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CargaDiariaTableAnnotationComposer(
            $db: $db,
            $table: $db.cargaDiaria,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> clienteProductosRefs<T extends Object>(
    Expression<T> Function($$ClienteProductosTableAnnotationComposer a) f,
  ) {
    final $$ClienteProductosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.clienteProductos,
      getReferencedColumn: (t) => t.productoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClienteProductosTableAnnotationComposer(
            $db: $db,
            $table: $db.clienteProductos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> entregasRefs<T extends Object>(
    Expression<T> Function($$EntregasTableAnnotationComposer a) f,
  ) {
    final $$EntregasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entregas,
      getReferencedColumn: (t) => t.productoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntregasTableAnnotationComposer(
            $db: $db,
            $table: $db.entregas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> stockNotifSettingsRefs<T extends Object>(
    Expression<T> Function($$StockNotifSettingsTableAnnotationComposer a) f,
  ) {
    final $$StockNotifSettingsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.stockNotifSettings,
          getReferencedColumn: (t) => t.productoId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$StockNotifSettingsTableAnnotationComposer(
                $db: $db,
                $table: $db.stockNotifSettings,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ProductosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductosTable,
          Producto,
          $$ProductosTableFilterComposer,
          $$ProductosTableOrderingComposer,
          $$ProductosTableAnnotationComposer,
          $$ProductosTableCreateCompanionBuilder,
          $$ProductosTableUpdateCompanionBuilder,
          (Producto, $$ProductosTableReferences),
          Producto,
          PrefetchHooks Function({
            bool productoPreciosRefs,
            bool cargaDiariaRefs,
            bool clienteProductosRefs,
            bool entregasRefs,
            bool stockNotifSettingsRefs,
          })
        > {
  $$ProductosTableTableManager(_$AppDatabase db, $ProductosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> repartoId = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<int> orden = const Value.absent(),
                Value<double> precio = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
              }) => ProductosCompanion(
                id: id,
                repartoId: repartoId,
                nombre: nombre,
                orden: orden,
                precio: precio,
                deleted: deleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> repartoId = const Value.absent(),
                required String nombre,
                Value<int> orden = const Value.absent(),
                Value<double> precio = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
              }) => ProductosCompanion.insert(
                id: id,
                repartoId: repartoId,
                nombre: nombre,
                orden: orden,
                precio: precio,
                deleted: deleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProductosTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                productoPreciosRefs = false,
                cargaDiariaRefs = false,
                clienteProductosRefs = false,
                entregasRefs = false,
                stockNotifSettingsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (productoPreciosRefs) db.productoPrecios,
                    if (cargaDiariaRefs) db.cargaDiaria,
                    if (clienteProductosRefs) db.clienteProductos,
                    if (entregasRefs) db.entregas,
                    if (stockNotifSettingsRefs) db.stockNotifSettings,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (productoPreciosRefs)
                        await $_getPrefetchedData<
                          Producto,
                          $ProductosTable,
                          ProductoPrecio
                        >(
                          currentTable: table,
                          referencedTable: $$ProductosTableReferences
                              ._productoPreciosRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductosTableReferences(
                                db,
                                table,
                                p0,
                              ).productoPreciosRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productoId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cargaDiariaRefs)
                        await $_getPrefetchedData<
                          Producto,
                          $ProductosTable,
                          CargaDiariaData
                        >(
                          currentTable: table,
                          referencedTable: $$ProductosTableReferences
                              ._cargaDiariaRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductosTableReferences(
                                db,
                                table,
                                p0,
                              ).cargaDiariaRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productoId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (clienteProductosRefs)
                        await $_getPrefetchedData<
                          Producto,
                          $ProductosTable,
                          ClienteProducto
                        >(
                          currentTable: table,
                          referencedTable: $$ProductosTableReferences
                              ._clienteProductosRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductosTableReferences(
                                db,
                                table,
                                p0,
                              ).clienteProductosRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productoId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (entregasRefs)
                        await $_getPrefetchedData<
                          Producto,
                          $ProductosTable,
                          Entrega
                        >(
                          currentTable: table,
                          referencedTable: $$ProductosTableReferences
                              ._entregasRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductosTableReferences(
                                db,
                                table,
                                p0,
                              ).entregasRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productoId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (stockNotifSettingsRefs)
                        await $_getPrefetchedData<
                          Producto,
                          $ProductosTable,
                          StockNotifSetting
                        >(
                          currentTable: table,
                          referencedTable: $$ProductosTableReferences
                              ._stockNotifSettingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductosTableReferences(
                                db,
                                table,
                                p0,
                              ).stockNotifSettingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productoId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProductosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductosTable,
      Producto,
      $$ProductosTableFilterComposer,
      $$ProductosTableOrderingComposer,
      $$ProductosTableAnnotationComposer,
      $$ProductosTableCreateCompanionBuilder,
      $$ProductosTableUpdateCompanionBuilder,
      (Producto, $$ProductosTableReferences),
      Producto,
      PrefetchHooks Function({
        bool productoPreciosRefs,
        bool cargaDiariaRefs,
        bool clienteProductosRefs,
        bool entregasRefs,
        bool stockNotifSettingsRefs,
      })
    >;
typedef $$ProductoPreciosTableCreateCompanionBuilder =
    ProductoPreciosCompanion Function({
      Value<int> id,
      Value<int?> repartoId,
      required int productoId,
      required String nombre,
      required double precio,
      Value<int> orden,
    });
typedef $$ProductoPreciosTableUpdateCompanionBuilder =
    ProductoPreciosCompanion Function({
      Value<int> id,
      Value<int?> repartoId,
      Value<int> productoId,
      Value<String> nombre,
      Value<double> precio,
      Value<int> orden,
    });

final class $$ProductoPreciosTableReferences
    extends
        BaseReferences<_$AppDatabase, $ProductoPreciosTable, ProductoPrecio> {
  $$ProductoPreciosTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProductosTable _productoIdTable(_$AppDatabase db) =>
      db.productos.createAlias(
        $_aliasNameGenerator(db.productoPrecios.productoId, db.productos.id),
      );

  $$ProductosTableProcessedTableManager get productoId {
    final $_column = $_itemColumn<int>('producto_id')!;

    final manager = $$ProductosTableTableManager(
      $_db,
      $_db.productos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProductoPreciosTableFilterComposer
    extends Composer<_$AppDatabase, $ProductoPreciosTable> {
  $$ProductoPreciosTableFilterComposer({
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

  ColumnFilters<int> get repartoId => $composableBuilder(
    column: $table.repartoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get precio => $composableBuilder(
    column: $table.precio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orden => $composableBuilder(
    column: $table.orden,
    builder: (column) => ColumnFilters(column),
  );

  $$ProductosTableFilterComposer get productoId {
    final $$ProductosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productoId,
      referencedTable: $db.productos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductosTableFilterComposer(
            $db: $db,
            $table: $db.productos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductoPreciosTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductoPreciosTable> {
  $$ProductoPreciosTableOrderingComposer({
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

  ColumnOrderings<int> get repartoId => $composableBuilder(
    column: $table.repartoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get precio => $composableBuilder(
    column: $table.precio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orden => $composableBuilder(
    column: $table.orden,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProductosTableOrderingComposer get productoId {
    final $$ProductosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productoId,
      referencedTable: $db.productos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductosTableOrderingComposer(
            $db: $db,
            $table: $db.productos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductoPreciosTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductoPreciosTable> {
  $$ProductoPreciosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get repartoId =>
      $composableBuilder(column: $table.repartoId, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<double> get precio =>
      $composableBuilder(column: $table.precio, builder: (column) => column);

  GeneratedColumn<int> get orden =>
      $composableBuilder(column: $table.orden, builder: (column) => column);

  $$ProductosTableAnnotationComposer get productoId {
    final $$ProductosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productoId,
      referencedTable: $db.productos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductosTableAnnotationComposer(
            $db: $db,
            $table: $db.productos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductoPreciosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductoPreciosTable,
          ProductoPrecio,
          $$ProductoPreciosTableFilterComposer,
          $$ProductoPreciosTableOrderingComposer,
          $$ProductoPreciosTableAnnotationComposer,
          $$ProductoPreciosTableCreateCompanionBuilder,
          $$ProductoPreciosTableUpdateCompanionBuilder,
          (ProductoPrecio, $$ProductoPreciosTableReferences),
          ProductoPrecio,
          PrefetchHooks Function({bool productoId})
        > {
  $$ProductoPreciosTableTableManager(
    _$AppDatabase db,
    $ProductoPreciosTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductoPreciosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductoPreciosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductoPreciosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> repartoId = const Value.absent(),
                Value<int> productoId = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<double> precio = const Value.absent(),
                Value<int> orden = const Value.absent(),
              }) => ProductoPreciosCompanion(
                id: id,
                repartoId: repartoId,
                productoId: productoId,
                nombre: nombre,
                precio: precio,
                orden: orden,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> repartoId = const Value.absent(),
                required int productoId,
                required String nombre,
                required double precio,
                Value<int> orden = const Value.absent(),
              }) => ProductoPreciosCompanion.insert(
                id: id,
                repartoId: repartoId,
                productoId: productoId,
                nombre: nombre,
                precio: precio,
                orden: orden,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProductoPreciosTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({productoId = false}) {
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
                    if (productoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.productoId,
                                referencedTable:
                                    $$ProductoPreciosTableReferences
                                        ._productoIdTable(db),
                                referencedColumn:
                                    $$ProductoPreciosTableReferences
                                        ._productoIdTable(db)
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

typedef $$ProductoPreciosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductoPreciosTable,
      ProductoPrecio,
      $$ProductoPreciosTableFilterComposer,
      $$ProductoPreciosTableOrderingComposer,
      $$ProductoPreciosTableAnnotationComposer,
      $$ProductoPreciosTableCreateCompanionBuilder,
      $$ProductoPreciosTableUpdateCompanionBuilder,
      (ProductoPrecio, $$ProductoPreciosTableReferences),
      ProductoPrecio,
      PrefetchHooks Function({bool productoId})
    >;
typedef $$CargaDiariaTableCreateCompanionBuilder =
    CargaDiariaCompanion Function({
      Value<int> id,
      required int productoId,
      required int repartoId,
      required int diaSemana,
      required String semana,
      Value<int> cantidad,
    });
typedef $$CargaDiariaTableUpdateCompanionBuilder =
    CargaDiariaCompanion Function({
      Value<int> id,
      Value<int> productoId,
      Value<int> repartoId,
      Value<int> diaSemana,
      Value<String> semana,
      Value<int> cantidad,
    });

final class $$CargaDiariaTableReferences
    extends BaseReferences<_$AppDatabase, $CargaDiariaTable, CargaDiariaData> {
  $$CargaDiariaTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProductosTable _productoIdTable(_$AppDatabase db) =>
      db.productos.createAlias(
        $_aliasNameGenerator(db.cargaDiaria.productoId, db.productos.id),
      );

  $$ProductosTableProcessedTableManager get productoId {
    final $_column = $_itemColumn<int>('producto_id')!;

    final manager = $$ProductosTableTableManager(
      $_db,
      $_db.productos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RepartosTable _repartoIdTable(_$AppDatabase db) =>
      db.repartos.createAlias(
        $_aliasNameGenerator(db.cargaDiaria.repartoId, db.repartos.id),
      );

  $$RepartosTableProcessedTableManager get repartoId {
    final $_column = $_itemColumn<int>('reparto_id')!;

    final manager = $$RepartosTableTableManager(
      $_db,
      $_db.repartos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_repartoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CargaDiariaTableFilterComposer
    extends Composer<_$AppDatabase, $CargaDiariaTable> {
  $$CargaDiariaTableFilterComposer({
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

  ColumnFilters<int> get diaSemana => $composableBuilder(
    column: $table.diaSemana,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semana => $composableBuilder(
    column: $table.semana,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cantidad => $composableBuilder(
    column: $table.cantidad,
    builder: (column) => ColumnFilters(column),
  );

  $$ProductosTableFilterComposer get productoId {
    final $$ProductosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productoId,
      referencedTable: $db.productos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductosTableFilterComposer(
            $db: $db,
            $table: $db.productos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepartosTableFilterComposer get repartoId {
    final $$RepartosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableFilterComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CargaDiariaTableOrderingComposer
    extends Composer<_$AppDatabase, $CargaDiariaTable> {
  $$CargaDiariaTableOrderingComposer({
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

  ColumnOrderings<int> get diaSemana => $composableBuilder(
    column: $table.diaSemana,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semana => $composableBuilder(
    column: $table.semana,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cantidad => $composableBuilder(
    column: $table.cantidad,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProductosTableOrderingComposer get productoId {
    final $$ProductosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productoId,
      referencedTable: $db.productos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductosTableOrderingComposer(
            $db: $db,
            $table: $db.productos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepartosTableOrderingComposer get repartoId {
    final $$RepartosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableOrderingComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CargaDiariaTableAnnotationComposer
    extends Composer<_$AppDatabase, $CargaDiariaTable> {
  $$CargaDiariaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get diaSemana =>
      $composableBuilder(column: $table.diaSemana, builder: (column) => column);

  GeneratedColumn<String> get semana =>
      $composableBuilder(column: $table.semana, builder: (column) => column);

  GeneratedColumn<int> get cantidad =>
      $composableBuilder(column: $table.cantidad, builder: (column) => column);

  $$ProductosTableAnnotationComposer get productoId {
    final $$ProductosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productoId,
      referencedTable: $db.productos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductosTableAnnotationComposer(
            $db: $db,
            $table: $db.productos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepartosTableAnnotationComposer get repartoId {
    final $$RepartosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableAnnotationComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CargaDiariaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CargaDiariaTable,
          CargaDiariaData,
          $$CargaDiariaTableFilterComposer,
          $$CargaDiariaTableOrderingComposer,
          $$CargaDiariaTableAnnotationComposer,
          $$CargaDiariaTableCreateCompanionBuilder,
          $$CargaDiariaTableUpdateCompanionBuilder,
          (CargaDiariaData, $$CargaDiariaTableReferences),
          CargaDiariaData,
          PrefetchHooks Function({bool productoId, bool repartoId})
        > {
  $$CargaDiariaTableTableManager(_$AppDatabase db, $CargaDiariaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CargaDiariaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CargaDiariaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CargaDiariaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> productoId = const Value.absent(),
                Value<int> repartoId = const Value.absent(),
                Value<int> diaSemana = const Value.absent(),
                Value<String> semana = const Value.absent(),
                Value<int> cantidad = const Value.absent(),
              }) => CargaDiariaCompanion(
                id: id,
                productoId: productoId,
                repartoId: repartoId,
                diaSemana: diaSemana,
                semana: semana,
                cantidad: cantidad,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int productoId,
                required int repartoId,
                required int diaSemana,
                required String semana,
                Value<int> cantidad = const Value.absent(),
              }) => CargaDiariaCompanion.insert(
                id: id,
                productoId: productoId,
                repartoId: repartoId,
                diaSemana: diaSemana,
                semana: semana,
                cantidad: cantidad,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CargaDiariaTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({productoId = false, repartoId = false}) {
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
                    if (productoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.productoId,
                                referencedTable: $$CargaDiariaTableReferences
                                    ._productoIdTable(db),
                                referencedColumn: $$CargaDiariaTableReferences
                                    ._productoIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (repartoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.repartoId,
                                referencedTable: $$CargaDiariaTableReferences
                                    ._repartoIdTable(db),
                                referencedColumn: $$CargaDiariaTableReferences
                                    ._repartoIdTable(db)
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

typedef $$CargaDiariaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CargaDiariaTable,
      CargaDiariaData,
      $$CargaDiariaTableFilterComposer,
      $$CargaDiariaTableOrderingComposer,
      $$CargaDiariaTableAnnotationComposer,
      $$CargaDiariaTableCreateCompanionBuilder,
      $$CargaDiariaTableUpdateCompanionBuilder,
      (CargaDiariaData, $$CargaDiariaTableReferences),
      CargaDiariaData,
      PrefetchHooks Function({bool productoId, bool repartoId})
    >;
typedef $$ClientesTableCreateCompanionBuilder =
    ClientesCompanion Function({
      Value<int> id,
      required int repartoId,
      required int diaSemana,
      required String nombre,
      Value<String> direccion,
      Value<String> telefono,
      Value<String> frecuencia,
      Value<String> etiqueta,
      Value<String> notas,
      Value<int> orden,
      Value<double> cuentaCorriente,
      Value<bool> showOnMap,
      Value<int> docTipo,
      Value<String> docNro,
    });
typedef $$ClientesTableUpdateCompanionBuilder =
    ClientesCompanion Function({
      Value<int> id,
      Value<int> repartoId,
      Value<int> diaSemana,
      Value<String> nombre,
      Value<String> direccion,
      Value<String> telefono,
      Value<String> frecuencia,
      Value<String> etiqueta,
      Value<String> notas,
      Value<int> orden,
      Value<double> cuentaCorriente,
      Value<bool> showOnMap,
      Value<int> docTipo,
      Value<String> docNro,
    });

final class $$ClientesTableReferences
    extends BaseReferences<_$AppDatabase, $ClientesTable, Cliente> {
  $$ClientesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RepartosTable _repartoIdTable(_$AppDatabase db) => db.repartos
      .createAlias($_aliasNameGenerator(db.clientes.repartoId, db.repartos.id));

  $$RepartosTableProcessedTableManager get repartoId {
    final $_column = $_itemColumn<int>('reparto_id')!;

    final manager = $$RepartosTableTableManager(
      $_db,
      $_db.repartos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_repartoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ClienteProductosTable, List<ClienteProducto>>
  _clienteProductosRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.clienteProductos,
    aliasName: $_aliasNameGenerator(
      db.clientes.id,
      db.clienteProductos.clienteId,
    ),
  );

  $$ClienteProductosTableProcessedTableManager get clienteProductosRefs {
    final manager = $$ClienteProductosTableTableManager(
      $_db,
      $_db.clienteProductos,
    ).filter((f) => f.clienteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _clienteProductosRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EntregasTable, List<Entrega>> _entregasRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.entregas,
    aliasName: $_aliasNameGenerator(db.clientes.id, db.entregas.clienteId),
  );

  $$EntregasTableProcessedTableManager get entregasRefs {
    final manager = $$EntregasTableTableManager(
      $_db,
      $_db.entregas,
    ).filter((f) => f.clienteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_entregasRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PagosTable, List<Pago>> _pagosRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.pagos,
    aliasName: $_aliasNameGenerator(db.clientes.id, db.pagos.clienteId),
  );

  $$PagosTableProcessedTableManager get pagosRefs {
    final manager = $$PagosTableTableManager(
      $_db,
      $_db.pagos,
    ).filter((f) => f.clienteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_pagosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FacturasTable, List<Factura>> _facturasRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.facturas,
    aliasName: $_aliasNameGenerator(db.clientes.id, db.facturas.clienteId),
  );

  $$FacturasTableProcessedTableManager get facturasRefs {
    final manager = $$FacturasTableTableManager(
      $_db,
      $_db.facturas,
    ).filter((f) => f.clienteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_facturasRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ClientesTableFilterComposer
    extends Composer<_$AppDatabase, $ClientesTable> {
  $$ClientesTableFilterComposer({
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

  ColumnFilters<int> get diaSemana => $composableBuilder(
    column: $table.diaSemana,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direccion => $composableBuilder(
    column: $table.direccion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get telefono => $composableBuilder(
    column: $table.telefono,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frecuencia => $composableBuilder(
    column: $table.frecuencia,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etiqueta => $composableBuilder(
    column: $table.etiqueta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notas => $composableBuilder(
    column: $table.notas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orden => $composableBuilder(
    column: $table.orden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cuentaCorriente => $composableBuilder(
    column: $table.cuentaCorriente,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showOnMap => $composableBuilder(
    column: $table.showOnMap,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get docTipo => $composableBuilder(
    column: $table.docTipo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get docNro => $composableBuilder(
    column: $table.docNro,
    builder: (column) => ColumnFilters(column),
  );

  $$RepartosTableFilterComposer get repartoId {
    final $$RepartosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableFilterComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> clienteProductosRefs(
    Expression<bool> Function($$ClienteProductosTableFilterComposer f) f,
  ) {
    final $$ClienteProductosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.clienteProductos,
      getReferencedColumn: (t) => t.clienteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClienteProductosTableFilterComposer(
            $db: $db,
            $table: $db.clienteProductos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> entregasRefs(
    Expression<bool> Function($$EntregasTableFilterComposer f) f,
  ) {
    final $$EntregasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entregas,
      getReferencedColumn: (t) => t.clienteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntregasTableFilterComposer(
            $db: $db,
            $table: $db.entregas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> pagosRefs(
    Expression<bool> Function($$PagosTableFilterComposer f) f,
  ) {
    final $$PagosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pagos,
      getReferencedColumn: (t) => t.clienteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PagosTableFilterComposer(
            $db: $db,
            $table: $db.pagos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> facturasRefs(
    Expression<bool> Function($$FacturasTableFilterComposer f) f,
  ) {
    final $$FacturasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.facturas,
      getReferencedColumn: (t) => t.clienteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FacturasTableFilterComposer(
            $db: $db,
            $table: $db.facturas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ClientesTableOrderingComposer
    extends Composer<_$AppDatabase, $ClientesTable> {
  $$ClientesTableOrderingComposer({
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

  ColumnOrderings<int> get diaSemana => $composableBuilder(
    column: $table.diaSemana,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direccion => $composableBuilder(
    column: $table.direccion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get telefono => $composableBuilder(
    column: $table.telefono,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frecuencia => $composableBuilder(
    column: $table.frecuencia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etiqueta => $composableBuilder(
    column: $table.etiqueta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notas => $composableBuilder(
    column: $table.notas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orden => $composableBuilder(
    column: $table.orden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cuentaCorriente => $composableBuilder(
    column: $table.cuentaCorriente,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showOnMap => $composableBuilder(
    column: $table.showOnMap,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get docTipo => $composableBuilder(
    column: $table.docTipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get docNro => $composableBuilder(
    column: $table.docNro,
    builder: (column) => ColumnOrderings(column),
  );

  $$RepartosTableOrderingComposer get repartoId {
    final $$RepartosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableOrderingComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClientesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClientesTable> {
  $$ClientesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get diaSemana =>
      $composableBuilder(column: $table.diaSemana, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<String> get direccion =>
      $composableBuilder(column: $table.direccion, builder: (column) => column);

  GeneratedColumn<String> get telefono =>
      $composableBuilder(column: $table.telefono, builder: (column) => column);

  GeneratedColumn<String> get frecuencia => $composableBuilder(
    column: $table.frecuencia,
    builder: (column) => column,
  );

  GeneratedColumn<String> get etiqueta =>
      $composableBuilder(column: $table.etiqueta, builder: (column) => column);

  GeneratedColumn<String> get notas =>
      $composableBuilder(column: $table.notas, builder: (column) => column);

  GeneratedColumn<int> get orden =>
      $composableBuilder(column: $table.orden, builder: (column) => column);

  GeneratedColumn<double> get cuentaCorriente => $composableBuilder(
    column: $table.cuentaCorriente,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showOnMap =>
      $composableBuilder(column: $table.showOnMap, builder: (column) => column);

  GeneratedColumn<int> get docTipo =>
      $composableBuilder(column: $table.docTipo, builder: (column) => column);

  GeneratedColumn<String> get docNro =>
      $composableBuilder(column: $table.docNro, builder: (column) => column);

  $$RepartosTableAnnotationComposer get repartoId {
    final $$RepartosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableAnnotationComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> clienteProductosRefs<T extends Object>(
    Expression<T> Function($$ClienteProductosTableAnnotationComposer a) f,
  ) {
    final $$ClienteProductosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.clienteProductos,
      getReferencedColumn: (t) => t.clienteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClienteProductosTableAnnotationComposer(
            $db: $db,
            $table: $db.clienteProductos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> entregasRefs<T extends Object>(
    Expression<T> Function($$EntregasTableAnnotationComposer a) f,
  ) {
    final $$EntregasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entregas,
      getReferencedColumn: (t) => t.clienteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntregasTableAnnotationComposer(
            $db: $db,
            $table: $db.entregas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> pagosRefs<T extends Object>(
    Expression<T> Function($$PagosTableAnnotationComposer a) f,
  ) {
    final $$PagosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pagos,
      getReferencedColumn: (t) => t.clienteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PagosTableAnnotationComposer(
            $db: $db,
            $table: $db.pagos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> facturasRefs<T extends Object>(
    Expression<T> Function($$FacturasTableAnnotationComposer a) f,
  ) {
    final $$FacturasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.facturas,
      getReferencedColumn: (t) => t.clienteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FacturasTableAnnotationComposer(
            $db: $db,
            $table: $db.facturas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ClientesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClientesTable,
          Cliente,
          $$ClientesTableFilterComposer,
          $$ClientesTableOrderingComposer,
          $$ClientesTableAnnotationComposer,
          $$ClientesTableCreateCompanionBuilder,
          $$ClientesTableUpdateCompanionBuilder,
          (Cliente, $$ClientesTableReferences),
          Cliente,
          PrefetchHooks Function({
            bool repartoId,
            bool clienteProductosRefs,
            bool entregasRefs,
            bool pagosRefs,
            bool facturasRefs,
          })
        > {
  $$ClientesTableTableManager(_$AppDatabase db, $ClientesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClientesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClientesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClientesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> repartoId = const Value.absent(),
                Value<int> diaSemana = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<String> direccion = const Value.absent(),
                Value<String> telefono = const Value.absent(),
                Value<String> frecuencia = const Value.absent(),
                Value<String> etiqueta = const Value.absent(),
                Value<String> notas = const Value.absent(),
                Value<int> orden = const Value.absent(),
                Value<double> cuentaCorriente = const Value.absent(),
                Value<bool> showOnMap = const Value.absent(),
                Value<int> docTipo = const Value.absent(),
                Value<String> docNro = const Value.absent(),
              }) => ClientesCompanion(
                id: id,
                repartoId: repartoId,
                diaSemana: diaSemana,
                nombre: nombre,
                direccion: direccion,
                telefono: telefono,
                frecuencia: frecuencia,
                etiqueta: etiqueta,
                notas: notas,
                orden: orden,
                cuentaCorriente: cuentaCorriente,
                showOnMap: showOnMap,
                docTipo: docTipo,
                docNro: docNro,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int repartoId,
                required int diaSemana,
                required String nombre,
                Value<String> direccion = const Value.absent(),
                Value<String> telefono = const Value.absent(),
                Value<String> frecuencia = const Value.absent(),
                Value<String> etiqueta = const Value.absent(),
                Value<String> notas = const Value.absent(),
                Value<int> orden = const Value.absent(),
                Value<double> cuentaCorriente = const Value.absent(),
                Value<bool> showOnMap = const Value.absent(),
                Value<int> docTipo = const Value.absent(),
                Value<String> docNro = const Value.absent(),
              }) => ClientesCompanion.insert(
                id: id,
                repartoId: repartoId,
                diaSemana: diaSemana,
                nombre: nombre,
                direccion: direccion,
                telefono: telefono,
                frecuencia: frecuencia,
                etiqueta: etiqueta,
                notas: notas,
                orden: orden,
                cuentaCorriente: cuentaCorriente,
                showOnMap: showOnMap,
                docTipo: docTipo,
                docNro: docNro,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ClientesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                repartoId = false,
                clienteProductosRefs = false,
                entregasRefs = false,
                pagosRefs = false,
                facturasRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (clienteProductosRefs) db.clienteProductos,
                    if (entregasRefs) db.entregas,
                    if (pagosRefs) db.pagos,
                    if (facturasRefs) db.facturas,
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
                        if (repartoId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.repartoId,
                                    referencedTable: $$ClientesTableReferences
                                        ._repartoIdTable(db),
                                    referencedColumn: $$ClientesTableReferences
                                        ._repartoIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (clienteProductosRefs)
                        await $_getPrefetchedData<
                          Cliente,
                          $ClientesTable,
                          ClienteProducto
                        >(
                          currentTable: table,
                          referencedTable: $$ClientesTableReferences
                              ._clienteProductosRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ClientesTableReferences(
                                db,
                                table,
                                p0,
                              ).clienteProductosRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.clienteId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (entregasRefs)
                        await $_getPrefetchedData<
                          Cliente,
                          $ClientesTable,
                          Entrega
                        >(
                          currentTable: table,
                          referencedTable: $$ClientesTableReferences
                              ._entregasRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ClientesTableReferences(
                                db,
                                table,
                                p0,
                              ).entregasRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.clienteId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (pagosRefs)
                        await $_getPrefetchedData<
                          Cliente,
                          $ClientesTable,
                          Pago
                        >(
                          currentTable: table,
                          referencedTable: $$ClientesTableReferences
                              ._pagosRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ClientesTableReferences(
                                db,
                                table,
                                p0,
                              ).pagosRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.clienteId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (facturasRefs)
                        await $_getPrefetchedData<
                          Cliente,
                          $ClientesTable,
                          Factura
                        >(
                          currentTable: table,
                          referencedTable: $$ClientesTableReferences
                              ._facturasRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ClientesTableReferences(
                                db,
                                table,
                                p0,
                              ).facturasRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.clienteId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ClientesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClientesTable,
      Cliente,
      $$ClientesTableFilterComposer,
      $$ClientesTableOrderingComposer,
      $$ClientesTableAnnotationComposer,
      $$ClientesTableCreateCompanionBuilder,
      $$ClientesTableUpdateCompanionBuilder,
      (Cliente, $$ClientesTableReferences),
      Cliente,
      PrefetchHooks Function({
        bool repartoId,
        bool clienteProductosRefs,
        bool entregasRefs,
        bool pagosRefs,
        bool facturasRefs,
      })
    >;
typedef $$ClienteProductosTableCreateCompanionBuilder =
    ClienteProductosCompanion Function({
      Value<int> id,
      required int clienteId,
      required int productoId,
      Value<int> cantidadHabitual,
      Value<int?> precioTipoId,
    });
typedef $$ClienteProductosTableUpdateCompanionBuilder =
    ClienteProductosCompanion Function({
      Value<int> id,
      Value<int> clienteId,
      Value<int> productoId,
      Value<int> cantidadHabitual,
      Value<int?> precioTipoId,
    });

final class $$ClienteProductosTableReferences
    extends
        BaseReferences<_$AppDatabase, $ClienteProductosTable, ClienteProducto> {
  $$ClienteProductosTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ClientesTable _clienteIdTable(_$AppDatabase db) =>
      db.clientes.createAlias(
        $_aliasNameGenerator(db.clienteProductos.clienteId, db.clientes.id),
      );

  $$ClientesTableProcessedTableManager get clienteId {
    final $_column = $_itemColumn<int>('cliente_id')!;

    final manager = $$ClientesTableTableManager(
      $_db,
      $_db.clientes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_clienteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProductosTable _productoIdTable(_$AppDatabase db) =>
      db.productos.createAlias(
        $_aliasNameGenerator(db.clienteProductos.productoId, db.productos.id),
      );

  $$ProductosTableProcessedTableManager get productoId {
    final $_column = $_itemColumn<int>('producto_id')!;

    final manager = $$ProductosTableTableManager(
      $_db,
      $_db.productos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ClienteProductosTableFilterComposer
    extends Composer<_$AppDatabase, $ClienteProductosTable> {
  $$ClienteProductosTableFilterComposer({
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

  ColumnFilters<int> get cantidadHabitual => $composableBuilder(
    column: $table.cantidadHabitual,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get precioTipoId => $composableBuilder(
    column: $table.precioTipoId,
    builder: (column) => ColumnFilters(column),
  );

  $$ClientesTableFilterComposer get clienteId {
    final $$ClientesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clienteId,
      referencedTable: $db.clientes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientesTableFilterComposer(
            $db: $db,
            $table: $db.clientes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductosTableFilterComposer get productoId {
    final $$ProductosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productoId,
      referencedTable: $db.productos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductosTableFilterComposer(
            $db: $db,
            $table: $db.productos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClienteProductosTableOrderingComposer
    extends Composer<_$AppDatabase, $ClienteProductosTable> {
  $$ClienteProductosTableOrderingComposer({
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

  ColumnOrderings<int> get cantidadHabitual => $composableBuilder(
    column: $table.cantidadHabitual,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get precioTipoId => $composableBuilder(
    column: $table.precioTipoId,
    builder: (column) => ColumnOrderings(column),
  );

  $$ClientesTableOrderingComposer get clienteId {
    final $$ClientesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clienteId,
      referencedTable: $db.clientes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientesTableOrderingComposer(
            $db: $db,
            $table: $db.clientes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductosTableOrderingComposer get productoId {
    final $$ProductosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productoId,
      referencedTable: $db.productos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductosTableOrderingComposer(
            $db: $db,
            $table: $db.productos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClienteProductosTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClienteProductosTable> {
  $$ClienteProductosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get cantidadHabitual => $composableBuilder(
    column: $table.cantidadHabitual,
    builder: (column) => column,
  );

  GeneratedColumn<int> get precioTipoId => $composableBuilder(
    column: $table.precioTipoId,
    builder: (column) => column,
  );

  $$ClientesTableAnnotationComposer get clienteId {
    final $$ClientesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clienteId,
      referencedTable: $db.clientes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientesTableAnnotationComposer(
            $db: $db,
            $table: $db.clientes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductosTableAnnotationComposer get productoId {
    final $$ProductosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productoId,
      referencedTable: $db.productos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductosTableAnnotationComposer(
            $db: $db,
            $table: $db.productos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClienteProductosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClienteProductosTable,
          ClienteProducto,
          $$ClienteProductosTableFilterComposer,
          $$ClienteProductosTableOrderingComposer,
          $$ClienteProductosTableAnnotationComposer,
          $$ClienteProductosTableCreateCompanionBuilder,
          $$ClienteProductosTableUpdateCompanionBuilder,
          (ClienteProducto, $$ClienteProductosTableReferences),
          ClienteProducto,
          PrefetchHooks Function({bool clienteId, bool productoId})
        > {
  $$ClienteProductosTableTableManager(
    _$AppDatabase db,
    $ClienteProductosTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClienteProductosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClienteProductosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClienteProductosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> clienteId = const Value.absent(),
                Value<int> productoId = const Value.absent(),
                Value<int> cantidadHabitual = const Value.absent(),
                Value<int?> precioTipoId = const Value.absent(),
              }) => ClienteProductosCompanion(
                id: id,
                clienteId: clienteId,
                productoId: productoId,
                cantidadHabitual: cantidadHabitual,
                precioTipoId: precioTipoId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int clienteId,
                required int productoId,
                Value<int> cantidadHabitual = const Value.absent(),
                Value<int?> precioTipoId = const Value.absent(),
              }) => ClienteProductosCompanion.insert(
                id: id,
                clienteId: clienteId,
                productoId: productoId,
                cantidadHabitual: cantidadHabitual,
                precioTipoId: precioTipoId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ClienteProductosTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({clienteId = false, productoId = false}) {
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
                    if (clienteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.clienteId,
                                referencedTable:
                                    $$ClienteProductosTableReferences
                                        ._clienteIdTable(db),
                                referencedColumn:
                                    $$ClienteProductosTableReferences
                                        ._clienteIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (productoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.productoId,
                                referencedTable:
                                    $$ClienteProductosTableReferences
                                        ._productoIdTable(db),
                                referencedColumn:
                                    $$ClienteProductosTableReferences
                                        ._productoIdTable(db)
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

typedef $$ClienteProductosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClienteProductosTable,
      ClienteProducto,
      $$ClienteProductosTableFilterComposer,
      $$ClienteProductosTableOrderingComposer,
      $$ClienteProductosTableAnnotationComposer,
      $$ClienteProductosTableCreateCompanionBuilder,
      $$ClienteProductosTableUpdateCompanionBuilder,
      (ClienteProducto, $$ClienteProductosTableReferences),
      ClienteProducto,
      PrefetchHooks Function({bool clienteId, bool productoId})
    >;
typedef $$EntregasTableCreateCompanionBuilder =
    EntregasCompanion Function({
      Value<int> id,
      required int clienteId,
      required int repartoId,
      required int productoId,
      required String semana,
      required int diaSemana,
      Value<int> entregado,
      Value<int> devuelto,
      Value<double> precioUnitario,
    });
typedef $$EntregasTableUpdateCompanionBuilder =
    EntregasCompanion Function({
      Value<int> id,
      Value<int> clienteId,
      Value<int> repartoId,
      Value<int> productoId,
      Value<String> semana,
      Value<int> diaSemana,
      Value<int> entregado,
      Value<int> devuelto,
      Value<double> precioUnitario,
    });

final class $$EntregasTableReferences
    extends BaseReferences<_$AppDatabase, $EntregasTable, Entrega> {
  $$EntregasTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ClientesTable _clienteIdTable(_$AppDatabase db) => db.clientes
      .createAlias($_aliasNameGenerator(db.entregas.clienteId, db.clientes.id));

  $$ClientesTableProcessedTableManager get clienteId {
    final $_column = $_itemColumn<int>('cliente_id')!;

    final manager = $$ClientesTableTableManager(
      $_db,
      $_db.clientes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_clienteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RepartosTable _repartoIdTable(_$AppDatabase db) => db.repartos
      .createAlias($_aliasNameGenerator(db.entregas.repartoId, db.repartos.id));

  $$RepartosTableProcessedTableManager get repartoId {
    final $_column = $_itemColumn<int>('reparto_id')!;

    final manager = $$RepartosTableTableManager(
      $_db,
      $_db.repartos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_repartoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProductosTable _productoIdTable(_$AppDatabase db) =>
      db.productos.createAlias(
        $_aliasNameGenerator(db.entregas.productoId, db.productos.id),
      );

  $$ProductosTableProcessedTableManager get productoId {
    final $_column = $_itemColumn<int>('producto_id')!;

    final manager = $$ProductosTableTableManager(
      $_db,
      $_db.productos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EntregasTableFilterComposer
    extends Composer<_$AppDatabase, $EntregasTable> {
  $$EntregasTableFilterComposer({
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

  ColumnFilters<String> get semana => $composableBuilder(
    column: $table.semana,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diaSemana => $composableBuilder(
    column: $table.diaSemana,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entregado => $composableBuilder(
    column: $table.entregado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get devuelto => $composableBuilder(
    column: $table.devuelto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get precioUnitario => $composableBuilder(
    column: $table.precioUnitario,
    builder: (column) => ColumnFilters(column),
  );

  $$ClientesTableFilterComposer get clienteId {
    final $$ClientesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clienteId,
      referencedTable: $db.clientes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientesTableFilterComposer(
            $db: $db,
            $table: $db.clientes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepartosTableFilterComposer get repartoId {
    final $$RepartosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableFilterComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductosTableFilterComposer get productoId {
    final $$ProductosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productoId,
      referencedTable: $db.productos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductosTableFilterComposer(
            $db: $db,
            $table: $db.productos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntregasTableOrderingComposer
    extends Composer<_$AppDatabase, $EntregasTable> {
  $$EntregasTableOrderingComposer({
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

  ColumnOrderings<String> get semana => $composableBuilder(
    column: $table.semana,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diaSemana => $composableBuilder(
    column: $table.diaSemana,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entregado => $composableBuilder(
    column: $table.entregado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get devuelto => $composableBuilder(
    column: $table.devuelto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get precioUnitario => $composableBuilder(
    column: $table.precioUnitario,
    builder: (column) => ColumnOrderings(column),
  );

  $$ClientesTableOrderingComposer get clienteId {
    final $$ClientesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clienteId,
      referencedTable: $db.clientes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientesTableOrderingComposer(
            $db: $db,
            $table: $db.clientes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepartosTableOrderingComposer get repartoId {
    final $$RepartosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableOrderingComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductosTableOrderingComposer get productoId {
    final $$ProductosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productoId,
      referencedTable: $db.productos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductosTableOrderingComposer(
            $db: $db,
            $table: $db.productos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntregasTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntregasTable> {
  $$EntregasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get semana =>
      $composableBuilder(column: $table.semana, builder: (column) => column);

  GeneratedColumn<int> get diaSemana =>
      $composableBuilder(column: $table.diaSemana, builder: (column) => column);

  GeneratedColumn<int> get entregado =>
      $composableBuilder(column: $table.entregado, builder: (column) => column);

  GeneratedColumn<int> get devuelto =>
      $composableBuilder(column: $table.devuelto, builder: (column) => column);

  GeneratedColumn<double> get precioUnitario => $composableBuilder(
    column: $table.precioUnitario,
    builder: (column) => column,
  );

  $$ClientesTableAnnotationComposer get clienteId {
    final $$ClientesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clienteId,
      referencedTable: $db.clientes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientesTableAnnotationComposer(
            $db: $db,
            $table: $db.clientes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepartosTableAnnotationComposer get repartoId {
    final $$RepartosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableAnnotationComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductosTableAnnotationComposer get productoId {
    final $$ProductosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productoId,
      referencedTable: $db.productos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductosTableAnnotationComposer(
            $db: $db,
            $table: $db.productos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntregasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntregasTable,
          Entrega,
          $$EntregasTableFilterComposer,
          $$EntregasTableOrderingComposer,
          $$EntregasTableAnnotationComposer,
          $$EntregasTableCreateCompanionBuilder,
          $$EntregasTableUpdateCompanionBuilder,
          (Entrega, $$EntregasTableReferences),
          Entrega,
          PrefetchHooks Function({
            bool clienteId,
            bool repartoId,
            bool productoId,
          })
        > {
  $$EntregasTableTableManager(_$AppDatabase db, $EntregasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntregasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntregasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntregasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> clienteId = const Value.absent(),
                Value<int> repartoId = const Value.absent(),
                Value<int> productoId = const Value.absent(),
                Value<String> semana = const Value.absent(),
                Value<int> diaSemana = const Value.absent(),
                Value<int> entregado = const Value.absent(),
                Value<int> devuelto = const Value.absent(),
                Value<double> precioUnitario = const Value.absent(),
              }) => EntregasCompanion(
                id: id,
                clienteId: clienteId,
                repartoId: repartoId,
                productoId: productoId,
                semana: semana,
                diaSemana: diaSemana,
                entregado: entregado,
                devuelto: devuelto,
                precioUnitario: precioUnitario,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int clienteId,
                required int repartoId,
                required int productoId,
                required String semana,
                required int diaSemana,
                Value<int> entregado = const Value.absent(),
                Value<int> devuelto = const Value.absent(),
                Value<double> precioUnitario = const Value.absent(),
              }) => EntregasCompanion.insert(
                id: id,
                clienteId: clienteId,
                repartoId: repartoId,
                productoId: productoId,
                semana: semana,
                diaSemana: diaSemana,
                entregado: entregado,
                devuelto: devuelto,
                precioUnitario: precioUnitario,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EntregasTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({clienteId = false, repartoId = false, productoId = false}) {
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
                        if (clienteId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.clienteId,
                                    referencedTable: $$EntregasTableReferences
                                        ._clienteIdTable(db),
                                    referencedColumn: $$EntregasTableReferences
                                        ._clienteIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (repartoId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.repartoId,
                                    referencedTable: $$EntregasTableReferences
                                        ._repartoIdTable(db),
                                    referencedColumn: $$EntregasTableReferences
                                        ._repartoIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (productoId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.productoId,
                                    referencedTable: $$EntregasTableReferences
                                        ._productoIdTable(db),
                                    referencedColumn: $$EntregasTableReferences
                                        ._productoIdTable(db)
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

typedef $$EntregasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntregasTable,
      Entrega,
      $$EntregasTableFilterComposer,
      $$EntregasTableOrderingComposer,
      $$EntregasTableAnnotationComposer,
      $$EntregasTableCreateCompanionBuilder,
      $$EntregasTableUpdateCompanionBuilder,
      (Entrega, $$EntregasTableReferences),
      Entrega,
      PrefetchHooks Function({bool clienteId, bool repartoId, bool productoId})
    >;
typedef $$PagosTableCreateCompanionBuilder =
    PagosCompanion Function({
      Value<int> id,
      required int clienteId,
      required int repartoId,
      required String semana,
      required int diaSemana,
      required String metodoPago,
      Value<double> monto,
    });
typedef $$PagosTableUpdateCompanionBuilder =
    PagosCompanion Function({
      Value<int> id,
      Value<int> clienteId,
      Value<int> repartoId,
      Value<String> semana,
      Value<int> diaSemana,
      Value<String> metodoPago,
      Value<double> monto,
    });

final class $$PagosTableReferences
    extends BaseReferences<_$AppDatabase, $PagosTable, Pago> {
  $$PagosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ClientesTable _clienteIdTable(_$AppDatabase db) => db.clientes
      .createAlias($_aliasNameGenerator(db.pagos.clienteId, db.clientes.id));

  $$ClientesTableProcessedTableManager get clienteId {
    final $_column = $_itemColumn<int>('cliente_id')!;

    final manager = $$ClientesTableTableManager(
      $_db,
      $_db.clientes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_clienteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RepartosTable _repartoIdTable(_$AppDatabase db) => db.repartos
      .createAlias($_aliasNameGenerator(db.pagos.repartoId, db.repartos.id));

  $$RepartosTableProcessedTableManager get repartoId {
    final $_column = $_itemColumn<int>('reparto_id')!;

    final manager = $$RepartosTableTableManager(
      $_db,
      $_db.repartos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_repartoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PagosTableFilterComposer extends Composer<_$AppDatabase, $PagosTable> {
  $$PagosTableFilterComposer({
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

  ColumnFilters<String> get semana => $composableBuilder(
    column: $table.semana,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diaSemana => $composableBuilder(
    column: $table.diaSemana,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metodoPago => $composableBuilder(
    column: $table.metodoPago,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get monto => $composableBuilder(
    column: $table.monto,
    builder: (column) => ColumnFilters(column),
  );

  $$ClientesTableFilterComposer get clienteId {
    final $$ClientesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clienteId,
      referencedTable: $db.clientes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientesTableFilterComposer(
            $db: $db,
            $table: $db.clientes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepartosTableFilterComposer get repartoId {
    final $$RepartosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableFilterComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PagosTableOrderingComposer
    extends Composer<_$AppDatabase, $PagosTable> {
  $$PagosTableOrderingComposer({
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

  ColumnOrderings<String> get semana => $composableBuilder(
    column: $table.semana,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diaSemana => $composableBuilder(
    column: $table.diaSemana,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metodoPago => $composableBuilder(
    column: $table.metodoPago,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get monto => $composableBuilder(
    column: $table.monto,
    builder: (column) => ColumnOrderings(column),
  );

  $$ClientesTableOrderingComposer get clienteId {
    final $$ClientesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clienteId,
      referencedTable: $db.clientes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientesTableOrderingComposer(
            $db: $db,
            $table: $db.clientes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepartosTableOrderingComposer get repartoId {
    final $$RepartosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableOrderingComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PagosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PagosTable> {
  $$PagosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get semana =>
      $composableBuilder(column: $table.semana, builder: (column) => column);

  GeneratedColumn<int> get diaSemana =>
      $composableBuilder(column: $table.diaSemana, builder: (column) => column);

  GeneratedColumn<String> get metodoPago => $composableBuilder(
    column: $table.metodoPago,
    builder: (column) => column,
  );

  GeneratedColumn<double> get monto =>
      $composableBuilder(column: $table.monto, builder: (column) => column);

  $$ClientesTableAnnotationComposer get clienteId {
    final $$ClientesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clienteId,
      referencedTable: $db.clientes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientesTableAnnotationComposer(
            $db: $db,
            $table: $db.clientes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepartosTableAnnotationComposer get repartoId {
    final $$RepartosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableAnnotationComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PagosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PagosTable,
          Pago,
          $$PagosTableFilterComposer,
          $$PagosTableOrderingComposer,
          $$PagosTableAnnotationComposer,
          $$PagosTableCreateCompanionBuilder,
          $$PagosTableUpdateCompanionBuilder,
          (Pago, $$PagosTableReferences),
          Pago,
          PrefetchHooks Function({bool clienteId, bool repartoId})
        > {
  $$PagosTableTableManager(_$AppDatabase db, $PagosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PagosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PagosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PagosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> clienteId = const Value.absent(),
                Value<int> repartoId = const Value.absent(),
                Value<String> semana = const Value.absent(),
                Value<int> diaSemana = const Value.absent(),
                Value<String> metodoPago = const Value.absent(),
                Value<double> monto = const Value.absent(),
              }) => PagosCompanion(
                id: id,
                clienteId: clienteId,
                repartoId: repartoId,
                semana: semana,
                diaSemana: diaSemana,
                metodoPago: metodoPago,
                monto: monto,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int clienteId,
                required int repartoId,
                required String semana,
                required int diaSemana,
                required String metodoPago,
                Value<double> monto = const Value.absent(),
              }) => PagosCompanion.insert(
                id: id,
                clienteId: clienteId,
                repartoId: repartoId,
                semana: semana,
                diaSemana: diaSemana,
                metodoPago: metodoPago,
                monto: monto,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PagosTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({clienteId = false, repartoId = false}) {
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
                    if (clienteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.clienteId,
                                referencedTable: $$PagosTableReferences
                                    ._clienteIdTable(db),
                                referencedColumn: $$PagosTableReferences
                                    ._clienteIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (repartoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.repartoId,
                                referencedTable: $$PagosTableReferences
                                    ._repartoIdTable(db),
                                referencedColumn: $$PagosTableReferences
                                    ._repartoIdTable(db)
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

typedef $$PagosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PagosTable,
      Pago,
      $$PagosTableFilterComposer,
      $$PagosTableOrderingComposer,
      $$PagosTableAnnotationComposer,
      $$PagosTableCreateCompanionBuilder,
      $$PagosTableUpdateCompanionBuilder,
      (Pago, $$PagosTableReferences),
      Pago,
      PrefetchHooks Function({bool clienteId, bool repartoId})
    >;
typedef $$ResumenesTableCreateCompanionBuilder =
    ResumenesCompanion Function({
      Value<int> id,
      required int repartoId,
      required String fecha,
      required String semana,
      required int diaSemana,
      required int duracionSegundos,
      Value<double> efectivo,
      Value<double> transferencia,
      Value<double> cuentaCorriente,
      Value<double> gastos,
      Value<double> sueldoBruto,
      Value<double> sueldoNeto,
      Value<String> createdAt,
      Value<String> productosJson,
      Value<String> gastosJson,
    });
typedef $$ResumenesTableUpdateCompanionBuilder =
    ResumenesCompanion Function({
      Value<int> id,
      Value<int> repartoId,
      Value<String> fecha,
      Value<String> semana,
      Value<int> diaSemana,
      Value<int> duracionSegundos,
      Value<double> efectivo,
      Value<double> transferencia,
      Value<double> cuentaCorriente,
      Value<double> gastos,
      Value<double> sueldoBruto,
      Value<double> sueldoNeto,
      Value<String> createdAt,
      Value<String> productosJson,
      Value<String> gastosJson,
    });

final class $$ResumenesTableReferences
    extends BaseReferences<_$AppDatabase, $ResumenesTable, Resumene> {
  $$ResumenesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RepartosTable _repartoIdTable(_$AppDatabase db) =>
      db.repartos.createAlias(
        $_aliasNameGenerator(db.resumenes.repartoId, db.repartos.id),
      );

  $$RepartosTableProcessedTableManager get repartoId {
    final $_column = $_itemColumn<int>('reparto_id')!;

    final manager = $$RepartosTableTableManager(
      $_db,
      $_db.repartos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_repartoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ResumenesTableFilterComposer
    extends Composer<_$AppDatabase, $ResumenesTable> {
  $$ResumenesTableFilterComposer({
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

  ColumnFilters<String> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semana => $composableBuilder(
    column: $table.semana,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diaSemana => $composableBuilder(
    column: $table.diaSemana,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duracionSegundos => $composableBuilder(
    column: $table.duracionSegundos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get efectivo => $composableBuilder(
    column: $table.efectivo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get transferencia => $composableBuilder(
    column: $table.transferencia,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cuentaCorriente => $composableBuilder(
    column: $table.cuentaCorriente,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gastos => $composableBuilder(
    column: $table.gastos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sueldoBruto => $composableBuilder(
    column: $table.sueldoBruto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sueldoNeto => $composableBuilder(
    column: $table.sueldoNeto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productosJson => $composableBuilder(
    column: $table.productosJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gastosJson => $composableBuilder(
    column: $table.gastosJson,
    builder: (column) => ColumnFilters(column),
  );

  $$RepartosTableFilterComposer get repartoId {
    final $$RepartosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableFilterComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ResumenesTableOrderingComposer
    extends Composer<_$AppDatabase, $ResumenesTable> {
  $$ResumenesTableOrderingComposer({
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

  ColumnOrderings<String> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semana => $composableBuilder(
    column: $table.semana,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diaSemana => $composableBuilder(
    column: $table.diaSemana,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duracionSegundos => $composableBuilder(
    column: $table.duracionSegundos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get efectivo => $composableBuilder(
    column: $table.efectivo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get transferencia => $composableBuilder(
    column: $table.transferencia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cuentaCorriente => $composableBuilder(
    column: $table.cuentaCorriente,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gastos => $composableBuilder(
    column: $table.gastos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sueldoBruto => $composableBuilder(
    column: $table.sueldoBruto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sueldoNeto => $composableBuilder(
    column: $table.sueldoNeto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productosJson => $composableBuilder(
    column: $table.productosJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gastosJson => $composableBuilder(
    column: $table.gastosJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$RepartosTableOrderingComposer get repartoId {
    final $$RepartosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableOrderingComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ResumenesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ResumenesTable> {
  $$ResumenesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fecha =>
      $composableBuilder(column: $table.fecha, builder: (column) => column);

  GeneratedColumn<String> get semana =>
      $composableBuilder(column: $table.semana, builder: (column) => column);

  GeneratedColumn<int> get diaSemana =>
      $composableBuilder(column: $table.diaSemana, builder: (column) => column);

  GeneratedColumn<int> get duracionSegundos => $composableBuilder(
    column: $table.duracionSegundos,
    builder: (column) => column,
  );

  GeneratedColumn<double> get efectivo =>
      $composableBuilder(column: $table.efectivo, builder: (column) => column);

  GeneratedColumn<double> get transferencia => $composableBuilder(
    column: $table.transferencia,
    builder: (column) => column,
  );

  GeneratedColumn<double> get cuentaCorriente => $composableBuilder(
    column: $table.cuentaCorriente,
    builder: (column) => column,
  );

  GeneratedColumn<double> get gastos =>
      $composableBuilder(column: $table.gastos, builder: (column) => column);

  GeneratedColumn<double> get sueldoBruto => $composableBuilder(
    column: $table.sueldoBruto,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sueldoNeto => $composableBuilder(
    column: $table.sueldoNeto,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get productosJson => $composableBuilder(
    column: $table.productosJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gastosJson => $composableBuilder(
    column: $table.gastosJson,
    builder: (column) => column,
  );

  $$RepartosTableAnnotationComposer get repartoId {
    final $$RepartosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableAnnotationComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ResumenesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ResumenesTable,
          Resumene,
          $$ResumenesTableFilterComposer,
          $$ResumenesTableOrderingComposer,
          $$ResumenesTableAnnotationComposer,
          $$ResumenesTableCreateCompanionBuilder,
          $$ResumenesTableUpdateCompanionBuilder,
          (Resumene, $$ResumenesTableReferences),
          Resumene,
          PrefetchHooks Function({bool repartoId})
        > {
  $$ResumenesTableTableManager(_$AppDatabase db, $ResumenesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResumenesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResumenesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResumenesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> repartoId = const Value.absent(),
                Value<String> fecha = const Value.absent(),
                Value<String> semana = const Value.absent(),
                Value<int> diaSemana = const Value.absent(),
                Value<int> duracionSegundos = const Value.absent(),
                Value<double> efectivo = const Value.absent(),
                Value<double> transferencia = const Value.absent(),
                Value<double> cuentaCorriente = const Value.absent(),
                Value<double> gastos = const Value.absent(),
                Value<double> sueldoBruto = const Value.absent(),
                Value<double> sueldoNeto = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> productosJson = const Value.absent(),
                Value<String> gastosJson = const Value.absent(),
              }) => ResumenesCompanion(
                id: id,
                repartoId: repartoId,
                fecha: fecha,
                semana: semana,
                diaSemana: diaSemana,
                duracionSegundos: duracionSegundos,
                efectivo: efectivo,
                transferencia: transferencia,
                cuentaCorriente: cuentaCorriente,
                gastos: gastos,
                sueldoBruto: sueldoBruto,
                sueldoNeto: sueldoNeto,
                createdAt: createdAt,
                productosJson: productosJson,
                gastosJson: gastosJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int repartoId,
                required String fecha,
                required String semana,
                required int diaSemana,
                required int duracionSegundos,
                Value<double> efectivo = const Value.absent(),
                Value<double> transferencia = const Value.absent(),
                Value<double> cuentaCorriente = const Value.absent(),
                Value<double> gastos = const Value.absent(),
                Value<double> sueldoBruto = const Value.absent(),
                Value<double> sueldoNeto = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> productosJson = const Value.absent(),
                Value<String> gastosJson = const Value.absent(),
              }) => ResumenesCompanion.insert(
                id: id,
                repartoId: repartoId,
                fecha: fecha,
                semana: semana,
                diaSemana: diaSemana,
                duracionSegundos: duracionSegundos,
                efectivo: efectivo,
                transferencia: transferencia,
                cuentaCorriente: cuentaCorriente,
                gastos: gastos,
                sueldoBruto: sueldoBruto,
                sueldoNeto: sueldoNeto,
                createdAt: createdAt,
                productosJson: productosJson,
                gastosJson: gastosJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ResumenesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({repartoId = false}) {
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
                    if (repartoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.repartoId,
                                referencedTable: $$ResumenesTableReferences
                                    ._repartoIdTable(db),
                                referencedColumn: $$ResumenesTableReferences
                                    ._repartoIdTable(db)
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

typedef $$ResumenesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ResumenesTable,
      Resumene,
      $$ResumenesTableFilterComposer,
      $$ResumenesTableOrderingComposer,
      $$ResumenesTableAnnotationComposer,
      $$ResumenesTableCreateCompanionBuilder,
      $$ResumenesTableUpdateCompanionBuilder,
      (Resumene, $$ResumenesTableReferences),
      Resumene,
      PrefetchHooks Function({bool repartoId})
    >;
typedef $$UserSettingsTableCreateCompanionBuilder =
    UserSettingsCompanion Function({
      Value<int> id,
      Value<String> workDays,
      Value<bool> qrEnabled,
      Value<bool> mapEnabled,
      Value<bool> deudaNotifEnabled,
      Value<int> deudaNotifWeeks,
      Value<bool> inactiveNotifEnabled,
      Value<int> inactiveNotifWeeks,
      Value<bool> stockNotifMasterEnabled,
      Value<int?> lastRepartoId,
      Value<String> afipToken,
      Value<String> afipCuit,
      Value<int> afipPtoVta,
      Value<String> afipRazonSocial,
      Value<String> afipDomicilio,
      Value<String> afipCondicionIva,
      Value<bool> afipProduction,
      Value<String> mpAccessToken,
    });
typedef $$UserSettingsTableUpdateCompanionBuilder =
    UserSettingsCompanion Function({
      Value<int> id,
      Value<String> workDays,
      Value<bool> qrEnabled,
      Value<bool> mapEnabled,
      Value<bool> deudaNotifEnabled,
      Value<int> deudaNotifWeeks,
      Value<bool> inactiveNotifEnabled,
      Value<int> inactiveNotifWeeks,
      Value<bool> stockNotifMasterEnabled,
      Value<int?> lastRepartoId,
      Value<String> afipToken,
      Value<String> afipCuit,
      Value<int> afipPtoVta,
      Value<String> afipRazonSocial,
      Value<String> afipDomicilio,
      Value<String> afipCondicionIva,
      Value<bool> afipProduction,
      Value<String> mpAccessToken,
    });

class $$UserSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableFilterComposer({
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

  ColumnFilters<String> get workDays => $composableBuilder(
    column: $table.workDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get qrEnabled => $composableBuilder(
    column: $table.qrEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get mapEnabled => $composableBuilder(
    column: $table.mapEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deudaNotifEnabled => $composableBuilder(
    column: $table.deudaNotifEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deudaNotifWeeks => $composableBuilder(
    column: $table.deudaNotifWeeks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get inactiveNotifEnabled => $composableBuilder(
    column: $table.inactiveNotifEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inactiveNotifWeeks => $composableBuilder(
    column: $table.inactiveNotifWeeks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get stockNotifMasterEnabled => $composableBuilder(
    column: $table.stockNotifMasterEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastRepartoId => $composableBuilder(
    column: $table.lastRepartoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get afipToken => $composableBuilder(
    column: $table.afipToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get afipCuit => $composableBuilder(
    column: $table.afipCuit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get afipPtoVta => $composableBuilder(
    column: $table.afipPtoVta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get afipRazonSocial => $composableBuilder(
    column: $table.afipRazonSocial,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get afipDomicilio => $composableBuilder(
    column: $table.afipDomicilio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get afipCondicionIva => $composableBuilder(
    column: $table.afipCondicionIva,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get afipProduction => $composableBuilder(
    column: $table.afipProduction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mpAccessToken => $composableBuilder(
    column: $table.mpAccessToken,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableOrderingComposer({
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

  ColumnOrderings<String> get workDays => $composableBuilder(
    column: $table.workDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get qrEnabled => $composableBuilder(
    column: $table.qrEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get mapEnabled => $composableBuilder(
    column: $table.mapEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deudaNotifEnabled => $composableBuilder(
    column: $table.deudaNotifEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deudaNotifWeeks => $composableBuilder(
    column: $table.deudaNotifWeeks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get inactiveNotifEnabled => $composableBuilder(
    column: $table.inactiveNotifEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inactiveNotifWeeks => $composableBuilder(
    column: $table.inactiveNotifWeeks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get stockNotifMasterEnabled => $composableBuilder(
    column: $table.stockNotifMasterEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastRepartoId => $composableBuilder(
    column: $table.lastRepartoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get afipToken => $composableBuilder(
    column: $table.afipToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get afipCuit => $composableBuilder(
    column: $table.afipCuit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get afipPtoVta => $composableBuilder(
    column: $table.afipPtoVta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get afipRazonSocial => $composableBuilder(
    column: $table.afipRazonSocial,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get afipDomicilio => $composableBuilder(
    column: $table.afipDomicilio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get afipCondicionIva => $composableBuilder(
    column: $table.afipCondicionIva,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get afipProduction => $composableBuilder(
    column: $table.afipProduction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mpAccessToken => $composableBuilder(
    column: $table.mpAccessToken,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workDays =>
      $composableBuilder(column: $table.workDays, builder: (column) => column);

  GeneratedColumn<bool> get qrEnabled =>
      $composableBuilder(column: $table.qrEnabled, builder: (column) => column);

  GeneratedColumn<bool> get mapEnabled => $composableBuilder(
    column: $table.mapEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deudaNotifEnabled => $composableBuilder(
    column: $table.deudaNotifEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deudaNotifWeeks => $composableBuilder(
    column: $table.deudaNotifWeeks,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get inactiveNotifEnabled => $composableBuilder(
    column: $table.inactiveNotifEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get inactiveNotifWeeks => $composableBuilder(
    column: $table.inactiveNotifWeeks,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get stockNotifMasterEnabled => $composableBuilder(
    column: $table.stockNotifMasterEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastRepartoId => $composableBuilder(
    column: $table.lastRepartoId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get afipToken =>
      $composableBuilder(column: $table.afipToken, builder: (column) => column);

  GeneratedColumn<String> get afipCuit =>
      $composableBuilder(column: $table.afipCuit, builder: (column) => column);

  GeneratedColumn<int> get afipPtoVta => $composableBuilder(
    column: $table.afipPtoVta,
    builder: (column) => column,
  );

  GeneratedColumn<String> get afipRazonSocial => $composableBuilder(
    column: $table.afipRazonSocial,
    builder: (column) => column,
  );

  GeneratedColumn<String> get afipDomicilio => $composableBuilder(
    column: $table.afipDomicilio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get afipCondicionIva => $composableBuilder(
    column: $table.afipCondicionIva,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get afipProduction => $composableBuilder(
    column: $table.afipProduction,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mpAccessToken => $composableBuilder(
    column: $table.mpAccessToken,
    builder: (column) => column,
  );
}

class $$UserSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserSettingsTable,
          UserSetting,
          $$UserSettingsTableFilterComposer,
          $$UserSettingsTableOrderingComposer,
          $$UserSettingsTableAnnotationComposer,
          $$UserSettingsTableCreateCompanionBuilder,
          $$UserSettingsTableUpdateCompanionBuilder,
          (
            UserSetting,
            BaseReferences<_$AppDatabase, $UserSettingsTable, UserSetting>,
          ),
          UserSetting,
          PrefetchHooks Function()
        > {
  $$UserSettingsTableTableManager(_$AppDatabase db, $UserSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> workDays = const Value.absent(),
                Value<bool> qrEnabled = const Value.absent(),
                Value<bool> mapEnabled = const Value.absent(),
                Value<bool> deudaNotifEnabled = const Value.absent(),
                Value<int> deudaNotifWeeks = const Value.absent(),
                Value<bool> inactiveNotifEnabled = const Value.absent(),
                Value<int> inactiveNotifWeeks = const Value.absent(),
                Value<bool> stockNotifMasterEnabled = const Value.absent(),
                Value<int?> lastRepartoId = const Value.absent(),
                Value<String> afipToken = const Value.absent(),
                Value<String> afipCuit = const Value.absent(),
                Value<int> afipPtoVta = const Value.absent(),
                Value<String> afipRazonSocial = const Value.absent(),
                Value<String> afipDomicilio = const Value.absent(),
                Value<String> afipCondicionIva = const Value.absent(),
                Value<bool> afipProduction = const Value.absent(),
                Value<String> mpAccessToken = const Value.absent(),
              }) => UserSettingsCompanion(
                id: id,
                workDays: workDays,
                qrEnabled: qrEnabled,
                mapEnabled: mapEnabled,
                deudaNotifEnabled: deudaNotifEnabled,
                deudaNotifWeeks: deudaNotifWeeks,
                inactiveNotifEnabled: inactiveNotifEnabled,
                inactiveNotifWeeks: inactiveNotifWeeks,
                stockNotifMasterEnabled: stockNotifMasterEnabled,
                lastRepartoId: lastRepartoId,
                afipToken: afipToken,
                afipCuit: afipCuit,
                afipPtoVta: afipPtoVta,
                afipRazonSocial: afipRazonSocial,
                afipDomicilio: afipDomicilio,
                afipCondicionIva: afipCondicionIva,
                afipProduction: afipProduction,
                mpAccessToken: mpAccessToken,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> workDays = const Value.absent(),
                Value<bool> qrEnabled = const Value.absent(),
                Value<bool> mapEnabled = const Value.absent(),
                Value<bool> deudaNotifEnabled = const Value.absent(),
                Value<int> deudaNotifWeeks = const Value.absent(),
                Value<bool> inactiveNotifEnabled = const Value.absent(),
                Value<int> inactiveNotifWeeks = const Value.absent(),
                Value<bool> stockNotifMasterEnabled = const Value.absent(),
                Value<int?> lastRepartoId = const Value.absent(),
                Value<String> afipToken = const Value.absent(),
                Value<String> afipCuit = const Value.absent(),
                Value<int> afipPtoVta = const Value.absent(),
                Value<String> afipRazonSocial = const Value.absent(),
                Value<String> afipDomicilio = const Value.absent(),
                Value<String> afipCondicionIva = const Value.absent(),
                Value<bool> afipProduction = const Value.absent(),
                Value<String> mpAccessToken = const Value.absent(),
              }) => UserSettingsCompanion.insert(
                id: id,
                workDays: workDays,
                qrEnabled: qrEnabled,
                mapEnabled: mapEnabled,
                deudaNotifEnabled: deudaNotifEnabled,
                deudaNotifWeeks: deudaNotifWeeks,
                inactiveNotifEnabled: inactiveNotifEnabled,
                inactiveNotifWeeks: inactiveNotifWeeks,
                stockNotifMasterEnabled: stockNotifMasterEnabled,
                lastRepartoId: lastRepartoId,
                afipToken: afipToken,
                afipCuit: afipCuit,
                afipPtoVta: afipPtoVta,
                afipRazonSocial: afipRazonSocial,
                afipDomicilio: afipDomicilio,
                afipCondicionIva: afipCondicionIva,
                afipProduction: afipProduction,
                mpAccessToken: mpAccessToken,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserSettingsTable,
      UserSetting,
      $$UserSettingsTableFilterComposer,
      $$UserSettingsTableOrderingComposer,
      $$UserSettingsTableAnnotationComposer,
      $$UserSettingsTableCreateCompanionBuilder,
      $$UserSettingsTableUpdateCompanionBuilder,
      (
        UserSetting,
        BaseReferences<_$AppDatabase, $UserSettingsTable, UserSetting>,
      ),
      UserSetting,
      PrefetchHooks Function()
    >;
typedef $$EtiquetaColorsTableCreateCompanionBuilder =
    EtiquetaColorsCompanion Function({
      Value<int> id,
      required int repartoId,
      required String nombre,
      required String colorHex,
    });
typedef $$EtiquetaColorsTableUpdateCompanionBuilder =
    EtiquetaColorsCompanion Function({
      Value<int> id,
      Value<int> repartoId,
      Value<String> nombre,
      Value<String> colorHex,
    });

final class $$EtiquetaColorsTableReferences
    extends BaseReferences<_$AppDatabase, $EtiquetaColorsTable, EtiquetaColor> {
  $$EtiquetaColorsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RepartosTable _repartoIdTable(_$AppDatabase db) =>
      db.repartos.createAlias(
        $_aliasNameGenerator(db.etiquetaColors.repartoId, db.repartos.id),
      );

  $$RepartosTableProcessedTableManager get repartoId {
    final $_column = $_itemColumn<int>('reparto_id')!;

    final manager = $$RepartosTableTableManager(
      $_db,
      $_db.repartos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_repartoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EtiquetaColorsTableFilterComposer
    extends Composer<_$AppDatabase, $EtiquetaColorsTable> {
  $$EtiquetaColorsTableFilterComposer({
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

  ColumnFilters<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  $$RepartosTableFilterComposer get repartoId {
    final $$RepartosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableFilterComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EtiquetaColorsTableOrderingComposer
    extends Composer<_$AppDatabase, $EtiquetaColorsTable> {
  $$EtiquetaColorsTableOrderingComposer({
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

  ColumnOrderings<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  $$RepartosTableOrderingComposer get repartoId {
    final $$RepartosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableOrderingComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EtiquetaColorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EtiquetaColorsTable> {
  $$EtiquetaColorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  $$RepartosTableAnnotationComposer get repartoId {
    final $$RepartosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableAnnotationComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EtiquetaColorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EtiquetaColorsTable,
          EtiquetaColor,
          $$EtiquetaColorsTableFilterComposer,
          $$EtiquetaColorsTableOrderingComposer,
          $$EtiquetaColorsTableAnnotationComposer,
          $$EtiquetaColorsTableCreateCompanionBuilder,
          $$EtiquetaColorsTableUpdateCompanionBuilder,
          (EtiquetaColor, $$EtiquetaColorsTableReferences),
          EtiquetaColor,
          PrefetchHooks Function({bool repartoId})
        > {
  $$EtiquetaColorsTableTableManager(
    _$AppDatabase db,
    $EtiquetaColorsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EtiquetaColorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EtiquetaColorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EtiquetaColorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> repartoId = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
              }) => EtiquetaColorsCompanion(
                id: id,
                repartoId: repartoId,
                nombre: nombre,
                colorHex: colorHex,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int repartoId,
                required String nombre,
                required String colorHex,
              }) => EtiquetaColorsCompanion.insert(
                id: id,
                repartoId: repartoId,
                nombre: nombre,
                colorHex: colorHex,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EtiquetaColorsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({repartoId = false}) {
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
                    if (repartoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.repartoId,
                                referencedTable: $$EtiquetaColorsTableReferences
                                    ._repartoIdTable(db),
                                referencedColumn:
                                    $$EtiquetaColorsTableReferences
                                        ._repartoIdTable(db)
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

typedef $$EtiquetaColorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EtiquetaColorsTable,
      EtiquetaColor,
      $$EtiquetaColorsTableFilterComposer,
      $$EtiquetaColorsTableOrderingComposer,
      $$EtiquetaColorsTableAnnotationComposer,
      $$EtiquetaColorsTableCreateCompanionBuilder,
      $$EtiquetaColorsTableUpdateCompanionBuilder,
      (EtiquetaColor, $$EtiquetaColorsTableReferences),
      EtiquetaColor,
      PrefetchHooks Function({bool repartoId})
    >;
typedef $$AppNotificationsTableCreateCompanionBuilder =
    AppNotificationsCompanion Function({
      Value<int> id,
      required String type,
      required String title,
      required String body,
      Value<int?> clienteId,
      required String createdAt,
      Value<bool> read,
    });
typedef $$AppNotificationsTableUpdateCompanionBuilder =
    AppNotificationsCompanion Function({
      Value<int> id,
      Value<String> type,
      Value<String> title,
      Value<String> body,
      Value<int?> clienteId,
      Value<String> createdAt,
      Value<bool> read,
    });

class $$AppNotificationsTableFilterComposer
    extends Composer<_$AppDatabase, $AppNotificationsTable> {
  $$AppNotificationsTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clienteId => $composableBuilder(
    column: $table.clienteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get read => $composableBuilder(
    column: $table.read,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppNotificationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppNotificationsTable> {
  $$AppNotificationsTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clienteId => $composableBuilder(
    column: $table.clienteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get read => $composableBuilder(
    column: $table.read,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppNotificationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppNotificationsTable> {
  $$AppNotificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get clienteId =>
      $composableBuilder(column: $table.clienteId, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get read =>
      $composableBuilder(column: $table.read, builder: (column) => column);
}

class $$AppNotificationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppNotificationsTable,
          AppNotification,
          $$AppNotificationsTableFilterComposer,
          $$AppNotificationsTableOrderingComposer,
          $$AppNotificationsTableAnnotationComposer,
          $$AppNotificationsTableCreateCompanionBuilder,
          $$AppNotificationsTableUpdateCompanionBuilder,
          (
            AppNotification,
            BaseReferences<
              _$AppDatabase,
              $AppNotificationsTable,
              AppNotification
            >,
          ),
          AppNotification,
          PrefetchHooks Function()
        > {
  $$AppNotificationsTableTableManager(
    _$AppDatabase db,
    $AppNotificationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppNotificationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppNotificationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppNotificationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int?> clienteId = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<bool> read = const Value.absent(),
              }) => AppNotificationsCompanion(
                id: id,
                type: type,
                title: title,
                body: body,
                clienteId: clienteId,
                createdAt: createdAt,
                read: read,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String type,
                required String title,
                required String body,
                Value<int?> clienteId = const Value.absent(),
                required String createdAt,
                Value<bool> read = const Value.absent(),
              }) => AppNotificationsCompanion.insert(
                id: id,
                type: type,
                title: title,
                body: body,
                clienteId: clienteId,
                createdAt: createdAt,
                read: read,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppNotificationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppNotificationsTable,
      AppNotification,
      $$AppNotificationsTableFilterComposer,
      $$AppNotificationsTableOrderingComposer,
      $$AppNotificationsTableAnnotationComposer,
      $$AppNotificationsTableCreateCompanionBuilder,
      $$AppNotificationsTableUpdateCompanionBuilder,
      (
        AppNotification,
        BaseReferences<_$AppDatabase, $AppNotificationsTable, AppNotification>,
      ),
      AppNotification,
      PrefetchHooks Function()
    >;
typedef $$NotifDismissalsTableCreateCompanionBuilder =
    NotifDismissalsCompanion Function({
      Value<int> id,
      required int clienteId,
      required String type,
    });
typedef $$NotifDismissalsTableUpdateCompanionBuilder =
    NotifDismissalsCompanion Function({
      Value<int> id,
      Value<int> clienteId,
      Value<String> type,
    });

class $$NotifDismissalsTableFilterComposer
    extends Composer<_$AppDatabase, $NotifDismissalsTable> {
  $$NotifDismissalsTableFilterComposer({
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

  ColumnFilters<int> get clienteId => $composableBuilder(
    column: $table.clienteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotifDismissalsTableOrderingComposer
    extends Composer<_$AppDatabase, $NotifDismissalsTable> {
  $$NotifDismissalsTableOrderingComposer({
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

  ColumnOrderings<int> get clienteId => $composableBuilder(
    column: $table.clienteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotifDismissalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotifDismissalsTable> {
  $$NotifDismissalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get clienteId =>
      $composableBuilder(column: $table.clienteId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);
}

class $$NotifDismissalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotifDismissalsTable,
          NotifDismissal,
          $$NotifDismissalsTableFilterComposer,
          $$NotifDismissalsTableOrderingComposer,
          $$NotifDismissalsTableAnnotationComposer,
          $$NotifDismissalsTableCreateCompanionBuilder,
          $$NotifDismissalsTableUpdateCompanionBuilder,
          (
            NotifDismissal,
            BaseReferences<
              _$AppDatabase,
              $NotifDismissalsTable,
              NotifDismissal
            >,
          ),
          NotifDismissal,
          PrefetchHooks Function()
        > {
  $$NotifDismissalsTableTableManager(
    _$AppDatabase db,
    $NotifDismissalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotifDismissalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotifDismissalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotifDismissalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> clienteId = const Value.absent(),
                Value<String> type = const Value.absent(),
              }) => NotifDismissalsCompanion(
                id: id,
                clienteId: clienteId,
                type: type,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int clienteId,
                required String type,
              }) => NotifDismissalsCompanion.insert(
                id: id,
                clienteId: clienteId,
                type: type,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotifDismissalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotifDismissalsTable,
      NotifDismissal,
      $$NotifDismissalsTableFilterComposer,
      $$NotifDismissalsTableOrderingComposer,
      $$NotifDismissalsTableAnnotationComposer,
      $$NotifDismissalsTableCreateCompanionBuilder,
      $$NotifDismissalsTableUpdateCompanionBuilder,
      (
        NotifDismissal,
        BaseReferences<_$AppDatabase, $NotifDismissalsTable, NotifDismissal>,
      ),
      NotifDismissal,
      PrefetchHooks Function()
    >;
typedef $$StockNotifSettingsTableCreateCompanionBuilder =
    StockNotifSettingsCompanion Function({
      Value<int> id,
      Value<int?> repartoId,
      required int productoId,
      Value<bool> enabled,
      Value<int> threshold,
    });
typedef $$StockNotifSettingsTableUpdateCompanionBuilder =
    StockNotifSettingsCompanion Function({
      Value<int> id,
      Value<int?> repartoId,
      Value<int> productoId,
      Value<bool> enabled,
      Value<int> threshold,
    });

final class $$StockNotifSettingsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $StockNotifSettingsTable,
          StockNotifSetting
        > {
  $$StockNotifSettingsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProductosTable _productoIdTable(_$AppDatabase db) =>
      db.productos.createAlias(
        $_aliasNameGenerator(db.stockNotifSettings.productoId, db.productos.id),
      );

  $$ProductosTableProcessedTableManager get productoId {
    final $_column = $_itemColumn<int>('producto_id')!;

    final manager = $$ProductosTableTableManager(
      $_db,
      $_db.productos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StockNotifSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $StockNotifSettingsTable> {
  $$StockNotifSettingsTableFilterComposer({
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

  ColumnFilters<int> get repartoId => $composableBuilder(
    column: $table.repartoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get threshold => $composableBuilder(
    column: $table.threshold,
    builder: (column) => ColumnFilters(column),
  );

  $$ProductosTableFilterComposer get productoId {
    final $$ProductosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productoId,
      referencedTable: $db.productos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductosTableFilterComposer(
            $db: $db,
            $table: $db.productos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockNotifSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $StockNotifSettingsTable> {
  $$StockNotifSettingsTableOrderingComposer({
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

  ColumnOrderings<int> get repartoId => $composableBuilder(
    column: $table.repartoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get threshold => $composableBuilder(
    column: $table.threshold,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProductosTableOrderingComposer get productoId {
    final $$ProductosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productoId,
      referencedTable: $db.productos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductosTableOrderingComposer(
            $db: $db,
            $table: $db.productos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockNotifSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockNotifSettingsTable> {
  $$StockNotifSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get repartoId =>
      $composableBuilder(column: $table.repartoId, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get threshold =>
      $composableBuilder(column: $table.threshold, builder: (column) => column);

  $$ProductosTableAnnotationComposer get productoId {
    final $$ProductosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productoId,
      referencedTable: $db.productos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductosTableAnnotationComposer(
            $db: $db,
            $table: $db.productos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockNotifSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StockNotifSettingsTable,
          StockNotifSetting,
          $$StockNotifSettingsTableFilterComposer,
          $$StockNotifSettingsTableOrderingComposer,
          $$StockNotifSettingsTableAnnotationComposer,
          $$StockNotifSettingsTableCreateCompanionBuilder,
          $$StockNotifSettingsTableUpdateCompanionBuilder,
          (StockNotifSetting, $$StockNotifSettingsTableReferences),
          StockNotifSetting,
          PrefetchHooks Function({bool productoId})
        > {
  $$StockNotifSettingsTableTableManager(
    _$AppDatabase db,
    $StockNotifSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockNotifSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockNotifSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockNotifSettingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> repartoId = const Value.absent(),
                Value<int> productoId = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> threshold = const Value.absent(),
              }) => StockNotifSettingsCompanion(
                id: id,
                repartoId: repartoId,
                productoId: productoId,
                enabled: enabled,
                threshold: threshold,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> repartoId = const Value.absent(),
                required int productoId,
                Value<bool> enabled = const Value.absent(),
                Value<int> threshold = const Value.absent(),
              }) => StockNotifSettingsCompanion.insert(
                id: id,
                repartoId: repartoId,
                productoId: productoId,
                enabled: enabled,
                threshold: threshold,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StockNotifSettingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({productoId = false}) {
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
                    if (productoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.productoId,
                                referencedTable:
                                    $$StockNotifSettingsTableReferences
                                        ._productoIdTable(db),
                                referencedColumn:
                                    $$StockNotifSettingsTableReferences
                                        ._productoIdTable(db)
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

typedef $$StockNotifSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StockNotifSettingsTable,
      StockNotifSetting,
      $$StockNotifSettingsTableFilterComposer,
      $$StockNotifSettingsTableOrderingComposer,
      $$StockNotifSettingsTableAnnotationComposer,
      $$StockNotifSettingsTableCreateCompanionBuilder,
      $$StockNotifSettingsTableUpdateCompanionBuilder,
      (StockNotifSetting, $$StockNotifSettingsTableReferences),
      StockNotifSetting,
      PrefetchHooks Function({bool productoId})
    >;
typedef $$FacturasTableCreateCompanionBuilder =
    FacturasCompanion Function({
      Value<int> id,
      required int clienteId,
      required int repartoId,
      Value<int> cbteTipo,
      required int ptoVta,
      required int cbteNro,
      required String fecha,
      required double importeTotal,
      required String cae,
      required String caeFchVto,
      Value<String> itemsJson,
      Value<String> receptorNombre,
      Value<int> receptorDocTipo,
      Value<String> receptorDocNro,
      Value<String> pdfPath,
      Value<String> createdAt,
    });
typedef $$FacturasTableUpdateCompanionBuilder =
    FacturasCompanion Function({
      Value<int> id,
      Value<int> clienteId,
      Value<int> repartoId,
      Value<int> cbteTipo,
      Value<int> ptoVta,
      Value<int> cbteNro,
      Value<String> fecha,
      Value<double> importeTotal,
      Value<String> cae,
      Value<String> caeFchVto,
      Value<String> itemsJson,
      Value<String> receptorNombre,
      Value<int> receptorDocTipo,
      Value<String> receptorDocNro,
      Value<String> pdfPath,
      Value<String> createdAt,
    });

final class $$FacturasTableReferences
    extends BaseReferences<_$AppDatabase, $FacturasTable, Factura> {
  $$FacturasTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ClientesTable _clienteIdTable(_$AppDatabase db) => db.clientes
      .createAlias($_aliasNameGenerator(db.facturas.clienteId, db.clientes.id));

  $$ClientesTableProcessedTableManager get clienteId {
    final $_column = $_itemColumn<int>('cliente_id')!;

    final manager = $$ClientesTableTableManager(
      $_db,
      $_db.clientes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_clienteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RepartosTable _repartoIdTable(_$AppDatabase db) => db.repartos
      .createAlias($_aliasNameGenerator(db.facturas.repartoId, db.repartos.id));

  $$RepartosTableProcessedTableManager get repartoId {
    final $_column = $_itemColumn<int>('reparto_id')!;

    final manager = $$RepartosTableTableManager(
      $_db,
      $_db.repartos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_repartoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FacturasTableFilterComposer
    extends Composer<_$AppDatabase, $FacturasTable> {
  $$FacturasTableFilterComposer({
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

  ColumnFilters<int> get cbteTipo => $composableBuilder(
    column: $table.cbteTipo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ptoVta => $composableBuilder(
    column: $table.ptoVta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cbteNro => $composableBuilder(
    column: $table.cbteNro,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get importeTotal => $composableBuilder(
    column: $table.importeTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cae => $composableBuilder(
    column: $table.cae,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caeFchVto => $composableBuilder(
    column: $table.caeFchVto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receptorNombre => $composableBuilder(
    column: $table.receptorNombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get receptorDocTipo => $composableBuilder(
    column: $table.receptorDocTipo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receptorDocNro => $composableBuilder(
    column: $table.receptorDocNro,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfPath => $composableBuilder(
    column: $table.pdfPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ClientesTableFilterComposer get clienteId {
    final $$ClientesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clienteId,
      referencedTable: $db.clientes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientesTableFilterComposer(
            $db: $db,
            $table: $db.clientes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepartosTableFilterComposer get repartoId {
    final $$RepartosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableFilterComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FacturasTableOrderingComposer
    extends Composer<_$AppDatabase, $FacturasTable> {
  $$FacturasTableOrderingComposer({
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

  ColumnOrderings<int> get cbteTipo => $composableBuilder(
    column: $table.cbteTipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ptoVta => $composableBuilder(
    column: $table.ptoVta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cbteNro => $composableBuilder(
    column: $table.cbteNro,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get importeTotal => $composableBuilder(
    column: $table.importeTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cae => $composableBuilder(
    column: $table.cae,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caeFchVto => $composableBuilder(
    column: $table.caeFchVto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receptorNombre => $composableBuilder(
    column: $table.receptorNombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get receptorDocTipo => $composableBuilder(
    column: $table.receptorDocTipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receptorDocNro => $composableBuilder(
    column: $table.receptorDocNro,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfPath => $composableBuilder(
    column: $table.pdfPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ClientesTableOrderingComposer get clienteId {
    final $$ClientesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clienteId,
      referencedTable: $db.clientes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientesTableOrderingComposer(
            $db: $db,
            $table: $db.clientes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepartosTableOrderingComposer get repartoId {
    final $$RepartosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableOrderingComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FacturasTableAnnotationComposer
    extends Composer<_$AppDatabase, $FacturasTable> {
  $$FacturasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get cbteTipo =>
      $composableBuilder(column: $table.cbteTipo, builder: (column) => column);

  GeneratedColumn<int> get ptoVta =>
      $composableBuilder(column: $table.ptoVta, builder: (column) => column);

  GeneratedColumn<int> get cbteNro =>
      $composableBuilder(column: $table.cbteNro, builder: (column) => column);

  GeneratedColumn<String> get fecha =>
      $composableBuilder(column: $table.fecha, builder: (column) => column);

  GeneratedColumn<double> get importeTotal => $composableBuilder(
    column: $table.importeTotal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cae =>
      $composableBuilder(column: $table.cae, builder: (column) => column);

  GeneratedColumn<String> get caeFchVto =>
      $composableBuilder(column: $table.caeFchVto, builder: (column) => column);

  GeneratedColumn<String> get itemsJson =>
      $composableBuilder(column: $table.itemsJson, builder: (column) => column);

  GeneratedColumn<String> get receptorNombre => $composableBuilder(
    column: $table.receptorNombre,
    builder: (column) => column,
  );

  GeneratedColumn<int> get receptorDocTipo => $composableBuilder(
    column: $table.receptorDocTipo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receptorDocNro => $composableBuilder(
    column: $table.receptorDocNro,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfPath =>
      $composableBuilder(column: $table.pdfPath, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ClientesTableAnnotationComposer get clienteId {
    final $$ClientesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clienteId,
      referencedTable: $db.clientes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClientesTableAnnotationComposer(
            $db: $db,
            $table: $db.clientes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepartosTableAnnotationComposer get repartoId {
    final $$RepartosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.repartoId,
      referencedTable: $db.repartos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepartosTableAnnotationComposer(
            $db: $db,
            $table: $db.repartos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FacturasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FacturasTable,
          Factura,
          $$FacturasTableFilterComposer,
          $$FacturasTableOrderingComposer,
          $$FacturasTableAnnotationComposer,
          $$FacturasTableCreateCompanionBuilder,
          $$FacturasTableUpdateCompanionBuilder,
          (Factura, $$FacturasTableReferences),
          Factura,
          PrefetchHooks Function({bool clienteId, bool repartoId})
        > {
  $$FacturasTableTableManager(_$AppDatabase db, $FacturasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FacturasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FacturasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FacturasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> clienteId = const Value.absent(),
                Value<int> repartoId = const Value.absent(),
                Value<int> cbteTipo = const Value.absent(),
                Value<int> ptoVta = const Value.absent(),
                Value<int> cbteNro = const Value.absent(),
                Value<String> fecha = const Value.absent(),
                Value<double> importeTotal = const Value.absent(),
                Value<String> cae = const Value.absent(),
                Value<String> caeFchVto = const Value.absent(),
                Value<String> itemsJson = const Value.absent(),
                Value<String> receptorNombre = const Value.absent(),
                Value<int> receptorDocTipo = const Value.absent(),
                Value<String> receptorDocNro = const Value.absent(),
                Value<String> pdfPath = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
              }) => FacturasCompanion(
                id: id,
                clienteId: clienteId,
                repartoId: repartoId,
                cbteTipo: cbteTipo,
                ptoVta: ptoVta,
                cbteNro: cbteNro,
                fecha: fecha,
                importeTotal: importeTotal,
                cae: cae,
                caeFchVto: caeFchVto,
                itemsJson: itemsJson,
                receptorNombre: receptorNombre,
                receptorDocTipo: receptorDocTipo,
                receptorDocNro: receptorDocNro,
                pdfPath: pdfPath,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int clienteId,
                required int repartoId,
                Value<int> cbteTipo = const Value.absent(),
                required int ptoVta,
                required int cbteNro,
                required String fecha,
                required double importeTotal,
                required String cae,
                required String caeFchVto,
                Value<String> itemsJson = const Value.absent(),
                Value<String> receptorNombre = const Value.absent(),
                Value<int> receptorDocTipo = const Value.absent(),
                Value<String> receptorDocNro = const Value.absent(),
                Value<String> pdfPath = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
              }) => FacturasCompanion.insert(
                id: id,
                clienteId: clienteId,
                repartoId: repartoId,
                cbteTipo: cbteTipo,
                ptoVta: ptoVta,
                cbteNro: cbteNro,
                fecha: fecha,
                importeTotal: importeTotal,
                cae: cae,
                caeFchVto: caeFchVto,
                itemsJson: itemsJson,
                receptorNombre: receptorNombre,
                receptorDocTipo: receptorDocTipo,
                receptorDocNro: receptorDocNro,
                pdfPath: pdfPath,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FacturasTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({clienteId = false, repartoId = false}) {
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
                    if (clienteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.clienteId,
                                referencedTable: $$FacturasTableReferences
                                    ._clienteIdTable(db),
                                referencedColumn: $$FacturasTableReferences
                                    ._clienteIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (repartoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.repartoId,
                                referencedTable: $$FacturasTableReferences
                                    ._repartoIdTable(db),
                                referencedColumn: $$FacturasTableReferences
                                    ._repartoIdTable(db)
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

typedef $$FacturasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FacturasTable,
      Factura,
      $$FacturasTableFilterComposer,
      $$FacturasTableOrderingComposer,
      $$FacturasTableAnnotationComposer,
      $$FacturasTableCreateCompanionBuilder,
      $$FacturasTableUpdateCompanionBuilder,
      (Factura, $$FacturasTableReferences),
      Factura,
      PrefetchHooks Function({bool clienteId, bool repartoId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RepartosTableTableManager get repartos =>
      $$RepartosTableTableManager(_db, _db.repartos);
  $$ProductosTableTableManager get productos =>
      $$ProductosTableTableManager(_db, _db.productos);
  $$ProductoPreciosTableTableManager get productoPrecios =>
      $$ProductoPreciosTableTableManager(_db, _db.productoPrecios);
  $$CargaDiariaTableTableManager get cargaDiaria =>
      $$CargaDiariaTableTableManager(_db, _db.cargaDiaria);
  $$ClientesTableTableManager get clientes =>
      $$ClientesTableTableManager(_db, _db.clientes);
  $$ClienteProductosTableTableManager get clienteProductos =>
      $$ClienteProductosTableTableManager(_db, _db.clienteProductos);
  $$EntregasTableTableManager get entregas =>
      $$EntregasTableTableManager(_db, _db.entregas);
  $$PagosTableTableManager get pagos =>
      $$PagosTableTableManager(_db, _db.pagos);
  $$ResumenesTableTableManager get resumenes =>
      $$ResumenesTableTableManager(_db, _db.resumenes);
  $$UserSettingsTableTableManager get userSettings =>
      $$UserSettingsTableTableManager(_db, _db.userSettings);
  $$EtiquetaColorsTableTableManager get etiquetaColors =>
      $$EtiquetaColorsTableTableManager(_db, _db.etiquetaColors);
  $$AppNotificationsTableTableManager get appNotifications =>
      $$AppNotificationsTableTableManager(_db, _db.appNotifications);
  $$NotifDismissalsTableTableManager get notifDismissals =>
      $$NotifDismissalsTableTableManager(_db, _db.notifDismissals);
  $$StockNotifSettingsTableTableManager get stockNotifSettings =>
      $$StockNotifSettingsTableTableManager(_db, _db.stockNotifSettings);
  $$FacturasTableTableManager get facturas =>
      $$FacturasTableTableManager(_db, _db.facturas);
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Filas crudas del catálogo tal como llegan de Supabase (o de la copia en
/// disco). Es el formato que se guarda para abrir el menú sin conexión.
class CatalogRows {
  /// Agrupa las filas de cada tabla del catálogo.
  const CatalogRows({
    this.publicBusinesses = const [],
    this.ownBusinesses = const [],
    this.branches = const [],
    this.dishes = const [],
    this.options = const [],
  });

  /// Filas de `businesses_public` (id, marca, cocina y descripción).
  final List<Map<String, dynamic>> publicBusinesses;

  /// Filas completas de `businesses` que RLS deja ver (solo las del dueño).
  final List<Map<String, dynamic>> ownBusinesses;

  /// Filas de `branches`.
  final List<Map<String, dynamic>> branches;

  /// Filas de `dishes`.
  final List<Map<String, dynamic>> dishes;

  /// Filas de `dish_options`.
  final List<Map<String, dynamic>> options;

  /// `true` si no trae ni sedes ni platos.
  bool get isEmpty => branches.isEmpty && dishes.isEmpty;

  /// Negocios mezclados por id: la fila completa del dueño pisa a la pública.
  List<Map<String, dynamic>> get businesses {
    final byId = <String, Map<String, dynamic>>{};
    for (final row in publicBusinesses) {
      final id = row['id'];
      if (id is String) byId[id] = row;
    }
    for (final row in ownBusinesses) {
      final id = row['id'];
      if (id is String) byId[id] = {...?byId[id], ...row};
    }
    return byId.values.toList();
  }

  /// Versión serializable para disco. Omite [ownBusinesses] a propósito:
  /// los datos bancarios y documentos del negocio no se guardan en el equipo.
  Map<String, dynamic> toJson() => {
    'v': 1,
    'businesses': publicBusinesses,
    'branches': branches,
    'dishes': dishes,
    'options': options,
  };

  /// Reconstruye las filas desde [toJson]; lanza [FormatException] si la
  /// versión no es la esperada.
  factory CatalogRows.fromJson(Map<String, dynamic> json) {
    if (json['v'] != 1) {
      throw const FormatException('Versión de copia del catálogo desconocida');
    }
    return CatalogRows(
      publicBusinesses: _rows(json['businesses']),
      branches: _rows(json['branches']),
      dishes: _rows(json['dishes']),
      options: _rows(json['options']),
    );
  }

  /// Convierte una lista JSON en filas tipadas.
  static List<Map<String, dynamic>> _rows(Object? value) => [
    for (final row in (value as List? ?? const []))
      Map<String, dynamic>.from(row as Map),
  ];
}

/// Almacén de la copia del catálogo en disco.
abstract class CatalogCache {
  /// Lee la copia guardada, o `null` si no hay.
  Future<String?> read();

  /// Guarda la copia (reemplaza la anterior).
  Future<void> write(String value);
}

/// Copia en memoria: para pruebas y como respaldo sin disco.
class MemoryCatalogCache implements CatalogCache {
  /// Crea la caché, opcionalmente con una copia previa.
  MemoryCatalogCache([this._value]);

  String? _value;

  /// Texto guardado actualmente.
  String? get value => _value;

  /// Devuelve la copia en memoria.
  @override
  Future<String?> read() async => _value;

  /// Reemplaza la copia en memoria.
  @override
  Future<void> write(String value) async => _value = value;
}

/// Copia persistente con `shared_preferences` (web, móvil y escritorio).
class SharedPrefsCatalogCache implements CatalogCache {
  /// Clave bajo la que se guarda el catálogo.
  static const key = 'biffy.catalog.v1';

  /// Lee la copia del almacenamiento local.
  @override
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  /// Guarda la copia en el almacenamiento local.
  @override
  Future<void> write(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}

/// Serializa las filas del catálogo a texto JSON.
String encodeCatalogRows(CatalogRows rows) => jsonEncode(rows.toJson());

/// Lee la copia guardada; devuelve `null` si no hay o está dañada.
CatalogRows? decodeCatalogRows(String? text) {
  if (text == null || text.isEmpty) return null;
  try {
    final json = jsonDecode(text);
    if (json is! Map) return null;
    return CatalogRows.fromJson(Map<String, dynamic>.from(json));
  } on Object {
    return null;
  }
}

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/local_db.dart';

/// Tablas sincronizadas con Supabase, en orden de dependencia.
const kTablasSync = [
  'ubicaciones',
  'tipos_evento',
  'perfiles_usuario',
  'permisos_usuario',
  'toros',
  'vacas',
  'caballos',
  'terneros',
  'pesadas_ternero',
  'traslados_ternero',
  'lotes',
  'movimientos_lote',
  'eventos_vaca',
  'eventos_masivos',
  'eventos_masivos_vacas',
  'registros_salud',
  'tratamientos_salud',
  'conceptos_financieros',
  'movimientos_financieros',
  'actividades',
  'solicitudes',
];

class SyncProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  bool _isSyncing = false;
  bool _isOnline = false;
  DateTime? _lastSync;
  String? _lastError;

  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  DateTime? get lastSync => _lastSync;
  String? get lastError => _lastError;

  SyncProvider() {
    _initConnectivity();
    Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && _isOnline) syncAll();
    });
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);
    if (_isOnline) syncAll();
    notifyListeners();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final online = !results.contains(ConnectivityResult.none);
    if (!_isOnline && online) {
      // Recuperamos conexión → sincronizar
      syncAll();
    }
    _isOnline = online;
    notifyListeners();
  }

  Future<void> syncAll() async {
    if (_isSyncing) return;
    if (_supabase.auth.currentUser == null) return;
    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    final errores = <String>[];
    // La bajada no pisa filas con cambios locales pendientes (synced = 0),
    // así que se puede bajar primero y luego subir.
    for (final tabla in kTablasSync) {
      try {
        await _pull(tabla);
      } catch (e) {
        errores.add('Bajar $tabla: $e');
      }
    }
    for (final tabla in kTablasSync) {
      try {
        await _push(tabla);
      } catch (e) {
        errores.add('Subir $tabla: $e');
      }
    }

    if (errores.isEmpty) {
      _lastSync = DateTime.now();
    } else {
      _lastError = errores.join('\n');
      debugPrint('Errores de sincronización:\n$_lastError');
    }
    _isSyncing = false;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> _fetchAll(String tabla) async {
    const pagina = 1000;
    final todos = <Map<String, dynamic>>[];
    var desde = 0;
    while (true) {
      final rows = await _supabase
          .from(tabla)
          .select()
          .order('id')
          .range(desde, desde + pagina - 1);
      todos.addAll(rows);
      if (rows.length < pagina) break;
      desde += pagina;
    }
    return todos;
  }

  Future<void> _pull(String tabla) async {
    final db = LocalDb.instance.db;
    final columnas = await LocalDb.instance.columnas(tabla);
    final remotos = await _fetchAll(tabla);

    // Filas con cambios locales pendientes: no se sobrescriben.
    final pendientes = (await db.query(tabla,
            columns: ['id'], where: 'synced = 0'))
        .map((r) => r['id'] as String)
        .toSet();

    final idsRemotos = <String>{};
    final batch = db.batch();
    for (final row in remotos) {
      final id = row['id'] as String;
      idsRemotos.add(id);
      if (pendientes.contains(id)) continue;
      batch.insert(tabla, _toLocalRow(row, columnas),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);

    // Lo que se borró en el servidor también se borra aquí.
    final locales = await db.query(tabla, columns: ['id'], where: 'synced = 1');
    for (final r in locales) {
      final id = r['id'] as String;
      if (!idsRemotos.contains(id)) {
        await db.delete(tabla, where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  Map<String, dynamic> _toLocalRow(
      Map<String, dynamic> row, Set<String> columnas) {
    final local = <String, dynamic>{};
    row.forEach((k, v) {
      if (!columnas.contains(k)) return;
      if (v is bool) {
        _columnasBool.add(k);
        local[k] = v ? 1 : 0;
      } else {
        local[k] = v;
      }
    });
    local['synced'] = 1;
    local['deleted'] = 0;
    return local;
  }

  Future<void> _push(String tabla) async {
    final db = LocalDb.instance.db;

    final unsynced = await db.query(tabla, where: 'synced = 0 AND deleted = 0');
    for (final row in unsynced) {
      await _supabase.from(tabla).upsert(_toRemoteRow(tabla, row));
      await db.update(tabla, {'synced': 1},
          where: 'id = ?', whereArgs: [row['id']]);
    }

    // Eliminar en remoto los marcados como deleted
    final deleted = await db.query(tabla, where: 'deleted = 1 AND synced = 0');
    for (final row in deleted) {
      await _supabase.from(tabla).delete().eq('id', row['id'] as String);
      await db.delete(tabla, where: 'id = ?', whereArgs: [row['id']]);
    }
  }

  // Columnas que Supabase guarda como boolean (SQLite las guarda como 0/1).
  // Se completa con lo que llega en cada bajada.
  final Set<String> _columnasBool = {
    'activa',
    'activo',
    'puede_ver',
    'puede_crear',
    'puede_editar',
    'puede_eliminar',
  };

  Map<String, dynamic> _toRemoteRow(String tabla, Map<String, dynamic> row) {
    final remote = Map<String, dynamic>.from(row);
    remote.remove('synced');
    remote.remove('deleted');
    for (final c in _columnasBool) {
      final v = remote[c];
      if (v is int) remote[c] = v == 1;
    }
    return remote;
  }
}

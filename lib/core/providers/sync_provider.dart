import 'dart:io';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  int _pendientes = 0;

  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  DateTime? get lastSync => _lastSync;
  String? get lastError => _lastError;

  /// Cambios hechos en el teléfono que todavía no se subieron.
  int get pendientes => _pendientes;

  static const _kUltimaSync = 'ultima_sincronizacion';

  SyncProvider() {
    _cargarUltimaSync();
    _initConnectivity();
    Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && _isOnline) syncAll();
    });
  }

  Future<void> _cargarUltimaSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_kUltimaSync);
      if (s != null && _lastSync == null) _lastSync = DateTime.tryParse(s);
    } catch (_) {}
    await contarPendientes();
  }

  /// Recalcula cuántas filas locales esperan subirse.
  Future<int> contarPendientes() async {
    final db = LocalDb.instance.db;
    var total = 0;
    for (final tabla in kTablasSync) {
      try {
        final r = await db
            .rawQuery('SELECT COUNT(*) AS c FROM $tabla WHERE synced = 0');
        total += (r.first['c'] as int?) ?? 0;
      } catch (_) {}
    }
    if (total != _pendientes) {
      _pendientes = total;
      notifyListeners();
    }
    return total;
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
        await _pull(tabla, errores);
      } catch (e) {
        errores.add('Bajar ${_nombreTabla(tabla)}: ${_mensaje(e)}');
      }
    }
    for (final tabla in kTablasSync) {
      try {
        await _push(tabla, errores);
      } catch (e) {
        errores.add('Subir ${_nombreTabla(tabla)}: ${_mensaje(e)}');
      }
    }

    // Se registra la hora aunque haya errores: lo que no falló sí quedó
    // sincronizado, y los errores se muestran aparte.
    _lastSync = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUltimaSync, _lastSync!.toIso8601String());
    } catch (_) {}
    if (errores.isNotEmpty) {
      const max = 25;
      _lastError = [
        ...errores.take(max),
        if (errores.length > max) '… y ${errores.length - max} errores más',
      ].join('\n');
      debugPrint('Errores de sincronización:\n${errores.join('\n')}');
    }
    await contarPendientes();
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

  Future<void> _pull(String tabla, List<String> errores) async {
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
    final ids = <String>[];
    for (final row in remotos) {
      final id = row['id'] as String;
      idsRemotos.add(id);
      if (pendientes.contains(id)) continue;
      ids.add(id);
      batch.insert(tabla, _toLocalRow(row, columnas),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    // Un registro que no se pueda guardar (p. ej. un dato obligatorio vacío
    // en el servidor) no impide guardar los demás.
    final resultados = await batch.commit(continueOnError: true);
    for (var i = 0; i < resultados.length; i++) {
      final r = resultados[i];
      if (r is DatabaseException || r is Exception) {
        errores.add('Bajar ${_nombreTabla(tabla)} (${ids[i]}): ${_mensaje(r!)}');
      }
    }

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

  /// Sube los cambios de [tabla]. Un registro con error no frena a los
  /// demás: el error se anota en [errores] y el registro queda pendiente.
  Future<void> _push(String tabla, List<String> errores) async {
    final db = LocalDb.instance.db;

    final unsynced = await db.query(tabla, where: 'synced = 0 AND deleted = 0');
    for (final row in unsynced) {
      final remoto = _toRemoteRow(tabla, row);
      var fotoPendiente = false;
      if (tabla == 'solicitudes' &&
          row['foto_local'] != null &&
          row['foto_url'] == null &&
          !await File(row['foto_local'] as String).exists()) {
        // La foto ya no está en el teléfono: no hay nada que subir.
        await db.update(tabla, {'foto_local': null},
            where: 'id = ?', whereArgs: [row['id']]);
      } else if (tabla == 'solicitudes' &&
          row['foto_local'] != null &&
          row['foto_url'] == null) {
        final url = await _subirFoto(row['id'] as String, row['foto_local'] as String);
        if (url != null) {
          remoto['foto_url'] = url;
          await db.update(tabla, {'foto_url': url},
              where: 'id = ?', whereArgs: [row['id']]);
        } else {
          fotoPendiente = true;
        }
      }
      if (tabla == 'solicitudes' && !_servidorTieneFotoUrl) {
        remoto.remove('foto_url');
        if (row['foto_local'] != null) fotoPendiente = true;
      }
      try {
        await _supabase.from(tabla).upsert(remoto);
      } on PostgrestException catch (e) {
        // El servidor aún no tiene la columna foto_url (falta ejecutar
        // 005_fotos_solicitudes.sql): se sube sin ella.
        if (e.code != 'PGRST204' || !remoto.containsKey('foto_url')) {
          errores.add('Subir ${_nombreTabla(tabla)} (${row['id']}): ${_mensaje(e)}');
          continue;
        }
        _servidorTieneFotoUrl = false;
        remoto.remove('foto_url');
        try {
          await _supabase.from(tabla).upsert(remoto);
        } catch (e2) {
          errores.add('Subir ${_nombreTabla(tabla)} (${row['id']}): ${_mensaje(e2)}');
          continue;
        }
        if (row['foto_local'] != null) fotoPendiente = true;
      } catch (e) {
        errores.add('Subir ${_nombreTabla(tabla)} (${row['id']}): ${_mensaje(e)}');
        continue;
      }
      // Con la foto pendiente la fila sigue marcada para reintentar
      // (y la bajada no la pisa, así no se pierde la foto local).
      if (!fotoPendiente) {
        await db.update(tabla, {'synced': 1},
            where: 'id = ?', whereArgs: [row['id']]);
      }
    }

    // Eliminar en remoto los marcados como deleted
    final deleted = await db.query(tabla, where: 'deleted = 1 AND synced = 0');
    for (final row in deleted) {
      try {
        await _supabase.from(tabla).delete().eq('id', row['id'] as String);
        await db.delete(tabla, where: 'id = ?', whereArgs: [row['id']]);
      } catch (e) {
        errores.add('Borrar ${_nombreTabla(tabla)} (${row['id']}): ${_mensaje(e)}');
      }
    }
  }

  bool _servidorTieneFotoUrl = true;

  static const _nombres = {
    'tipos_evento': 'tipos de evento',
    'perfiles_usuario': 'usuarios',
    'permisos_usuario': 'permisos',
    'pesadas_ternero': 'pesadas',
    'traslados_ternero': 'traslados',
    'movimientos_lote': 'movimientos de lote',
    'eventos_vaca': 'eventos',
    'eventos_masivos': 'eventos masivos',
    'eventos_masivos_vacas': 'eventos masivos',
    'registros_salud': 'salud',
    'tratamientos_salud': 'tratamientos',
    'conceptos_financieros': 'conceptos',
    'movimientos_financieros': 'finanzas',
  };

  String _nombreTabla(String t) => _nombres[t] ?? t;

  /// Mensaje corto y útil de un error de Supabase u otro.
  String _mensaje(Object e) {
    if (e is PostgrestException) {
      final partes = [
        e.message,
        if (e.details != null && '${e.details}'.isNotEmpty) '${e.details}',
        if (e.hint != null && e.hint!.isNotEmpty) e.hint!,
        if (e.code != null) '[${e.code}]',
      ];
      return partes.join(' · ');
    }
    if (e is SocketException) return 'Sin conexión con el servidor';
    final s = e.toString();
    return s.length > 300 ? '${s.substring(0, 300)}…' : s;
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

  /// Sube la foto de una solicitud al bucket "solicitudes" y devuelve su URL
  /// pública, o null si no se pudo (sin bucket, archivo borrado, etc.).
  Future<String?> _subirFoto(String id, String rutaLocal) async {
    try {
      final archivo = File(rutaLocal);
      if (!await archivo.exists()) return null;
      final ruta = '$id.jpg';
      await _supabase.storage.from('solicitudes').upload(ruta, archivo,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
      return _supabase.storage.from('solicitudes').getPublicUrl(ruta);
    } catch (e) {
      debugPrint('No se pudo subir la foto de la solicitud $id: $e');
      return null;
    }
  }

  // Columnas que solo existen en el teléfono.
  static const _columnasLocales = {'synced', 'deleted', 'foto_local'};

  Map<String, dynamic> _toRemoteRow(String tabla, Map<String, dynamic> row) {
    final remote = Map<String, dynamic>.from(row);
    remote.removeWhere((k, _) => _columnasLocales.contains(k));
    for (final c in _columnasBool) {
      final v = remote[c];
      if (v is int) remote[c] = v == 1;
    }
    return remote;
  }
}

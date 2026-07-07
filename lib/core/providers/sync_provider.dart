import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/local_db.dart';

class SyncProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  bool _isSyncing = false;
  bool _isOnline = false;
  DateTime? _lastSync;

  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  DateTime? get lastSync => _lastSync;

  SyncProvider() {
    _initConnectivity();
    Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
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
    notifyListeners();

    try {
      await _pullFromSupabase();
      await _pushToSupabase();
      _lastSync = DateTime.now();
    } catch (_) {
      // Silenciamos errores de sync, la app sigue funcionando offline
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _pullFromSupabase() async {
    final db = LocalDb.instance.db;

    // Tipos de evento
    final tiposEvento =
        await _supabase.from('tipos_evento').select().order('nombre');
    for (final row in tiposEvento) {
      await db.insert('tipos_evento', _toLocalRow(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Ubicaciones
    final ubicaciones =
        await _supabase.from('ubicaciones').select().order('nombre');
    for (final row in ubicaciones) {
      await db.insert('ubicaciones', _toLocalRow(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Toros
    final toros = await _supabase.from('toros').select().order('numero');
    for (final row in toros) {
      await db.insert('toros', _toLocalRow(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    // Vacas
    final vacas = await _supabase.from('vacas').select().order('numero');
    for (final row in vacas) {
      await db.insert('vacas', _toLocalRow(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Caballos
    final caballos = await _supabase.from('caballos').select().order('nombre');
    for (final row in caballos) {
      await db.insert('caballos', _toLocalRow(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Lotes
    final lotes = await _supabase.from('lotes').select().order('nombre');
    for (final row in lotes) {
      await db.insert('lotes', _toLocalRow(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Movimientos lote
    final movimientos =
        await _supabase.from('movimientos_lote').select().order('fecha');
    for (final row in movimientos) {
      await db.insert('movimientos_lote', _toLocalRow(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Eventos vaca
    final eventos =
        await _supabase.from('eventos_vaca').select().order('fecha');
    for (final row in eventos) {
      await db.insert('eventos_vaca', _toLocalRow(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Conceptos financieros
    final conceptos =
        await _supabase.from('conceptos_financieros').select().order('nombre');
    for (final row in conceptos) {
      await db.insert('conceptos_financieros', _toLocalRow(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Movimientos financieros
    final movimientosFinancieros = await _supabase
        .from('movimientos_financieros')
        .select()
        .order('fecha');
    for (final row in movimientosFinancieros) {
      await db.insert('movimientos_financieros', _toLocalRow(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Perfiles de usuario
    final perfiles =
        await _supabase.from('perfiles_usuario').select().order('nombre');
    for (final row in perfiles) {
      await db.insert('perfiles_usuario', _toLocalRow(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Permisos de usuario
    final permisos = await _supabase.from('permisos_usuario').select();
    for (final row in permisos) {
      await db.insert('permisos_usuario', _toLocalRow(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Map<String, dynamic> _toLocalRow(Map<String, dynamic> row) {
    final local = Map<String, dynamic>.from(row);
    local['synced'] = 1;
    local['deleted'] = 0;
    return local;
  }

  Future<void> _pushToSupabase() async {
    final db = LocalDb.instance.db;

    // Push registros no sincronizados de cada tabla
    final tables = [
      'ubicaciones',
      'tipos_evento',
      'toros',
      'vacas',
      'caballos',
      'lotes',
      'movimientos_lote',
      'eventos_vaca',
      'eventos_masivos',
      'eventos_masivos_vacas',
      'conceptos_financieros',
      'movimientos_financieros',
      'perfiles_usuario',
      'permisos_usuario',
    ];

    for (final table in tables) {
      final unsynced =
          await db.query(table, where: 'synced = 0 AND deleted = 0');
      for (final row in unsynced) {
        final remoteRow = _toRemoteRow(row);
        await _supabase.from(table).upsert(remoteRow);
        await db.update(table, {'synced': 1},
            where: 'id = ?', whereArgs: [row['id']]);
      }

      // Eliminar en remoto los marcados como deleted
      final deleted =
          await db.query(table, where: 'deleted = 1 AND synced = 0');
      for (final row in deleted) {
        await _supabase.from(table).delete().eq('id', row['id'] as String);
        await db.delete(table, where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }

  Map<String, dynamic> _toRemoteRow(Map<String, dynamic> row) {
    final remote = Map<String, dynamic>.from(row);
    remote.remove('synced');
    remote.remove('deleted');
    return remote;
  }
}

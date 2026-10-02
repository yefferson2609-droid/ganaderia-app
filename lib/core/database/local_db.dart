import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  // Columnas de cada tabla local, para filtrar lo que llega de Supabase.
  final Map<String, Set<String>> _columnas = {};

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ganaderia_v2.db');

    _db = await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Database get db {
    if (_db == null) throw StateError('LocalDb no inicializada');
    return _db!;
  }

  Future<Set<String>> columnas(String tabla) async {
    final cached = _columnas[tabla];
    if (cached != null) return cached;
    final info = await db.rawQuery('PRAGMA table_info($tabla)');
    final cols = info.map((r) => r['name'] as String).toSet();
    _columnas[tabla] = cols;
    return cols;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ubicaciones (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        activa INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE tipos_evento (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE toros (
        id TEXT PRIMARY KEY,
        numero TEXT NOT NULL,
        nombre TEXT NOT NULL,
        fecha_nacimiento TEXT,
        estado TEXT NOT NULL DEFAULT 'activo',
        padre_id TEXT,
        madre_id TEXT,
        ubicacion_id TEXT,
        color TEXT,
        nota TEXT,
        created_by TEXT,
        updated_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE vacas (
        id TEXT PRIMARY KEY,
        numero TEXT NOT NULL,
        fecha_nacimiento TEXT,
        estado TEXT NOT NULL DEFAULT 'activa',
        padre_id TEXT,
        madre_id TEXT,
        estado_reproductivo TEXT NOT NULL DEFAULT 'vacia',
        fecha_monta TEXT,
        toro_id TEXT,
        fecha_estimada_parto TEXT,
        ubicacion_id TEXT,
        color TEXT,
        nota TEXT,
        created_by TEXT,
        updated_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE caballos (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'activo',
        ubicacion_id TEXT,
        color TEXT,
        nota TEXT,
        created_by TEXT,
        updated_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE lotes (
        id TEXT PRIMARY KEY,
        tipo TEXT NOT NULL,
        nombre TEXT NOT NULL,
        hembras INTEGER NOT NULL DEFAULT 0,
        machos INTEGER NOT NULL DEFAULT 0,
        ubicacion_id TEXT,
        created_by TEXT,
        updated_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE movimientos_lote (
        id TEXT PRIMARY KEY,
        lote_id TEXT NOT NULL,
        tipo_movimiento TEXT NOT NULL,
        cantidad INTEGER NOT NULL,
        sexo TEXT NOT NULL,
        fecha TEXT NOT NULL,
        notas TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE eventos_vaca (
        id TEXT PRIMARY KEY,
        vaca_id TEXT NOT NULL,
        tipo_evento_id TEXT NOT NULL,
        fecha TEXT NOT NULL,
        notas TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE eventos_masivos (
        id TEXT PRIMARY KEY,
        tipo_evento_id TEXT NOT NULL,
        fecha TEXT NOT NULL,
        notas TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE eventos_masivos_vacas (
        id TEXT PRIMARY KEY,
        evento_masivo_id TEXT NOT NULL,
        vaca_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _createFinanzasTables(db);
    await _createUsuariosTables(db);
    await _createTernerosTables(db);
    await _createSaludTables(db);
    await _createOperacionTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createFinanzasTables(db);
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE toros ADD COLUMN fecha_nacimiento TEXT');
      await db.execute('ALTER TABLE toros ADD COLUMN padre_id TEXT');
      await db.execute('ALTER TABLE toros ADD COLUMN madre_id TEXT');
    }
    if (oldVersion < 4) {
      await _createUsuariosTables(db);
    }
    if (oldVersion < 5) {
      for (final t in ['vacas', 'toros', 'caballos']) {
        await db.execute('ALTER TABLE $t ADD COLUMN color TEXT');
        await db.execute('ALTER TABLE $t ADD COLUMN nota TEXT');
      }
      for (final t in ['vacas', 'toros', 'caballos', 'lotes']) {
        await db.execute('ALTER TABLE $t ADD COLUMN created_by TEXT');
        await db.execute('ALTER TABLE $t ADD COLUMN updated_by TEXT');
      }
      await db.execute(
          "UPDATE vacas SET estado = 'fallecida' WHERE estado = 'muerta'");
      await db.execute(
          "UPDATE toros SET estado = 'fallecido' WHERE estado = 'muerto'");
      await db.execute(
          "UPDATE caballos SET estado = 'fallecido' WHERE estado = 'muerto'");
      await _createTernerosTables(db);
      await _createSaludTables(db);
      await _createOperacionTables(db);
    }
  }

  Future<void> _createUsuariosTables(Database db) async {
    await db.execute('''
      CREATE TABLE perfiles_usuario (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        correo TEXT NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE permisos_usuario (
        id TEXT PRIMARY KEY,
        usuario_id TEXT NOT NULL,
        modulo TEXT NOT NULL,
        puede_ver INTEGER NOT NULL DEFAULT 0,
        puede_crear INTEGER NOT NULL DEFAULT 0,
        puede_editar INTEGER NOT NULL DEFAULT 0,
        puede_eliminar INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createFinanzasTables(Database db) async {
    await db.execute('''
      CREATE TABLE conceptos_financieros (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        tipo TEXT NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE movimientos_financieros (
        id TEXT PRIMARY KEY,
        tipo TEXT NOT NULL,
        concepto_id TEXT,
        nota TEXT,
        monto REAL NOT NULL,
        fecha TEXT NOT NULL,
        ubicacion_id TEXT,
        created_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createTernerosTables(Database db) async {
    await db.execute('''
      CREATE TABLE terneros (
        id TEXT PRIMARY KEY,
        numero TEXT NOT NULL,
        sexo TEXT NOT NULL,
        fecha_nacimiento TEXT,
        etapa TEXT NOT NULL DEFAULT 'lactancia',
        capado INTEGER NOT NULL DEFAULT 0,
        estado TEXT NOT NULL DEFAULT 'activo',
        padre_id TEXT,
        madre_id TEXT,
        ubicacion_id TEXT,
        color TEXT,
        nota TEXT,
        created_by TEXT,
        updated_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE pesadas_ternero (
        id TEXT PRIMARY KEY,
        ternero_id TEXT NOT NULL,
        fecha TEXT NOT NULL,
        peso REAL NOT NULL,
        notas TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE traslados_ternero (
        id TEXT PRIMARY KEY,
        ternero_id TEXT NOT NULL,
        fecha TEXT NOT NULL,
        ubicacion_origen_id TEXT,
        ubicacion_destino_id TEXT NOT NULL,
        notas TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createSaludTables(Database db) async {
    await db.execute('''
      CREATE TABLE registros_salud (
        id TEXT PRIMARY KEY,
        animal_tipo TEXT NOT NULL,
        animal_id TEXT NOT NULL,
        fecha_inicio TEXT NOT NULL,
        diagnostico TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'activo',
        fecha_fin TEXT,
        created_by TEXT,
        updated_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE tratamientos_salud (
        id TEXT PRIMARY KEY,
        registro_salud_id TEXT NOT NULL,
        fecha TEXT NOT NULL,
        medicamento TEXT NOT NULL,
        dosis TEXT,
        notas TEXT,
        estado TEXT NOT NULL DEFAULT 'aplicado',
        created_by TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createOperacionTables(Database db) async {
    await db.execute('''
      CREATE TABLE actividades (
        id TEXT PRIMARY KEY,
        descripcion TEXT NOT NULL,
        fecha_limite TEXT,
        ubicacion_id TEXT,
        prioridad TEXT NOT NULL DEFAULT 'media',
        estado TEXT NOT NULL DEFAULT 'pendiente',
        asignado_a TEXT NOT NULL,
        creado_por TEXT,
        completado_por TEXT,
        fecha_completada TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE solicitudes (
        id TEXT PRIMARY KEY,
        item TEXT NOT NULL,
        cantidad TEXT,
        ubicacion_id TEXT,
        estado TEXT NOT NULL DEFAULT 'pendiente',
        nota TEXT,
        costo REAL,
        solicitado_por TEXT,
        resuelto_por TEXT,
        fecha_resolucion TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }
}

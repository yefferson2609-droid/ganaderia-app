import 'package:uuid/uuid.dart';
import '../database/local_db.dart';
import '../models/concepto_financiero.dart';

class ConceptoFinancieroRepository {
  final _db = LocalDb.instance.db;
  final _uuid = const Uuid();

  Future<List<ConceptoFinanciero>> getAll({
    String? tipo,
    bool soloActivos = false,
  }) async {
    String where = 'deleted = 0';
    List<dynamic> args = [];
    if (tipo != null) {
      where += ' AND tipo = ?';
      args.add(tipo);
    }
    if (soloActivos) where += ' AND activo = 1';
    final rows = await _db.query('conceptos_financieros',
        where: where,
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'nombre ASC');
    return rows.map(ConceptoFinanciero.fromMap).toList();
  }

  Future<ConceptoFinanciero?> getById(String id) async {
    final rows = await _db.query('conceptos_financieros',
        where: 'id = ? AND deleted = 0', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ConceptoFinanciero.fromMap(rows.first);
  }

  Future<ConceptoFinanciero> create({
    required String nombre,
    required String tipo,
  }) async {
    final now = DateTime.now();
    final concepto = ConceptoFinanciero(
      id: _uuid.v4(),
      nombre: nombre,
      tipo: tipo,
      activo: true,
      createdAt: now,
      updatedAt: now,
    );
    final map = concepto.toMap();
    map['synced'] = 0;
    map['deleted'] = 0;
    await _db.insert('conceptos_financieros', map);
    return concepto;
  }

  Future<void> update(ConceptoFinanciero concepto) async {
    final map = concepto.toMap();
    map['synced'] = 0;
    map['deleted'] = 0;
    await _db.update('conceptos_financieros', map,
        where: 'id = ?', whereArgs: [concepto.id]);
  }

  Future<void> delete(String id) async {
    await _db.update('conceptos_financieros', {'deleted': 1, 'synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }
}

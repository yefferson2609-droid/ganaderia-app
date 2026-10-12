import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../database/local_db.dart';
import '../models/ternero.dart';
import '../theme/app_theme.dart';

final _fmt = DateFormat('dd/MM/yyyy');

/// Una cría (o un progenitor) para mostrar en la descendencia.
class Pariente {
  final String ruta; // '/vacas/id', '/toros/id', '/terneros/id'
  final String nombre; // "Vaca #6120", "Toro #12 Rey", "Ternera #7655"
  final bool macho;
  final DateTime? nacimiento;
  final String? estado; // "Vendido", "Fallecida"… (null si está activo)
  final String? madreId;
  final String? padreId;
  const Pariente(this.ruta, this.nombre, this.macho,
      {this.nacimiento, this.estado, this.madreId, this.padreId});
}

DateTime? _f(Object? v) => v == null ? null : DateTime.tryParse(v as String);
String? _estado(Object? e, {required bool activo}) {
  final s = e as String?;
  if (s == null || activo) return null;
  return s[0].toUpperCase() + s.substring(1);
}

Pariente _deVaca(Map<String, Object?> r) => Pariente(
    '/vacas/${r['id']}', 'Vaca #${r['numero']}', false,
    nacimiento: _f(r['fecha_nacimiento']),
    estado: _estado(r['estado'], activo: r['estado'] == 'activa'),
    madreId: r['madre_id'] as String?,
    padreId: r['padre_id'] as String?);

Pariente _deToro(Map<String, Object?> r) => Pariente(
    '/toros/${r['id']}', 'Toro #${r['numero']} ${r['nombre'] ?? ''}'.trim(), true,
    nacimiento: _f(r['fecha_nacimiento']),
    estado: _estado(r['estado'], activo: r['estado'] == 'activo'),
    madreId: r['madre_id'] as String?,
    padreId: r['padre_id'] as String?);

Pariente _deTernero(Map<String, Object?> r) {
  final t = Ternero.fromMap(r);
  return Pariente('/terneros/${t.id}', nombreJovenCorto(t), t.esMacho,
      nacimiento: t.fechaNacimiento,
      estado: _estado(t.estado, activo: t.estado == 'activo'),
      madreId: t.madreId,
      padreId: t.padreId);
}

String nombreJovenCorto(Ternero t) => '${t.categoriaLabel} #${t.numero}';

/// Busca crías y progenitores en las tablas de vacas, toros y levante.
class DescendenciaRepository {
  final _db = LocalDb.instance.db;

  /// Hijos de un animal (como madre o como padre), del más joven al más viejo.
  Future<List<Pariente>> hijosDe(String id) async {
    const w = 'deleted = 0 AND (madre_id = ? OR padre_id = ?)';
    final hijos = [
      ...(await _db.query('vacas', where: w, whereArgs: [id, id])).map(_deVaca),
      ...(await _db.query('toros', where: w, whereArgs: [id, id])).map(_deToro),
      ...(await _db.query('terneros', where: w, whereArgs: [id, id]))
          .map(_deTernero),
    ];
    hijos.sort((a, b) {
      if (a.nacimiento == null) return 1;
      if (b.nacimiento == null) return -1;
      return b.nacimiento!.compareTo(a.nacimiento!);
    });
    return hijos;
  }

  /// La vaca o el toro con ese id (null si no existe o fue eliminado).
  Future<Pariente?> buscar(String? id) async {
    if (id == null) return null;
    final v = await _db.query('vacas',
        where: 'id = ? AND deleted = 0', whereArgs: [id]);
    if (v.isNotEmpty) return _deVaca(v.first);
    final t = await _db.query('toros',
        where: 'id = ? AND deleted = 0', whereArgs: [id]);
    if (t.isNotEmpty) return _deToro(t.first);
    return null;
  }
}

/// Madre, padre y lista de crías de un animal. Va dentro de un cuadro
/// plegable o sola en su tarjeta ([marco]).
class DescendenciaSection extends StatefulWidget {
  final String animalId;
  final String? madreId;
  final String? padreId;
  final bool marco;
  /// Avisa cuántas crías tiene (para el título del cuadro).
  final ValueChanged<int>? onTotal;
  const DescendenciaSection({
    super.key,
    required this.animalId,
    this.madreId,
    this.padreId,
    this.marco = true,
    this.onTotal,
  });

  @override
  State<DescendenciaSection> createState() => _DescendenciaSectionState();
}

class _DescendenciaSectionState extends State<DescendenciaSection> {
  final _repo = DescendenciaRepository();
  Pariente? _madre;
  Pariente? _padre;
  List<Pariente> _hijos = [];
  final Map<String, String> _nombres = {}; // id → nombre del otro progenitor
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _madre = await _repo.buscar(widget.madreId);
    _padre = await _repo.buscar(widget.padreId);
    _hijos = await _repo.hijosDe(widget.animalId);
    for (final h in _hijos) {
      for (final id in [h.madreId, h.padreId]) {
        if (id == null || id == widget.animalId || _nombres.containsKey(id)) {
          continue;
        }
        final p = await _repo.buscar(id);
        if (p != null) _nombres[id] = p.nombre;
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
    widget.onTotal?.call(_hijos.length);
  }

  void _abrir(String ruta) => context.push(ruta).then((_) => _load());

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.marco)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Descendencia',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
        _progenitor('Madre', _madre, widget.madreId != null),
        _progenitor('Padre', _padre, widget.padreId != null),
        const SizedBox(height: 8),
        Text(
          _hijos.isEmpty
              ? 'Sin crías registradas'
              : 'Crías (${_hijos.length}): '
                  '${_hijos.where((h) => !h.macho).length} hembras, '
                  '${_hijos.where((h) => h.macho).length} machos',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        for (final h in _hijos) _cria(h),
      ],
    );
    return widget.marco
        ? Card(
            child: Padding(padding: const EdgeInsets.all(16), child: contenido))
        : contenido;
  }

  Widget _progenitor(String label, Pariente? p, bool tieneId) => InkWell(
        onTap: p == null ? null : () => _abrir(p.ruta),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(
                width: 70,
                child: Text(label,
                    style: const TextStyle(color: Colors.grey, fontSize: 13))),
            Expanded(
              child: Text(
                p?.nombre ?? (tieneId ? 'Ya no está registrado' : 'No registrado'),
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: p != null ? AppColors.primary : null),
              ),
            ),
            if (p != null) const Icon(Icons.chevron_right, size: 18),
          ]),
        ),
      );

  Widget _cria(Pariente h) {
    final otroId = h.madreId == widget.animalId ? h.padreId : h.madreId;
    final otroLabel = h.madreId == widget.animalId ? 'Padre' : 'Madre';
    final detalles = [
      if (h.nacimiento != null) _fmt.format(h.nacimiento!),
      if (otroId != null && _nombres[otroId] != null)
        '$otroLabel: ${_nombres[otroId]}',
      if (h.estado != null) h.estado!,
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(h.macho ? Icons.male : Icons.female,
          color: h.macho ? AppColors.info : Colors.pink),
      title: Text(h.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: detalles.isEmpty ? null : Text(detalles.join(' · ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _abrir(h.ruta),
    );
  }
}

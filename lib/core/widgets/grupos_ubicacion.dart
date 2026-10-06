import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

final _numeroInicial = RegExp(r'^\s*(\d+)');

/// Compara números de animales de forma natural: "2" < "10" < "7655 bigote"
/// < "A3" (los que empiezan con número van por ese número).
int compararNumero(String a, String b) {
  final na = int.tryParse(_numeroInicial.firstMatch(a)?.group(1) ?? '');
  final nb = int.tryParse(_numeroInicial.firstMatch(b)?.group(1) ?? '');
  if (na != null && nb != null) {
    final c = na.compareTo(nb);
    return c != 0 ? c : a.toLowerCase().compareTo(b.toLowerCase());
  }
  if (na != null) return -1;
  if (nb != null) return 1;
  return a.toLowerCase().compareTo(b.toLowerCase());
}

/// Lista de animales agrupada por ubicación, en grupos plegables:
/// ubicaciones en orden alfabético, "Sin ubicación" al final, y dentro de
/// cada grupo los animales por número. Recuerda qué grupos se cerraron.
class GruposUbicacion<T> extends StatefulWidget {
  /// Identifica la lista para recordar los grupos cerrados (p. ej. 'vacas').
  final String clave;
  final List<T> items;
  final String? Function(T) ubicacionDe;
  final String Function(T) numeroDe;
  final Map<String, String> nombresUbicacion;
  final Widget Function(T) itemBuilder;
  final Future<void> Function() onRefresh;
  final String textoVacio;

  const GruposUbicacion({
    super.key,
    required this.clave,
    required this.items,
    required this.ubicacionDe,
    required this.numeroDe,
    required this.nombresUbicacion,
    required this.itemBuilder,
    required this.onRefresh,
    this.textoVacio = 'No hay animales',
  });

  @override
  State<GruposUbicacion<T>> createState() => _GruposUbicacionState<T>();
}

class _GruposUbicacionState<T> extends State<GruposUbicacion<T>> {
  static const _sinUbicacion = '__sin__';
  Set<String> _cerrados = {};

  String get _prefKey => 'grupos_cerrados_${widget.clave}';

  @override
  void initState() {
    super.initState();
    _cargarCerrados();
  }

  Future<void> _cargarCerrados() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final l = prefs.getStringList(_prefKey);
      if (l != null && mounted) setState(() => _cerrados = l.toSet());
    } catch (_) {}
  }

  Future<void> _alternar(String grupo) async {
    setState(() {
      if (!_cerrados.remove(grupo)) _cerrados.add(grupo);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefKey, _cerrados.toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Agrupar (una ubicación borrada o desconocida cuenta como sin ubicación).
    final grupos = <String, List<T>>{};
    for (final it in widget.items) {
      final u = widget.ubicacionDe(it);
      final clave = (u != null && widget.nombresUbicacion.containsKey(u))
          ? u
          : _sinUbicacion;
      grupos.putIfAbsent(clave, () => []).add(it);
    }
    for (final l in grupos.values) {
      l.sort((a, b) => compararNumero(widget.numeroDe(a), widget.numeroDe(b)));
    }
    final orden = grupos.keys.where((k) => k != _sinUbicacion).toList()
      ..sort((a, b) => widget.nombresUbicacion[a]!
          .toLowerCase()
          .compareTo(widget.nombresUbicacion[b]!.toLowerCase()));
    if (grupos.containsKey(_sinUbicacion)) orden.add(_sinUbicacion);

    if (widget.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text(widget.textoVacio)),
          ),
        ]),
      );
    }

    final hijos = <Widget>[];
    for (final g in orden) {
      final lista = grupos[g]!;
      final abierto = !_cerrados.contains(g);
      final nombre =
          g == _sinUbicacion ? 'Sin ubicación' : widget.nombresUbicacion[g]!;
      hijos.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Material(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _alternar(g),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(children: [
                Icon(abierto ? Icons.expand_more : Icons.chevron_right),
                const SizedBox(width: 4),
                Icon(
                    g == _sinUbicacion ? Icons.location_off : Icons.location_on,
                    size: 18,
                    color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Text('${lista.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ),
      ));
      if (abierto) hijos.addAll(lista.map(widget.itemBuilder));
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
        children: hijos,
      ),
    );
  }
}

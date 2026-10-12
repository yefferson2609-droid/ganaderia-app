import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/mi_finca.dart';
import '../../core/providers/finca_provider.dart';
import '../../core/theme/app_theme.dart';

/// Una finca vista por el vendedor (resumen de `panel_fincas`).
class _FincaPanel {
  final String id;
  final String nombre;
  final String codigo;
  final String estado;
  final DateTime? pruebaHasta;
  final String? notas;
  final DateTime creada;
  final String? duenoId;
  final String duenoNombre;
  final String duenoCorreo;
  final int miembros;
  final int pendientes;
  final int vacas;
  final int toros;
  final int terneros;
  final int caballos;
  final DateTime? ultimaActividad;

  _FincaPanel.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        nombre = m['nombre'] as String,
        codigo = m['codigo'] as String,
        estado = m['estado'] as String,
        pruebaHasta = _fecha(m['prueba_hasta']),
        notas = m['notas_vendedor'] as String?,
        creada = _fecha(m['created_at'])!,
        duenoId = m['dueno_id'] as String?,
        duenoNombre = (m['dueno_nombre'] as String?) ?? '—',
        duenoCorreo = (m['dueno_correo'] as String?) ?? '',
        miembros = (m['miembros'] as num?)?.toInt() ?? 0,
        pendientes = (m['pendientes'] as num?)?.toInt() ?? 0,
        vacas = (m['vacas'] as num?)?.toInt() ?? 0,
        toros = (m['toros'] as num?)?.toInt() ?? 0,
        terneros = (m['terneros'] as num?)?.toInt() ?? 0,
        caballos = (m['caballos'] as num?)?.toInt() ?? 0,
        ultimaActividad = _fecha(m['ultima_actividad']);

  static DateTime? _fecha(Object? v) =>
      v == null ? null : DateTime.tryParse(v as String)?.toLocal();

  int get animales => vacas + toros + terneros + caballos;
}

const _estados = {
  'pendiente': ('En revisión', AppColors.warning),
  'prueba': ('Prueba', AppColors.info),
  'activa': ('Activa', AppColors.success),
  'suspendida': ('Suspendida', AppColors.danger),
};

/// Panel del súper administrador: todas las fincas, sus dueños y uso;
/// activar, dar prueba, suspender y abrir cualquier finca para soporte.
class PanelVendedorScreen extends StatefulWidget {
  const PanelVendedorScreen({super.key});

  @override
  State<PanelVendedorScreen> createState() => _PanelVendedorScreenState();
}

class _PanelVendedorScreenState extends State<PanelVendedorScreen> {
  final _supabase = Supabase.instance.client;
  final _fecha = DateFormat('dd/MM/yyyy');
  List<_FincaPanel> _fincas = [];
  bool _loading = true;
  String? _error;
  String _buscar = '';
  String? _filtroEstado;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _supabase.rpc('panel_fincas') as List;
      _fincas = rows
          .map((r) => _FincaPanel.fromMap((r as Map).cast<String, dynamic>()))
          .toList();
    } on PostgrestException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Se necesita internet para ver el panel.';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Cuántas fincas tiene registradas cada dueño.
  Map<String, int> get _fincasPorDueno {
    final m = <String, int>{};
    for (final f in _fincas) {
      if (f.duenoId != null) m[f.duenoId!] = (m[f.duenoId!] ?? 0) + 1;
    }
    return m;
  }

  Future<void> _cambiarEstado(_FincaPanel f, String estado, {int? dias}) async {
    try {
      await _supabase.rpc('cambiar_estado_finca', params: {
        'p_finca': f.id,
        'p_estado': estado,
        'p_dias_prueba': dias,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${f.nombre}: ${_estados[estado]!.$1}'),
          backgroundColor: AppColors.success));
      await _load();
    } on PostgrestException catch (e) {
      _snackError(e.message);
    } catch (_) {
      _snackError('No se pudo guardar. Revisa el internet.');
    }
  }

  void _snackError(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t), backgroundColor: AppColors.danger));
  }

  Future<int?> _pedirDias() async {
    final ctrl = TextEditingController(text: '30');
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Días de prueba'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Días desde hoy'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
              onPressed: () {
                final n = int.tryParse(ctrl.text.trim());
                if (n != null && n > 0) Navigator.pop(ctx, n);
              },
              child: const Text('Dar prueba')),
        ],
      ),
    );
  }

  Future<void> _abrirFinca(_FincaPanel f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Abrir ${f.nombre}'),
        content: const Text(
            'Entrarás como soporte con acceso completo: lo que cambies se '
            'guarda en los datos del cliente. Ten cuidado.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Abrir')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final fp = context.read<FincaProvider>();
    await fp.abrir(MiFinca.soporte(
        fincaId: f.id, nombre: f.nombre, codigo: f.codigo, estadoFinca: f.estado));
    if (mounted) context.go('/dashboard');
  }

  Future<void> _opciones(_FincaPanel f) async {
    final accion = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(f.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${f.duenoNombre} · ${f.duenoCorreo}'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.login, color: AppColors.primary),
                title: const Text('Abrir finca (soporte)'),
                onTap: () => Navigator.pop(ctx, 'abrir'),
              ),
              if (f.estado != 'activa')
                ListTile(
                  leading: const Icon(Icons.check_circle, color: AppColors.success),
                  title: const Text('Activar'),
                  onTap: () => Navigator.pop(ctx, 'activa'),
                ),
              ListTile(
                leading: const Icon(Icons.timer_outlined, color: AppColors.info),
                title: const Text('Dar prueba por días'),
                onTap: () => Navigator.pop(ctx, 'prueba'),
              ),
              if (f.estado != 'suspendida')
                ListTile(
                  leading: const Icon(Icons.block, color: AppColors.danger),
                  title: const Text('Suspender'),
                  onTap: () => Navigator.pop(ctx, 'suspendida'),
                ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: Text('Copiar código (${f.codigo})'),
                onTap: () => Navigator.pop(ctx, 'codigo'),
              ),
              ListTile(
                leading: const Icon(Icons.alternate_email),
                title: const Text('Copiar correo del dueño'),
                onTap: () => Navigator.pop(ctx, 'correo'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || accion == null) return;
    switch (accion) {
      case 'abrir':
        await _abrirFinca(f);
      case 'activa':
        await _cambiarEstado(f, 'activa');
      case 'prueba':
        final dias = await _pedirDias();
        if (dias != null) await _cambiarEstado(f, 'prueba', dias: dias);
      case 'suspendida':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Suspender finca'),
            content: Text(
                'Nadie de ${f.nombre} podrá usarla hasta que la actives. Sus datos no se borran.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Suspender')),
            ],
          ),
        );
        if (ok == true) await _cambiarEstado(f, 'suspendida');
      case 'codigo':
        await Clipboard.setData(ClipboardData(text: f.codigo));
      case 'correo':
        await Clipboard.setData(ClipboardData(text: f.duenoCorreo));
    }
  }

  @override
  Widget build(BuildContext context) {
    final porDueno = _fincasPorDueno;
    final b = _buscar.toLowerCase();
    final lista = _fincas.where((f) {
      if (_filtroEstado != null && f.estado != _filtroEstado) return false;
      if (b.isEmpty) return true;
      return f.nombre.toLowerCase().contains(b) ||
          f.duenoNombre.toLowerCase().contains(b) ||
          f.duenoCorreo.toLowerCase().contains(b) ||
          f.codigo.toLowerCase().contains(b);
    }).toList();
    final duenos = porDueno.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel del vendedor'),
        leading: BackButton(onPressed: () => context.go('/fincas?elegir=1')),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _load),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(_error!),
                ),
              ),
            if (_loading && _fincas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_fincas.isNotEmpty) ...[
              Text('${_fincas.length} fincas · $duenos dueños',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: Text('Todas (${_fincas.length})'),
                    selected: _filtroEstado == null,
                    onSelected: (_) => setState(() => _filtroEstado = null),
                  ),
                  for (final e in _estados.entries)
                    ChoiceChip(
                      label: Text(
                          '${e.value.$1} (${_fincas.where((f) => f.estado == e.key).length})'),
                      selected: _filtroEstado == e.key,
                      onSelected: (_) => setState(() =>
                          _filtroEstado = _filtroEstado == e.key ? null : e.key),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Buscar finca, dueño, correo o código',
                ),
                onChanged: (v) => setState(() => _buscar = v.trim()),
              ),
              const SizedBox(height: 12),
            ],
            if (!_loading && _fincas.isEmpty && _error == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Todavía no hay fincas registradas.'),
              ),
            for (final f in lista)
              _tarjeta(f, porDueno[f.duenoId] ?? 1),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta(_FincaPanel f, int fincasDelDueno) {
    final (texto, color) = _estados[f.estado] ?? (f.estado, Colors.grey);
    final estadoTexto = f.estado == 'prueba' && f.pruebaHasta != null
        ? '$texto hasta ${_fecha.format(f.pruebaHasta!)}'
        : texto;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _opciones(f),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(f.nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(estadoTexto,
                        style: TextStyle(color: color, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Dueño: ${f.duenoNombre} · ${f.duenoCorreo}'),
              if (fincasDelDueno > 1)
                Text('Este dueño tiene $fincasDelDueno fincas',
                    style: const TextStyle(color: AppColors.info)),
              const SizedBox(height: 4),
              Text(
                '${f.miembros} usuarios'
                '${f.pendientes > 0 ? ' (+${f.pendientes} por aprobar)' : ''}'
                ' · ${f.animales} animales '
                '(${f.vacas} vacas, ${f.toros} toros, ${f.terneros} levante, ${f.caballos} caballos)',
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
              Text(
                'Registrada ${_fecha.format(f.creada)} · Código ${f.codigo}'
                ' · Último uso: ${f.ultimaActividad == null ? 'sin datos' : _fecha.format(f.ultimaActividad!)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

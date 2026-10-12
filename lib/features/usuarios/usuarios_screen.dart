import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/local_db.dart';
import '../../core/providers/finca_provider.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/theme/app_theme.dart';

/// Un miembro de la finca, leído de Supabase (necesita internet).
class _Miembro {
  final String id;
  final String usuarioId;
  final String nombre;
  final String correo;
  final String rol;
  final String estado;

  _Miembro.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        usuarioId = m['usuario_id'] as String,
        nombre = m['nombre'] as String,
        correo = (m['correo'] as String?) ?? '',
        rol = m['rol'] as String,
        estado = m['estado'] as String;

  String get rolTexto => switch (rol) {
        'dueno' => 'Dueño',
        'admin' => 'Administrador',
        _ => 'Trabajador',
      };
}

/// Usuarios de la finca: código para invitar, solicitudes por aprobar y
/// miembros (rol, activar/desactivar, permisos).
class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final _supabase = Supabase.instance.client;
  List<_Miembro> _miembros = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fincaId = LocalDb.instance.fincaId;
    if (fincaId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _supabase
          .from('miembros_finca')
          .select('id, usuario_id, nombre, correo, rol, estado')
          .eq('finca_id', fincaId)
          .order('nombre');
      _miembros = rows.map(_Miembro.fromMap).toList();
    } catch (_) {
      _error = 'Para ver y aprobar usuarios se necesita internet.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _gestionar(_Miembro m, String estado, {String? rol}) async {
    try {
      await _supabase.rpc('gestionar_miembro', params: {
        'p_miembro': m.id,
        'p_estado': estado,
        'p_rol': rol,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Listo'), backgroundColor: AppColors.success));
      await _load();
      // Trae los permisos y la lista de usuarios actualizados.
      if (mounted) context.read<SyncProvider>().syncAll();
    } on PostgrestException catch (e) {
      _errorSnack(e.message);
    } catch (_) {
      _errorSnack('No se pudo guardar. Revisa el internet.');
    }
  }

  void _errorSnack(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(texto), backgroundColor: AppColors.danger));
  }

  Future<void> _aprobar(_Miembro m) async {
    final rol = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Aprobar a ${m.nombre}'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'empleado'),
            child: const ListTile(
              leading: Icon(Icons.person),
              title: Text('Como trabajador'),
              subtitle: Text('Solo actividades y solicitudes; tú le das más permisos'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'admin'),
            child: const ListTile(
              leading: Icon(Icons.admin_panel_settings),
              title: Text('Como administrador'),
              subtitle: Text('Ve y maneja todo, incluidos usuarios'),
            ),
          ),
        ],
      ),
    );
    if (rol != null) await _gestionar(m, 'aprobado', rol: rol);
  }

  Future<void> _opciones(_Miembro m) async {
    final accion = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(m.nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${m.rolTexto} · ${m.correo}'),
            ),
            const Divider(height: 1),
            if (m.estado == 'aprobado') ...[
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Permisos por módulo'),
                onTap: () => Navigator.pop(ctx, 'permisos'),
              ),
              if (m.rol == 'empleado')
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('Hacer administrador'),
                  onTap: () => Navigator.pop(ctx, 'admin'),
                )
              else
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Pasar a trabajador'),
                  onTap: () => Navigator.pop(ctx, 'empleado'),
                ),
              ListTile(
                leading: const Icon(Icons.block, color: AppColors.danger),
                title: const Text('Quitar acceso a la finca'),
                onTap: () => Navigator.pop(ctx, 'inactivo'),
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.check_circle, color: AppColors.success),
                title: const Text('Devolver el acceso'),
                onTap: () => Navigator.pop(ctx, 'reactivar'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || accion == null) return;
    switch (accion) {
      case 'permisos':
        await context.push('/usuarios/${m.usuarioId}/permisos');
      case 'admin':
      case 'empleado':
        await _gestionar(m, 'aprobado', rol: accion);
      case 'inactivo':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Quitar acceso'),
            content: Text(
                '${m.nombre} ya no podrá ver ni guardar datos de esta finca.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Quitar acceso')),
            ],
          ),
        );
        if (ok == true) await _gestionar(m, 'inactivo');
      case 'reactivar':
        await _gestionar(m, 'aprobado');
    }
  }

  @override
  Widget build(BuildContext context) {
    final finca = context.watch<FincaProvider>().actual;
    final pendientes = _miembros.where((m) => m.estado == 'pendiente').toList();
    final activos = _miembros.where((m) => m.estado == 'aprobado').toList();
    final otros = _miembros
        .where((m) => m.estado == 'inactivo' || m.estado == 'rechazado')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        leading: BackButton(onPressed: () => context.go('/dashboard')),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (finca != null) _CodigoCard(codigo: finca.codigo),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.wifi_off),
                  title: Text(_error!),
                  trailing: TextButton(
                      onPressed: _load, child: const Text('Reintentar')),
                ),
              )
            else ...[
              if (pendientes.isNotEmpty) ...[
                _titulo('Piden entrar (${pendientes.length})'),
                for (final m in pendientes)
                  Card(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    child: ListTile(
                      leading: const Icon(Icons.person_add_alt_1,
                          color: AppColors.warning),
                      title: Text(m.nombre,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(m.correo),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.danger),
                            tooltip: 'Rechazar',
                            onPressed: () => _gestionar(m, 'rechazado'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check, color: AppColors.success),
                            tooltip: 'Aprobar',
                            onPressed: () => _aprobar(m),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              _titulo('Miembros (${activos.length})'),
              for (final m in activos) _miembroTile(m),
              if (otros.isNotEmpty) ...[
                _titulo('Sin acceso'),
                for (final m in otros) _miembroTile(m),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _miembroTile(_Miembro m) {
    final activo = m.estado == 'aprobado';
    final esYo = m.usuarioId == _supabase.auth.currentUser?.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              activo ? AppColors.primaryContainer : Colors.grey[200],
          child: Icon(
              m.rol == 'empleado' ? Icons.person : Icons.admin_panel_settings,
              color: activo ? AppColors.primary : Colors.grey),
        ),
        title: Text(esYo ? '${m.nombre} (tú)' : m.nombre,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${m.rolTexto} · ${m.correo}'),
        // Al dueño nadie lo cambia; uno mismo tampoco se quita el acceso.
        trailing: m.rol == 'dueno' || esYo
            ? null
            : const Icon(Icons.more_vert),
        onTap: m.rol == 'dueno' || esYo ? null : () => _opciones(m),
      ),
    );
  }
}

class _CodigoCard extends StatelessWidget {
  final String codigo;
  const _CodigoCard({required this.codigo});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Código de la finca',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    codigo,
                    style: const TextStyle(
                        fontSize: 28,
                        letterSpacing: 4,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copiar',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: codigo));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Código copiado')));
                  },
                ),
              ],
            ),
            const Text(
              'Pásaselo a tu trabajador (por WhatsApp, por ejemplo). Él crea '
              'su cuenta, toca "Unirme con un código" y tú lo apruebas aquí.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

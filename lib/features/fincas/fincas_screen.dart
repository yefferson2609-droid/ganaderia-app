import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/models/mi_finca.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/finca_provider.dart';
import '../../core/theme/app_theme.dart';

/// "Mis fincas": elegir finca, registrar una nueva o entrar con un código.
class FincasScreen extends StatefulWidget {
  /// true cuando se llega desde "Cambiar de finca": no abre ninguna sola.
  final bool elegir;
  const FincasScreen({super.key, this.elegir = false});

  @override
  State<FincasScreen> createState() => _FincasScreenState();
}

class _FincasScreenState extends State<FincasScreen> {
  bool _autoAbierta = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<FincaProvider>().cargar();
      _abrirSiHayUna();
    });
  }

  /// Con una sola finca disponible se entra directo.
  void _abrirSiHayUna() {
    if (!mounted || widget.elegir || _autoAbierta) return;
    final fp = context.read<FincaProvider>();
    final usables = fp.fincas.where((f) => f.usable).toList();
    if (usables.length == 1 && fp.fincas.length == 1) {
      _autoAbierta = true;
      _abrir(usables.first);
    }
  }

  Future<void> _abrir(MiFinca f) async {
    if (!f.usable) {
      _aviso(f.motivoBloqueo ?? 'No disponible', AppColors.warning);
      return;
    }
    await context.read<FincaProvider>().abrir(f);
    if (mounted) context.go('/dashboard');
  }

  void _aviso(String texto, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(texto), backgroundColor: color));
  }

  /// Formulario corto para registrar finca o unirse con código.
  Future<void> _formulario({required bool crear}) async {
    final auth = context.read<AuthProvider>();
    final fp = context.read<FincaProvider>();
    final campo1 = TextEditingController();
    final campo2 = TextEditingController(text: auth.nombreRegistrado);
    final formKey = GlobalKey<FormState>();
    var enviando = false;
    String? errorTexto;

    // true = enviado; null = cancelado.
    final enviado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(crear ? 'Registrar mi finca' : 'Unirme a una finca'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  crear
                      ? 'Quedará en revisión. Cuando la activemos podrás usarla.'
                      : 'Pídele el código al dueño de la finca. Él debe aprobarte.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: campo1,
                  autofocus: true,
                  textCapitalization: crear
                      ? TextCapitalization.words
                      : TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: crear ? 'Nombre de la finca' : 'Código (6 letras)',
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return crear ? 'Escribe el nombre' : 'Escribe el código';
                    if (!crear && t.replaceAll(' ', '').length != 6) {
                      return 'El código tiene 6 letras o números';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: campo2,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Tu nombre'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Escribe tu nombre' : null,
                ),
                if (errorTexto != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(errorTexto!,
                        style: const TextStyle(color: AppColors.danger)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: enviando ? null : () => Navigator.pop(ctx, null),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: enviando
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setD(() => enviando = true);
                      final e = crear
                          ? await fp.crearFinca(campo1.text.trim(), campo2.text.trim())
                          : await fp.unirse(campo1.text.trim(), campo2.text.trim());
                      if (!ctx.mounted) return;
                      if (e != null) {
                        setD(() {
                          enviando = false;
                          errorTexto = e;
                        });
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
              child: Text(crear ? 'Registrar' : 'Enviar'),
            ),
          ],
        ),
      ),
    );
    if (enviado != true || !mounted) return;
    _aviso(
        crear
            ? 'Finca registrada. Queda en revisión hasta que la activemos.'
            : 'Solicitud enviada. Espera que el dueño te apruebe.',
        AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FincaProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis fincas'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: fp.cargando ? null : fp.cargar,
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'logout') {
                await context.read<AuthProvider>().signOut();
                if (context.mounted) context.go('/login');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fp.cargar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (auth.currentUser?.email != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Sesión: ${auth.currentUser!.email}',
                    style: TextStyle(color: Colors.grey[600])),
              ),
            if (fp.error != null)
              Card(
                color: AppColors.warning.withValues(alpha: 0.15),
                child: ListTile(
                  leading: const Icon(Icons.wifi_off),
                  title: Text(fp.error!),
                ),
              ),
            if (fp.cargando && fp.fincas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!fp.cargando && fp.fincas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Todavía no perteneces a ninguna finca.\n\n'
                  '• Si eres el dueño, registra tu finca.\n'
                  '• Si trabajas en una finca, pide el código al dueño y únete.',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            for (final f in fp.fincas) _FincaCard(finca: f, onTap: () => _abrir(f)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _formulario(crear: true),
              icon: const Icon(Icons.add_home_work_outlined),
              label: const Text('Registrar mi finca'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _formulario(crear: false),
              icon: const Icon(Icons.vpn_key_outlined),
              label: const Text('Unirme con un código'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FincaCard extends StatelessWidget {
  final MiFinca finca;
  final VoidCallback onTap;
  const _FincaCard({required this.finca, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final motivo = finca.motivoBloqueo;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: finca.usable
              ? AppColors.primaryContainer
              : Colors.grey[200],
          child: Icon(Icons.agriculture,
              color: finca.usable ? AppColors.primary : Colors.grey),
        ),
        title: Text(finca.nombre,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(motivo == null
            ? finca.rolTexto
            : '${finca.rolTexto} · $motivo'),
        trailing: Icon(finca.usable ? Icons.chevron_right : Icons.hourglass_empty),
        onTap: onTap,
      ),
    );
  }
}

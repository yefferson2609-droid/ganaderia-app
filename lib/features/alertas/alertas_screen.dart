import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/alertas_service.dart';
import '../../core/theme/app_theme.dart';

const _iconos = {
  TipoAlerta.partos: (Icons.child_friendly, AppColors.info),
  TipoAlerta.secar: (Icons.water_drop_outlined, AppColors.warning),
  TipoAlerta.vacias: (Icons.hourglass_bottom, AppColors.danger),
  TipoAlerta.vitamina: (Icons.medication_liquid, AppColors.accentPurple),
  TipoAlerta.destete: (Icons.event_available, AppColors.warning),
  TipoAlerta.categoria: (Icons.trending_up, AppColors.info),
};

class AlertasScreen extends StatefulWidget {
  const AlertasScreen({super.key});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  Map<TipoAlerta, List<Alerta>> _alertas = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _alertas = await AlertasService().generar();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alertas del hato')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: TipoAlerta.values.map((t) {
                  final lista = _alertas[t] ?? [];
                  final (titulo, ayuda) = kTipoAlertaInfo[t]!;
                  final (icono, color) = _iconos[t]!;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      initiallyExpanded: lista.isNotEmpty && lista.length <= 8,
                      leading: Icon(icono, color: lista.isEmpty ? Colors.grey : color),
                      title: Text('$titulo (${lista.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(ayuda, style: const TextStyle(fontSize: 12)),
                      children: lista.isEmpty
                          ? [
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Nada pendiente ✔'),
                              )
                            ]
                          : lista
                              .map((a) => ListTile(
                                    dense: true,
                                    title: Text(a.titulo,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    subtitle: Text(a.detalle),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => context
                                        .push(a.ruta)
                                        .then((_) => _load()),
                                  ))
                              .toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}

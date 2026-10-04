import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/nomina.dart';
import '../../core/repositories/nomina_repository.dart';
import '../../core/theme/app_theme.dart';
import 'nomina_screen.dart' show money;

final _fmt = DateFormat('dd/MM/yyyy');

/// Detalle exacto de una semana pagada (se abre también desde Finanzas).
class NominaSemanaScreen extends StatefulWidget {
  final String id;
  const NominaSemanaScreen({super.key, required this.id});

  @override
  State<NominaSemanaScreen> createState() => _NominaSemanaScreenState();
}

class _NominaSemanaScreenState extends State<NominaSemanaScreen> {
  NominaSemana? _semana;
  List<FilaNomina> _filas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = NominaRepository();
    _semana = await repo.getSemanaPorId(widget.id);
    if (_semana != null) _filas = await repo.detalle(widget.id);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _semana;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de nómina')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : s == null
              ? const Center(child: Text('Nómina no encontrada'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Semana del ${_fmt.format(s.semanaFin.subtract(const Duration(days: 6)))} '
                                'al ${_fmt.format(s.semanaFin)}',
                                style: const TextStyle(color: Colors.grey)),
                            Text(money.format(s.total),
                                style: const TextStyle(
                                    fontSize: 28, fontWeight: FontWeight.bold)),
                            Text(
                                '${s.trabajadores} trabajadores · '
                                '${s.automatica ? 'pagada automáticamente' : 'pagada manualmente'}'
                                '${s.pagadaAt != null ? ' el ${_fmt.format(s.pagadaAt!.toLocal())}' : ''}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._filas.map((f) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(f.nombre,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  Text(money.format(f.neto),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ]),
                                const SizedBox(height: 4),
                                _linea('Sueldo', f.salario),
                                if (f.bonos > 0)
                                  _linea('Bonos / extras', f.bonos,
                                      signo: '+', color: AppColors.success),
                                if (f.anticipos > 0)
                                  _linea('Anticipos', f.anticipos,
                                      signo: '−', color: AppColors.danger),
                                if (f.cuotas > 0)
                                  _linea('Cuota de préstamo', f.cuotas,
                                      signo: '−', color: AppColors.danger),
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
    );
  }

  Widget _linea(String label, double v, {String signo = '', Color? color}) =>
      Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text('$signo${money.format(v)}',
            style: TextStyle(fontSize: 13, color: color)),
      ]);
}

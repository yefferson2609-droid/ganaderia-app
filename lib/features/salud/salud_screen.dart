import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/salud.dart';
import '../../core/repositories/registro_salud_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/animal_nombre.dart';
import '../../core/widgets/animal_face.dart';

final _fmt = DateFormat('dd/MM/yyyy');

class SaludScreen extends StatefulWidget {
  const SaludScreen({super.key});

  @override
  State<SaludScreen> createState() => _SaludScreenState();
}

class _SaludScreenState extends State<SaludScreen> {
  final _repo = RegistroSaludRepository();
  List<RegistroSalud> _enTratamiento = [];
  List<TratamientoSalud> _dosis = [];
  final Map<String, String> _nombres = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _enTratamiento = await _repo.getEnTratamiento();
    _dosis = await _repo.getDosisProgramadas();
    for (final r in _enTratamiento) {
      _nombres['${r.animalTipo}:${r.animalId}'] =
          await nombreAnimal(r.animalTipo, r.animalId);
    }
    for (final d in _dosis) {
      if (d.animalTipo == null || d.animalId == null) continue;
      _nombres['${d.animalTipo}:${d.animalId}'] ??=
          await nombreAnimal(d.animalTipo!, d.animalId!);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final titulo = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);
    final hoy = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Salud')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Animales en tratamiento actualmente', style: titulo),
                  const SizedBox(height: 8),
                  if (_enTratamiento.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                            child: Text('Ningún animal está en tratamiento ahora')),
                      ),
                    )
                  else
                    ..._enTratamiento.map((r) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: AnimalFace(
                                tipo: r.animalTipo,
                                estadoColor: AppColors.danger),
                            title: Text(
                                _nombres['${r.animalTipo}:${r.animalId}'] ??
                                    kAnimalTipoLabels[r.animalTipo] ??
                                    'Animal'),
                            subtitle: Text(
                                '${r.diagnostico}\nEn tratamiento desde ${_fmt.format(r.fechaInicio)}'),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context
                                .push(rutaAnimal(r.animalTipo, r.animalId))
                                .then((_) => _load()),
                          ),
                        )),
                  const SizedBox(height: 24),
                  Text('Próximas dosis', style: titulo),
                  const SizedBox(height: 8),
                  if (_dosis.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No hay dosis programadas')),
                      ),
                    )
                  else
                    ..._dosis.map((d) {
                      final vencida = !d.fecha
                          .isAfter(DateTime(hoy.year, hoy.month, hoy.day, 23, 59));
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(Icons.vaccines,
                              color: vencida
                                  ? AppColors.danger
                                  : AppColors.warning),
                          title: Text(
                              '${d.medicamento}${d.dosis != null ? ' · ${d.dosis}' : ''}'),
                          subtitle: Text(
                              '${_nombres['${d.animalTipo}:${d.animalId}'] ?? ''}\n'
                              '${vencida ? 'Para aplicar: ' : 'Programada: '}${_fmt.format(d.fecha)}'),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: 'Marcar dosis como aplicada',
                            icon: const Icon(Icons.done_all,
                                color: AppColors.success),
                            onPressed: () async {
                              await _repo.marcarTratamientoAplicado(d.id);
                              _load();
                            },
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

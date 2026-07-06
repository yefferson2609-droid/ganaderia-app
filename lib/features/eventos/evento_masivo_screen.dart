import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/tipo_evento.dart';
import '../../core/models/vaca.dart';
import '../../core/repositories/evento_masivo_repository.dart';
import '../../core/repositories/tipo_evento_repository.dart';
import '../../core/repositories/vaca_repository.dart';

class EventoMasivoScreen extends StatefulWidget {
  const EventoMasivoScreen({super.key});

  @override
  State<EventoMasivoScreen> createState() => _EventoMasivoScreenState();
}

class _EventoMasivoScreenState extends State<EventoMasivoScreen> {
  final _tipoRepo = TipoEventoRepository();
  final _vacaRepo = VacaRepository();
  final _eventoRepo = EventoMasivoRepository();

  List<TipoEvento> _tipos = [];
  List<Vaca> _vacas = [];
  Set<String> _seleccionadas = {};
  String? _tipoSeleccionado;
  DateTime _fecha = DateTime.now();
  final _notasCtrl = TextEditingController();
  bool _loading = false;
  bool _loadingData = true;
  String _filtroEstado = 'todos';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _tipos = await _tipoRepo.getAll(soloActivos: true);
    _vacas = await _vacaRepo.getAll();
    if (_tipos.isNotEmpty) _tipoSeleccionado = _tipos.first.id;
    setState(() => _loadingData = false);
  }

  List<Vaca> get _vacasFiltradas {
    if (_filtroEstado == 'todos') return _vacas;
    return _vacas.where((v) => v.estado == _filtroEstado).toList();
  }

  Future<void> _guardar() async {
    if (_tipoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un tipo de evento')));
      return;
    }
    if (_seleccionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una vaca')));
      return;
    }

    setState(() => _loading = true);
    await _eventoRepo.registrar(
      tipoEventoId: _tipoSeleccionado!,
      vacaIds: _seleccionadas.toList(),
      fecha: _fecha,
      notas: _notasCtrl.text.isEmpty ? null : _notasCtrl.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Evento registrado para ${_seleccionadas.length} vaca${_seleccionadas.length != 1 ? 's' : ''}'),
        backgroundColor: Colors.green,
      ));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evento Masivo'),
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Configuración del evento
                Container(
                  color: Colors.grey[50],
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _tipoSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de evento',
                          isDense: true,
                        ),
                        items: _tipos
                            .map((t) => DropdownMenuItem(
                                value: t.id, child: Text(t.nombre)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _tipoSeleccionado = v),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _fecha,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => _fecha = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fecha',
                            isDense: true,
                          ),
                          child: Text(
                              DateFormat('dd/MM/yyyy').format(_fecha)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notasCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Notas (opcional)',
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                // Filtros
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text('${_seleccionadas.length} seleccionadas',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      ...['todos', 'activa', 'vendida', 'muerta'].map((e) =>
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: FilterChip(
                              label: Text(e == 'todos'
                                  ? 'Todas'
                                  : e[0].toUpperCase() + e.substring(1),
                                  style: const TextStyle(fontSize: 11)),
                              selected: _filtroEstado == e,
                              onSelected: (_) =>
                                  setState(() => _filtroEstado = e),
                              padding: EdgeInsets.zero,
                            ),
                          )),
                    ],
                  ),
                ),
                // Seleccionar todas
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _seleccionadas =
                            _vacasFiltradas.map((v) => v.id).toSet()),
                        child: const Text('Seleccionar todas'),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _seleccionadas = {}),
                        child: const Text('Deseleccionar'),
                      ),
                    ],
                  ),
                ),
                // Lista de vacas
                Expanded(
                  child: _vacasFiltradas.isEmpty
                      ? const Center(child: Text('No hay vacas'))
                      : ListView.builder(
                          itemCount: _vacasFiltradas.length,
                          itemBuilder: (_, i) {
                            final vaca = _vacasFiltradas[i];
                            final seleccionada =
                                _seleccionadas.contains(vaca.id);
                            return CheckboxListTile(
                              value: seleccionada,
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _seleccionadas.add(vaca.id);
                                } else {
                                  _seleccionadas.remove(vaca.id);
                                }
                              }),
                              title: Text('Vaca #${vaca.numero}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  '${vaca.estado[0].toUpperCase()}${vaca.estado.substring(1)}'
                                  '${vaca.estadoReproductivo == 'prenada' ? ' · Preñada' : ''}'),
                              secondary: CircleAvatar(
                                radius: 18,
                                backgroundColor: seleccionada
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey[200],
                                child: Icon(Icons.check,
                                    size: 16,
                                    color: seleccionada
                                        ? Colors.white
                                        : Colors.grey),
                              ),
                            );
                          },
                        ),
                ),
                // Botón guardar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: _loading ? null : _guardar,
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            'Registrar evento (${_seleccionadas.length} vacas)'),
                  ),
                ),
              ],
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/concepto_financiero.dart';
import '../../core/models/ubicacion.dart';
import '../../core/repositories/concepto_financiero_repository.dart';
import '../../core/repositories/movimiento_financiero_repository.dart';
import '../../core/repositories/ubicacion_repository.dart';

class MovimientoFormScreen extends StatefulWidget {
  final String? id;
  final String tipoInicial;
  const MovimientoFormScreen({
    super.key,
    this.id,
    this.tipoInicial = 'ingreso',
  });

  @override
  State<MovimientoFormScreen> createState() => _MovimientoFormScreenState();
}

class _MovimientoFormScreenState extends State<MovimientoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _movimientoRepo = MovimientoFinancieroRepository();
  final _conceptoRepo = ConceptoFinancieroRepository();
  final _ubicacionRepo = UbicacionRepository();

  final _montoCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  late String _tipo;
  String? _conceptoId;
  String? _ubicacionId;
  DateTime _fecha = DateTime.now();
  List<ConceptoFinanciero> _conceptos = [];
  List<Ubicacion> _ubicaciones = [];
  bool _loading = false;
  bool _loadingData = true;

  bool get _isEditing => widget.id != null;

  @override
  void initState() {
    super.initState();
    _tipo = widget.tipoInicial;
    _loadData();
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loadingData = true);
    if (_isEditing) {
      final m = await _movimientoRepo.getById(widget.id!);
      if (m != null) {
        _tipo = m.tipo;
        _conceptoId = m.conceptoId;
        _ubicacionId = m.ubicacionId;
        _fecha = m.fecha;
        _montoCtrl.text = m.monto.toStringAsFixed(2);
        _notaCtrl.text = m.nota ?? '';
      }
    }
    await _loadConceptos();
    _ubicaciones = await _ubicacionRepo.getAll(soloActivas: true);
    setState(() => _loadingData = false);
  }

  Future<void> _loadConceptos() async {
    _conceptos = await _conceptoRepo.getAll(tipo: _tipo, soloActivos: true);
    if (_conceptoId != null && !_conceptos.any((c) => c.id == _conceptoId)) {
      _conceptoId = null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final monto = double.parse(_montoCtrl.text.replaceAll(',', '.'));
    final nota = _notaCtrl.text.trim().isEmpty ? null : _notaCtrl.text.trim();

    if (_isEditing) {
      final m = await _movimientoRepo.getById(widget.id!);
      if (m != null) {
        await _movimientoRepo.update(m.copyWith(
          tipo: _tipo,
          conceptoId: _conceptoId,
          clearConceptoId: _conceptoId == null,
          nota: nota,
          clearNota: nota == null,
          monto: monto,
          fecha: _fecha,
          ubicacionId: _ubicacionId,
          clearUbicacion: _ubicacionId == null,
        ));
      }
    } else {
      await _movimientoRepo.create(
        tipo: _tipo,
        conceptoId: _conceptoId,
        nota: nota,
        monto: monto,
        fecha: _fecha,
        ubicacionId: _ubicacionId,
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final esIngreso = _tipo == 'ingreso';
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? 'Editar movimiento'
            : esIngreso
                ? 'Nuevo ingreso'
                : 'Nuevo gasto'),
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'ingreso',
                            label: Text('Ingreso'),
                            icon: Icon(Icons.arrow_downward)),
                        ButtonSegment(
                            value: 'gasto',
                            label: Text('Gasto'),
                            icon: Icon(Icons.arrow_upward)),
                      ],
                      selected: {_tipo},
                      onSelectionChanged: (v) {
                        setState(() => _tipo = v.first);
                        _loadConceptos().then((_) => setState(() {}));
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _montoCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monto (USD) *',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Campo requerido';
                        final n = double.tryParse(v.replaceAll(',', '.'));
                        if (n == null || n <= 0) return 'Monto inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _conceptoId,
                      decoration: const InputDecoration(
                        labelText: 'Concepto (opcional)',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: _conceptos
                          .map((c) => DropdownMenuItem(
                              value: c.id, child: Text(c.nombre)))
                          .toList(),
                      onChanged: (v) => setState(() => _conceptoId = v),
                    ),
                    const SizedBox(height: 16),
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
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _ubicacionId,
                      decoration: const InputDecoration(
                        labelText: 'Ubicación (opcional)',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      items: _ubicaciones
                          .map((u) => DropdownMenuItem(
                              value: u.id, child: Text(u.nombre)))
                          .toList(),
                      onChanged: (v) => setState(() => _ubicacionId = v),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nota (opcional)',
                        prefixIcon: Icon(Icons.notes),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _loading ? null : _save,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_isEditing
                              ? 'Guardar cambios'
                              : esIngreso
                                  ? 'Registrar ingreso'
                                  : 'Registrar gasto'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

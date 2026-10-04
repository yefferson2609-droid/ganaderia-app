import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/ubicacion.dart';
import '../../core/repositories/caballo_repository.dart';
import '../../core/repositories/ubicacion_repository.dart';
import '../../core/utils/auditoria.dart';
import '../../core/widgets/raza_field.dart';
import '../../core/utils/edad.dart';

class CaballoFormScreen extends StatefulWidget {
  final String? id;
  const CaballoFormScreen({super.key, this.id});

  @override
  State<CaballoFormScreen> createState() => _CaballoFormScreenState();
}

class _CaballoFormScreenState extends State<CaballoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = CaballoRepository();
  final _nombreCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _razaCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  String _estado = 'activo';
  DateTime? _fechaNacimiento;
  String? _ubicacionId;
  List<Ubicacion> _ubicaciones = [];
  bool _loading = false;
  bool _loadingData = true;

  bool get _isEditing => widget.id != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _colorCtrl.dispose();
    _razaCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _ubicaciones = await UbicacionRepository().getAll(soloActivas: true);
    if (_isEditing) {
      final c = await _repo.getById(widget.id!);
      if (c != null) {
        _nombreCtrl.text = c.nombre;
        _colorCtrl.text = c.color ?? '';
        _razaCtrl.text = c.raza ?? '';
        _notaCtrl.text = c.nota ?? '';
        _estado = c.estado == 'muerto' ? 'fallecido' : c.estado;
        _fechaNacimiento = c.fechaNacimiento;
        _ubicacionId = c.ubicacionId;
      }
    }
    if (!_ubicaciones.any((u) => u.id == _ubicacionId)) _ubicacionId = null;
    setState(() => _loadingData = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    if (_isEditing) {
      final c = await _repo.getById(widget.id!);
      if (c != null) {
        await _repo.update(c.copyWith(
          nombre: _nombreCtrl.text.trim(),
          estado: _estado,
          fechaNacimiento: _fechaNacimiento,
          ubicacionId: _ubicacionId,
          clearUbicacion: _ubicacionId == null,
          color: textoONull(_colorCtrl.text),
          raza: textoONull(_razaCtrl.text),
          nota: textoONull(_notaCtrl.text),
        ));
      }
    } else {
      await _repo.create(
        nombre: _nombreCtrl.text.trim(),
        estado: _estado,
        fechaNacimiento: _fechaNacimiento,
        ubicacionId: _ubicacionId,
        color: textoONull(_colorCtrl.text),
        raza: textoONull(_razaCtrl.text),
        nota: textoONull(_notaCtrl.text),
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Caballo' : 'Nuevo Caballo'),
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
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre *',
                        prefixIcon: Icon(Icons.pets),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _fechaNacimiento ?? DateTime.now(),
                          firstDate: DateTime(1990),
                          lastDate: DateTime.now(),
                        );
                        if (p != null) setState(() => _fechaNacimiento = p);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Fecha de nacimiento',
                          prefixIcon: const Icon(Icons.calendar_today),
                          suffixIcon: _fechaNacimiento != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () =>
                                      setState(() => _fechaNacimiento = null))
                              : null,
                        ),
                        child: Text(
                          _fechaNacimiento != null
                              ? '${DateFormat('dd/MM/yyyy').format(_fechaNacimiento!)}'
                                  ' (${edadTexto(_fechaNacimiento)})'
                              : 'Seleccionar fecha',
                          style: TextStyle(
                              color: _fechaNacimiento != null
                                  ? null
                                  : Colors.grey[600]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _estado,
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'activo', child: Text('Activo')),
                        DropdownMenuItem(
                            value: 'vendido', child: Text('Vendido')),
                        DropdownMenuItem(
                            value: 'fallecido', child: Text('Fallecido')),
                      ],
                      onChanged: (v) => setState(() => _estado = v!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: _ubicacionId,
                      decoration: const InputDecoration(
                          labelText: 'Ubicación',
                          prefixIcon: Icon(Icons.location_on)),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Sin asignar')),
                        ..._ubicaciones.map((u) => DropdownMenuItem(
                            value: u.id, child: Text(u.nombre))),
                      ],
                      onChanged: (v) => setState(() => _ubicacionId = v),
                    ),
                    const SizedBox(height: 16),
                    RazaField(controller: _razaCtrl),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _colorCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Color',
                          prefixIcon: Icon(Icons.palette_outlined)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notaCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Nota (opcional)',
                          prefixIcon: Icon(Icons.notes)),
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
                              : 'Registrar caballo'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/toro.dart';
import '../../core/models/ubicacion.dart';
import '../../core/models/vaca.dart';
import '../../core/repositories/reproduccion_repository.dart';
import '../../core/repositories/toro_repository.dart';
import '../../core/repositories/ubicacion_repository.dart';
import '../../core/repositories/vaca_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/auditoria.dart';
import '../../core/widgets/raza_field.dart';

class ToroFormScreen extends StatefulWidget {
  final String? id;
  const ToroFormScreen({super.key, this.id});

  @override
  State<ToroFormScreen> createState() => _ToroFormScreenState();
}

class _ToroFormScreenState extends State<ToroFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ToroRepository();
  final _vacaRepo = VacaRepository();
  final _ubicacionRepo = UbicacionRepository();
  final _numeroCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _razaCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  DateTime? _fechaNacimiento;
  String _estado = 'activo';
  String? _padreId;
  String? _madreId;
  String? _ubicacionId;

  List<Toro> _torosDisponibles = [];
  List<Vaca> _vacas = [];
  List<Ubicacion> _ubicaciones = [];
  Toro? _toroOriginal;

  bool _loading = false;
  bool _loadingData = false;

  bool get _isEditing => widget.id != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _nombreCtrl.dispose();
    _colorCtrl.dispose();
    _razaCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loadingData = true);
    _torosDisponibles = await _repo.getAll();
    _vacas = await _vacaRepo.getAll();
    _ubicaciones = await _ubicacionRepo.getAll();

    if (_isEditing) {
      _toroOriginal = await _repo.getById(widget.id!);
      if (_toroOriginal != null) {
        _numeroCtrl.text = _toroOriginal!.numero;
        _nombreCtrl.text = _toroOriginal!.nombre;
        _fechaNacimiento = _toroOriginal!.fechaNacimiento;
        _estado = _toroOriginal!.estado == 'muerto'
            ? 'fallecido'
            : _toroOriginal!.estado;
        _colorCtrl.text = _toroOriginal!.color ?? '';
        _razaCtrl.text = _toroOriginal!.raza ?? '';
        _notaCtrl.text = _toroOriginal!.nota ?? '';
        _padreId = _toroOriginal!.padreId;
        _madreId = _toroOriginal!.madreId;
        _ubicacionId = _toroOriginal!.ubicacionId;
      }
    }
    if (!_torosDisponibles.any((t) => t.id == _padreId)) _padreId = null;
    if (!_vacas.any((v) => v.id == _madreId)) _madreId = null;
    if (!_ubicaciones.any((u) => u.id == _ubicacionId)) _ubicacionId = null;
    setState(() => _loadingData = false);
  }

  Future<void> _pickFechaNacimiento() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _fechaNacimiento = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final numero = _numeroCtrl.text.trim();
    final existe = await _repo.existeNumero(numero,
        excludeId: _isEditing ? widget.id : null);
    if (existe) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Ya existe un toro con ese número'),
            backgroundColor: AppColors.danger));
      }
      return;
    }

    if (_isEditing && _toroOriginal != null) {
      await _repo.update(_toroOriginal!.copyWith(
        numero: numero,
        nombre: _nombreCtrl.text.trim(),
        fechaNacimiento: _fechaNacimiento,
        estado: _estado,
        padreId: _padreId,
        clearPadreId: _padreId == null,
        madreId: _madreId,
        clearMadreId: _madreId == null,
        ubicacionId: _ubicacionId,
        clearUbicacion: _ubicacionId == null,
        color: textoONull(_colorCtrl.text),
        raza: textoONull(_razaCtrl.text),
        nota: textoONull(_notaCtrl.text),
      ));
    } else {
      await _repo.create(
        numero: numero,
        nombre: _nombreCtrl.text.trim(),
        fechaNacimiento: _fechaNacimiento,
        estado: _estado,
        padreId: _padreId,
        madreId: _madreId,
        ubicacionId: _ubicacionId,
        color: textoONull(_colorCtrl.text),
        raza: textoONull(_razaCtrl.text),
        nota: textoONull(_notaCtrl.text),
      );
    }
    // Si se puso o cambió la madre (o la fecha), anotar su parto si falta.
    if (_madreId != null &&
        (_toroOriginal?.madreId != _madreId ||
            _toroOriginal?.fechaNacimiento != _fechaNacimiento) &&
        await ReproduccionRepository().partoSiFalta(_madreId!, _fechaNacimiento,
            notas: 'Registrado al poner la madre de $numero') &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('También se registró el parto de la madre. '
              'Si ya está seca, márcala con "Secar vaca".')));
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Toro' : 'Nuevo Toro'),
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
                      controller: _numeroCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Número *',
                        prefixIcon: Icon(Icons.tag),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 16),
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
                      onTap: _pickFechaNacimiento,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha de nacimiento',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _fechaNacimiento != null
                              ? DateFormat('dd/MM/yyyy').format(_fechaNacimiento!)
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
                        DropdownMenuItem(value: 'vendido', child: Text('Vendido')),
                        DropdownMenuItem(value: 'fallecido', child: Text('Fallecido')),
                      ],
                      onChanged: (v) => setState(() => _estado = v!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: _ubicacionId,
                      decoration: const InputDecoration(
                        labelText: 'Ubicación',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Sin asignar')),
                        ..._ubicaciones.map((u) => DropdownMenuItem(
                            value: u.id, child: Text(u.nombre))),
                      ],
                      onChanged: (v) => setState(() => _ubicacionId = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: _padreId,
                      decoration: const InputDecoration(
                        labelText: 'Padre (toro)',
                        prefixIcon: Icon(Icons.male),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Sin registrar')),
                        ..._torosDisponibles
                            .where((t) => t.id != widget.id)
                            .map((t) => DropdownMenuItem(
                                value: t.id, child: Text(t.displayName))),
                      ],
                      onChanged: (v) => setState(() => _padreId = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: _madreId,
                      decoration: const InputDecoration(
                        labelText: 'Madre (vaca)',
                        prefixIcon: Icon(Icons.female),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Sin registrar')),
                        ..._vacas.map((v) => DropdownMenuItem(
                            value: v.id, child: Text('Vaca #${v.numero}'))),
                      ],
                      onChanged: (v) => setState(() => _madreId = v),
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
                              height: 20, width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_isEditing ? 'Guardar cambios' : 'Registrar toro'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

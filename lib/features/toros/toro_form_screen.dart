import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/toro.dart';
import '../../core/models/ubicacion.dart';
import '../../core/models/vaca.dart';
import '../../core/repositories/reproduccion_repository.dart';
import '../../core/repositories/toro_repository.dart';
import '../../core/repositories/ubicacion_repository.dart';
import '../../core/repositories/vaca_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/auditoria.dart';
import '../../core/services/foto_animal_service.dart';
import '../../core/widgets/procedencia_campos.dart';
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
  final _proc = ProcedenciaControl();
  String? _foto; // foto elegida al registrar (se guarda al crear)

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
    _proc.dispose();
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
        _proc.cargar(_toroOriginal!.procedencia);
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

    // Padre o madre de fuera de la finca: no se liga a un animal de aquí.
    final padreId = _proc.padreExterno ? null : _padreId;
    final madreId = _proc.madreExterna ? null : _madreId;

    if (_isEditing && _toroOriginal != null) {
      await _repo.update(_toroOriginal!.copyWith(
        numero: numero,
        nombre: _nombreCtrl.text.trim(),
        fechaNacimiento: _fechaNacimiento,
        estado: _estado,
        padreId: padreId,
        clearPadreId: padreId == null,
        madreId: madreId,
        clearMadreId: madreId == null,
        procedencia: _proc.valor,
        ubicacionId: _ubicacionId,
        clearUbicacion: _ubicacionId == null,
        color: textoONull(_colorCtrl.text),
        raza: textoONull(_razaCtrl.text),
        nota: textoONull(_notaCtrl.text),
      ));
    } else {
      final nuevo = await _repo.create(
        numero: numero,
        nombre: _nombreCtrl.text.trim(),
        fechaNacimiento: _fechaNacimiento,
        estado: _estado,
        padreId: padreId,
        madreId: madreId,
        procedencia: _proc.valor,
        ubicacionId: _ubicacionId,
        color: textoONull(_colorCtrl.text),
        raza: textoONull(_razaCtrl.text),
        nota: textoONull(_notaCtrl.text),
      );
      if (_foto != null) await FotoAnimalService().guardar('toro', nuevo.id, _foto!);
    }
    // Si se puso o cambió la madre (o la fecha), anotar su parto si falta.
    if (madreId != null &&
        (_toroOriginal?.madreId != madreId ||
            _toroOriginal?.fechaNacimiento != _fechaNacimiento) &&
        await ReproduccionRepository().partoSiFalta(madreId, _fechaNacimiento,
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
                    // La foto de un toro ya registrado se cambia en su ficha.
                    if (!_isEditing) ...[
                      FotoAlRegistrar(
                          tipo: 'toro',
                          ruta: _foto,
                          onCambio: (r) => setState(() => _foto = r)),
                      const SizedBox(height: 8),
                    ],
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
                    FechaNacimientoCampo(
                      fecha: _fechaNacimiento,
                      onElegir: _pickFechaNacimiento,
                      onBorrar: () => setState(() => _fechaNacimiento = null),
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
                    const SizedBox(height: 20),
                    // Procedencia: origen, registro y padres (de la finca o de fuera)
                    OrigenCampos(
                        control: _proc,
                        hembra: false,
                        onCambio: () => setState(() {})),
                    const SizedBox(height: 16),
                    PadreCampo(
                      esPadre: true,
                      externo: _proc.padreExterno,
                      onExterno: (v) => setState(() => _proc.padreExterno = v),
                      nombre: _proc.padreNombre,
                      registro: _proc.padreRegistro,
                      raza: _proc.padreRaza,
                      selectorFinca: DropdownButtonFormField<String?>(
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
                    ),
                    const SizedBox(height: 12),
                    PadreCampo(
                      esPadre: false,
                      externo: _proc.madreExterna,
                      onExterno: (v) => setState(() => _proc.madreExterna = v),
                      nombre: _proc.madreNombre,
                      registro: _proc.madreRegistro,
                      raza: _proc.madreRaza,
                      selectorFinca: DropdownButtonFormField<String?>(
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

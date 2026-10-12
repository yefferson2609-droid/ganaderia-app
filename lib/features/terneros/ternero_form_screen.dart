import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/ternero.dart';
import '../../core/models/toro.dart';
import '../../core/models/ubicacion.dart';
import '../../core/models/vaca.dart';
import '../../core/repositories/reproduccion_repository.dart';
import '../../core/repositories/ternero_repository.dart';
import '../../core/repositories/toro_repository.dart';
import '../../core/repositories/ubicacion_repository.dart';
import '../../core/repositories/vaca_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/auditoria.dart';
import '../../core/widgets/raza_field.dart';

class TerneroFormScreen extends StatefulWidget {
  final String? id;
  const TerneroFormScreen({super.key, this.id});

  @override
  State<TerneroFormScreen> createState() => _TerneroFormScreenState();
}

class _TerneroFormScreenState extends State<TerneroFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = TerneroRepository();
  final _numeroCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _razaCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  bool _loading = false;
  bool _loadingData = true;
  String _sexo = 'hembra';
  String _categoria = 'ternera';
  bool _capado = false;
  DateTime? _fechaDestete;
  DateTime? _fechaNacimiento;
  String? _padreId;
  String? _madreId;
  String? _ubicacionId;

  List<Toro> _toros = [];
  List<Vaca> _vacas = [];
  List<Ubicacion> _ubicaciones = [];
  Ternero? _original;

  bool get _isEditing => widget.id != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _colorCtrl.dispose();
    _razaCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _toros = await ToroRepository().getAll();
    _vacas = await VacaRepository().getAll();
    _ubicaciones = await UbicacionRepository().getAll(soloActivas: true);
    if (_isEditing) {
      _original = await _repo.getById(widget.id!);
      final t = _original;
      if (t != null) {
        _numeroCtrl.text = t.numero;
        _colorCtrl.text = t.color ?? '';
        _razaCtrl.text = t.raza ?? '';
        _notaCtrl.text = t.nota ?? '';
        _sexo = t.sexo;
        _categoria = t.categoriaActual;
        _capado = t.capado;
        _fechaDestete = t.fechaDestete;
        _fechaNacimiento = t.fechaNacimiento;
        _padreId = t.padreId;
        _madreId = t.madreId;
        _ubicacionId = t.ubicacionId;
      }
    }
    // Evita valores que ya no existen en los desplegables.
    if (!_toros.any((x) => x.id == _padreId)) _padreId = null;
    if (!_vacas.any((x) => x.id == _madreId)) _madreId = null;
    if (!_ubicaciones.any((x) => x.id == _ubicacionId)) _ubicacionId = null;
    setState(() => _loadingData = false);
  }

  Future<void> _pickDate() async {
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
    if (await _repo.existeNumero(numero,
        excludeId: _isEditing ? widget.id : null)) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Ya existe un ternero con ese número'),
            backgroundColor: AppColors.danger));
      }
      return;
    }

    if (_isEditing && _original != null) {
      await _repo.update(_original!.copyWith(
        numero: numero,
        sexo: _sexo,
        categoria: _categoria,
        capado: _sexo == 'macho' && _capado,
        fechaDestete: _fechaDestete,
        fechaNacimiento: _fechaNacimiento,
        padreId: _padreId,
        madreId: _madreId,
        ubicacionId: _ubicacionId,
        color: textoONull(_colorCtrl.text),
        raza: textoONull(_razaCtrl.text),
        nota: textoONull(_notaCtrl.text),
      ));
    } else {
      await _repo.create(
        numero: numero,
        sexo: _sexo,
        categoria: _categoria,
        capado: _sexo == 'macho' && _capado,
        fechaDestete: _fechaDestete,
        fechaNacimiento: _fechaNacimiento,
        padreId: _padreId,
        madreId: _madreId,
        ubicacionId: _ubicacionId,
        color: textoONull(_colorCtrl.text),
        raza: textoONull(_razaCtrl.text),
        nota: textoONull(_notaCtrl.text),
      );
    }
    // Si se puso o cambió la madre (o la fecha), anotar su parto si falta.
    var parto = false;
    if (_madreId != null &&
        (_original?.madreId != _madreId ||
            _original?.fechaNacimiento != _fechaNacimiento)) {
      parto = await ReproduccionRepository().partoSiFalta(
          _madreId!, _fechaNacimiento,
          notas: 'Registrado al poner la madre de $numero');
    }
    if (!mounted) return;
    if (parto) {
      final madre = _vacas.where((v) => v.id == _madreId).firstOrNull;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'También se registró el parto de Vaca #${madre?.numero ?? ''}. '
              'Si ya está seca, márcala con "Secar vaca".')));
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(_isEditing ? 'Editar animal' : 'Nuevo animal')),
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
                          labelText: 'Número *', prefixIcon: Icon(Icons.tag)),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Campo requerido'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'hembra',
                            label: Text('Hembra'),
                            icon: Icon(Icons.female)),
                        ButtonSegment(
                            value: 'macho',
                            label: Text('Macho'),
                            icon: Icon(Icons.male)),
                      ],
                      selected: {_sexo},
                      onSelectionChanged: (s) => setState(() {
                        _sexo = s.first;
                        // La categoría debe corresponder al sexo.
                        final validas = _sexo == 'macho'
                            ? kCategoriasMacho
                            : kCategoriasHembra;
                        if (!validas.contains(_categoria)) {
                          _categoria = validas.first;
                        }
                      }),
                    ),
                    if (_sexo == 'macho')
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _capado,
                        onChanged: (v) => setState(() {
                          _capado = v!;
                          if (_capado &&
                              (_categoria == 'torete' ||
                                  _categoria == 'torete_venta')) {
                            _categoria = 'novillo_ceba';
                          }
                        }),
                        title: const Text('Capado'),
                      ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Fecha de nacimiento',
                            prefixIcon: Icon(Icons.calendar_today)),
                        child: Text(
                            _fechaNacimiento != null
                                ? DateFormat('dd/MM/yyyy')
                                    .format(_fechaNacimiento!)
                                : 'Seleccionar fecha',
                            style: TextStyle(
                                color: _fechaNacimiento != null
                                    ? null
                                    : Colors.grey[600])),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _categoria,
                      decoration: const InputDecoration(
                          labelText: 'Categoría',
                          prefixIcon: Icon(Icons.category_outlined)),
                      items: (_sexo == 'macho'
                              ? kCategoriasMacho
                              : kCategoriasHembra)
                          .where((c) => !(_capado &&
                              (c == 'torete' || c == 'torete_venta')))
                          .map((c) => DropdownMenuItem(
                              value: c, child: Text(kCategoriaLabels[c]!)))
                          .toList(),
                      onChanged: (v) => setState(() => _categoria = v!),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _fechaDestete ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (p != null) setState(() => _fechaDestete = p);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Fecha de destete (opcional)',
                          prefixIcon: const Icon(Icons.event_available),
                          suffixIcon: _fechaDestete != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () =>
                                      setState(() => _fechaDestete = null))
                              : null,
                        ),
                        child: Text(
                            _fechaDestete != null
                                ? DateFormat('dd/MM/yyyy').format(_fechaDestete!)
                                : 'Sin destetar',
                            style: TextStyle(
                                color: _fechaDestete != null
                                    ? null
                                    : Colors.grey[600])),
                      ),
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
                    DropdownButtonFormField<String?>(
                      value: _madreId,
                      decoration: const InputDecoration(
                          labelText: 'Madre', prefixIcon: Icon(Icons.female)),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Sin registrar')),
                        ..._vacas.map((v) => DropdownMenuItem(
                            value: v.id, child: Text('Vaca #${v.numero}'))),
                      ],
                      onChanged: (v) => setState(() => _madreId = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: _padreId,
                      decoration: const InputDecoration(
                          labelText: 'Padre (toro)',
                          prefixIcon: Icon(Icons.male)),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Sin registrar')),
                        ..._toros.map((t) => DropdownMenuItem(
                            value: t.id, child: Text(t.displayName))),
                      ],
                      onChanged: (v) => setState(() => _padreId = v),
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
                              : 'Registrar ternero'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

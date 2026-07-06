import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/toro.dart';
import '../../core/models/ubicacion.dart';
import '../../core/models/vaca.dart';
import '../../core/repositories/toro_repository.dart';
import '../../core/repositories/ubicacion_repository.dart';
import '../../core/repositories/vaca_repository.dart';

class VacaFormScreen extends StatefulWidget {
  final String? id;
  const VacaFormScreen({super.key, this.id});

  @override
  State<VacaFormScreen> createState() => _VacaFormScreenState();
}

class _VacaFormScreenState extends State<VacaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = VacaRepository();
  final _toroRepo = ToroRepository();
  final _ubicacionRepo = UbicacionRepository();
  final _numeroCtrl = TextEditingController();

  bool _loading = false;
  bool _loadingData = false;
  DateTime? _fechaNacimiento;
  String _estado = 'activa';
  String? _padreId;
  String? _madreId;
  String _estadoReproductivo = 'vacia';
  DateTime? _fechaMonta;
  String? _toroId;
  String? _ubicacionId;

  List<Vaca> _vacasDisponibles = [];
  List<Toro> _toros = [];
  List<Ubicacion> _ubicaciones = [];
  Vaca? _vacaOriginal;

  bool get _isEditing => widget.id != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loadingData = true);
    _vacasDisponibles = await _repo.getAll();
    _toros = await _toroRepo.getAll(soloActivos: true);
    _ubicaciones = await _ubicacionRepo.getAll(soloActivas: true);

    if (_isEditing) {
      _vacaOriginal = await _repo.getById(widget.id!);
      if (_vacaOriginal != null) {
        _numeroCtrl.text = _vacaOriginal!.numero;
        _fechaNacimiento = _vacaOriginal!.fechaNacimiento;
        _estado = _vacaOriginal!.estado;
        _padreId = _vacaOriginal!.padreId;
        _madreId = _vacaOriginal!.madreId;
        _estadoReproductivo = _vacaOriginal!.estadoReproductivo;
        _fechaMonta = _vacaOriginal!.fechaMonta;
        _toroId = _vacaOriginal!.toroId;
        _ubicacionId = _vacaOriginal!.ubicacionId;
      }
    }
    setState(() => _loadingData = false);
  }

  Future<void> _pickDate(bool isMonta) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isMonta ? _fechaMonta : _fechaNacimiento) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isMonta) {
          _fechaMonta = picked;
        } else {
          _fechaNacimiento = picked;
        }
      });
    }
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
            content: Text('Ya existe una vaca con ese número'),
            backgroundColor: Colors.red));
      }
      return;
    }

    // Calcular fecha estimada de parto (283 días)
    DateTime? fechaParto;
    if (_estadoReproductivo == 'prenada' && _fechaMonta != null) {
      fechaParto = _fechaMonta!.add(const Duration(days: 283));
    }

    if (_isEditing && _vacaOriginal != null) {
      await _repo.update(_vacaOriginal!.copyWith(
        numero: numero,
        fechaNacimiento: _fechaNacimiento,
        estado: _estado,
        padreId: _padreId,
        madreId: _madreId,
        estadoReproductivo: _estadoReproductivo,
        fechaMonta: _fechaMonta,
        clearFechaMonta: _estadoReproductivo == 'vacia',
        toroId: _toroId,
        clearToroId: _estadoReproductivo == 'vacia',
        fechaEstimadaParto: fechaParto,
        clearFechaParto: _estadoReproductivo == 'vacia',
        ubicacionId: _ubicacionId,
      ));
    } else {
      await _repo.create(
        numero: numero,
        fechaNacimiento: _fechaNacimiento,
        estado: _estado,
        padreId: _padreId,
        madreId: _madreId,
        estadoReproductivo: _estadoReproductivo,
        fechaMonta: _estadoReproductivo == 'prenada' ? _fechaMonta : null,
        toroId: _estadoReproductivo == 'prenada' ? _toroId : null,
        fechaEstimadaParto: fechaParto,
        ubicacionId: _ubicacionId,
      );
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Editar Vaca' : 'Nueva Vaca')),
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
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => _pickDate(false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Fecha de nacimiento',
                            prefixIcon: Icon(Icons.calendar_today)),
                        child: Text(_fechaNacimiento != null
                            ? DateFormat('dd/MM/yyyy').format(_fechaNacimiento!)
                            : 'Seleccionar fecha',
                            style: TextStyle(
                                color: _fechaNacimiento != null
                                    ? null
                                    : Colors.grey[600])),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _estado,
                      decoration: const InputDecoration(
                          labelText: 'Estado', prefixIcon: Icon(Icons.info_outline)),
                      items: const [
                        DropdownMenuItem(value: 'activa', child: Text('Activa')),
                        DropdownMenuItem(value: 'vendida', child: Text('Vendida')),
                        DropdownMenuItem(value: 'muerta', child: Text('Muerta')),
                      ],
                      onChanged: (v) => setState(() => _estado = v!),
                    ),
                    const SizedBox(height: 16),
                    // Estado reproductivo
                    DropdownButtonFormField<String>(
                      value: _estadoReproductivo,
                      decoration: const InputDecoration(
                          labelText: 'Estado reproductivo',
                          prefixIcon: Icon(Icons.favorite_outline)),
                      items: const [
                        DropdownMenuItem(value: 'vacia', child: Text('Vacía')),
                        DropdownMenuItem(value: 'prenada', child: Text('Preñada')),
                      ],
                      onChanged: (v) => setState(() => _estadoReproductivo = v!),
                    ),
                    if (_estadoReproductivo == 'prenada') ...[
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => _pickDate(true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                              labelText: 'Fecha de monta *',
                              prefixIcon: Icon(Icons.event)),
                          child: Text(_fechaMonta != null
                              ? DateFormat('dd/MM/yyyy').format(_fechaMonta!)
                              : 'Seleccionar fecha',
                              style: TextStyle(
                                  color: _fechaMonta != null
                                      ? null
                                      : Colors.grey[600])),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String?>(
                        value: _toroId,
                        decoration: const InputDecoration(
                            labelText: 'Toro padre',
                            prefixIcon: Icon(Icons.male)),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Sin registrar')),
                          ..._toros.map((t) => DropdownMenuItem(
                              value: t.id, child: Text(t.displayName))),
                        ],
                        onChanged: (v) => setState(() => _toroId = v),
                      ),
                      if (_fechaMonta != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Parto estimado: ${DateFormat('dd/MM/yyyy').format(_fechaMonta!.add(const Duration(days: 283)))}',
                            style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    // Ubicación
                    DropdownButtonFormField<String?>(
                      value: _ubicacionId,
                      decoration: const InputDecoration(
                          labelText: 'Ubicación',
                          prefixIcon: Icon(Icons.location_on)),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Sin asignar')),
                        ..._ubicaciones.map((u) =>
                            DropdownMenuItem(value: u.id, child: Text(u.nombre))),
                      ],
                      onChanged: (v) => setState(() => _ubicacionId = v),
                    ),
                    const SizedBox(height: 16),
                    // Padres
                    DropdownButtonFormField<String?>(
                      value: _padreId,
                      decoration: const InputDecoration(
                          labelText: 'Padre (vaca)', prefixIcon: Icon(Icons.male)),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Sin registrar')),
                        ..._vacasDisponibles
                            .where((v) => v.id != widget.id)
                            .map((v) => DropdownMenuItem(
                                value: v.id, child: Text('Vaca #${v.numero}'))),
                      ],
                      onChanged: (v) => setState(() => _padreId = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: _madreId,
                      decoration: const InputDecoration(
                          labelText: 'Madre', prefixIcon: Icon(Icons.female)),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Sin registrar')),
                        ..._vacasDisponibles
                            .where((v) => v.id != widget.id)
                            .map((v) => DropdownMenuItem(
                                value: v.id, child: Text('Vaca #${v.numero}'))),
                      ],
                      onChanged: (v) => setState(() => _madreId = v),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _loading ? null : _save,
                      child: _loading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_isEditing
                              ? 'Guardar cambios'
                              : 'Registrar vaca'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

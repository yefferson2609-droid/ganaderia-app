import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/repositories/toro_repository.dart';

class ToroFormScreen extends StatefulWidget {
  final String? id;
  const ToroFormScreen({super.key, this.id});

  @override
  State<ToroFormScreen> createState() => _ToroFormScreenState();
}

class _ToroFormScreenState extends State<ToroFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ToroRepository();
  final _numeroCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  String _estado = 'activo';
  bool _loading = false;
  bool _loadingData = false;

  bool get _isEditing => widget.id != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadData();
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loadingData = true);
    final t = await _repo.getById(widget.id!);
    if (t != null) {
      _numeroCtrl.text = t.numero;
      _nombreCtrl.text = t.nombre;
      _estado = t.estado;
    }
    setState(() => _loadingData = false);
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
            backgroundColor: Colors.red));
      }
      return;
    }

    if (_isEditing) {
      final t = await _repo.getById(widget.id!);
      if (t != null) {
        await _repo.update(t.copyWith(
          numero: numero,
          nombre: _nombreCtrl.text.trim(),
          estado: _estado,
        ));
      }
    } else {
      await _repo.create(
        numero: numero,
        nombre: _nombreCtrl.text.trim(),
        estado: _estado,
      );
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
                    DropdownButtonFormField<String>(
                      value: _estado,
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'activo', child: Text('Activo')),
                        DropdownMenuItem(value: 'vendido', child: Text('Vendido')),
                        DropdownMenuItem(value: 'muerto', child: Text('Muerto')),
                      ],
                      onChanged: (v) => setState(() => _estado = v!),
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

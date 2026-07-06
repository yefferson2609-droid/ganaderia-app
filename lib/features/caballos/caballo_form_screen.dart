import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/repositories/caballo_repository.dart';

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
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loadingData = true);
    final c = await _repo.getById(widget.id!);
    if (c != null) {
      _nombreCtrl.text = c.nombre;
      _estado = c.estado;
    }
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
        ));
      }
    } else {
      await _repo.create(
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
                            value: 'muerto', child: Text('Muerto')),
                      ],
                      onChanged: (v) => setState(() => _estado = v!),
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

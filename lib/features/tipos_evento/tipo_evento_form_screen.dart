import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/repositories/tipo_evento_repository.dart';

class TipoEventoFormScreen extends StatefulWidget {
  final String? id;
  const TipoEventoFormScreen({super.key, this.id});

  @override
  State<TipoEventoFormScreen> createState() => _TipoEventoFormScreenState();
}

class _TipoEventoFormScreenState extends State<TipoEventoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = TipoEventoRepository();
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
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
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loadingData = true);
    final t = await _repo.getById(widget.id!);
    if (t != null) {
      _nombreCtrl.text = t.nombre;
      _descCtrl.text = t.descripcion ?? '';
    }
    setState(() => _loadingData = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    if (_isEditing) {
      final t = await _repo.getById(widget.id!);
      if (t != null) {
        await _repo.update(t.copyWith(
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descCtrl.text.isEmpty ? null : _descCtrl.text.trim(),
        ));
      }
    } else {
      await _repo.create(
        nombre: _nombreCtrl.text.trim(),
        descripcion: _descCtrl.text.isEmpty ? null : _descCtrl.text.trim(),
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Tipo' : 'Nuevo Tipo de Evento'),
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
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        prefixIcon: Icon(Icons.description_outlined),
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
                          : Text(_isEditing ? 'Guardar cambios' : 'Crear tipo'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

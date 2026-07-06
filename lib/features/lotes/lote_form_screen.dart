import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/repositories/lote_repository.dart';

class LoteFormScreen extends StatefulWidget {
  final String? id;
  const LoteFormScreen({super.key, this.id});

  @override
  State<LoteFormScreen> createState() => _LoteFormScreenState();
}

class _LoteFormScreenState extends State<LoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = LoteRepository();
  final _nombreCtrl = TextEditingController();
  final _hembrasCtrl = TextEditingController(text: '0');
  final _machosCtrl = TextEditingController(text: '0');
  String _tipo = 'cerdo';
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
    _hembrasCtrl.dispose();
    _machosCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loadingData = true);
    final l = await _repo.getById(widget.id!);
    if (l != null) {
      _nombreCtrl.text = l.nombre;
      _tipo = l.tipo;
      _hembrasCtrl.text = l.hembras.toString();
      _machosCtrl.text = l.machos.toString();
    }
    setState(() => _loadingData = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final hembras = int.tryParse(_hembrasCtrl.text) ?? 0;
    final machos = int.tryParse(_machosCtrl.text) ?? 0;

    if (_isEditing) {
      final l = await _repo.getById(widget.id!);
      if (l != null) {
        await _repo.update(l.copyWith(
          nombre: _nombreCtrl.text.trim(),
          hembras: hembras,
          machos: machos,
        ));
      }
    } else {
      await _repo.create(
        tipo: _tipo,
        nombre: _nombreCtrl.text.trim(),
        hembras: hembras,
        machos: machos,
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Lote' : 'Nuevo Lote'),
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
                    if (!_isEditing)
                      DropdownButtonFormField<String>(
                        value: _tipo,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de animal',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'cerdo', child: Text('Cerdos')),
                          DropdownMenuItem(
                              value: 'ovejo', child: Text('Ovejos')),
                        ],
                        onChanged: (v) => setState(() => _tipo = v!),
                      ),
                    if (!_isEditing) const SizedBox(height: 16),
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del lote *',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _hembrasCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Hembras ♀',
                              prefixIcon: Icon(Icons.female),
                            ),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n < 0) return 'Número válido';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _machosCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Machos ♂',
                              prefixIcon: Icon(Icons.male),
                            ),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n < 0) return 'Número válido';
                              return null;
                            },
                          ),
                        ),
                      ],
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
                          : Text(
                              _isEditing ? 'Guardar cambios' : 'Crear lote'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

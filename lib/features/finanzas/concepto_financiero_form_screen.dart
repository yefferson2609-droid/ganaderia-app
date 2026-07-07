import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/repositories/concepto_financiero_repository.dart';

class ConceptoFinancieroFormScreen extends StatefulWidget {
  final String? id;
  final String tipoInicial;
  const ConceptoFinancieroFormScreen({
    super.key,
    this.id,
    this.tipoInicial = 'ingreso',
  });

  @override
  State<ConceptoFinancieroFormScreen> createState() =>
      _ConceptoFinancieroFormScreenState();
}

class _ConceptoFinancieroFormScreenState
    extends State<ConceptoFinancieroFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ConceptoFinancieroRepository();
  final _nombreCtrl = TextEditingController();
  late String _tipo;
  bool _loading = false;
  bool _loadingData = false;

  bool get _isEditing => widget.id != null;

  @override
  void initState() {
    super.initState();
    _tipo = widget.tipoInicial;
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
      _tipo = c.tipo;
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
          tipo: _tipo,
        ));
      }
    } else {
      await _repo.create(
        nombre: _nombreCtrl.text.trim(),
        tipo: _tipo,
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Concepto' : 'Nuevo Concepto'),
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
                      onSelectionChanged: (v) =>
                          setState(() => _tipo = v.first),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre *',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Campo requerido' : null,
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
                              _isEditing ? 'Guardar cambios' : 'Crear concepto'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

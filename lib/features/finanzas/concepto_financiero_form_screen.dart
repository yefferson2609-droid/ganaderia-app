import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/repositories/concepto_financiero_repository.dart';
import '../../core/theme/app_theme.dart';

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
  bool _activo = true;
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
      _activo = c.activo;
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
          activo: _activo,
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

  Future<void> _eliminar() async {
    // Un concepto con movimientos no se puede borrar (se perdería a qué
    // corresponden): se ofrece desactivarlo.
    final usados = await _repo.movimientosQueLoUsan(widget.id!);
    if (!mounted) return;
    if (usados > 0) {
      final desactivar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No se puede eliminar'),
          content: Text(
              '"${_nombreCtrl.text.trim()}" tiene $usados '
              'movimiento${usados == 1 ? '' : 's'} registrado${usados == 1 ? '' : 's'}.\n\n'
              'Puedes desactivarlo: deja de salir al registrar, y los '
              'movimientos que ya tiene conservan su nombre.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Desactivar')),
          ],
        ),
      );
      if (desactivar != true) return;
      final c = await _repo.getById(widget.id!);
      if (c != null) await _repo.update(c.copyWith(activo: false));
      if (mounted) context.pop();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar concepto'),
        content: Text('¿Eliminar "${_nombreCtrl.text.trim()}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.delete(widget.id!);
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
                    if (_isEditing) ...[
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Activo'),
                        subtitle: Text(_activo
                            ? 'Sale en la lista al registrar'
                            : 'No sale al registrar (se conserva en lo ya anotado)'),
                        value: _activo,
                        onChanged: (v) => setState(() => _activo = v),
                      ),
                    ],
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
                    if (_isEditing) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _eliminar,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Eliminar concepto'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

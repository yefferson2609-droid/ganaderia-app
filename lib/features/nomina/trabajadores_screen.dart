import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/nomina.dart';
import '../../core/repositories/nomina_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/auditoria.dart';
import 'nomina_screen.dart' show money;

final _fmt = DateFormat('dd/MM/yyyy');

class TrabajadoresScreen extends StatefulWidget {
  const TrabajadoresScreen({super.key});

  @override
  State<TrabajadoresScreen> createState() => _TrabajadoresScreenState();
}

class _TrabajadoresScreenState extends State<TrabajadoresScreen> {
  final _repo = NominaRepository();
  List<Trabajador> _lista = [];
  List<PrestamoTrabajador> _prestamos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _lista = await _repo.getTrabajadores();
    _prestamos = await _repo.getPrestamos();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _form([Trabajador? t]) async {
    final nombre = TextEditingController(text: t?.nombre);
    final cedula = TextEditingController(text: t?.cedula);
    final cargo = TextEditingController(text: t?.cargo);
    final telefono = TextEditingController(text: t?.telefono);
    final salario = TextEditingController(
        text: t != null ? t.salarioSemanal.toStringAsFixed(2) : '');
    final notas = TextEditingController(text: t?.notas);
    DateTime? ingreso = t?.fechaIngreso;
    bool activo = t?.activo ?? true;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t == null ? 'Nuevo trabajador' : 'Editar trabajador',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                    controller: nombre,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nombre *')),
                const SizedBox(height: 8),
                TextField(
                    controller: salario,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Sueldo semanal (USD) *', prefixText: r'$ ')),
                const SizedBox(height: 8),
                TextField(
                    controller: cargo,
                    decoration:
                        const InputDecoration(labelText: 'Cargo (ej. ordeñador)')),
                const SizedBox(height: 8),
                TextField(
                    controller: cedula,
                    decoration: const InputDecoration(labelText: 'Cédula')),
                const SizedBox(height: 8),
                TextField(
                    controller: telefono,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Teléfono')),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final p = await showDatePicker(
                        context: ctx,
                        initialDate: ingreso ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 60)));
                    if (p != null) setSt(() => ingreso = p);
                  },
                  child: InputDecorator(
                    decoration:
                        const InputDecoration(labelText: 'Fecha de ingreso'),
                    child: Text(ingreso != null ? _fmt.format(ingreso!) : 'Sin fecha'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                    controller: notas,
                    decoration: const InputDecoration(labelText: 'Notas')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: activo,
                  onChanged: (v) => setSt(() => activo = v),
                  title: const Text('Activo (entra en la nómina)'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    final s = double.tryParse(salario.text.replaceAll(',', '.'));
                    if (nombre.text.trim().isEmpty || s == null || s < 0) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    await _repo.guardarTrabajador(
      id: t?.id,
      nombre: nombre.text.trim(),
      cedula: textoONull(cedula.text),
      cargo: textoONull(cargo.text),
      telefono: textoONull(telefono.text),
      salarioSemanal: double.parse(salario.text.replaceAll(',', '.')),
      fechaIngreso: ingreso,
      activo: activo,
      notas: textoONull(notas.text),
    );
    _load();
  }

  Future<void> _prestamo(Trabajador t) async {
    final monto = TextEditingController();
    final cuota = TextEditingController();
    final desc = TextEditingController();
    DateTime fecha = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final m = double.tryParse(monto.text.replaceAll(',', '.'));
          final c = double.tryParse(cuota.text.replaceAll(',', '.'));
          final semanas = (m != null && c != null && c > 0) ? (m / c).ceil() : null;
          return AlertDialog(
            title: Text('Préstamo a ${t.nombre}'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: monto,
                  autofocus: true,
                  onChanged: (_) => setSt(() {}),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Monto prestado (USD) *', prefixText: r'$ '),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: cuota,
                  onChanged: (_) => setSt(() {}),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Descontar cada domingo (USD) *', prefixText: r'$ '),
                ),
                if (semanas != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Se paga en $semanas semana${semanas == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                const SizedBox(height: 8),
                TextField(
                    controller: desc,
                    decoration: const InputDecoration(labelText: 'Motivo (opcional)')),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final p = await showDatePicker(
                        context: ctx,
                        initialDate: fecha,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now());
                    if (p != null) setSt(() => fecha = p);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Fecha de entrega'),
                    child: Text(_fmt.format(fecha)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Se registra ya como gasto en Finanzas.',
                    style: TextStyle(fontSize: 12)),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              ElevatedButton(
                  onPressed: () {
                    if (m == null || m <= 0 || c == null || c <= 0) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Guardar')),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    await _repo.agregarPrestamo(
      trabajador: t,
      monto: double.parse(monto.text.replaceAll(',', '.')),
      cuotaSemanal: double.parse(cuota.text.replaceAll(',', '.')),
      fecha: fecha,
      descripcion: textoONull(desc.text),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trabajadores')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo trabajador'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lista.isEmpty
              ? const Center(child: Text('No hay trabajadores registrados'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: _lista.map((t) {
                    final prestamos =
                        _prestamos.where((p) => p.trabajadorId == t.id).toList();
                    final activos = prestamos.where((p) => p.estado == 'activo');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: t.activo
                              ? AppColors.primaryContainer
                              : Colors.grey[300],
                          child: Icon(Icons.badge,
                              color: t.activo ? AppColors.primary : Colors.grey),
                        ),
                        title: Text(t.nombre,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text([
                          '${money.format(t.salarioSemanal)}/semana',
                          if (t.cargo != null) t.cargo!,
                          if (!t.activo) 'Inactivo',
                          if (activos.isNotEmpty)
                            'Debe ${money.format(activos.fold(0.0, (a, p) => a + p.saldo))}',
                        ].join(' · ')),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (t.cedula != null) Text('Cédula: ${t.cedula}'),
                          if (t.telefono != null) Text('Teléfono: ${t.telefono}'),
                          if (t.fechaIngreso != null)
                            Text('Ingresó: ${_fmt.format(t.fechaIngreso!)}'),
                          if (t.notas != null) Text('Notas: ${t.notas}'),
                          const SizedBox(height: 8),
                          Text('Préstamos',
                              style: Theme.of(context).textTheme.labelLarge),
                          if (prestamos.isEmpty)
                            const Text('Sin préstamos',
                                style: TextStyle(color: Colors.grey))
                          else
                            ...prestamos.map((p) => Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${_fmt.format(p.fecha)} · ${money.format(p.montoTotal)}'
                                    ' · cuota ${money.format(p.cuotaSemanal)} · '
                                    '${p.estado == 'pagado' ? 'pagado ✔' : 'saldo ${money.format(p.saldo)}'}'
                                    '${p.descripcion != null ? ' · ${p.descripcion}' : ''}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                )),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, children: [
                            OutlinedButton.icon(
                              onPressed: () => _form(t),
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Editar'),
                            ),
                            if (t.activo)
                              OutlinedButton.icon(
                                onPressed: () => _prestamo(t),
                                icon: const Icon(Icons.request_quote, size: 18),
                                label: const Text('Préstamo'),
                              ),
                          ]),
                        ],
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/services/reporte_pdf_service.dart';
import '../../core/theme/app_theme.dart';

final _fmt = DateFormat('dd/MM/yyyy');

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  late DateTime _desde;
  late DateTime _hasta;
  bool _inventario = true;
  bool _finanzas = true;
  bool _salud = true;
  bool _eventos = true;
  bool _generando = false;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _desde = DateTime(hoy.year, hoy.month, 1);
    _hasta = hoy;
  }

  void _rapido(String r) {
    final hoy = DateTime.now();
    setState(() {
      switch (r) {
        case 'mes':
          _desde = DateTime(hoy.year, hoy.month, 1);
        case 'anterior':
          _desde = DateTime(hoy.year, hoy.month - 1, 1);
          _hasta = DateTime(hoy.year, hoy.month, 0);
          return;
        case '90':
          _desde = hoy.subtract(const Duration(days: 90));
        case 'anio':
          _desde = DateTime(hoy.year, 1, 1);
      }
      _hasta = hoy;
    });
  }

  Future<void> _pick(bool desde) async {
    final p = await showDatePicker(
      context: context,
      initialDate: desde ? _desde : _hasta,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (p == null) return;
    setState(() {
      if (desde) {
        _desde = p;
        if (_hasta.isBefore(p)) _hasta = p;
      } else {
        _hasta = p;
        if (_desde.isAfter(p)) _desde = p;
      }
    });
  }

  SeccionesReporte get _secciones => SeccionesReporte(
        inventario: _inventario,
        finanzas: _finanzas,
        salud: _salud,
        eventos: _eventos,
      );

  Future<void> _generar({required bool compartir}) async {
    if (!_secciones.alguna) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Elige al menos una sección para el reporte')));
      return;
    }
    setState(() => _generando = true);
    try {
      final bytes = await ReportePdfService()
          .generar(desde: _desde, hasta: _hasta, secciones: _secciones);
      final nombre = ReportePdfService.nombreArchivo();
      if (compartir) {
        await Printing.sharePdf(bytes: bytes, filename: nombre);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: nombre);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No se pudo generar el reporte: $e'),
            backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Rango de fechas', style: titulo),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () => _pick(true),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Desde'),
                  child: Text(_fmt.format(_desde)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => _pick(false),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Hasta'),
                  child: Text(_fmt.format(_hasta)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ActionChip(label: const Text('Este mes'), onPressed: () => _rapido('mes')),
            ActionChip(
                label: const Text('Mes anterior'),
                onPressed: () => _rapido('anterior')),
            ActionChip(
                label: const Text('Últimos 90 días'),
                onPressed: () => _rapido('90')),
            ActionChip(label: const Text('Este año'), onPressed: () => _rapido('anio')),
          ]),
          const SizedBox(height: 24),
          Text('Secciones a incluir', style: titulo),
          CheckboxListTile(
            value: _inventario,
            onChanged: (v) => setState(() => _inventario = v!),
            title: const Text('Inventario de animales'),
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: _finanzas,
            onChanged: (v) => setState(() => _finanzas = v!),
            title: const Text('Finanzas'),
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: _salud,
            onChanged: (v) => setState(() => _salud = v!),
            title: const Text('Salud'),
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: _eventos,
            onChanged: (v) => setState(() => _eventos = v!),
            title: const Text('Eventos y actividades'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          Text(
            'El rango de fechas aplica a Finanzas, Salud y Eventos. '
            'El Inventario siempre muestra el estado actual.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _generando ? null : () => _generar(compartir: false),
            icon: _generando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf),
            label: const Text('Generar PDF'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _generando ? null : () => _generar(compartir: true),
            icon: const Icon(Icons.share),
            label: const Text('Compartir PDF'),
          ),
        ],
      ),
    );
  }
}

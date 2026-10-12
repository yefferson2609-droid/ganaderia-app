DateTime? _fecha(Object? v) => v == null ? null : DateTime.tryParse(v as String);
double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
bool _bool(Object? v) => v is bool ? v : (v as int? ?? 0) == 1;
String _dia(DateTime f) => f.toIso8601String().split('T')[0];

/// Domingo que cierra la semana de nómina a la que pertenece [fecha].
DateTime semanaFin(DateTime fecha) {
  final d = DateTime(fecha.year, fecha.month, fecha.day);
  return d.add(Duration(days: 7 - d.weekday)); // weekday: lunes=1 … domingo=7
}

class Trabajador {
  final String id;
  final String nombre;
  final String? cedula;
  final String? cargo;
  final String? telefono;
  final double salarioSemanal;
  final DateTime? fechaIngreso;
  final bool activo;
  final String? notas;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Trabajador({
    required this.id,
    required this.nombre,
    this.cedula,
    this.cargo,
    this.telefono,
    required this.salarioSemanal,
    this.fechaIngreso,
    this.activo = true,
    this.notas,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Trabajador.fromMap(Map<String, dynamic> m) => Trabajador(
        id: m['id'] as String,
        nombre: m['nombre'] as String,
        cedula: m['cedula'] as String?,
        cargo: m['cargo'] as String?,
        telefono: m['telefono'] as String?,
        salarioSemanal: _num(m['salario_semanal']),
        fechaIngreso: _fecha(m['fecha_ingreso']),
        activo: _bool(m['activo']),
        notas: m['notas'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'cedula': cedula,
        'cargo': cargo,
        'telefono': telefono,
        'salario_semanal': salarioSemanal,
        'fecha_ingreso': fechaIngreso == null ? null : _dia(fechaIngreso!),
        'activo': activo ? 1 : 0,
        'notas': notas,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// Bono (se suma el domingo) o anticipo (se descuenta el domingo).
class NovedadNomina {
  final String id;
  final String trabajadorId;
  final DateTime semanaFin;
  final String tipo; // 'bono' | 'anticipo'
  final double monto;
  final String? descripcion;
  final String? movimientoId;
  final DateTime createdAt;

  const NovedadNomina({
    required this.id,
    required this.trabajadorId,
    required this.semanaFin,
    required this.tipo,
    required this.monto,
    this.descripcion,
    this.movimientoId,
    required this.createdAt,
  });

  factory NovedadNomina.fromMap(Map<String, dynamic> m) => NovedadNomina(
        id: m['id'] as String,
        trabajadorId: m['trabajador_id'] as String,
        semanaFin: DateTime.parse(m['semana_fin'] as String),
        tipo: m['tipo'] as String,
        monto: _num(m['monto']),
        descripcion: m['descripcion'] as String?,
        movimientoId: m['movimiento_id'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class PrestamoTrabajador {
  final String id;
  final String trabajadorId;
  final DateTime fecha;
  final double montoTotal;
  final double cuotaSemanal;
  final String? descripcion;
  final String estado; // 'activo' | 'pagado'
  final double pagado; // suma de cuotas descontadas (calculado)

  const PrestamoTrabajador({
    required this.id,
    required this.trabajadorId,
    required this.fecha,
    required this.montoTotal,
    required this.cuotaSemanal,
    this.descripcion,
    this.estado = 'activo',
    this.pagado = 0,
  });

  double get saldo => (montoTotal - pagado).clamp(0, double.infinity).toDouble();

  /// Cuota que se descontaría el próximo domingo.
  double get proximaCuota =>
      estado == 'activo' ? (cuotaSemanal < saldo ? cuotaSemanal : saldo) : 0;

  factory PrestamoTrabajador.fromMap(Map<String, dynamic> m) => PrestamoTrabajador(
        id: m['id'] as String,
        trabajadorId: m['trabajador_id'] as String,
        fecha: DateTime.parse(m['fecha'] as String),
        montoTotal: _num(m['monto_total']),
        cuotaSemanal: _num(m['cuota_semanal']),
        descripcion: m['descripcion'] as String?,
        estado: m['estado'] as String? ?? 'activo',
        pagado: _num(m['pagado']),
      );
}

class NominaSemana {
  final String id;
  final DateTime semanaFin;
  final String estado; // 'pendiente' | 'pagada'
  final double total;
  final int trabajadores;
  final String? movimientoId;
  final bool automatica;
  final DateTime? pagadaAt;

  const NominaSemana({
    required this.id,
    required this.semanaFin,
    required this.estado,
    required this.total,
    required this.trabajadores,
    this.movimientoId,
    this.automatica = false,
    this.pagadaAt,
  });

  bool get pagada => estado == 'pagada';

  factory NominaSemana.fromMap(Map<String, dynamic> m) => NominaSemana(
        id: m['id'] as String,
        semanaFin: DateTime.parse(m['semana_fin'] as String),
        estado: m['estado'] as String? ?? 'pendiente',
        total: _num(m['total']),
        trabajadores: (m['trabajadores'] as int?) ?? 0,
        movimientoId: m['movimiento_id'] as String?,
        automatica: _bool(m['automatica']),
        pagadaAt: _fecha(m['pagada_at']),
      );
}

/// Una fila de la nómina: la calculada (vista previa) o la pagada (detalle).
class FilaNomina {
  final String trabajadorId;
  final String nombre;
  final double salario;
  final double bonos;
  final double anticipos;
  final double cuotas;

  const FilaNomina({
    required this.trabajadorId,
    required this.nombre,
    required this.salario,
    this.bonos = 0,
    this.anticipos = 0,
    this.cuotas = 0,
  });

  double get neto => salario + bonos - anticipos - cuotas;

  factory FilaNomina.fromDetalle(Map<String, dynamic> m) => FilaNomina(
        trabajadorId: m['trabajador_id'] as String,
        nombre: m['trabajador_nombre'] as String,
        salario: _num(m['salario']),
        bonos: _num(m['bonos']),
        anticipos: _num(m['anticipos']),
        cuotas: _num(m['cuotas']),
      );
}

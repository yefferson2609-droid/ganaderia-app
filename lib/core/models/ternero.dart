import '../config/ajustes.dart';
import '../utils/auditoria.dart';

/// Etapas antiguas (se siguen guardando para compatibilidad con el servidor;
/// ahora se derivan de la categoría).
const kEtapasTernero = ['lactancia', 'destete', 'ceba'];

// El valor guardado sigue siendo 'destete'; en pantalla se muestra "Levante".
const kEtapaLabels = {
  'lactancia': 'Lactancia',
  'destete': 'Levante',
  'ceba': 'Ceba',
};

/// Categorías ganaderas de "Levante y ceba", en el orden en que se muestran.
const kCategoriasHembra = ['ternera', 'novilla_levante', 'novilla_vientre'];
const kCategoriasMacho = ['ternero', 'torete', 'torete_venta', 'novillo_ceba'];
const kCategorias = [...kCategoriasHembra, ...kCategoriasMacho];

const kCategoriaLabels = {
  'ternera': 'Ternera',
  'novilla_levante': 'Novilla de levante',
  'novilla_vientre': 'Novilla de vientre',
  'ternero': 'Ternero',
  'torete': 'Torete',
  'torete_venta': 'Torete para venta',
  'novillo_ceba': 'Novillo de ceba',
};

/// Plural corto para pestañas y conteos.
const kCategoriaPlural = {
  'ternera': 'Terneras',
  'novilla_levante': 'Novillas levante',
  'novilla_vientre': 'Novillas vientre',
  'ternero': 'Terneros',
  'torete': 'Toretes',
  'torete_venta': 'Toretes venta',
  'novillo_ceba': 'Novillos ceba',
};

/// Etapa antigua equivalente a cada categoría.
String etapaDeCategoria(String categoria) {
  switch (categoria) {
    case 'ternera':
    case 'ternero':
      return 'lactancia';
    case 'novillo_ceba':
      return 'ceba';
    default:
      return 'destete';
  }
}

class Ternero {
  final String id;
  final String numero;
  final String sexo; // 'hembra' | 'macho'
  final DateTime? fechaNacimiento;
  final String etapa;
  final String? categoria; // null = aún sin clasificar (se usa la sugerida)
  final DateTime? fechaDestete;
  final bool capado;
  final String estado; // 'activo' | 'vendido' | 'fallecido' | 'promovido'
  final String? padreId;
  final String? madreId;
  final String? ubicacionId;
  final String? color;
  final String? raza;
  final String? fotoUrl; // foto subida a Supabase Storage
  final String? fotoLocal; // ruta en el teléfono (solo local)
  final String? nota;
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get tieneFoto => fotoUrl != null || fotoLocal != null;

  const Ternero({
    required this.id,
    required this.numero,
    required this.sexo,
    this.fechaNacimiento,
    this.etapa = 'lactancia',
    this.categoria,
    this.fechaDestete,
    this.capado = false,
    this.estado = 'activo',
    this.padreId,
    this.madreId,
    this.ubicacionId,
    this.color,
    this.raza,
    this.fotoUrl,
    this.fotoLocal,
    this.nota,
    this.createdBy,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get esMacho => sexo == 'macho';

  String get etapaLabel => kEtapaLabels[etapa] ?? etapa;

  /// Edad en meses (null si no hay fecha de nacimiento).
  int? get meses => fechaNacimiento == null
      ? null
      : (DateTime.now().difference(fechaNacimiento!).inDays / 30.44).floor();

  bool get destetado => fechaDestete != null || etapa != 'lactancia';

  /// Categoría propuesta según sexo, destete, capado y edad.
  String get categoriaSugerida {
    final m = meses;
    final sinDestetar = !destetado && (m == null || m < kMesesDestete);
    if (!esMacho) {
      if (sinDestetar) return 'ternera';
      return (m != null && m >= kMesesNovillaVientre)
          ? 'novilla_vientre'
          : 'novilla_levante';
    }
    if (sinDestetar) return 'ternero';
    if (capado) return 'novillo_ceba';
    return categoria == 'torete_venta' ? 'torete_venta' : 'torete';
  }

  /// La guardada, o la sugerida si aún no se ha clasificado.
  String get categoriaActual =>
      (categoria != null && kCategorias.contains(categoria)) ? categoria! : categoriaSugerida;

  String get categoriaLabel => kCategoriaLabels[categoriaActual] ?? categoriaActual;

  /// Si la categoría guardada ya no corresponde (p. ej. la novilla cumplió
  /// 24 meses), devuelve la nueva categoría sugerida; si no, null.
  String? get cambioSugerido {
    if (estado != 'activo') return null;
    final sugerida = categoriaSugerida;
    final actual = categoriaActual;
    if (sugerida == actual) return null;
    // Solo se sugiere avanzar, nunca retroceder.
    const orden = [...kCategoriasHembra, ...kCategoriasMacho];
    if (actual == 'torete_venta' && sugerida == 'torete') return null;
    return orden.indexOf(sugerida) > orden.indexOf(actual) ? sugerida : null;
  }

  /// ¿Cumplió la edad de destete sin haberse destetado?
  bool get debeDestetarse =>
      estado == 'activo' && !destetado && (meses ?? 0) >= kMesesDestete;

  /// Siguiente etapa, o null si ya está en la última.
  String? get siguienteEtapa {
    final i = kEtapasTernero.indexOf(etapa);
    if (i < 0 || i >= kEtapasTernero.length - 1) return null;
    return kEtapasTernero[i + 1];
  }

  String get edad {
    if (fechaNacimiento == null) return 'Sin fecha';
    final diff = DateTime.now().difference(fechaNacimiento!);
    final years = diff.inDays ~/ 365;
    final months = (diff.inDays % 365) ~/ 30;
    if (years > 0) {
      return '$years año${years > 1 ? 's' : ''} $months mes${months != 1 ? 'es' : ''}';
    }
    if (months > 0) return '$months mes${months != 1 ? 'es' : ''}';
    return '${diff.inDays} días';
  }

  factory Ternero.fromMap(Map<String, dynamic> map) => Ternero(
        id: map['id'] as String,
        numero: map['numero'] as String,
        sexo: map['sexo'] as String,
        fechaNacimiento: map['fecha_nacimiento'] != null
            ? DateTime.tryParse(map['fecha_nacimiento'] as String)
            : null,
        etapa: map['etapa'] as String? ?? 'lactancia',
        categoria: map['categoria'] as String?,
        fechaDestete: map['fecha_destete'] != null
            ? DateTime.tryParse(map['fecha_destete'] as String)
            : null,
        capado: (map['capado'] as int? ?? 0) == 1,
        estado: map['estado'] as String? ?? 'activo',
        padreId: map['padre_id'] as String?,
        madreId: map['madre_id'] as String?,
        ubicacionId: map['ubicacion_id'] as String?,
        color: map['color'] as String?,
        raza: map['raza'] as String?,
        fotoUrl: map['foto_url'] as String?,
        fotoLocal: map['foto_local'] as String?,
        nota: map['nota'] as String?,
        createdBy: map['created_by'] as String?,
        updatedBy: map['updated_by'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'numero': numero,
        'sexo': sexo,
        'fecha_nacimiento': fechaNacimiento?.toIso8601String().split('T')[0],
        'etapa': etapa,
        'categoria': categoria,
        'fecha_destete': fechaDestete?.toIso8601String().split('T')[0],
        'capado': capado ? 1 : 0,
        'estado': estado,
        'padre_id': padreId,
        'madre_id': madreId,
        'ubicacion_id': ubicacionId,
        'color': color,
        'raza': raza,
        'foto_url': fotoUrl,
        'foto_local': fotoLocal,
        'nota': nota,
        'created_by': createdBy,
        'updated_by': updatedBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Ternero copyWith({
    String? numero,
    String? sexo,
    Object? fechaNacimiento = sinCambio,
    String? etapa,
    String? categoria,
    Object? fechaDestete = sinCambio,
    bool? capado,
    String? estado,
    Object? padreId = sinCambio,
    Object? madreId = sinCambio,
    Object? ubicacionId = sinCambio,
    Object? color = sinCambio,
    Object? raza = sinCambio,
    Object? nota = sinCambio,
  }) =>
      Ternero(
        id: id,
        numero: numero ?? this.numero,
        sexo: sexo ?? this.sexo,
        fechaNacimiento:
            valorOAnterior<DateTime>(fechaNacimiento, this.fechaNacimiento),
        // Al fijar una categoría, la etapa antigua se mantiene coherente.
        etapa: categoria != null ? etapaDeCategoria(categoria) : (etapa ?? this.etapa),
        categoria: categoria ?? this.categoria,
        fechaDestete: valorOAnterior<DateTime>(fechaDestete, this.fechaDestete),
        capado: capado ?? this.capado,
        estado: estado ?? this.estado,
        padreId: valorOAnterior<String>(padreId, this.padreId),
        madreId: valorOAnterior<String>(madreId, this.madreId),
        ubicacionId: valorOAnterior<String>(ubicacionId, this.ubicacionId),
        color: valorOAnterior<String>(color, this.color),
        raza: valorOAnterior<String>(raza, this.raza),
        fotoUrl: fotoUrl,
        fotoLocal: fotoLocal,
        nota: valorOAnterior<String>(nota, this.nota),
        createdBy: createdBy,
        updatedBy: updatedBy,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

class PesadaTernero {
  final String id;
  final String terneroId;
  final DateTime fecha;
  final double peso;
  final String? notas;
  final DateTime createdAt;

  const PesadaTernero({
    required this.id,
    required this.terneroId,
    required this.fecha,
    required this.peso,
    this.notas,
    required this.createdAt,
  });

  factory PesadaTernero.fromMap(Map<String, dynamic> map) => PesadaTernero(
        id: map['id'] as String,
        terneroId: map['ternero_id'] as String,
        fecha: DateTime.parse(map['fecha'] as String),
        peso: (map['peso'] as num).toDouble(),
        notas: map['notas'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'ternero_id': terneroId,
        'fecha': fecha.toIso8601String().split('T')[0],
        'peso': peso,
        'notas': notas,
        'created_at': createdAt.toIso8601String(),
      };
}

class TrasladoTernero {
  final String id;
  final String terneroId;
  final DateTime fecha;
  final String? ubicacionOrigenId;
  final String ubicacionDestinoId;
  final String? notas;
  final DateTime createdAt;

  const TrasladoTernero({
    required this.id,
    required this.terneroId,
    required this.fecha,
    this.ubicacionOrigenId,
    required this.ubicacionDestinoId,
    this.notas,
    required this.createdAt,
  });

  factory TrasladoTernero.fromMap(Map<String, dynamic> map) => TrasladoTernero(
        id: map['id'] as String,
        terneroId: map['ternero_id'] as String,
        fecha: DateTime.parse(map['fecha'] as String),
        ubicacionOrigenId: map['ubicacion_origen_id'] as String?,
        ubicacionDestinoId: map['ubicacion_destino_id'] as String,
        notas: map['notas'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'ternero_id': terneroId,
        'fecha': fecha.toIso8601String().split('T')[0],
        'ubicacion_origen_id': ubicacionOrigenId,
        'ubicacion_destino_id': ubicacionDestinoId,
        'notas': notas,
        'created_at': createdAt.toIso8601String(),
      };
}

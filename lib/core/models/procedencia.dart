/// De dónde viene un animal (vacas, toros y levante): su origen, su número
/// de registro genealógico y los datos del padre y de la madre cuando no
/// están en la finca (animales comprados o importados, inseminación).
class Procedencia {
  /// 'finca' | 'comprada' | 'importada'; null = sin dato.
  final String? origen;
  final String? registro;
  final String? padreNombre;
  final String? padreRegistro;
  final String? padreRaza;
  final String? madreNombre;
  final String? madreRegistro;
  final String? madreRaza;

  const Procedencia({
    this.origen,
    this.registro,
    this.padreNombre,
    this.padreRegistro,
    this.padreRaza,
    this.madreNombre,
    this.madreRegistro,
    this.madreRaza,
  });

  static const origenes = ['finca', 'comprada', 'importada'];

  /// "Nacida en la finca" / "Comprado" / "Importada"...
  static String origenTexto(String origen, {required bool hembra}) {
    final a = hembra ? 'a' : 'o';
    return switch (origen) {
      'finca' => 'Nacid$a en la finca',
      'comprada' => 'Comprad$a',
      'importada' => 'Importad$a',
      _ => origen,
    };
  }

  bool get padreExterno =>
      padreNombre != null || padreRegistro != null || padreRaza != null;
  bool get madreExterna =>
      madreNombre != null || madreRegistro != null || madreRaza != null;

  /// "Lucero · Reg. 12345 · Brahman" (null si no hay datos).
  static String? _texto(String? nombre, String? registro, String? raza) {
    final partes = [
      if (nombre != null) nombre,
      if (registro != null) 'Reg. $registro',
      if (raza != null) raza,
    ];
    return partes.isEmpty ? null : partes.join(' · ');
  }

  String? get padreTexto => _texto(padreNombre, padreRegistro, padreRaza);
  String? get madreTexto => _texto(madreNombre, madreRegistro, madreRaza);

  factory Procedencia.fromMap(Map<String, dynamic> m) => Procedencia(
        origen: m['origen'] as String?,
        registro: m['registro'] as String?,
        padreNombre: m['padre_ext_nombre'] as String?,
        padreRegistro: m['padre_ext_registro'] as String?,
        padreRaza: m['padre_ext_raza'] as String?,
        madreNombre: m['madre_ext_nombre'] as String?,
        madreRegistro: m['madre_ext_registro'] as String?,
        madreRaza: m['madre_ext_raza'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'origen': origen,
        'registro': registro,
        'padre_ext_nombre': padreNombre,
        'padre_ext_registro': padreRegistro,
        'padre_ext_raza': padreRaza,
        'madre_ext_nombre': madreNombre,
        'madre_ext_registro': madreRegistro,
        'madre_ext_raza': madreRaza,
      };

  /// Columnas en las tablas vacas, toros y terneros.
  static const columnas = [
    'origen',
    'registro',
    'padre_ext_nombre',
    'padre_ext_registro',
    'padre_ext_raza',
    'madre_ext_nombre',
    'madre_ext_registro',
    'madre_ext_raza',
  ];
}

/// Valores de manejo de la finca usados por alertas y sugerencias.

/// Días máximos entre dosis de vitamina antes de avisar.
const kDiasVitamina = 120;

/// Días de secado antes del parto mientras no haya historial propio.
const kDiasSecadoPorDefecto = 60;

/// Mínimo de casos propios para usar el promedio en lugar del valor por defecto.
const kMinimoCasosPromedio = 3;

/// Avisar de partos que ocurrirán dentro de estos días.
const kDiasAvisoParto = 30;

/// Avisar de vacas que siguen vacías este tiempo después del parto.
const kDiasVaciaPostParto = 90;

/// Edad (meses) a la que se destetan los terneros.
const kMesesDestete = 9;

/// Edad (meses) a la que una novilla de levante pasa a novilla de vientre.
const kMesesNovillaVientre = 24;

/// Gestación bovina promedio.
const kDiasGestacion = 283;

/// Razas sugeridas (el campo acepta cualquier otra).
const kRazasSugeridas = [
  'Mestiza',
  'Brahman',
  'Gyr',
  'Girolando',
  'Holstein',
  'Pardo Suizo',
  'Jersey',
  'Simmental',
  'Normando',
  'Cebú',
];

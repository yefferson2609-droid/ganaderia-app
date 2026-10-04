/// Edad legible a partir de la fecha de nacimiento: "3 años 2 meses",
/// "5 meses", "12 días" o "Sin fecha".
String edadTexto(DateTime? nacimiento) {
  if (nacimiento == null) return 'Sin fecha';
  final diff = DateTime.now().difference(nacimiento);
  final years = diff.inDays ~/ 365;
  final months = (diff.inDays % 365) ~/ 30;
  if (years > 0) {
    return '$years año${years > 1 ? 's' : ''} $months mes${months != 1 ? 'es' : ''}';
  }
  if (months > 0) return '$months mes${months != 1 ? 'es' : ''}';
  return '${diff.inDays} días';
}

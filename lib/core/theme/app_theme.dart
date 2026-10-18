import 'package:flutter/material.dart';

/// Paleta "Campo moderno" (multi-finca): verde pasto como color de marca,
/// tierra como acento, fondo crema claro con tarjetas blancas, y colores de
/// estado que se leen bien al sol y en tema oscuro.
class AppColors {
  AppColors._();

  // Marca
  static const primary = Color(0xFF2E6B3F);
  static const primaryLight = Color(0xFF5E9A68);
  static const primaryDark = Color(0xFF1E4A2B);
  static const primaryContainer = Color(0xFFDCEBDD);

  // Tierra
  static const secondary = Color(0xFF9C6B3C);
  static const secondaryContainer = Color(0xFFF3E6D3);

  // Estado / semántica
  static const success = Color(0xFF2E6B3F);
  static const warning = Color(0xFFC27A12);
  static const danger = Color(0xFFB3261E);
  static const dangerContainer = Color(0xFFFBE9E7);
  static const info = Color(0xFF2563A8);
  static const accentPurple = Color(0xFF6A3D9A);

  static const neutralGrey = Color(0xFF6B7470);

  // Superficies (tema claro)
  static const fondo = Color(0xFFF6F3EC); // crema
  static const tarjeta = Colors.white;
  static const borde = Color(0xFFE5E0D4);
  static const texto = Color(0xFF1D2A21);
  static const textoSuave = Color(0xFF5C6660);

  // Superficies (tema oscuro)
  static const fondoOscuro = Color(0xFF121813);
  static const tarjetaOscura = Color(0xFF1B231D);
  static const bordeOscuro = Color(0xFF2C3830);
}

class AppTheme {
  /// Letra fija solo para la vista previa de diseño (en el teléfono es null:
  /// se usa la del sistema).
  static String? fuente;

  static ThemeData get light => _tema(Brightness.light);
  static ThemeData get dark => _tema(Brightness.dark);

  static ThemeData _tema(Brightness brillo) {
    final oscuro = brillo == Brightness.dark;
    final principal = oscuro ? const Color(0xFF8CC796) : AppColors.primary;
    final sobrePrincipal = oscuro ? const Color(0xFF0E2414) : Colors.white;
    final fondo = oscuro ? AppColors.fondoOscuro : AppColors.fondo;
    final tarjeta = oscuro ? AppColors.tarjetaOscura : AppColors.tarjeta;
    final borde = oscuro ? AppColors.bordeOscuro : AppColors.borde;
    final texto = oscuro ? const Color(0xFFE6ECE7) : AppColors.texto;
    final textoSuave = oscuro ? const Color(0xFFA3AEA6) : AppColors.textoSuave;

    final esquema = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brillo,
    ).copyWith(
      primary: principal,
      onPrimary: sobrePrincipal,
      primaryContainer:
          oscuro ? const Color(0xFF244A2D) : AppColors.primaryContainer,
      onPrimaryContainer:
          oscuro ? const Color(0xFFCDE8D1) : AppColors.primaryDark,
      secondary: oscuro ? const Color(0xFFD9A876) : AppColors.secondary,
      onSecondary: oscuro ? const Color(0xFF2B1A08) : Colors.white,
      secondaryContainer:
          oscuro ? const Color(0xFF4A3420) : AppColors.secondaryContainer,
      onSecondaryContainer:
          oscuro ? const Color(0xFFF3E6D3) : const Color(0xFF4A3018),
      error: AppColors.danger,
      surface: tarjeta,
      onSurface: texto,
      onSurfaceVariant: textoSuave,
      outline: borde,
      outlineVariant: borde,
      surfaceContainerLowest: tarjeta,
      surfaceContainerLow: tarjeta,
      surfaceContainer: tarjeta,
      surfaceContainerHigh: tarjeta,
      surfaceContainerHighest:
          oscuro ? const Color(0xFF243027) : const Color(0xFFEFEBE2),
    );

    final redondo12 = BorderRadius.circular(12);
    final redondo14 = BorderRadius.circular(14);

    final base = ThemeData(
      useMaterial3: true,
      brightness: brillo,
      colorScheme: esquema,
      fontFamily: fuente,
    );
    final letras = base.textTheme.apply(bodyColor: texto, displayColor: texto);

    return base.copyWith(
      scaffoldBackgroundColor: fondo,
      canvasColor: fondo,
      dividerColor: borde,
      textTheme: letras.copyWith(
        headlineMedium:
            letras.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        headlineSmall:
            letras.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        titleLarge: letras.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: letras.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: letras.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: letras.bodyLarge?.copyWith(height: 1.35),
        bodyMedium: letras.bodyMedium?.copyWith(height: 1.35),
        bodySmall: letras.bodySmall?.copyWith(color: textoSuave),
      ),

      // Barra superior verde oscuro, título con presencia.
      appBarTheme: AppBarTheme(
        backgroundColor:
            oscuro ? const Color(0xFF16301D) : AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontFamily: fuente,
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.15),
      ),

      // Tarjetas blancas planas con borde suave.
      cardTheme: CardThemeData(
        color: tarjeta,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borde),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: principal,
        textColor: texto,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),

      // Campos de texto rellenos, bordes redondeados, verde al escribir.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tarjeta,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIconColor: textoSuave,
        labelStyle: TextStyle(fontFamily: fuente, color: textoSuave),
        floatingLabelStyle: TextStyle(
            fontFamily: fuente, color: principal, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(
            borderRadius: redondo12, borderSide: BorderSide(color: borde)),
        enabledBorder: OutlineInputBorder(
            borderRadius: redondo12, borderSide: BorderSide(color: borde)),
        focusedBorder: OutlineInputBorder(
            borderRadius: redondo12,
            borderSide: BorderSide(color: principal, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: redondo12,
            borderSide: const BorderSide(color: AppColors.danger)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: redondo12,
            borderSide: const BorderSide(color: AppColors.danger, width: 2)),
      ),

      // Botones grandes y cómodos para el dedo.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: principal,
          foregroundColor: sobrePrincipal,
          elevation: 0,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: TextStyle(
              fontFamily: fuente, fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: redondo14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: TextStyle(
              fontFamily: fuente, fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: redondo14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: principal,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: BorderSide(color: principal, width: 1.4),
          textStyle: TextStyle(
              fontFamily: fuente, fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: redondo14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: principal,
          textStyle: TextStyle(fontFamily: fuente, fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: principal,
        foregroundColor: sobrePrincipal,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: tarjeta,
        selectedColor: esquema.primaryContainer,
        side: BorderSide(color: borde),
        labelStyle: TextStyle(
            fontFamily: fuente, color: texto, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // Avisos flotantes redondeados.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: oscuro ? const Color(0xFF2B372E) : AppColors.texto,
        contentTextStyle:
            TextStyle(fontFamily: fuente, color: Colors.white, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: redondo12),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: tarjeta,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
            fontFamily: fuente,
            color: texto,
            fontSize: 20,
            fontWeight: FontWeight.w700),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tarjeta,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: tarjeta,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: redondo12),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: tarjeta,
        surfaceTintColor: Colors.transparent,
      ),

      dividerTheme: DividerThemeData(color: borde, thickness: 1, space: 1),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: principal),

      tabBarTheme: TabBarThemeData(
        labelColor: principal,
        unselectedLabelColor: textoSuave,
        indicatorColor: principal,
        labelStyle: TextStyle(fontFamily: fuente, fontWeight: FontWeight.w700),
      ),
    );
  }
}

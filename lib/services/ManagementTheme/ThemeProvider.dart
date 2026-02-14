import 'package:flutter/material.dart';
import 'ThemePrefs.dart';

class ThemeProvider with ChangeNotifier {
  late bool _isDark; // Stato corrente del tema
  final ThemePrefs _preferences = ThemePrefs(); // Gestione delle preferenze

  // Getter per verificare se il tema è scuro
  bool get isDark => _isDark;

  // Getter per il tema attuale (ThemeData)
  ThemeData get currentTheme => _isDark ? darkTheme : lightTheme;

  // Costruttore
  ThemeProvider() {
    _isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    _loadPreferences(); // Carica il tema dalle preferenze
  }

  // Cambia tema e salva nelle preferenze
  void toggleTheme() {
    _isDark = !_isDark;
    _preferences.setTheme(_isDark); // Salva preferenze
    notifyListeners(); // Aggiorna la UI
  }

  // Carica il tema salvato
  Future<void> _loadPreferences() async {
    final savedTheme = await _preferences.getTheme();
    if (savedTheme != null) {
      _isDark = savedTheme;
    }
    notifyListeners(); // Aggiorna la UI dopo il caricamento
  }
}

// Definizione dei temi
const _lightScheme = ColorScheme.light(
  primary: Color(0xFF0057B8),
  onPrimary: Colors.white,
  secondary: Color(0xFFD97706),
  onSecondary: Colors.white,
  surface: Color(0xFFEAF4FF),
  onSurface: Color(0xFF111827),
);

const _darkScheme = ColorScheme.dark(
  primary: Color(0xFF4DA3FF),
  onPrimary: Color(0xFF001A3A),
  secondary: Color(0xFFFFB347),
  onSecondary: Color(0xFF2B1200),
  surface: Color(0xFF1F242B),
  onSurface: Color(0xFFEFF4FB),
);

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  primaryColor: Colors.white,
  colorScheme: _lightScheme,
  scaffoldBackgroundColor: _lightScheme.surface,
  bottomAppBarTheme: const BottomAppBarThemeData(color: Colors.white),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _lightScheme.primary,
      foregroundColor: _lightScheme.onPrimary,
      disabledBackgroundColor: const Color(0xFF9CA3AF),
      disabledForegroundColor: Colors.white,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: _lightScheme.primary,
      foregroundColor: _lightScheme.onPrimary,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _lightScheme.primary,
      side: BorderSide(color: _lightScheme.primary),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFF0057B8),
    foregroundColor: Colors.white,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(
      borderSide:
          BorderSide(color: _lightScheme.primary.withValues(alpha: 0.32)),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: _lightScheme.primary, width: 1.6),
    ),
  ),
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  primaryColor: const Color.fromARGB(255, 89, 88, 88),
  colorScheme: _darkScheme,
  scaffoldBackgroundColor: const Color(0xFF14191F),
  bottomAppBarTheme:
      const BottomAppBarThemeData(color: Color.fromARGB(255, 50, 54, 60)),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _darkScheme.primary,
      foregroundColor: _darkScheme.onPrimary,
      disabledBackgroundColor: const Color(0xFF4B5563),
      disabledForegroundColor: const Color(0xFFD1D5DB),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: _darkScheme.primary,
      foregroundColor: _darkScheme.onPrimary,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _darkScheme.primary,
      side: BorderSide(color: _darkScheme.primary),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFF4DA3FF),
    foregroundColor: Color(0xFF001A3A),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF1F242B),
    enabledBorder: OutlineInputBorder(
      borderSide:
          BorderSide(color: _darkScheme.primary.withValues(alpha: 0.45)),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: _darkScheme.primary, width: 1.6),
    ),
  ),
);

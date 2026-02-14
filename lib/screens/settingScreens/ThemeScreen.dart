import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seawatch/services/ManagementTheme/ThemeProvider.dart';

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tema',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.primary,
      ),
      body: Container(
        width:
            double.infinity, // Fa sì che il contenuto occupi tutto lo schermo
        height:
            double.infinity, // Fa sì che il contenuto occupi tutta l'altezza
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.colorScheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        themeProvider.isDark
                            ? Icons.dark_mode
                            : Icons.light_mode,
                        color: theme.colorScheme.secondary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        themeProvider.isDark ? "Tema Scuro" : "Tema Chiaro",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch(
                        value: themeProvider.isDark,
                        onChanged: (bool value) {
                          themeProvider.toggleTheme();
                        },
                        activeThumbColor: theme.colorScheme.secondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Altri contenuti della pagina qui
            ],
          ),
        ),
      ),
    );
  }
}

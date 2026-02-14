import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:seawatch/screens/MainScreen.dart';
import 'package:seawatch/screens/authentication/LoginScreen.dart';
import 'package:seawatch/screens/authentication/RegistrationScreen.dart';
import 'package:seawatch/screens/settingScreens/SettingsScreen.dart';
import 'package:seawatch/services/AuthServiceGeneral/AuthService.dart';
import 'package:seawatch/services/ManagementTheme/ThemeProvider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );

  final authService = AuthService();
  final isAuthenticated = await authService.checkSession();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MyApp(isAuthenticated: isAuthenticated),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.isAuthenticated});

  final bool isAuthenticated;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Provider.of<ThemeProvider>(context).currentTheme,
      initialRoute: isAuthenticated ? '/main' : '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/registrazione': (_) => const RegistrationScreen(),
        '/main': (_) => const MainScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}

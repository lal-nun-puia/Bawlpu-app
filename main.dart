import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/register_screen.dart';
import 'screens/admin_dashboard_screen.dart';

// ── GLOBAL NOTIFIERS ─────────────────────────────────────────────────────────
final fontSizeNotifier     = ValueNotifier<double>(1.0);
final profilePhotoNotifier = ValueNotifier<String>('');
final themeModeNotifier    = ValueNotifier<ThemeMode>(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load saved font size
  final prefs = await SharedPreferences.getInstance();
  final savedFont = prefs.getDouble('bawlpu_font_scale') ?? 1.0;
  fontSizeNotifier.value = savedFont;
  runApp(const BawlpuApp());
}

class BawlpuApp extends StatelessWidget {
  const BawlpuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (_, mode, __) => ValueListenableBuilder<double>(
        valueListenable: fontSizeNotifier,
        builder: (_, scale, __) => MaterialApp(
          title: 'Bawlpu',
          debugShowCheckedModeBanner: false,
          themeMode: mode,

          // Apply font scale to ALL text in app
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),

          // ── LIGHT THEME ──────────────────────────────────────────────────
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF0F5FB),
            cardColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A6BB5),
              secondary: Color(0xFF3B9EE8),
              surface: Colors.white,
              background: Color(0xFFF0F5FB),
            ),
            textTheme: const TextTheme(
              bodyLarge:  TextStyle(color: Color(0xFF1A2340)),
              bodyMedium: TextStyle(color: Color(0xFF6B7A9B)),
            ),
            useMaterial3: false,
          ),

          // ── DARK THEME ───────────────────────────────────────────────────
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0F1624),
            cardColor: const Color(0xFF1A2235),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF3B9EE8),
              secondary: Color(0xFF1A6BB5),
              surface: Color(0xFF1A2235),
              background: Color(0xFF0F1624),
            ),
            textTheme: const TextTheme(
              bodyLarge:  TextStyle(color: Color(0xFFE8ECFF)),
              bodyMedium: TextStyle(color: Color(0xFF8B9CC5)),
            ),
            useMaterial3: false,
          ),

          initialRoute: '/login',
          routes: {
            '/login':    (_) => const LoginScreen(),
            '/home':     (_) => const HomeScreen(),
            '/register': (_) => const RegisterScreen(),
            '/admin':    (_) => const AdminDashboardScreen(),
          },
        ),
      ),
    );
  }
}
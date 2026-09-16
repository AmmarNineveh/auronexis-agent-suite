 import 'package:flutter/material.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
 import 'screens/pairing_screen.dart';
 
 void main() {
   WidgetsFlutterBinding.ensureInitialized();
   runApp(const ProviderScope(child: AgentMobileApp()));
 }
 
 class AgentMobileApp extends StatelessWidget {
   const AgentMobileApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    // Calm, professional slate-blue palette with balanced contrast (no neon)
    const primaryBlue = Color(0xFF3B82F6); // Balanced, soft royal blue
    const deepNavy = Color(0xFF0F172A); // Slate 900
    const cardSurface = Color(0xFF1E293B); // Slate 800
    const textPrimary = Color(0xFFF8FAFC); // Clean soft white

    return MaterialApp(
      title: 'AgentMobile',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          scrolledUnderElevation: 2,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.dark,
          surface: deepNavy,
          surfaceContainerHighest: cardSurface,
          primary: primaryBlue,
          onPrimary: Colors.white,
        ),
        scaffoldBackgroundColor: deepNavy,
        cardTheme: CardThemeData(
          elevation: 0,
          color: cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: deepNavy,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const PairingScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/lobby_screen.dart'; // Ini akan dibuat nanti
import 'models/game_state.dart';   // Ini akan dibuat nanti
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Pastikan ini ada

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const WerewolfApp());
}

class WerewolfApp extends StatelessWidget {
  const WerewolfApp({super.key}); // Ubah Key? key menjadi super.key

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => GameState(),
      child: MaterialApp(
        title: 'Werewolf Game',
        theme: ThemeData(
          primarySwatch: Colors.red,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF1E1E1E),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E1E1E),
            elevation: 0,
          ),
          textTheme: GoogleFonts.poppinsTextTheme(
            const TextTheme(
              headlineMedium: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.white70),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red.shade800, width: 2),
            ),
          ),
          useMaterial3: true, // Opsional: gunakan Material 3
        ),
        home: const LobbyScreen(), // LobbyScreen adalah layar awal Anda
      ),
    );
  }
}
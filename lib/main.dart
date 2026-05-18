import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'features/splash/presentation/splash_screen.dart';
//import 'core/constants/app_strings.dart';

// The remote control for our theme
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // THE FIX: Wait for Firebase to securely restore the user session first!
  final user = await FirebaseAuth.instance.authStateChanges().first;
  
  if (user != null) {
    try {
      // Now that we definitely have the user, grab their saved theme
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final isDark = doc.data()?['isDarkMode'] ?? false;
        themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
      }
    } catch (e) {
      // If offline, it just safely defaults to light
    }
  }

  runApp(const ProviderScope(child: DesiFitApp()));
}

class DesiFitApp extends StatelessWidget {
  const DesiFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'DesiFit',
          themeMode: currentMode,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: const SplashScreen(),
        );
      },
    );
  }
}
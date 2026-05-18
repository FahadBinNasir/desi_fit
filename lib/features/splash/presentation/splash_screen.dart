import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- UPDATED IMPORT: Point to MainScreen instead of HomeScreen ---
import '../../../presentation/main_screen.dart'; 
import '../../onboarding/presentation/screens/onboarding_screen.dart';
import '../../auth/presentation/screens/auth_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  Future<Widget> _checkUserStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        return const AuthScreen();
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (snapshot.exists && snapshot.data() != null) {
        // --- UPDATED ROUTE: Go to MainScreen to load the Bottom Nav Bar ---
        return const MainScreen(); 
      } else {
        return const OnboardingScreen();
      }
    } catch (e) {
      return const AuthScreen();
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueAccent, // Or Theme.of(context).colorScheme.primary
      body: FutureBuilder<Widget>(
        future: _checkUserStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => snapshot.data!),
              );
            });
          }
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // UPGRADED SPLASH SCREEN UI
                Icon(Icons.local_fire_department, size: 100, color: Colors.orangeAccent),
                SizedBox(height: 10),
                Text(
                  "DESIFIT", 
                  style: TextStyle(
                    fontSize: 36, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.white, 
                    letterSpacing: 4
                  )
                ),
                SizedBox(height: 40),
                CircularProgressIndicator(color: Colors.white),
              ],
            ),
          );
        },
      ),
    );
  }
}
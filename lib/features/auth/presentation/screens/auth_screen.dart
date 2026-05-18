import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:desi_fit/features/splash/presentation/splash_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  String _generatePin() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  Future<bool> _send2FAEmail(String userEmail, String pinCode) async {
    const serviceId = ''; 
    const templateId = '';
    const publicKey = ''; 

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    
    try {
      final response = await http.post(
        url,
        // BUG FIX: Added 'origin' to bypass strict mobile network blocks
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost' 
        },
        body: json.encode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': publicKey,
          'template_params': {
            'email': userEmail,
            'pin_code': pinCode,
          }
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false; 
    }
  }

  Future<void> _showPinVerificationDialog(String userEmail, String actualPin) async {
    final pinController = TextEditingController();
    bool isVerifying = false;

    await showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Two-Factor Authentication'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('We sent a 6-digit security code to your email. Please enter it below.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    FirebaseAuth.instance.signOut(); 
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: isVerifying ? null : () async {
                    setState(() => isVerifying = true);
                    
                    if (pinController.text.trim() == actualPin) {
                      Navigator.pop(context); 
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SplashScreen()));
                    } else {
                      setState(() => isVerifying = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Incorrect PIN. Try again.'), backgroundColor: Colors.red)
                      );
                    }
                  },
                  child: isVerifying ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Verify'),
                )
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid email and a password (min 6 chars).')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
        
        // TOGGLE LOGIC: Check if 2FA is enabled for this user
        final doc = await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).get();
        final is2FAEnabled = doc.data()?['is2FAEnabled'] ?? false;

        if (!is2FAEnabled) {
          if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SplashScreen()));
          return; // Skip 2FA completely
        }
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
        // By default, new users need 2FA. We will save the toggle state during onboarding.
      }
      
      if (mounted) {
        final newPin = _generatePin();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending 2FA code...'), duration: Duration(seconds: 2)));

        final emailSent = await _send2FAEmail(email, newPin);
        
        if (emailSent && mounted) {
          await _showPinVerificationDialog(email, newPin);
        } else if (mounted) {
          FirebaseAuth.instance.signOut();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send 2FA email. Please try again.'), backgroundColor: Colors.red));
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Authentication failed.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_person, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                _isLogin ? 'Welcome Back' : 'Create Account',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitAuth,
                child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_isLogin ? 'Login' : 'Sign Up'),
              ),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin ? 'Need an account? Sign up' : 'Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
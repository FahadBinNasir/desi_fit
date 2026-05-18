import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/calorie_calculator.dart';
import '../../../../presentation/main_screen.dart';
import '../../data/models/user_profile.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();

  bool _isMale = true;
  String _selectedGoal = AppStrings.goalLoss;
  double _activityLevel = 1.15;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Profile'), elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person))),
              const SizedBox(height: 16),
              TextField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      prefixIcon: Icon(Icons.monitor_weight))),
              const SizedBox(height: 16),
              TextField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Height (cm)',
                      prefixIcon: Icon(Icons.height))),
              const SizedBox(height: 16),
              TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Age', prefixIcon: Icon(Icons.cake))),
              const SizedBox(height: 24),

              const Text('Gender',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

              // FIX: Replaced deprecated groupValue/onChanged on Radio with RadioGroup
              RadioGroup<bool>(
                groupValue: _isMale,
                onChanged: (val) => setState(() => _isMale = val!),
                child: Row(
                  children: [
                    Radio<bool>(value: true, activeColor: Theme.of(context).primaryColor),
                    const Text('Male'),
                    const SizedBox(width: 20),
                    Radio<bool>(value: false, activeColor: Theme.of(context).primaryColor),
                    const Text('Female'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _selectedGoal,
                items: [
                  AppStrings.goalLoss,
                  AppStrings.goalMaintain,
                  AppStrings.goalGain,
                  AppStrings.goalMuscle
                ]
                    .map((goal) =>
                        DropdownMenuItem(value: goal, child: Text(goal)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedGoal = val!),
                decoration: const InputDecoration(
                    labelText: 'Your Goal',
                    prefixIcon: Icon(Icons.flag)),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<double>(
                initialValue: _activityLevel,
                items: const [
                  DropdownMenuItem(
                      value: 1.15, child: Text('No exercise')),
                  DropdownMenuItem(
                      value: 1.37, child: Text('1-3 days/week')),
                  DropdownMenuItem(
                      value: 1.5, child: Text('4-5 days/week')),
                  DropdownMenuItem(
                      value: 1.72, child: Text('6-7 days/week')),
                ],
                onChanged: (val) =>
                    setState(() => _activityLevel = val!),
                decoration: const InputDecoration(
                    labelText: 'Activity Level',
                    prefixIcon: Icon(Icons.directions_run)),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () async {
                  if (_nameController.text.trim().isEmpty ||
                      _weightController.text.trim().isEmpty ||
                      _heightController.text.trim().isEmpty ||
                      _ageController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Please fill all fields to calculate your calories!'),
                          backgroundColor: Colors.red),
                    );
                    return;
                  }

                  double w =
                      double.tryParse(_weightController.text) ?? 0;
                  double h =
                      double.tryParse(_heightController.text) ?? 0;
                  int a = int.tryParse(_ageController.text) ?? 0;

                  double bmr = CalorieCalculator.calculateBMR(
                      weight: w, height: h, age: a, isMale: _isMale);
                  double tdee = CalorieCalculator.calculateTDEE(
                      bmr, _activityLevel);

                  int finalCalories = tdee.round();
                  if (_selectedGoal == AppStrings.goalLoss) {
                    finalCalories -= 400;
                  }
                  if (_selectedGoal == AppStrings.goalGain ||
                      _selectedGoal == AppStrings.goalMuscle) {
                    finalCalories += 400;
                  }

                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  final profile = UserProfile(
                    uid: user.uid,
                    name: _nameController.text.trim(),
                    age: a,
                    weight: w,
                    height: h,
                    isMale: _isMale,
                    goal: _selectedGoal,
                    activityLevel: _activityLevel,
                    dailyCalorieTarget: finalCalories,
                  );

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(profile.uid)
                      .set(profile.toMap());

                  if (context.mounted) {
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const MainScreen()));
                  }
                },
                child: const Text('Calculate & Save',
                    style: TextStyle(fontSize: 18)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

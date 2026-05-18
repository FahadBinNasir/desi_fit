import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/utils/calorie_calculator.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../../../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoadingStats = true;

  int _avgCals = 0;
  int _avgBurn = 0;
  int _avgWater = 0;

  List<double> _calData = List.filled(7, 0);
  List<double> _burnData = List.filled(7, 0);
  List<double> _waterData = List.filled(7, 0);

  @override
  void initState() {
    super.initState();
    _fetchWeeklyStats();
  }

  Future<void> _fetchWeeklyStats() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final now = DateTime.now();

    final int daysSinceMonday = now.weekday - 1;
    final DateTime monday =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: daysSinceMonday));
    final DateTime nextMonday = monday.add(const Duration(days: 7));

    int totalCals = 0, totalBurn = 0, totalWater = 0;
    List<double> tempCals = List.filled(7, 0);
    List<double> tempBurn = List.filled(7, 0);
    List<double> tempWater = List.filled(7, 0);

    try {
      final mealsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('meals')
          .where('timestamp', isGreaterThanOrEqualTo: monday)
          .where('timestamp', isLessThan: nextMonday)
          .get();
      for (var doc in mealsSnap.docs) {
        DateTime date = (doc['timestamp'] as Timestamp).toDate();
        int cals = doc['calories'] ?? 0;
        totalCals += cals;
        tempCals[date.weekday - 1] += cals;
      }

      final workoutSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('workouts')
          .where('timestamp', isGreaterThanOrEqualTo: monday)
          .where('timestamp', isLessThan: nextMonday)
          .get();
      for (var doc in workoutSnap.docs) {
        DateTime date = (doc['timestamp'] as Timestamp).toDate();
        int burn = doc['calories'] ?? 0;
        totalBurn += burn;
        tempBurn[date.weekday - 1] += burn;
      }

      String startStr =
          "${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}";
      String endStr =
          "${nextMonday.year}-${nextMonday.month.toString().padLeft(2, '0')}-${nextMonday.day.toString().padLeft(2, '0')}";

      final waterSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('water_logs')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startStr)
          .where(FieldPath.documentId, isLessThan: endStr)
          .get();

      for (var doc in waterSnap.docs) {
        DateTime date = (doc['timestamp'] as Timestamp).toDate();
        int glasses = doc['glasses'] ?? 0;
        totalWater += glasses;
        tempWater[date.weekday - 1] += glasses;
      }

      int daysPassed = now.weekday;
      setState(() {
        _avgCals = (totalCals / daysPassed).round();
        _avgBurn = (totalBurn / daysPassed).round();
        _avgWater = (totalWater / daysPassed).round();
        _calData = tempCals;
        _burnData = tempBurn;
        _waterData = tempWater;
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _deleteAccount() async {
    bool? firstConfirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Delete Account?"),
              content: const Text(
                  "This action cannot be undone. All your data, meals, and workouts will be wiped forever."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Cancel")),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text("Delete",
                        style: TextStyle(color: Colors.red))),
              ],
            ));

    if (firstConfirm != true) return;

    if (!mounted) return;
    bool? finalConfirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Are you absolutely sure?",
                  style: TextStyle(color: Colors.red)),
              content: const Text("Type 'DELETE' to confirm."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("PERMANENTLY DELETE"),
                ),
              ],
            ));

    if (finalConfirm != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final uid = user.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      await user.delete();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
            (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Error: Please log out, log back in, and try again. (Security Requirement)"),
            backgroundColor: Colors.red));
      }
    }
  }

  void _showEditProfile(Map<String, dynamic> currentData) {
    final weightCtrl =
        TextEditingController(text: currentData['weight']?.toString());

    String rawGoal = (currentData['goal'] ?? 'Maintain').toString();
    String selectedGoal = 'Maintain';

    final validGoals = ['Lose Weight', 'Maintain', 'Gain Weight', 'Build Muscle'];
    if (validGoals.contains(rawGoal)) {
      selectedGoal = rawGoal;
    } else {
      if (rawGoal.toLowerCase().contains('lose')) {
        selectedGoal = 'Lose Weight';
      } else if (rawGoal.toLowerCase().contains('gain')) {
        selectedGoal = 'Gain Weight';
      } else if (rawGoal.toLowerCase().contains('build') ||
          rawGoal.toLowerCase().contains('muscle')) {
        selectedGoal = 'Build Muscle';
      }
    }

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                  left: 24,
                  right: 24,
                  top: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Edit Profile",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: weightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: "Current Weight (kg)",
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGoal,
                    items: validGoals
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) =>
                        setModalState(() => selectedGoal = val!),
                    decoration: const InputDecoration(
                        labelText: "Goal", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50)),
                    onPressed: () async {
                      double w = double.tryParse(weightCtrl.text) ?? 70.0;
                      double h =
                          (currentData['height'] ?? 170.0).toDouble();
                      int a = (currentData['age'] ?? 25).toInt();
                      bool isMale = currentData['isMale'] ?? true;
                      double activity =
                          (currentData['activityLevel'] ?? 1.2).toDouble();

                      double bmr = CalorieCalculator.calculateBMR(
                          weight: w, height: h, age: a, isMale: isMale);
                      double tdee =
                          CalorieCalculator.calculateTDEE(bmr, activity);

                      int newTarget = tdee.round();
                      if (selectedGoal.contains('Lose')) newTarget -= 400;
                      if (selectedGoal.contains('Gain') ||
                          selectedGoal.contains('Build')) {
                        newTarget += 400;
                      }

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .set({
                        'weight': w,
                        'goal': selectedGoal,
                        'dailyCalorieTarget': newTarget,
                      }, SetOptions(merge: true));

                      // ignore: use_build_context_synchronously
                      if (mounted) Navigator.pop(ctx);
                    },
                    child: const Text("Save Changes"),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Not logged in"));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
          title: const Text("Profile & Settings"),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData =
              snapshot.data!.data() as Map<String, dynamic>? ?? {};
          bool isDark = userData['isDarkMode'] ?? false;
          bool is2FA = userData['is2FAEnabled'] ?? false;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.blueAccent,
                            child: Icon(Icons.person,
                                size: 40, color: Colors.white)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(userData['name'] ?? "DesiFit User",
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                  "${userData['weight']} kg • ${userData['height']} cm",
                                  style:
                                      const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text("Goal: ${userData['goal']}",
                                    style: TextStyle(
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              )
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditProfile(userData),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text("This Week's Averages",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatBox("Eaten", "$_avgCals", "kcal", Colors.green),
                    const SizedBox(width: 8),
                    _buildStatBox("Burned", "$_avgBurn", "kcal", Colors.orange),
                    const SizedBox(width: 8),
                    _buildStatBox(
                        "Water", "$_avgWater", "glasses", Colors.blue),
                  ],
                ),
                const SizedBox(height: 16),

                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Weekly Activity (Mon-Sun)",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _isLoadingStats
                            ? const Center(child: CircularProgressIndicator())
                            : SizedBox(
                                height: 150,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: List.generate(7, (index) {
                                    final days = [
                                      'M', 'T', 'W', 'T', 'F', 'S', 'S'
                                    ];
                                    double calHeight =
                                        (_calData[index] / 3000).clamp(0.0, 1.0) * 100;
                                    double burnHeight =
                                        (_burnData[index] / 1000).clamp(0.0, 1.0) * 100;
                                    double waterHeight =
                                        (_waterData[index] / 15).clamp(0.0, 1.0) * 100;

                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.end,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                                width: 6,
                                                height: calHeight,
                                                color: Colors.green,
                                                margin: const EdgeInsets.only(
                                                    right: 2)),
                                            Container(
                                                width: 6,
                                                height: burnHeight,
                                                color: Colors.orange,
                                                margin: const EdgeInsets.only(
                                                    right: 2)),
                                            Container(
                                                width: 6,
                                                height: waterHeight,
                                                color: Colors.blue),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(days[index],
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                        const SizedBox(height: 16),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.circle, size: 10, color: Colors.green),
                            SizedBox(width: 4),
                            Text("Intake", style: TextStyle(fontSize: 12)),
                            SizedBox(width: 12),
                            Icon(Icons.circle,
                                size: 10, color: Colors.orange),
                            SizedBox(width: 4),
                            Text("Burn", style: TextStyle(fontSize: 12)),
                            SizedBox(width: 12),
                            Icon(Icons.circle, size: 10, color: Colors.blue),
                            SizedBox(width: 4),
                            Text("Water", style: TextStyle(fontSize: 12)),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text("Settings",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text("Dark Theme"),
                        secondary: const Icon(Icons.dark_mode),
                        value: isDark,
                        onChanged: (val) {
                          themeNotifier.value =
                              val ? ThemeMode.dark : ThemeMode.light;
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .set({'isDarkMode': val},
                                  SetOptions(merge: true));
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text("Two-Factor Authentication"),
                        secondary: const Icon(Icons.security),
                        value: is2FA,
                        onChanged: (val) {
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .set({'is2FAEnabled': val},
                                  SetOptions(merge: true));
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text("Log Out"),
                        onTap: () async {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (context) => const AuthScreen()),
                                (route) => false);
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.delete_forever,
                            color: Colors.red),
                        title: const Text("Delete Account",
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold)),
                        onTap: _deleteAccount,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatBox(
      String title, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
            // FIX: withOpacity -> withValues
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Column(
          children: [
            Text(title,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            Text(unit,
                style:
                    const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

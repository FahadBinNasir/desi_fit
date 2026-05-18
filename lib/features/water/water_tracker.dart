import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:percent_indicator/percent_indicator.dart';

class WaterTrackerScreen extends StatefulWidget {
  const WaterTrackerScreen({super.key});

  @override
  State<WaterTrackerScreen> createState() => _WaterTrackerScreenState();
}

class _WaterTrackerScreenState extends State<WaterTrackerScreen> {
  DateTime _selectedDate = DateTime.now();

  void _changeDate(int days) {
    final newDate = _selectedDate.add(Duration(days: days));
    final today = DateTime.now();

    // Normalize to compare just the calendar days
    final normalizedNew = DateTime(newDate.year, newDate.month, newDate.day);
    final normalizedToday = DateTime(today.year, today.month, today.day);

    // Stop if they try to go into the future
    if (normalizedNew.isAfter(normalizedToday)) return;

    setState(() => _selectedDate = newDate);
  }

  String _getDisplayDate() {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${weekdays[_selectedDate.weekday - 1]}, ${months[_selectedDate.month - 1]} ${_selectedDate.day}";
  }

  String _getDocIdDate() {
    return "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
  }

  Future<void> _updateWater(int amount, int currentGlasses) async {
    if (currentGlasses == 0 && amount < 0) return; 

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Null safety check
    
    final dateId = _getDocIdDate();
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('water_logs').doc(dateId);
    
    await docRef.set({
      'glasses': FieldValue.increment(amount),
      'timestamp': DateTime.now(), 
    }, SetOptions(merge: true));
  }

  Future<void> _updateSettings(String key, dynamic value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      key: value
    }, SetOptions(merge: true));
  }

  Future<void> _selectTime(BuildContext context, String currentStringTime, String key) async {
    List<String> parts = currentStringTime.split(":");
    TimeOfDay initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: initialTime);
    if (picked != null) {
      String formattedTime = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      await _updateSettings(key, formattedTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    // Fallback UI if user data drops momentarily
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final dateId = _getDocIdDate();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,//Colors.grey[100],
      appBar: AppBar(
        title: const Text('Water Tracker'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: userRef.snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) return Center(child: Text('Error: ${userSnapshot.error}'));
          if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          // Safely cast data to avoid Null Check Operator crash
          final userData = (userSnapshot.data?.data() as Map<String, dynamic>?) ?? {};
          
          double weight = (userData['weight'] ?? 70.0).toDouble();
          int targetGlasses = ((weight * 0.033) / 0.25).round();
          if (targetGlasses < 4) targetGlasses = 8; 

          bool remindersOn = userData['waterRemindersOn'] ?? false;
          String startTime = userData['waterStartTime'] ?? "08:00";
          String endTime = userData['waterEndTime'] ?? "20:00";

          return StreamBuilder<DocumentSnapshot>(
            stream: userRef.collection('water_logs').doc(dateId).snapshots(),
            builder: (context, waterSnapshot) {
              
              if (waterSnapshot.hasError) return Center(child: Text('Error: ${waterSnapshot.error}'));
              if (waterSnapshot.connectionState == ConnectionState.waiting && !waterSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              int currentGlasses = 0;
              final waterData = waterSnapshot.data?.data() as Map<String, dynamic>?;
              if (waterData != null) {
                currentGlasses = waterData['glasses'] ?? 0;
              }

              double percent = targetGlasses > 0 ? (currentGlasses / targetGlasses).toDouble().clamp(0.0, 1.0) : 0.0;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => _changeDate(-1)),
                        Text(_getDisplayDate(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.arrow_forward_ios), onPressed: () => _changeDate(1)),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Card(
                      margin: const EdgeInsets.all(24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        child: Column(
                          children: [
                            CircularPercentIndicator(
                              radius: 120.0,
                              lineWidth: 20.0,
                              animation: true,
                              animateFromLastPercent: true,
                              percent: percent,
                              center: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.water_drop, color: Colors.blueAccent, size: 40),
                                  const SizedBox(height: 8),
                                  Text('$currentGlasses / $targetGlasses', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                                  const Text('Glasses', style: TextStyle(fontSize: 16, color: Colors.grey)),
                                ],
                              ),
                              circularStrokeCap: CircularStrokeCap.round,
                              progressColor: Colors.blueAccent,
                              backgroundColor: Colors.blue.shade50,
                            ),
                            const SizedBox(height: 40),
                            
                            // FIXED CONTROLS: Replaced ElevatedButton with safely bounded Material + IconButton
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Material(
                                  color: Colors.grey.shade200,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    iconSize: 32,
                                    padding: const EdgeInsets.all(16),
                                    onPressed: () => _updateWater(-1, currentGlasses),
                                    icon: const Icon(Icons.remove, color: Colors.black),
                                  ),
                                ),
                                Material(
                                  color: Colors.blueAccent,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    iconSize: 40,
                                    padding: const EdgeInsets.all(20),
                                    onPressed: () => _updateWater(1, currentGlasses),
                                    icon: const Icon(Icons.add, color: Colors.white),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text("Hourly Reminders", style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: const Text("Drink water every hour"),
                              activeThumbColor: Colors.blueAccent,
                              value: remindersOn,
                              onChanged: (val) => _updateSettings('waterRemindersOn', val),
                              secondary: const Icon(Icons.notifications_active, color: Colors.blueAccent),
                            ),
                            if (remindersOn) ...[
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.wb_sunny, color: Colors.orange),
                                title: const Text("Start Time"),
                                trailing: Text(startTime, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                onTap: () => _selectTime(context, startTime, 'waterStartTime'),
                              ),
                              ListTile(
                                leading: const Icon(Icons.nights_stay, color: Colors.indigo),
                                title: const Text("End Time"),
                                trailing: Text(endTime, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                onTap: () => _selectTime(context, endTime, 'waterEndTime'),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 30)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
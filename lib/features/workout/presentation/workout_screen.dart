import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'log_workout_screen.dart';
import 'workout_ai_screen.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  DateTime _selectedDate = DateTime.now();

  void _changeDate(int days) {
    final newDate = _selectedDate.add(Duration(days: days));
    final today = DateTime.now();

    // Normalize to compare just the calendar days, ignoring the exact time
    final normalizedNew = DateTime(newDate.year, newDate.month, newDate.day);
    final normalizedToday = DateTime(today.year, today.month, today.day);

    // Stop them in their tracks if they try to swipe into the future
    if (normalizedNew.isAfter(normalizedToday)) return;

    setState(() => _selectedDate = newDate);
  }

  String _getFormattedDate() {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${weekdays[_selectedDate.weekday - 1]}, ${months[_selectedDate.month - 1]} ${_selectedDate.day}";
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final workoutsRef = userRef.collection('workouts');

    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,//Colors.grey[100],
      appBar: AppBar(
        title: const Text('Workout Tracker'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      // STREAM 1: Get User Profile (for Weight & Goal)
      body: StreamBuilder<DocumentSnapshot>(
        stream: userRef.snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
          
          final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
          final String goal = (userData['goal'] ?? '').toString().toLowerCase();
          
          // Smart Target Logic based on user's goal
          int targetBurn = 300; // Default for maintaining
          if (goal.contains('lose') || goal.contains('loss')) targetBurn = 400;
          if (goal.contains('muscle') || goal.contains('gain')) targetBurn = 350;
          
          // Override if you ever save a specific 'dailyBurnTarget' in Firebase
          if (userData.containsKey('dailyBurnTarget')) {
            targetBurn = userData['dailyBurnTarget'];
          }

          // STREAM 2: Get Today's Workouts
          return StreamBuilder<QuerySnapshot>(
            stream: workoutsRef
                .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
                .where('timestamp', isLessThan: endOfDay)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, workoutSnap) {
              if (workoutSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final workouts = workoutSnap.data?.docs ?? [];
              
              // Calculate total calories burned today
              int totalBurned = 0;
              for (var doc in workouts) {
                final data = doc.data() as Map<String, dynamic>;
                totalBurned += (data['calories'] as num?)?.toInt() ?? 0;
              }

              double percent = targetBurn > 0 ? (totalBurned / targetBurn).clamp(0.0, 1.0) : 0.0;

              return CustomScrollView(
                slivers: [
                  // --- DATE SELECTOR ---
                  SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => _changeDate(-1)),
                        Text(_getFormattedDate(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.arrow_forward_ios), onPressed: () => _changeDate(1)),
                      ],
                    ),
                  ),

                  // --- CALORIE BURN PROGRESS RING ---
                  SliverToBoxAdapter(
                    child: Card(
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: CircularPercentIndicator(
                          radius: 100.0,
                          lineWidth: 15.0,
                          animation: true,
                          animateFromLastPercent: true,
                          percent: percent,
                          center: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.local_fire_department, color: Colors.orange, size: 30),
                              Text('$totalBurned', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                              Text('/ $targetBurn kcal', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                            ],
                          ),
                          circularStrokeCap: CircularStrokeCap.round,
                          progressColor: Colors.orangeAccent,
                          backgroundColor: Colors.orange.shade50,
                          footer: Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Text(
                              totalBurned >= targetBurn ? 'Goal Reached! 🔥' : 'Keep moving!', 
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // --- AI WORKOUT BUTTON ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.purple, foregroundColor: Colors.white),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkoutAiScreen())),
                        icon: const Icon(Icons.smart_toy),
                        label: const Text('View Today\'s AI Workout Plan', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),

                  // --- WORKOUT LIST ---
                  workouts.isEmpty 
                    ? const SliverFillRemaining(child: Center(child: Text("No workouts logged for this day.")))
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final doc = workouts[index];
                            final data = doc.data() as Map<String, dynamic>;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: Dismissible(
                                key: Key(doc.id),
                                background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                                direction: DismissDirection.endToStart,
                                onDismissed: (direction) => workoutsRef.doc(doc.id).delete(),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: data['type'] == 'Cardio' ? Colors.blue : Colors.orange,
                                    child: Icon(data['type'] == 'Cardio' ? Icons.directions_run : Icons.fitness_center, color: Colors.white),
                                  ),
                                  title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(data['type'] == 'Cardio' 
                                      ? '${data['duration']} mins | ${data['distance']} km' 
                                      : '${data['duration']} mins | Intensity: ${data['intensity']}'),
                                  trailing: Text('${data['calories']} kcal', style: const TextStyle(fontSize: 16, color: Colors.orange, fontWeight: FontWeight.bold)),
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LogWorkoutScreen(workoutId: doc.id, existingData: data))),
                                ),
                              ),
                            );
                          },
                          childCount: workouts.length,
                        ),
                      ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orangeAccent,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LogWorkoutScreen())),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
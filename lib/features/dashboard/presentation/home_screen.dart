import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'meal_logging_screen.dart';
import 'ai_recommendation_screen.dart';
import '../../splash/presentation/splash_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now();

  void _changeDate(int days) {
    final newDate = _selectedDate.add(Duration(days: days));
    final today = DateTime.now();

    final normalizedNew = DateTime(newDate.year, newDate.month, newDate.day);
    final normalizedToday = DateTime(today.year, today.month, today.day);

    if (normalizedNew.isAfter(normalizedToday)) return; 

    setState(() {
      _selectedDate = newDate;
    });
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

    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, //Colors.grey[100],
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SplashScreen()));
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: userRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final target = data['dailyCalorieTarget'] ?? 2000;

          return StreamBuilder<QuerySnapshot>(
            stream: userRef.collection('meals')
                .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
                .where('timestamp', isLessThan: endOfDay)
                .snapshots(),
            builder: (context, mealSnap) {
              if (!mealSnap.hasData) return const Center(child: CircularProgressIndicator());
              
              int totalEaten = 0, cBreak = 0, cMorn = 0, cLunch = 0, cEve = 0, cDin = 0;
              final meals = mealSnap.data!.docs;
              
              for (var doc in meals) {
                final m = doc.data() as Map<String, dynamic>;
                final cals = m['calories'] as int;
                totalEaten += cals;
                switch(m['type']) {
                  case 'Breakfast': cBreak += cals; break;
                  case 'Morning Snack': cMorn += cals; break;
                  case 'Lunch': cLunch += cals; break;
                  case 'Evening Snack': cEve += cals; break;
                  case 'Dinner': cDin += cals; break;
                }
              }

              return CustomScrollView(
                slivers: [
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
                          percent: (totalEaten / target).clamp(0.0, 1.0),
                          center: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${target - totalEaten}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                              const Text('kcal left', style: TextStyle(fontSize: 16, color: Colors.grey)),
                            ],
                          ),
                          circularStrokeCap: CircularStrokeCap.round,
                          progressColor: (target - totalEaten) > 0 ? Colors.greenAccent : Colors.redAccent,
                          backgroundColor: Colors.grey.shade200,
                          footer: Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Text('Eaten: $totalEaten  /  Target: $target', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildRing('Breakfast', cBreak, (target * 0.255).round()),
                        _buildRing('Morning Snack', cMorn, (target * 0.1125).round()),
                        _buildRing('Lunch', cLunch, (target * 0.255).round()),
                        _buildRing('Evening Snack', cEve, (target * 0.1125).round()),
                        _buildRing('Dinner', cDin, (target * 0.255).round()),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AiRecommendationScreen())),
                          child: const Text('AI Meal Ideas', style: TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(height: 24),
                        const Text('Logged Meals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                      ]),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final meal = meals[index];
                        final mealData = meal.data() as Map<String, dynamic>;
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Dismissible(
                            key: Key(meal.id),
                            background: Container(
                              color: Colors.red, 
                              alignment: Alignment.centerRight, 
                              padding: const EdgeInsets.only(right: 20), 
                              child: const Icon(Icons.delete, color: Colors.white)
                            ),
                            direction: DismissDirection.endToStart,
                            onDismissed: (direction) {
                              FirebaseFirestore.instance.collection('users').doc(uid).collection('meals').doc(meal.id).delete();
                            },
                            child: ListTile(
                              title: Text(mealData['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(mealData['type'] ?? 'Meal'),
                              trailing: Text('${mealData['calories']} kcal', style: const TextStyle(fontSize: 16, color: Colors.deepOrange)),
                              onTap: () {
                                Navigator.push(
                                  context, 
                                  MaterialPageRoute(
                                    builder: (context) => MealLoggingScreen(
                                      mealId: meal.id,
                                      existingData: mealData,
                                    )
                                  )
                                );
                              },
                            ),
                          ),
                        );
                      },
                      childCount: meals.length,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MealLoggingScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRing(String title, int eaten, int target) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$eaten / $target kcal'),
        trailing: CircularPercentIndicator(
          radius: 20.0,
          lineWidth: 4.0,
          percent: (eaten / target).clamp(0.0, 1.0),
          progressColor: eaten > target ? Colors.red : Colors.green,
          backgroundColor: Colors.grey.shade200,
        ),
      ),
    );
  }
}
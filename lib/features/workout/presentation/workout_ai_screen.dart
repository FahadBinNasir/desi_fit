import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class WorkoutAiScreen extends StatefulWidget {
  const WorkoutAiScreen({super.key});

  @override
  State<WorkoutAiScreen> createState() => _WorkoutAiScreenState();
}

class _WorkoutAiScreenState extends State<WorkoutAiScreen> {
  bool _isLoading = true;
  String _plan = "";
  
  static const _apiKey = ''; // <-- PUT YOUR API KEY HERE

  @override
  void initState() {
    super.initState();
    _fetchOrGeneratePlan();
  }

  Future<void> _fetchOrGeneratePlan() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final todayStr = DateTime.now().toString().split(' ')[0]; // Returns "YYYY-MM-DD"
      
      final planRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('ai_workout_plans').doc(todayStr);
      final existingPlan = await planRef.get();

      // IF PLAN EXISTS FOR TODAY, JUST LOAD IT (Saves API calls!)
      if (existingPlan.exists) {
        setState(() {
          _plan = existingPlan.data()!['planText'];
          _isLoading = false;
        });
        return;
      }

      // IF NO PLAN, FETCH USER PHYSIQUE AND CALL GEMINI
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      
      final double weight = (userData['weight'] ?? 70).toDouble();
      final double height = (userData['height'] ?? 170).toDouble();
      final String goal = userData['goal'] ?? 'Maintain weight';

      final prompt = '''
      My weight is $weight kg, height is $height cm, and my primary fitness goal is: $goal.
      I need a daily workout routine for today. Please provide a mix of cardio and weightlifting/bodyweight exercises.
      Include specific exercise names, recommended durations (minutes), and intensity levels (Light/Moderate/Heavy).
      Keep it very concise, use bullet points, and ensure it is realistic for a single day.
      ''';

      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"contents": [{"parts": [{"text": prompt}]}]})
      );
      
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final aiText = resData['candidates'][0]['content']['parts'][0]['text'];
        
        // SAVE PLAN TO FIREBASE SO IT REMAINS FOR THE REST OF THE DAY
        await planRef.set({
          'planText': aiText,
          'createdAt': DateTime.now(),
        });

        setState(() {
          _plan = aiText;
          _isLoading = false;
        });
      } else {
        setState(() { _plan = "API Error: ${response.statusCode}"; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _plan = "Error: $e"; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Today\'s Workout Routine ✨'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(_plan, style: const TextStyle(fontSize: 16, height: 1.6)),
              ),
            ),
          ),
    );
  }
}
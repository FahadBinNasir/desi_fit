import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AiRecommendationScreen extends StatefulWidget {
  const AiRecommendationScreen({super.key});

  @override
  State<AiRecommendationScreen> createState() => _AiRecommendationScreenState();
}

class _AiRecommendationScreenState extends State<AiRecommendationScreen> {
  bool _isLoading = true;
  String _recommendations = "";
  
  static const _apiKey = ''; // <-- PUT YOUR API KEY HERE

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final todayStr = DateTime.now().toString().split(' ')[0]; // Returns "YYYY-MM-DD"
      
      // 1. CHECK FIREBASE FIRST FOR TODAY'S PLAN
      final planRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('ai_meal_plans')
          .doc(todayStr);

      final existingPlan = await planRef.get();

      // IF PLAN EXISTS, LOAD IT INSTANTLY AND STOP
      if (existingPlan.exists) {
        setState(() {
          _recommendations = existingPlan.data()!['planText'];
          _isLoading = false;
        });
        return; 
      }

      // 2. IF NO PLAN EXISTS, FETCH USER TARGETS AND CALL GEMINI
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data()!;
      
      final int target = data['dailyCalorieTarget'] ?? 2000;
      final String goal = data['goal'] ?? 'Maintain weight';

      final int breakfast = (target * 0.25).round();
      final int morningSnack = (target * 0.125).round();
      final int lunch = (target * 0.25).round();
      final int eveningSnack = (target * 0.125).round();
      final int dinner = (target * 0.25).round();

      final prompt = '''
      My total daily calorie target is $target kcal. My fitness goal is: $goal.
      Create a 1-day healthy Pakistani meal plan strictly divided into these 5 portions:
      * Breakfast: $breakfast kcal
      * Morning Snack: $morningSnack kcal
      * Lunch: $lunch kcal
      * Evening Snack: $eveningSnack kcal
      * Dinner: $dinner kcal
      
      Keep it very concise, use bullet points, and name specific Pakistani dishes.
      ''';

      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{"parts": [{"text": prompt}]}]
        })
      );
      
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final aiText = resData['candidates'][0]['content']['parts'][0]['text'];
        
        // 3. SAVE THE NEW PLAN TO FIREBASE SO IT STAYS ALL DAY
        await planRef.set({
          'planText': aiText,
          'createdAt': DateTime.now(),
        });

        setState(() {
          _recommendations = aiText;
          _isLoading = false;
        });
      } else {
        setState(() {
          _recommendations = "API Error: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _recommendations = "Error: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('AI Meal Ideas ✨'),
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
                child: Text(
                  _recommendations,
                  style: const TextStyle(fontSize: 16, height: 1.6),
                ),
              ),
            ),
          ),
    );
  }
}
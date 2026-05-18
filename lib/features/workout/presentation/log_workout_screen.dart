import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LogWorkoutScreen extends StatefulWidget {
  final String? workoutId;
  final Map<String, dynamic>? existingData;

  const LogWorkoutScreen({super.key, this.workoutId, this.existingData});

  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  final _nameCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _speedCtrl = TextEditingController();

  String _type = 'Cardio';
  String _intensity = 'Moderate';
  bool _isLoading = false;
  double _userWeight = 70.0;

  final List<String> _cardioExercises = [
    'Running', 'Cycling', 'Walking', 'Swimming', 'Jump Rope', 'Elliptical'
  ];
  final List<String> _weightExercises = [
    'Chest Workout', 'Leg Workout', 'Back Workout', 'Bicep Workout',
    'Tricep Workout', 'Shoulder Workout', 'Abs Workout', 'Forearm Workout'
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserWeight();

    if (widget.existingData != null) {
      _type = widget.existingData!['type'];
      _nameCtrl.text = widget.existingData!['name'];
      _durationCtrl.text = widget.existingData!['duration'].toString();
      if (_type == 'Cardio') {
        _distanceCtrl.text =
            widget.existingData!['distance']?.toString() ?? '';
        _speedCtrl.text = widget.existingData!['speed']?.toString() ?? '';
      } else {
        _intensity = widget.existingData!['intensity'] ?? 'Moderate';
      }
    }
  }

  Future<void> _fetchUserWeight() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists && doc.data()!.containsKey('weight')) {
      setState(
          () => _userWeight = (doc.data()!['weight'] as num).toDouble());
    }
  }

  void _autoCalculateCardio() {
    double? dist = double.tryParse(_distanceCtrl.text);
    double? dur = double.tryParse(_durationCtrl.text);
    double? spd = double.tryParse(_speedCtrl.text);

    if (dist != null && dur != null && dur > 0 && _speedCtrl.text.isEmpty) {
      _speedCtrl.text = (dist / (dur / 60)).toStringAsFixed(2);
    } else if (dist != null &&
        spd != null &&
        spd > 0 &&
        _durationCtrl.text.isEmpty) {
      _durationCtrl.text = ((dist / spd) * 60).toStringAsFixed(0);
    } else if (dur != null &&
        spd != null &&
        spd > 0 &&
        _distanceCtrl.text.isEmpty) {
      _distanceCtrl.text = (spd * (dur / 60)).toStringAsFixed(2);
    }
    setState(() {});
  }

  Future<void> _saveWorkout() async {
    if (_nameCtrl.text.isEmpty || _durationCtrl.text.isEmpty) return;

    setState(() => _isLoading = true);
    double durationMins = double.parse(_durationCtrl.text);
    int caloriesBurned = 0;
    double met = 4.0;

    if (_type == 'Cardio') {
      _autoCalculateCardio();
      double speed = double.tryParse(_speedCtrl.text) ?? 0;
      String exName = _nameCtrl.text.toLowerCase();

      // FIX: wrapped all single-statement ifs in blocks
      if (exName == 'running') {
        met = speed > 0 ? speed * 1.05 : 9.8;
      } else if (exName == 'cycling') {
        met = speed > 0 ? speed * 0.4 : 8.0;
      } else if (exName == 'walking') {
        met = speed > 0 ? speed * 0.8 : 4.3;
      } else if (exName == 'swimming') {
        met = 8.0;
      } else if (exName == 'jump rope') {
        met = 11.8;
      } else if (exName == 'elliptical') {
        met = 5.0;
      } else {
        met = 7.0;
      }
    } else {
      if (_intensity == 'Light') {
        met = 3.0;
      }
      if (_intensity == 'Moderate') {
        met = 4.5;
      }
      if (_intensity == 'Heavy') {
        met = 6.0;
      }
    }

    caloriesBurned = (met * _userWeight * (durationMins / 60)).round();

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final data = {
      'type': _type,
      'name': _nameCtrl.text.trim(),
      'duration': durationMins.round(),
      'calories': caloriesBurned,
      'timestamp':
          widget.existingData?['timestamp'] ?? DateTime.now(),
    };

    if (_type == 'Cardio') {
      data['distance'] = double.tryParse(_distanceCtrl.text) ?? 0.0;
      data['speed'] = double.tryParse(_speedCtrl.text) ?? 0.0;
    } else {
      data['intensity'] = _intensity;
    }

    try {
      if (widget.workoutId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('workouts')
            .doc(widget.workoutId)
            .update(data);
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('workouts')
            .add(data);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> suggestions =
        _type == 'Cardio' ? _cardioExercises : _weightExercises;

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.workoutId != null
              ? 'Edit Workout'
              : 'Log Workout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Cardio', label: Text('Cardio')),
                ButtonSegment(
                    value: 'Weightlifting',
                    label: Text('Weightlifting')),
              ],
              selected: {_type},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _type = newSelection.first;
                  _nameCtrl.clear();
                });
              },
            ),
            const SizedBox(height: 24),

            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textVal) {
                if (textVal.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return suggestions.where((opt) =>
                    opt.toLowerCase().contains(textVal.text.toLowerCase()));
              },
              onSelected: (String selection) =>
                  _nameCtrl.text = selection,
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                if (_nameCtrl.text.isNotEmpty &&
                    controller.text.isEmpty) {
                  controller.text = _nameCtrl.text;
                }
                controller.addListener(
                    () => _nameCtrl.text = controller.text);
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                      labelText: 'Exercise Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search)),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
                controller: _durationCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Duration (mins)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.timer))),
            const SizedBox(height: 16),

            if (_type == 'Cardio') ...[
              const SizedBox(height: 8),
              TextField(
                  controller: _distanceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Distance (km)',
                      border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(
                  controller: _speedCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Speed (km/h)',
                      border: OutlineInputBorder())),
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: _autoCalculateCardio,
                  child: const Text("Auto-Fill Missing Value")),
            ] else ...[
              DropdownButtonFormField<String>(
                initialValue: _intensity,
                items: ['Light', 'Moderate', 'Heavy']
                    .map((e) =>
                        DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _intensity = val!),
                decoration: const InputDecoration(
                    labelText: 'Intensity',
                    border: OutlineInputBorder()),
              ),
            ],

            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16)),
              onPressed: _isLoading ? null : _saveWorkout,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Calculate Calories & Save',
                      style: TextStyle(fontSize: 18)),
            )
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class MealLoggingScreen extends StatefulWidget {
  final String? mealId;
  final Map<String, dynamic>? existingData;

  const MealLoggingScreen({super.key, this.mealId, this.existingData});

  @override
  State<MealLoggingScreen> createState() => _MealLoggingScreenState();
}

class _MealLoggingScreenState extends State<MealLoggingScreen> {
  final _foodController = TextEditingController();
  final _portionController = TextEditingController(text: '100');
  final _caloriesController = TextEditingController();

  bool _isLoading = false;
  bool _isSearching = false;

  String _selectedMeal = 'Breakfast';
  final List<String> _meals = [
    'Breakfast', 'Morning Snack', 'Lunch', 'Evening Snack', 'Dinner'
  ];

  final Map<String, double> _db = {
    'aloo biryani': 160, 'naan': 297,
    'beef biryani': 170, 'boiled white rice': 110, 'boiled egg': 155,
    'beef keema': 188, 'milk': 67, 'plain bread': 280, 'aloo samosa': 280,
    'chana dal gravy': 120, 'chapati': 260, 'chicken karahi': 160, 'chai': 40,
    'chicken biryani': 165, 'mutton biryani': 190, 'chicken yakhni pulao': 149, 'chicken korma': 200,
    'beef korma': 222, 'aloo palak': 87, 'beef yakhni pulao': 155, 'chicken tikka': 156,
    'lacha paratha': 300, 'aloo matar beef keema': 152, 'mutton karahi': 225,
    'chana tarkari': 156, 'lahori murg cholay': 145, 'chicken achar gosht': 170, 'aloo gosht': 170,
    'moong dal khichri': 128, 'beef nihari': 250, 'beef haleem': 180, 'chicken haleem': 160,
    'mix chana chaat': 130, 'anda shami burger': 260, 'beef shami kabab': 260, 'chicken shami kabab': 194,
    'dahi': 60, 'mix fruit chaat': 86, 'fruit custard': 135, 'khoya gajar halwa': 198, 'gulab jamun': 348,
    'beef kofta': 220, 'poori': 350, 'aloo tarkari': 102, 'bbq beef boti': 247, 'besan roti with ghee': 290,
    'mutton yakhni pulao': 165, 'chicken seekh kabab': 171, 'suji halwa': 194, 'kathiawari cholay': 85,
    'kheer': 203, 'beef kaleji': 190, 'lahori paaya': 200, 'aloo tahari': 130, 'palak paneer': 126,
    'Ande Cholay': 140, 'aloo keema': 175, 'Ande Aloo': 135, 'Lauki Gosht': 120, 'aloo paratha': 261,
    'khoa barfi': 431, 'mix salad': 36, 'fried naan': 380, 'taftaan': 297, 'sheermal': 310,
    'afghani dumba pulao': 180, 'kashmiri chai': 45, 'Gola Ganda': 100, 'meethay gol gappay': 151,
    'meetha paan': 230, 'anda ghotala': 140, 'vegetable spring roll': 260, 'french fries': 340,
    'egg omelette': 230, 'pepsi': 40, 'chicken vegetable spaghetti': 148, 'chicken vegetable macroni': 145,
    'date': 317, 'green chutney': 35, 'red mirch chutney': 257, 'fried fish': 220, 'grill fish': 118,
    'digestive biscuit': 467, 'innovative digestive': 507, 'marie biscuit': 441, 'bravo biscuit': 491,
    'sooper biscuit': 529, 'tuc biscuit': 515, 'chocolatto biscuit': 517, 'novita wafers': 483, 'choco bites': 523, 'candi biscuit': 483,
    'jam hearts': 440, 'rio biscuit': 514, 'prince biscuit': 525, 'original sandwich biscuit': 500, 'zeera plus': 488,
    'day dream biscuit': 500, 'cadbury cookies': 504, 'cadbury biscuits': 512, 'butterpuff': 492, 'gluco biscuit': 980, 'click biscuit': 494,
    'mayfair a1': 522, 'mayfair cafe': 500, 'peanut pik': 500, 'party pik': 502, 'choc day': 500, 'oreo': 463,
    'lu nankhatai': 547, 'tiger biscuit': 450, 'saltish biscuit': 521, 'gala biscuit': 476, 'chocolate chip biscuit': 511, 'cocomo': 508,
    'snickers': 480, 'kitkat': 508, 'paradise chocolate': 463, 'sonnet chocolate': 453, 'dairy milk': 538, 'you chocolate': 533,
    'sooper cake': 437, 'lotte choco pie': 435, 'baketime cake slices': 363, 'dawn fruit bun': 340,
    'cornetto double choc': 156, 'chocbar': 206, 'feast ice cream': 311, 'nestle yoghurt sugarfree': 56,
    'kurkure': 568, 'tringo chips': 477, 'wavy': 544, 'lays yoghurt': 553, 'cheetos cheese': 517, 'cheetos red': 561,
    'catty chins': 500, 'slice juice': 54, 'nestle mango juice': 44, 'nestle apple juice': 47, 'olpers choco milk': 76,
  };

  // TODO: Replace with your actual USDA API key
  
  static const String _usdaApiKey = 'DEMO_KEY';
  static const String _usdaBaseUrl = 'https://api.nal.usda.gov/fdc/v1/foods/search';

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _foodController.text = widget.existingData!['name'];
      // FIX: Use initialValue pattern — set text directly on controller
      _caloriesController.text = widget.existingData!['calories'].toString();
      _selectedMeal = widget.existingData!['type'] ?? 'Breakfast';
    }
  }

  Future<void> _fetchCaloriesAPI() async {
    // FIX: removed unnecessary string interpolation
    final query = _foodController.text.trim().toLowerCase().replaceAll('\n', ' ');
    final portionGrams = double.tryParse(_portionController.text.trim()) ?? 100.0;

    if (query.isEmpty) return;

    if (_db.containsKey(query)) {
      _caloriesController.text = ((_db[query]! / 100) * portionGrams).round().toString();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Found locally!'), backgroundColor: Colors.green));
      return;
    }

    setState(() => _isSearching = true);

    try {
      // FIX: corrected broken URL construction
      final url = Uri.parse('$_usdaBaseUrl?query=${Uri.encodeComponent(query)}&api_key=$_usdaApiKey');

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List? foods = data['foods'];

        if (foods != null && foods.isNotEmpty) {
          if (mounted) setState(() => _isSearching = false);

          if (mounted) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Select Food'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: foods.length > 20 ? 20 : foods.length,
                      itemBuilder: (context, index) {
                        final food = foods[index];
                        return ListTile(
                          title: Text(food['description'] ?? 'Unknown'),
                          onTap: () {
                            final nutrients = food['foodNutrients'] as List?;
                            double apiCals = 0.0;

                            if (nutrients != null) {
                              for (var nutrient in nutrients) {
                                if (nutrient['unitName'] == 'KCAL' &&
                                    nutrient['nutrientName']
                                        .toString()
                                        .toLowerCase()
                                        .contains('energy')) {
                                  apiCals = double.tryParse(
                                          nutrient['value'].toString()) ??
                                      0.0;
                                  break;
                                }
                              }
                            }

                            setState(() {
                              _caloriesController.text =
                                  ((apiCals / 100) * portionGrams)
                                      .round()
                                      .toString();
                            });

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content:
                                    Text('Selected: ${food['description']}'),
                                backgroundColor: Colors.green));
                          },
                        );
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'))
                  ],
                );
              },
            );
          }
          return;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Food not found'), backgroundColor: Colors.orange));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('API Error: ${response.statusCode}'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Crash: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _saveMeal() async {
    final foodName = _foodController.text.trim();
    final cals = int.tryParse(_caloriesController.text.trim());

    if (foodName.isEmpty || cals == null || cals <= 0) return;
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final data = {
        'name': foodName,
        'calories': cals,
        'type': _selectedMeal,
        'timestamp': widget.existingData?['timestamp'] ?? DateTime.now(),
      };

      if (widget.mealId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('meals')
            .doc(widget.mealId)
            .update(data);
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('meals')
            .add(data);
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.mealId != null ? 'Edit Meal' : 'Log Meal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedMeal,
              items: _meals
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedMeal = v!),
              decoration: const InputDecoration(
                  labelText: 'Meal Type', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return _db.keys.where((String option) =>
                    option.contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (String selection) {
                _foodController.text = selection;
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                if (_foodController.text.isNotEmpty &&
                    controller.text.isEmpty) {
                  controller.text = _foodController.text;
                }
                controller.addListener(
                    () => _foodController.text = controller.text);
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                      labelText: 'Food', border: OutlineInputBorder()),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: _portionController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Grams',
                            border: OutlineInputBorder()))),
                IconButton(
                    onPressed: _isSearching ? null : _fetchCaloriesAPI,
                    icon: _isSearching
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator())
                        : const Icon(Icons.search,
                            size: 32, color: Colors.blue))
              ],
            ),
            const SizedBox(height: 16),
            TextField(
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Calories', border: OutlineInputBorder())),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              onPressed: _isLoading ? null : _saveMeal,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Save'),
            )
          ],
        ),
      ),
    );
  }
}

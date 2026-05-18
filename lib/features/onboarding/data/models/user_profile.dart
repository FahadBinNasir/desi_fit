class UserProfile {
  final String uid;
  final String name;
  final int age;
  final double weight;
  final double height;
  final bool isMale;
  final String goal; 
  final double activityLevel; 
  final int dailyCalorieTarget;

  UserProfile({
    required this.uid,
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
    required this.isMale,
    required this.goal,
    required this.activityLevel,
    required this.dailyCalorieTarget,
  });

  // Converts our object into a map to easily save to Firebase
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'age': age,
      'weight': weight,
      'height': height,
      'isMale': isMale,
      'goal': goal,
      'activityLevel': activityLevel,
      'dailyCalorieTarget': dailyCalorieTarget,
    };
  }
}
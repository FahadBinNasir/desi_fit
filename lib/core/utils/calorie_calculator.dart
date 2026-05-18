class CalorieCalculator {
  // Calculates basic resting calories (Mifflin-St Jeor Equation)
  static double calculateBMR({
    required double weight, 
    required double height, 
    required int age, 
    required bool isMale
  }) {
    if (isMale) {
      return (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      return (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }
  }

  // Multiplies BMR by activity level to get daily calorie limit
  static double calculateTDEE(double bmr, double activityMultiplier) {
    return bmr * activityMultiplier;
  }
}
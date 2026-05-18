<div align="center">

<img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white"/>
<img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black"/>
<img src="https://img.shields.io/badge/Gemini_2.5_Flash-4285F4?style=for-the-badge&logo=google&logoColor=white"/>
<img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white"/>

# 🍛 DesiFit
### *Your AI-Powered Desi Health Companion*

> A cloud-based fitness and nutrition app built for the Pakistani lifestyle — track desi meals, get AI meal & workout plans, and stay hydrated. All powered by Google Firebase and Gemini 2.5 Flash.

</div>

---

## 📖 About

Most fitness apps don't know what **Biryani** is. DesiFit does.

DesiFit is a Flutter Android app designed specifically for Pakistani users. It combines a hand-curated database of **100+ desi foods**, an **AI meal and workout planner** (Gemini 2.5 Flash), and **real-time cloud sync** via Firebase — all on a free-tier backend.

Built as a Cloud Computing semester project at **Bahria University Karachi Campus**, Department of Software Engineering — Spring 2026.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🍽️ **Desi Food Logging** | Search 100+ Pakistani foods by name with auto-populated calories |
| 🤖 **AI Meal Planning** | Gemini-generated daily meal plan split across 5 desi meals |
| 🏋️ **AI Workout Planning** | Personalized workout routines based on your biometrics and goal |
| 🔥 **Calorie Burn Tracker** | MET-based calculation for cardio and weightlifting sessions |
| 💧 **Water Intake Tracker** | Weight-based daily glass target with real-time progress ring |
| 📊 **Real-Time Dashboard** | Live calorie ring and per-meal progress via Firestore streams |
| 📈 **Weekly Analytics** | Bar chart aggregating 7 days of meals, workouts, and water |
| 🔐 **2FA Authentication** | Optional 6-digit OTP sent to your email via EmailJS |
| 🌙 **Dark Mode** | Theme preference persisted to Firebase and restored on launch |
| 👤 **Smart Onboarding** | BMR/TDEE calculated using Mifflin-St Jeor equation |

---

## 🏗️ Architecture

```
Flutter App (Android)
       │
       ├── Firebase Authentication  ← login, 2FA session gating
       ├── Cloud Firestore          ← all user data, AI plan cache, streams
       ├── Firebase Storage         ← media assets
       │
       ├── Gemini 2.5 Flash API     ← AI meal & workout plans
       ├── USDA FoodData Central    ← fallback for unknown foods
       └── EmailJS API              ← 2FA OTP delivery
```

**No custom backend server.** All logic runs in the Flutter client and communicates directly with managed cloud services.

---

## 🗂️ Project Structure

```
lib/
├── app/                    # App root, routing, theme
├── core/                   # CalorieCalculator, AppTheme, AppColors, AppStrings
└── features/
    ├── auth/               # Login, Sign Up, 2FA PIN dialog
    ├── onboarding/         # BMR/TDEE setup flow
    ├── dashboard/
    │   └── presentation/
    │       ├── home_screen.dart             # Real-time calorie ring
    │       ├── meal_logging_screen.dart     # Desi food search & log
    │       └── ai_recommendation_screen.dart # Gemini meal plans
    ├── workout/            # Workout tracker, AI plans, MET calculator
    ├── water/              # Water intake logger
    ├── profile/            # Weekly analytics, settings
    ├── settings/           # Dark mode, 2FA toggle, delete account
    └── splash/             # Auth state routing
```

---

## ☁️ Cloud & Data Model

All user data lives under `users/{uid}` in Firestore:

```
users/{uid}
├── dailyCalorieTarget, goal, weight, height, isDarkMode, is2FAEnabled ...
├── meals/{id}              → name, calories, type, timestamp
├── workouts/{id}           → type, name, duration, calories, timestamp
├── water_logs/{YYYY-MM-DD} → glasses, timestamp
├── ai_meal_plans/{YYYY-MM-DD}    → planText, createdAt
└── ai_workout_plans/{YYYY-MM-DD} → planText, createdAt
```

AI plans are **cached per day** — Gemini is only called once per date, then served from Firestore instantly.

---

## 🧮 Core Formulas

**BMR (Mifflin-St Jeor)**
```
Male:   BMR = (10 × weight) + (6.25 × height) − (5 × age) + 5
Female: BMR = (10 × weight) + (6.25 × height) − (5 × age) − 161
```

**TDEE & Calorie Target**
```
TDEE   = BMR × activityMultiplier
Target = TDEE ± 400 kcal  (based on goal: loss / gain / maintain)
```

**Calorie Burn (MET-based)**
```
Calories = MET × weight(kg) × duration(hours)
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter 3.x
- Android Studio or VS Code with Flutter extension
- A Firebase project with Firestore, Auth, and Storage enabled

### Setup

```bash
# Clone the repo
git clone https://github.com/FahadBinNasir/desi_fit.git
cd desi_fit

# Install dependencies
flutter pub get

# Run on a connected Android device
flutter run
```

> **Note:** You'll need your own `firebase_options.dart` and `google-services.json` with your Firebase project credentials. Replace the Gemini API key in `ai_recommendation_screen.dart` with your own from [Google AI Studio](https://aistudio.google.com).

---

## 🧪 Testing Summary

| Type | Tests | Passed |
|---|---|---|
| Functional | 15 | 15 ✅ |
| Integration | 7 | 7 ✅ |
| Security | 6 | 6 ✅ |
| Deployment | 5 | 5 ✅ |
| UAT Tasks | 7 | 7 ✅ |

---

## 👨‍💻 Team

| Name | Role |
|---|---|
| **Usman Hameed** | Team Lead — Data Storage, Food DB, Workout & Water Modules |
| **Mustafa Zaman Khan** | Cloud Backend, Gemini AI Integration, Firestore Caching |
| **Fahad Bin Nasir** | UI/UX Design, Dashboard, Meal Logging, Splash Screen |
| **Qudama Ahmed Khan** | Auth, 2FA, Onboarding, Analytics, Dark Mode |

**Course:** CSL 220 Cloud Computing — BSE 6A, Spring 2026  
**Bahria University Karachi Campus, Department of Software Engineering**

---

## 🔮 Future Work

- [ ] Firebase Cloud Functions backend proxy (secure API keys)
- [ ] Server-side 2FA OTP validation
- [ ] Firebase Cloud Messaging for water reminders
- [ ] iOS build target
- [ ] Barcode scanner for packaged foods
- [ ] Protein / carbs / fats breakdown per meal
- [ ] Streak tracking and gamification
- [ ] Formal Firestore security audit

---

## 📚 References

- [Firebase Documentation](https://firebase.google.com/docs)
- [Gemini API Docs](https://ai.google.dev/docs)
- [Flutter Architectural Overview](https://flutter.dev/docs/resources/architectural-overview)
- [USDA FoodData Central API](https://fdc.nal.usda.gov/api-guide.html)
- Mifflin MD et al. — *A new predictive equation for resting energy expenditure*, AJCN, 1990

---

<div align="center">

Made with 🍛 in Karachi

</div>

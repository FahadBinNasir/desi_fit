//import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Make sure this imports your main.dart file
import 'package:desi_fit/main.dart'; 
import 'package:desi_fit/core/constants/app_strings.dart';

void main() {
  testWidgets('App starts successfully', (WidgetTester tester) async {
    // Build our app wrapped in Riverpod ProviderScope
    await tester.pumpWidget(const ProviderScope(child: DesiFitApp()));

    // Verify that our temporary home screen loads by looking for the welcome text
    expect(find.text(AppStrings.welcome), findsOneWidget);
  });
}
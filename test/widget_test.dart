import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bill_manager_app/screens/splash_screen.dart';

void main() {
  testWidgets('SplashScreen shows app name and loading indicator', (
    WidgetTester tester,
  ) async {
    // 1. Test without loading indicator
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen(isLoading: false)),
    );

    // Verify app name and tagline are present
    expect(find.text('BillMinder'), findsOneWidget);
    expect(find.text('Never miss a payment'), findsOneWidget);

    // Verify loading indicator is NOT visible (opacity 0)
    final animatedOpacity = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(animatedOpacity.opacity, 0.0);

    // 2. Test with loading indicator
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen(isLoading: true)),
    );

    // Verify loading indicator IS visible (opacity 1)
    final animatedOpacityVisible = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(animatedOpacityVisible.opacity, 1.0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

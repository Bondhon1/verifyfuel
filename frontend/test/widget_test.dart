import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:verifyfuel/main.dart';

void main() {
  testWidgets('VerifyFuel splash renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashView()));
    expect(find.text('VerifyFuel'), findsOneWidget);
  });
}

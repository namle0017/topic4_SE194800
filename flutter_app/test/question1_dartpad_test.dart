import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../question1_dartpad.dart' as question1;

void main() {
  testWidgets('protected home does not render the raw authentication token', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: question1.HomePage(
          email: 'demo@test.com',
          token: 'secret-token-value',
        ),
      ),
    );

    expect(find.text('demo@test.com'), findsOneWidget);
    expect(find.textContaining('secret-token-value'), findsNothing);
  });

  testWidgets('protected home renders a readable authenticated status', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: question1.HomePage(
          email: 'demo@test.com',
          token: 'secret-token-value',
        ),
      ),
    );

    expect(find.text('✅ Đã đăng nhập'), findsOneWidget);
  });
}

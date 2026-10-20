import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controldeck/railways_native_screen.dart';

void main() {
  testWidgets('native Railway empty state explains missing workspace access', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: EmptyRailway(
          title: 'No workspaces assigned',
          detail: 'Ask your administrator to grant access.',
        ),
      ),
    ));

    expect(find.text('No workspaces assigned'), findsOneWidget);
    expect(find.text('Ask your administrator to grant access.'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:controldeck/main.dart';
import 'package:controldeck/supabase_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the ControlDeck sign-in screen when signed out', (tester) async {
    await Supabase.initialize(url: SupabaseConfig.primaryUrl, anonKey: SupabaseConfig.primaryKey);
    await tester.pumpWidget(const ControlDeckApp());
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Sign in to sync your app hub across devices.'), findsOneWidget);
  });
}

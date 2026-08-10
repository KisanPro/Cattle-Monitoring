import 'package:flutter_test/flutter_test.dart';
import 'package:kisan_pro_milk_monitoring/main.dart';

void main() {
  testWidgets('Milk Monitoring App compilation and smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our main KisanPro heading is found on the app bar.
    expect(find.text('Kisan Pro'), findsOneWidget);
    expect(find.text('Milk Monitoring System'), findsOneWidget);
  });
}

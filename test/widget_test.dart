import 'package:flutter_test/flutter_test.dart';
import 'package:dinor/main.dart';

void main() {
  testWidgets('Dinor app renders without crashing', (WidgetTester tester) async {
    // Just verify the app starts
    await tester.pumpWidget(const DinorApp());
    expect(find.byType(DinorApp), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:nextone/main.dart';

void main() {
  testWidgets('renders app root', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MyApp), findsOneWidget);
  });
}

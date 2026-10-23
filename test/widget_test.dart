import 'package:flutter_test/flutter_test.dart';
import 'package:nodelink/main.dart';

void main() {
  testWidgets('NodeLink smoke test', (WidgetTester tester) async {
    // Build NodeLink app and trigger a frame.
    await tester.pumpWidget(const NodeLinkApp());
    expect(find.text('NodeLink'), findsWidgets);
  });
}

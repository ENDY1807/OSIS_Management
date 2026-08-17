import 'package:flutter_test/flutter_test.dart';
import 'package:osis_jurnal/main.dart';

void main() {
  testWidgets('OsisApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OsisApp());
    expect(find.byType(OsisApp), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kosfinder_device_demo/main.dart';

void main() {
  testWidgets('KosFinder app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const KosFinderDeviceApp());

    expect(find.text('KosFinder Device Demo'), findsOneWidget);
  });
}

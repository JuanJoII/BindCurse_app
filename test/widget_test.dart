import 'package:flutter_test/flutter_test.dart';
import 'package:bind_curse_app/main.dart';

void main() {
  testWidgets('BindCurseApp renders main tabs and Stitch UI elements', (WidgetTester tester) async {
    await tester.pumpWidget(const BindCurseApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('BindCurse'), findsOneWidget);
    expect(find.text('CURSED LINK // UDP'), findsOneWidget);
    expect(find.text('Vínculo de Red'), findsOneWidget);
    expect(find.text('Calibración de Audio'), findsOneWidget);
    expect(find.text('Vincular Audio (Bind)'), findsOneWidget);

    // Switch to Dispositivos tab
    await tester.tap(find.text('Dispositivos'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Dispositivos Sellados'), findsOneWidget);
    // Verified that mock devices are removed and real state is rendered
    expect(find.text('Aún no hay altares sellados'), findsOneWidget);
  });
}

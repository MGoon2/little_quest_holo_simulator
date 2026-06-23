// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in the test, use the WidgetTester
// utility in the flutter_test package.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('App renders empty state', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const HoloCardApp());
    await tester.pumpAndSettle();

    // 카드가 없을 때 빈 상태 메시지가 표시되어야 한다.
    expect(find.text('아직 카드가 없습니다'), findsOneWidget);
    expect(find.text('카드 만들기'), findsOneWidget);
  });
}

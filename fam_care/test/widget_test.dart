// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fam_care/main.dart';
import 'package:fam_care/models/booking_model.dart';
import 'package:fam_care/providers/patients_provider.dart';

void main() {
  testWidgets('Shows patient selection screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientsProvider.overrideWith((ref) async => [
                PatientModel(
                  id: '1',
                  name: 'Test Patient',
                  email: 'test@example.com',
                  phone: '1234567890',
                ),
              ]),
        ],
        child: const FamCareApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Select Patient'), findsOneWidget);
    expect(find.text('Test Patient'), findsOneWidget);
  });
}

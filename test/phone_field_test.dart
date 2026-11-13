import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_queue/widgets/malaysian_phone_field.dart';

void main() {
  testWidgets(
    'fixed prefix remains outside the editable number and pasted phone is normalized',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MalaysianPhoneField(controller: controller)),
        ),
      );
      expect(find.text('+60'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '+6012-7347838');
      await tester.pump();
      expect(controller.text, '127347838');
      expect(find.text('+60'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'letters, foreign country codes and overlong pastes do not become valid numbers',
    (tester) async {
      final controller = TextEditingController(text: '127347838');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MalaysianPhoneField(controller: controller)),
        ),
      );
      for (final input in [
        'abc127347838',
        '+6512345678',
        '+600127347838',
        '127347838999',
      ]) {
        await tester.enterText(find.byType(TextFormField), input);
        await tester.pump();
        expect(controller.text, '127347838');
      }
    },
  );
  testWidgets('required and too-short inputs prevent form submission', (
    tester,
  ) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: MalaysianPhoneField(controller: controller),
          ),
        ),
      ),
    );
    expect(formKey.currentState!.validate(), false);
    await tester.pump();
    expect(find.text('Phone number is required.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '123');
    expect(formKey.currentState!.validate(), false);
    await tester.enterText(find.byType(TextFormField), '127347838');
    expect(formKey.currentState!.validate(), true);
  });
}

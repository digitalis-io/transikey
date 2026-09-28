import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I enter the namespace {'team-b'}
///
/// Replaces the chosen namespaces with this one. An empty name only
/// clears them.
Future<void> iEnterTheNamespace(WidgetTester tester, String namespace) async {
  // Each chosen namespace is a chip whose delete button says "Remove …".
  final remove = find.byWidgetPredicate(
    (w) => w is Tooltip && (w.message?.startsWith('Remove ') ?? false),
  );
  while (tester.any(remove)) {
    await tester.tap(remove.first);
    await tester.pumpAndSettle();
  }
  await addNamespace(tester, namespace);
}

/// Types [namespace] in the field and confirms it with Enter.
Future<void> addNamespace(WidgetTester tester, String namespace) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Namespaces'),
    namespace,
  );
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

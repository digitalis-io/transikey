import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'sharing_world.dart';

/// Usage: wrapping is disabled with a sign in hint
Future<void> wrappingIsDisabledWithASignInHint(WidgetTester tester) async {
  await tester.tap(find.text('Wrap'));
  await tester.pumpAndSettle();
  expect(find.textContaining('Sign in to wrap a secret'), findsOneWidget);
  await tester.tap(find.text('Wrap secret'));
  await tester.pumpAndSettle();
  verifyNever(() => SharingWorld.server.wrapSecret(any(), any()));
  expect(find.byType(CircularProgressIndicator), findsNothing);
}

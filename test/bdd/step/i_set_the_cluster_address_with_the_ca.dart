import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I set the cluster address {'https://k8s.test:6443'} with the CA {'/etc/k8s/ca.crt'}
Future<void> iSetTheClusterAddressWithTheCa(
  WidgetTester tester,
  String server,
  String caPath,
) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'API server URL'),
    server,
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'CA certificate path (optional)'),
    caPath,
  );
  // Settings are saved after a pause in typing.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

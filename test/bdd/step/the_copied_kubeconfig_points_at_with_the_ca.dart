import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'kubernetes_world.dart';

/// Usage: the copied kubeconfig points at {'https://k8s.test:6443'} with the CA {'/etc/k8s/ca.crt'}
Future<void> theCopiedKubeconfigPointsAtWithTheCa(
  WidgetTester tester,
  String server,
  String caPath,
) async {
  final kubeconfig = KubernetesWorld.clipboard.copies.last;
  expect(kubeconfig, contains('server: "$server"'));
  // The CA travels inside the kubeconfig, not as a path to it.
  final pem = KubernetesWorld.caFiles[caPath]!;
  expect(
    kubeconfig,
    contains(
      'certificate-authority-data: "${base64.encode(utf8.encode('$pem\n'))}"',
    ),
  );
}

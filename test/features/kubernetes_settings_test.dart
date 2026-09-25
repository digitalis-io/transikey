import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/features/settings/domain/app_settings.dart';
import 'package:transikey/features/settings/domain/server_profile.dart';

void main() {
  const target = SavedKubeTarget(
    server: 'https://k8s.prod:6443',
    caPath: '/etc/k8s/prod-ca.crt',
  );

  test('the cluster address belongs to the server profile', () {
    const settings = AppSettings(
      kubernetesMount: 'k8s',
      kubernetesTargets: {'k8s': target},
    );
    final profile = settings.toProfile(id: 'prod', name: 'Prod');
    expect(profile.kubernetesMount, 'k8s');
    expect(profile.kubernetesTargets, {'k8s': target});

    final other = const AppSettings().withProfile(profile);
    expect(other.kubernetesTargets['k8s'], target);
  });

  test('switching to another profile drops the previous cluster', () {
    const settings = AppSettings(kubernetesTargets: {'kubernetes': target});
    final switched = settings.withProfile(
      const ServerProfile(id: 'dev', name: 'Dev'),
    );
    expect(switched.kubernetesTargets, isEmpty);
    expect(switched.kubernetesMount, 'kubernetes');
  });

  test('the cluster address survives the keystore round trip', () {
    const settings = AppSettings(kubernetesTargets: {'kubernetes': target});
    // Stored as a JSON string, like SecureSettingsRepository does.
    final restored = AppSettings.fromJson(
      jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>,
    );
    expect(restored.kubernetesTargets['kubernetes'], target);
  });

  test('settings saved before Kubernetes support still load', () {
    final json = const AppSettings().toJson()
      ..remove('kubernetesMount')
      ..remove('kubernetesTargets');
    final restored = AppSettings.fromJson(json);
    expect(restored.kubernetesMount, 'kubernetes');
    expect(restored.kubernetesTargets, isEmpty);
  });

  group('fallback mounts', () {
    test('are read from a comma separated list', () {
      const settings = AppSettings(kubernetesMount: ' /k8s/, prod ,,k8s');
      expect(settings.kubernetesMountList, ['k8s', 'prod']);
    });

    test('default to kubernetes when the setting is blank', () {
      const settings = AppSettings(kubernetesMount: ' , ');
      expect(settings.kubernetesMountList, ['kubernetes']);
    });
  });
}

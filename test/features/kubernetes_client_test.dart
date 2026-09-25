import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/core/api/dio_vault_api_client.dart';
import 'package:transikey/core/api/vault_connection_config.dart';
import 'package:transikey/core/errors/vault_exception.dart';
import 'package:transikey/core/models/kubernetes_credentials.dart';
import 'package:transikey/core/models/lease_info.dart';

/// Answers every request with [answer] and remembers what was sent.
class _FakeServer extends Interceptor {
  _FakeServer(this.answer);

  final Map<String, dynamic> answer;
  final sent = <RequestOptions>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    sent.add(options);
    handler.resolve(
      Response(requestOptions: options, statusCode: 200, data: answer),
    );
  }
}

const _issued = {
  'lease_id': 'kubernetes/creds/developer/abc',
  'lease_duration': 600,
  'renewable': false,
  'data': {
    'service_account_name': 'v-demo-developer-123',
    'service_account_namespace': 'team-a',
    'service_account_token': 'eyJhbGciOi.secret-token',
  },
};

void main() {
  late _FakeServer server;
  late DioVaultApiClient client;

  void answer(Map<String, dynamic> body) {
    server = _FakeServer(body);
    client = DioVaultApiClient(
      dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'))
        ..interceptors.add(server),
      config: const VaultConnectionConfig(address: 'http://127.0.0.1:1'),
    );
  }

  group('token request', () {
    setUp(() => answer(_issued));

    test('posts the namespace only when nothing else is asked for', () async {
      await client.getKubernetesCredentials(
        'kubernetes',
        'developer',
        namespace: ' team-a ',
      );
      final sent = server.sent.single;
      expect(sent.method, 'POST');
      expect(sent.path, '/v1/kubernetes/creds/developer');
      expect(sent.data, {'kubernetes_namespace': 'team-a'});
    });

    test('sends the TTL and the cluster-wide binding when asked', () async {
      await client.getKubernetesCredentials(
        'k8s/prod',
        'viewer',
        namespace: 'team-a',
        ttl: '30m',
        clusterRoleBinding: true,
      );
      final sent = server.sent.single;
      expect(sent.path, '/v1/k8s/prod/creds/viewer');
      expect(sent.data, {
        'kubernetes_namespace': 'team-a',
        'ttl': '30m',
        'cluster_role_binding': true,
      });
    });

    test('an empty TTL is left to the role default', () async {
      await client.getKubernetesCredentials(
        'kubernetes',
        'developer',
        namespace: 'team-a',
        ttl: '  ',
      );
      expect((server.sent.single.data as Map).containsKey('ttl'), isFalse);
    });

    test('maps the answer and its lease', () async {
      final creds = await client.getKubernetesCredentials(
        'kubernetes',
        'developer',
        namespace: 'team-a',
      );
      expect(creds.key, 'kubernetes/developer');
      expect(creds.serviceAccountName, 'v-demo-developer-123');
      expect(creds.serviceAccountNamespace, 'team-a');
      expect(creds.serviceAccountToken, 'eyJhbGciOi.secret-token');
      expect(creds.lease.leaseId, 'kubernetes/creds/developer/abc');
      expect(creds.lease.leaseDuration, const Duration(minutes: 10));
    });

    test('a blank namespace never becomes a request', () async {
      await expectLater(
        client.getKubernetesCredentials(
          'kubernetes',
          'developer',
          namespace: ' ',
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(server.sent, isEmpty);
    });

    for (final (mount, role) in [
      ('..', 'developer'),
      ('kubernetes/../sys', 'developer'),
      ('kubernetes', '../../sys/raw'),
    ]) {
      test('"$mount" / "$role" never becomes a request', () async {
        await expectLater(
          client.getKubernetesCredentials(mount, role, namespace: 'a'),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          client.describeKubernetesRole(mount, role),
          throwsA(isA<ValidationException>()),
        );
        expect(server.sent, isEmpty);
      });
    }
  });

  group('role description', () {
    test('reads the allowed namespaces and the role type', () async {
      answer({
        'data': {
          'allowed_kubernetes_namespaces': ['*', 'team-a'],
          'kubernetes_role_type': 'ClusterRole',
        },
      });
      final info = await client.describeKubernetesRole('kubernetes', 'viewer');
      expect(server.sent.single.path, '/v1/kubernetes/roles/viewer');
      expect(info.allowedNamespaces, ['*', 'team-a']);
      expect(info.roleType, 'ClusterRole');
      expect(info.namespaceSelector, isEmpty);
      expect(info.suggestedNamespace, 'team-a');
    });

    test(
      'several namespaces are offered as choices, wildcard left out',
      () async {
        answer({
          'data': {
            'allowed_kubernetes_namespaces': ['team-a', '*', ' team-b ', ''],
          },
        });
        final info = await client.describeKubernetesRole(
          'kubernetes',
          'viewer',
        );
        expect(info.namespaceChoices, ['team-a', 'team-b']);
        expect(info.suggestedNamespace, 'team-a');
      },
    );

    test('reads the namespace label selector', () async {
      answer({
        'data': {
          'allowed_kubernetes_namespace_selector':
              '{"matchLabels":{"team":"payments"}}',
        },
      });
      final info = await client.describeKubernetesRole('kubernetes', 'pay');
      expect(info.namespaceSelector, '{"matchLabels":{"team":"payments"}}');
      expect(info.namespaceChoices, isEmpty);
    });

    test('a wildcard alone suggests no namespace', () async {
      answer({
        'data': {
          'allowed_kubernetes_namespaces': ['*'],
        },
      });
      final info = await client.describeKubernetesRole('kubernetes', 'viewer');
      expect(info.suggestedNamespace, isNull);
    });

    test('a role without allowed namespaces reads as none', () async {
      answer({'data': <String, dynamic>{}});
      final info = await client.describeKubernetesRole('kubernetes', 'viewer');
      expect(info.allowedNamespaces, isEmpty);
      expect(info.suggestedNamespace, isNull);
    });
  });

  test('toString never shows the token', () {
    const creds = KubernetesCredentials(
      mount: 'kubernetes',
      role: 'developer',
      serviceAccountToken: 'eyJhbGciOi.secret-token',
      serviceAccountName: 'v-demo',
      serviceAccountNamespace: 'team-a',
      lease: LeaseInfo(
        leaseId: 'l',
        leaseDuration: Duration.zero,
        renewable: false,
      ),
    );
    expect(creds.toString(), isNot(contains('secret-token')));
    expect(creds.toString(), contains('serviceAccountToken: ***'));
  });
}

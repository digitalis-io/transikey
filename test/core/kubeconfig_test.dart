import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/core/models/kubernetes_credentials.dart';
import 'package:transikey/core/models/lease_info.dart';
import 'package:transikey/core/utils/kubeconfig.dart';

KubernetesCredentials _creds({
  String token = 'tok-123',
  String ns = 'team-a',
}) => KubernetesCredentials(
  mount: 'k8s/prod',
  role: 'developer',
  serviceAccountToken: token,
  serviceAccountName: 'v-demo',
  serviceAccountNamespace: ns,
  lease: const LeaseInfo(
    leaseId: 'l',
    leaseDuration: Duration.zero,
    renewable: false,
  ),
);

const _pem = '-----BEGIN CERTIFICATE-----\nMIIBdev\n-----END CERTIFICATE-----';

void main() {
  const home = {'HOME': '/home/dev', 'USERPROFILE': r'C:\Users\dev'};

  group('kubeconfig', () {
    test('holds cluster, user and context for the token', () {
      final yaml = kubeconfigYaml(
        [_creds()],
        server: ' https://k8s.example.com:6443 ',
        caPem: _pem,
      );
      expect(yaml, contains('kind: Config'));
      expect(yaml, contains('server: "https://k8s.example.com:6443"'));
      // Embedded, so the file works from any directory or machine.
      final data = RegExp(
        r'certificate-authority-data: "([^"]+)"',
      ).firstMatch(yaml)!.group(1)!;
      expect(utf8.decode(base64.decode(data)), '$_pem\n');
      expect(yaml, isNot(contains('certificate-authority:')));
      expect(yaml, contains('token: "tok-123"'));
      expect(yaml, contains('namespace: "team-a"'));
      // Mount paths hold slashes; names stay one word.
      expect(
        yaml,
        contains('current-context: "transikey-k8s-prod-developer-team-a"'),
      );
    });

    test('several tokens share the cluster, one user and context each', () {
      final yaml = kubeconfigYaml([
        _creds(token: 'tok-a', ns: 'team-a'),
        _creds(token: 'tok-b', ns: 'team-b'),
      ], server: 'https://k8s:6443');
      expect(
        RegExp(
          r'^  - name: "transikey-k8s-prod"$',
          multiLine: true,
        ).allMatches(yaml),
        hasLength(1),
      );
      for (final (ns, token) in [('team-a', 'tok-a'), ('team-b', 'tok-b')]) {
        final name = '"transikey-k8s-prod-developer-$ns"';
        // One user and one context of that name.
        expect(
          RegExp(
            '^  - name: ${RegExp.escape(name)}\$',
            multiLine: true,
          ).allMatches(yaml),
          hasLength(2),
        );
        expect(yaml, contains('token: "$token"'));
        expect(yaml, contains('namespace: "$ns"'));
      }
      expect(yaml, contains('user: "transikey-k8s-prod-developer-team-b"'));
      // The first namespace is where kubectl starts.
      expect(
        yaml,
        contains('current-context: "transikey-k8s-prod-developer-team-a"'),
      );
    });

    test('there is no kubeconfig without a token', () {
      expect(
        () => kubeconfigYaml(const [], server: 'https://k8s'),
        throwsArgumentError,
      );
    });

    test('leaves the CA out when there is none', () {
      final yaml = kubeconfigYaml([_creds()], server: 'https://k8s:6443');
      expect(yaml, isNot(contains('certificate-authority')));
    });

    test('a value with quotes or a newline cannot break out of its field', () {
      const token = 'a"b\nkind: Evil';
      final yaml = kubeconfigYaml([
        _creds(token: token),
      ], server: 'https://k8s');
      final line = yaml
          .split('\n')
          .singleWhere((l) => l.trimLeft().startsWith('token:'));
      expect(jsonDecode(line.trimLeft().substring('token: '.length)), token);
      expect(
        yaml.split('\n').where((l) => l.startsWith('kind:')),
        hasLength(1),
      );
    });
  });

  group('CA certificate', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('transikey-ca-');
      addTearDown(() => dir.delete(recursive: true));
    });

    test('is read from an absolute path', () async {
      final file = File('${dir.path}/ca.crt')..writeAsStringSync(_pem);
      expect(await readCaCertificate(file.path), _pem);
    });

    test('is read from a path under ~', () async {
      File('${dir.path}/ca.crt').writeAsStringSync(_pem);
      final env = {'HOME': dir.path, 'USERPROFILE': dir.path};
      expect(await readCaCertificate('~/ca.crt', env), _pem);
    });

    test('an empty path means no CA', () async {
      expect(await readCaCertificate('  '), isEmpty);
    });

    test('a relative path is refused', () async {
      await expectLater(
        readCaCertificate('dev/k3s-ca.crt'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('absolute'),
          ),
        ),
      );
    });

    test('a missing file is refused', () async {
      await expectLater(
        readCaCertificate('${dir.path}/missing.crt'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            startsWith('Cannot read'),
          ),
        ),
      );
    });

    test('a file without a certificate is refused', () async {
      final file = File('${dir.path}/key.pem')
        ..writeAsStringSync('-----BEGIN PRIVATE KEY-----\n');
      await expectLater(
        readCaCertificate(file.path),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            startsWith('No PEM certificate'),
          ),
        ),
      );
    });
  });

  group('kubectl command', () {
    test('points KUBECONFIG at the saved file and never holds the token', () {
      final cmd = kubectlCommand('/home/dev/.kube/dev.yaml', _creds());
      expect(
        cmd,
        "KUBECONFIG='/home/dev/.kube/dev.yaml' kubectl "
        "--context 'transikey-k8s-prod-developer-team-a' "
        "get pods -n 'team-a'",
      );
      expect(cmd, isNot(contains('tok-123')));
    });

    test('quotes a path with spaces and quotes', () {
      final cmd = kubectlCommand("/tmp/it's here.yaml", _creds());
      expect(cmd, startsWith(r"KUBECONFIG='/tmp/it'\''s here.yaml' kubectl"));
    });

    test('quotes a namespace that tries to run a command', () {
      final cmd = kubectlCommand('/tmp/k.yaml', _creds(ns: r'a; rm -rf ~'));
      expect(cmd, endsWith("-n 'a; rm -rf ~'"));
    });
  });

  group('expandHome', () {
    test('leaves other paths alone', () {
      expect(expandHome('/etc/ca.crt', home), '/etc/ca.crt');
      expect(expandHome('~other/ca.crt', home), '~other/ca.crt');
    });

    test('keeps ~ when there is no home directory', () {
      expect(expandHome('~/ca.crt', const {}), '~/ca.crt');
    });
  });
}

import 'dart:convert';

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

void main() {
  const home = {'HOME': '/home/dev', 'USERPROFILE': r'C:\Users\dev'};

  group('kubeconfig', () {
    test('holds cluster, user and context for the token', () {
      final yaml = kubeconfigYaml(
        _creds(),
        server: ' https://k8s.example.com:6443 ',
        caPath: '/etc/k8s/ca.crt',
      );
      expect(yaml, contains('kind: Config'));
      expect(yaml, contains('server: "https://k8s.example.com:6443"'));
      expect(yaml, contains('certificate-authority: "/etc/k8s/ca.crt"'));
      expect(yaml, contains('token: "tok-123"'));
      expect(yaml, contains('namespace: "team-a"'));
      // Mount paths hold slashes; names stay one word.
      expect(yaml, contains('current-context: "transikey-k8s-prod-developer"'));
    });

    test('leaves the CA out when no path is given', () {
      final yaml = kubeconfigYaml(_creds(), server: 'https://k8s:6443');
      expect(yaml, isNot(contains('certificate-authority')));
    });

    test('expands ~ in the CA path, which kubectl does not', () {
      final yaml = kubeconfigYaml(
        _creds(),
        server: 'https://k8s:6443',
        caPath: '~/.kube/ca.crt',
        environment: home,
      );
      expect(yaml, isNot(contains('~')));
      expect(yaml, contains('.kube/ca.crt"'));
    });

    test('a value with quotes or a newline cannot break out of its field', () {
      const token = 'a"b\nkind: Evil';
      final yaml = kubeconfigYaml(_creds(token: token), server: 'https://k8s');
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

  group('kubectl command', () {
    test('points KUBECONFIG at the saved file and never holds the token', () {
      final cmd = kubectlCommand('/home/dev/.kube/dev.yaml', 'team-a');
      expect(
        cmd,
        "KUBECONFIG='/home/dev/.kube/dev.yaml' kubectl get pods -n 'team-a'",
      );
    });

    test('quotes a path with spaces and quotes', () {
      final cmd = kubectlCommand("/tmp/it's here.yaml", 'ns');
      expect(cmd, startsWith(r"KUBECONFIG='/tmp/it'\''s here.yaml' kubectl"));
    });

    test('quotes a namespace that tries to run a command', () {
      final cmd = kubectlCommand('/tmp/k.yaml', r'a; rm -rf ~');
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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/core/utils/cli_environment.dart';

void main() {
  CliEnvironment detect(
    Map<String, String> env, {
    Map<String, String> files = const {},
  }) => CliEnvironment.from(
    env,
    fileExists: files.containsKey,
    readFile: (p) => files[p] ?? (throw FileSystemException('missing', p)),
  );

  final tokenFile = '/home/me${Platform.pathSeparator}.vault-token';

  test('BAO_* wins over VAULT_*', () {
    final cli = detect({
      'VAULT_ADDR': 'https://vault.example:8200',
      'BAO_ADDR': 'https://bao.example:8200',
      'VAULT_NAMESPACE': 'old',
      'BAO_NAMESPACE': 'team-a',
    });
    expect(cli.address, 'https://bao.example:8200');
    expect(cli.addressSource, 'BAO_ADDR');
    expect(cli.namespace, 'team-a');
  });

  test('VAULT_ADDR is used when BAO_ADDR is unset or blank', () {
    final cli = detect({
      'BAO_ADDR': '  ',
      'VAULT_ADDR': 'http://127.0.0.1:8200',
    });
    expect(cli.address, 'http://127.0.0.1:8200');
    expect(cli.addressSource, 'VAULT_ADDR');
  });

  test('an address that is not an http(s) URL is ignored', () {
    expect(detect({'VAULT_ADDR': 'vault.example:8200'}).address, isNull);
    expect(detect({'VAULT_ADDR': 'file:///etc/passwd'}).address, isNull);
  });

  test('skip verify accepts the CLI spellings', () {
    for (final v in ['1', 'true', 'TRUE', 't', 'yes']) {
      expect(detect({'VAULT_SKIP_VERIFY': v}).skipVerify, isTrue, reason: v);
    }
    for (final v in ['0', 'false', '']) {
      expect(detect({'VAULT_SKIP_VERIFY': v}).skipVerify, isFalse, reason: v);
    }
  });

  test('a token variable wins over the token file', () {
    final cli = detect(
      {'HOME': '/home/me', 'VAULT_TOKEN': 'env-token'},
      files: {tokenFile: 'file-token'},
    );
    expect(cli.tokenSource, 'VAULT_TOKEN');
    expect(cli.readToken(), 'env-token');
  });

  test('the token file is found and trimmed', () {
    final cli = detect(
      {'HOME': '/home/me'},
      files: {tokenFile: 'file-token\n'},
    );
    expect(cli.tokenSource, '~/.vault-token');
    expect(cli.readToken(), 'file-token');
    expect(cli.hasAnything, isTrue);
  });

  test('an empty token file yields no token', () {
    final cli = detect({'HOME': '/home/me'}, files: {tokenFile: '  \n'});
    expect(cli.readToken(), isNull);
  });

  test('nothing set means nothing to import', () {
    final cli = detect({'HOME': '/home/me'});
    expect(cli.hasAnything, isFalse);
    expect(cli.readToken(), isNull);
    expect(cli.readCaCert(), isNull);
  });

  test('toString never shows the token', () {
    final cli = detect({'VAULT_TOKEN': 'super-secret-token'});
    expect(cli.toString(), isNot(contains('super-secret-token')));
  });
}

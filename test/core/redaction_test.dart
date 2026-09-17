import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/core/utils/redaction.dart';

void main() {
  group('Redaction.value', () {
    test('masks sensitive keys at any depth', () {
      final out =
          Redaction.value({
                'username': 'alice',
                'password': 'hunter2',
                'auth': {
                  'client_token': 'hvs.abcdefghijklmnop',
                  'policies': ['a'],
                },
                'items': [
                  {'secret_id': 'x'},
                ],
              })
              as Map;
      expect(out['username'], 'alice');
      expect(out['password'], Redaction.mask);
      expect((out['auth'] as Map)['client_token'], Redaction.mask);
      expect((out['auth'] as Map)['policies'], ['a']);
      expect(
        ((out['items'] as List).first as Map)['secret_id'],
        Redaction.mask,
      );
    });

    test('leaves non-sensitive scalars untouched', () {
      expect(Redaction.value(42), 42);
      expect(Redaction.value(null), isNull);
    });
  });

  group('Redaction.text', () {
    test('masks Vault and OpenBao style tokens', () {
      const input = 'token hvs.CAESIJ1234567890abcdef and s.abcdefgh12345678';
      final out = Redaction.text(input);
      expect(out, isNot(contains('CAESIJ')));
      expect(out, isNot(contains('abcdefgh12345678')));
    });

    test('masks PEM blocks', () {
      const pem =
          '-----BEGIN PRIVATE KEY-----\nMIIabc\n-----END PRIVATE KEY-----';
      expect(Redaction.text('key: $pem'), 'key: ${Redaction.mask}');
    });

    test('keeps ordinary text', () {
      expect(
        Redaction.text('GET /v1/sys/health 200'),
        'GET /v1/sys/health 200',
      );
    });
  });
}

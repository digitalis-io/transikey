import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/features/sharing/presentation/sharing_screen.dart';

void main() {
  test('a JSON object is used as is', () {
    expect(parseSecretPayload('{"user":"a","pass":"b"}'), {
      'user': 'a',
      'pass': 'b',
    });
  });

  test('plain text is wrapped under the "secret" key', () {
    expect(parseSecretPayload('  hello  '), {'secret': 'hello'});
  });

  test('broken JSON falls back to plain text', () {
    expect(parseSecretPayload('{not json'), {'secret': '{not json'});
  });

  test('empty input gives an empty payload', () {
    expect(parseSecretPayload('   '), isEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/core/utils/share_link.dart';

void main() {
  const link = ShareLink(
    address: 'https://bao.example.com:8200',
    namespace: 'team-a/prod',
    token: 'hvs.CAESIwrappingtoken',
  );

  test('a link survives a round trip through its URL', () {
    final url = link.toUri().toString();
    expect(url, startsWith('transikey://unwrap?'));
    expect(ShareLink.tryParse(url), link);
  });

  test('the namespace is optional', () {
    const bare = ShareLink(address: 'http://127.0.0.1:8200', token: 't0ken');
    final url = bare.toUri().toString();
    expect(url, isNot(contains('ns=')));
    expect(ShareLink.tryParse(url), bare);
  });

  test('the CLI command quotes every value for the shell', () {
    const tricky = ShareLink(address: 'https://bao.test', token: "a'b; rm -rf");
    expect(
      tricky.toCliCommand(),
      "BAO_ADDR='https://bao.test' bao unwrap 'a'\\''b; rm -rf'",
    );
    expect(link.toCliCommand(), contains("BAO_NAMESPACE='team-a/prod'"));
  });

  test('toString never shows the token', () {
    expect(link.toString(), isNot(contains('wrappingtoken')));
  });

  group('malformed links are rejected', () {
    for (final (name, input) in [
      ('another scheme', 'https://unwrap?addr=https://x&token=t'),
      ('another action', 'transikey://wrap?addr=https://x&token=t'),
      ('no token', 'transikey://unwrap?addr=https://bao.test'),
      ('empty token', 'transikey://unwrap?addr=https://bao.test&token='),
      ('no address', 'transikey://unwrap?token=t'),
      ('address without host', 'transikey://unwrap?addr=https://&token=t'),
      (
        'non-http address',
        'transikey://unwrap?addr=file:///etc/passwd&token=t',
      ),
      ('not a URL', 'hello world'),
      ('empty', ''),
    ]) {
      test(name, () => expect(ShareLink.tryParse(input), isNull));
    }
  });
}

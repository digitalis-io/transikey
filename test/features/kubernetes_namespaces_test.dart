import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/features/kubernetes/presentation/kubernetes_provider.dart';

void main() {
  group('namespaces to request', () {
    test('are the chosen ones plus what is typed', () {
      expect(namespacesToRequest(['team-a', 'team-b'], ' team-c '), [
        'team-a',
        'team-b',
        'team-c',
      ]);
    });

    test('a typed namespace that is already chosen counts once', () {
      expect(namespacesToRequest(['team-a'], 'team-a'), ['team-a']);
    });

    test('blank entries are dropped', () {
      expect(namespacesToRequest(['', ' '], '  '), isEmpty);
    });

    test('only what is typed when nothing is chosen', () {
      expect(namespacesToRequest(const [], 'sandbox'), ['sandbox']);
    });
  });
}

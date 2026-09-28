import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/features/kubernetes/presentation/namespace_field.dart';

void main() {
  group('namespace help', () {
    test('lists a few allowed namespaces', () {
      expect(
        namespaceHelp(allowed: ['a', 'b'], choices: ['a', 'b'], selector: ''),
        'Allowed: a, b',
      );
    });

    test('counts many instead of listing them', () {
      final many = [for (var i = 0; i < 12; i++) 'ns-$i'];
      expect(
        namespaceHelp(allowed: many, choices: many, selector: ''),
        '12 allowed, type to filter',
      );
    });

    test('a wildcard allows any namespace', () {
      expect(
        namespaceHelp(allowed: ['*', 'a'], choices: ['a'], selector: ''),
        'Any namespace',
      );
    });

    test('names the labels of a selector', () {
      expect(
        namespaceHelp(
          allowed: const [],
          choices: const [],
          selector: '{"matchLabels":{"team":"payments","env":"dev"}}',
        ),
        'Namespaces labelled team=payments, env=dev',
      );
    });

    test('combines a list and a selector', () {
      expect(
        namespaceHelp(
          allowed: ['a'],
          choices: ['a'],
          selector: '{"matchLabels":{"team":"x"}}',
        ),
        'Allowed: a, or labelled team=x',
      );
    });

    test('says nothing when the role cannot tell', () {
      expect(
        namespaceHelp(allowed: const [], choices: const [], selector: ''),
        isNull,
      );
    });
  });

  group('selector label', () {
    test('shows YAML as the server returned it', () {
      expect(
        selectorLabel('matchLabels:\n  team: x'),
        'matchLabels:\n  team: x',
      );
    });

    test('shows expressions as the server returned them', () {
      const selector =
          '{"matchExpressions":[{"key":"team","operator":"In","values":["x"]}]}';
      expect(selectorLabel(selector), selector);
    });
  });
}

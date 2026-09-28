import 'package:flutter_test/flutter_test.dart';

import 'i_enter_the_namespace.dart';

/// Usage: I add the namespace {'default'}
///
/// Keeps the namespaces already chosen.
Future<void> iAddTheNamespace(WidgetTester tester, String namespace) =>
    addNamespace(tester, namespace);

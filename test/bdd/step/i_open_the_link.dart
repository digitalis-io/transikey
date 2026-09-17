import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/app/providers/deep_link_provider.dart';
import 'package:transikey/core/utils/share_link.dart';

import 'sharing_world.dart';

/// Usage: I open the link {'transikey://unwrap?addr=...&token=...'}
///
/// Mirrors the OS deep link listener: parse, then offer valid links only.
Future<void> iOpenTheLink(WidgetTester tester, String url) async {
  final link = ShareLink.tryParse(url);
  if (link != null) {
    SharingWorld.container.read(pendingShareLinkProvider.notifier).offer(link);
  }
  await tester.pumpAndSettle();
}

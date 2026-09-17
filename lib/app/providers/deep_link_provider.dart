import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/share_link.dart';
import 'core_providers.dart';

/// Share link waiting to be unwrapped. The sharing screen consumes it.
final pendingShareLinkProvider =
    NotifierProvider<PendingShareLinkNotifier, ShareLink?>(
      PendingShareLinkNotifier.new,
    );

class PendingShareLinkNotifier extends Notifier<ShareLink?> {
  @override
  ShareLink? build() => null;

  void offer(ShareLink link) => state = link;

  /// Returns the pending link and forgets it.
  ShareLink? take() {
    final link = state;
    state = null;
    return link;
  }
}

/// Listens for `transikey://` links opened from the OS (cold and warm start).
final deepLinkListenerProvider = Provider<void>((ref) {
  StreamSubscription<Uri>? subscription;
  try {
    subscription = AppLinks().uriLinkStream.listen((uri) {
      final link = ShareLink.tryParse(uri.toString());
      if (link == null) {
        ref.read(loggerProvider).warning('deeplink.ignored: malformed link');
        return;
      }
      ref.read(pendingShareLinkProvider.notifier).offer(link);
    }, onError: (Object _) {});
  } on MissingPluginException {
    // Platform without deep link support (tests).
  }
  ref.onDispose(() => subscription?.cancel());
});

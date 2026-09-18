import 'package:flutter_test/flutter_test.dart';

import 'the_secret_sharing_screen_is_open.dart';

/// Usage: the secret sharing screen is open without a session
Future<void> theSecretSharingScreenIsOpenWithoutASession(WidgetTester tester) =>
    theSecretSharingScreenIsOpen(tester, signedIn: false);

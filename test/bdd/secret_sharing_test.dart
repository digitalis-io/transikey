// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_secret_sharing_screen_is_open.dart';
import './step/i_wrap_the_secret.dart';
import './step/i_see_the_button.dart';
import './step/i_see_the_text.dart';
import './step/i_do_not_see_the_button.dart';
import './step/i_open_the_link.dart';
import './step/the_unwrap_form_targets_the_server.dart';
import './step/no_secret_has_been_requested.dart';

void main() {
  group('''Secret sharing links''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theSecretSharingScreenIsOpen(tester);
    }

    testWidgets('''Wrapping a secret offers a share link and a CLI command''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iWrapTheSecret(tester, 'database password is hunter2');
      await iSeeTheButton(tester, 'Copy share link');
      await iSeeTheButton(tester, 'Copy CLI command');
    });
    testWidgets('''Wrapping nothing is refused''', (tester) async {
      await bddSetUp(tester);
      await iWrapTheSecret(tester, '');
      await iSeeTheText(tester, 'Nothing to wrap.');
      await iDoNotSeeTheButton(tester, 'Copy share link');
    });
    testWidgets(
      '''Opening a share link prefills the unwrap form without sending anything''',
      (tester) async {
        await bddSetUp(tester);
        await iOpenTheLink(
          tester,
          'transikey://unwrap?addr=https%3A%2F%2Fbao.partner.example%3A8200&token=wrapping-token-1',
        );
        await theUnwrapFormTargetsTheServer(
          tester,
          'https://bao.partner.example:8200',
        );
        await noSecretHasBeenRequested(tester);
      },
    );
    testWidgets('''A malformed link is ignored''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheLink(
        tester,
        'transikey://unwrap?addr=file%3A%2F%2F%2Fetc%2Fpasswd&token=x',
      );
      await iSeeTheButton(tester, 'Wrap secret');
      await noSecretHasBeenRequested(tester);
    });
  });
}

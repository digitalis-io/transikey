// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_connected_to_a_test_server.dart';
import './step/i_sign_in_with_userpass_as_and_password.dart';
import './step/i_see_the_message.dart';
import './step/i_do_not_see_the_message.dart';
import './step/i_submit_the_sign_in_form_without_credentials.dart';
import './step/i_sign_out.dart';

void main() {
  group('''Authentication''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsConnectedToATestServer(tester);
    }

    testWidgets('''Sign in with a username and password''', (tester) async {
      await bddSetUp(tester);
      await iSignInWithUserpassAsAndPassword(tester, 'demo', 'good-password');
      await iSeeTheMessage(tester, 'Signed in');
      await iSeeTheMessage(tester, 'demo');
    });
    testWidgets('''A wrong password is rejected''', (tester) async {
      await bddSetUp(tester);
      await iSignInWithUserpassAsAndPassword(tester, 'demo', 'bad-password');
      await iSeeTheMessage(tester, 'Login failed. Check your credentials.');
      await iDoNotSeeTheMessage(tester, 'Signed in');
    });
    testWidgets('''The token form refuses an empty token''', (tester) async {
      await bddSetUp(tester);
      await iSubmitTheSignInFormWithoutCredentials(tester);
      await iSeeTheMessage(tester, 'Required');
      await iDoNotSeeTheMessage(tester, 'Signed in');
    });
    testWidgets('''Signing out returns to the sign in form''', (tester) async {
      await bddSetUp(tester);
      await iSignInWithUserpassAsAndPassword(tester, 'demo', 'good-password');
      await iSignOut(tester);
      await iSeeTheMessage(tester, 'Sign in');
      await iDoNotSeeTheMessage(tester, 'Signed in');
    });
  });
}

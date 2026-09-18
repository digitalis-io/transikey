// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_connected_to_a_test_server.dart';
import './step/i_sign_in_with_userpass_as_and_password.dart';
import './step/i_see_the_message.dart';
import './step/i_sign_in_with_ldap_as_and_password.dart';
import './step/i_do_not_see_the_message.dart';
import './step/i_submit_the_sign_in_form_without_credentials.dart';
import './step/i_sign_out.dart';
import './step/the_servers_and_are_remembered.dart';
import './step/i_pick_the_server.dart';
import './step/the_sign_in_form_targets_as.dart';
import './step/i_import_the_cli_environment.dart';

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
    testWidgets('''Sign in with an LDAP account''', (tester) async {
      await bddSetUp(tester);
      await iSignInWithLdapAsAndPassword(tester, 'demo', 'good-password');
      await iSeeTheMessage(tester, 'Signed in');
      await iSeeTheMessage(tester, 'ldap');
    });
    testWidgets('''A wrong LDAP password is rejected''', (tester) async {
      await bddSetUp(tester);
      await iSignInWithLdapAsAndPassword(tester, 'demo', 'bad-password');
      await iSeeTheMessage(tester, 'Login failed. Check your credentials.');
      await iDoNotSeeTheMessage(tester, 'Signed in');
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
    testWidgets('''Picking a remembered server fills in the sign in form''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theServersAndAreRemembered(tester, 'prod', 'dev');
      await iPickTheServer(tester, 'prod');
      await theSignInFormTargetsAs(
        tester,
        'https://bao.prod.example:8200',
        'sergio',
      );
    });
    testWidgets('''A new server starts from an empty form''', (tester) async {
      await bddSetUp(tester);
      await theServersAndAreRemembered(tester, 'prod', 'dev');
      await iPickTheServer(tester, 'prod');
      await iPickTheServer(tester, 'New server…');
      await theSignInFormTargetsAs(tester, '', '');
    });
    testWidgets(
      '''Importing the CLI environment fills in the form without signing in''',
      (tester) async {
        await bddSetUp(tester);
        await iImportTheCliEnvironment(tester);
        await theSignInFormTargetsAs(
          tester,
          'https://bao.cli.example:8200',
          '',
        );
        await iDoNotSeeTheMessage(tester, 'Signed in');
      },
    );
  });
}

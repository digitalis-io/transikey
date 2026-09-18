// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_database_credentials_screen_is_open.dart';
import './step/i_pick_the_role.dart';
import './step/i_request_database_credentials.dart';
import './step/i_see_the_text.dart';
import './step/i_do_not_see_the_text.dart';

void main() {
  group('''Database credentials''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theDatabaseCredentialsScreenIsOpen(tester);
    }

    testWidgets('''Requesting credentials shows them for the chosen role''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iPickTheRole(tester, 'readonly');
      await iRequestDatabaseCredentials(tester);
      await iSeeTheText(tester, 'Password');
    });
    testWidgets('''Picking another role clears the previous credentials''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iPickTheRole(tester, 'readonly');
      await iRequestDatabaseCredentials(tester);
      await iPickTheRole(tester, 'short-lived');
      await iDoNotSeeTheText(tester, 'Password');
      await iSeeTheText(tester, 'Request credentials for short-lived');
    });
    testWidgets('''Picking the same role again keeps the credentials''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iPickTheRole(tester, 'readonly');
      await iRequestDatabaseCredentials(tester);
      await iPickTheRole(tester, 'readonly');
      await iSeeTheText(tester, 'Password');
    });
  });
}

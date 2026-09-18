// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_server_that_offers_database_roles.dart';
import './step/the_database_credentials_screen_is_open.dart';
import './step/i_pick_the_role.dart';
import './step/i_request_database_credentials.dart';
import './step/i_see_the_text.dart';
import './step/i_do_not_see_the_text.dart';
import './step/the_database_mount_offers_the_role.dart';
import './step/i_clear_the_credentials_from_the_screen.dart';
import './step/the_database_mount_refuses_to_list_its_roles.dart';
import './step/the_server_reveals_a_cassandra_cluster_behind_the_role.dart';

void main() {
  group('''Database credentials''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aServerThatOffersDatabaseRoles(tester);
    }

    testWidgets('''Requesting credentials shows them for the chosen role''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theDatabaseCredentialsScreenIsOpen(tester);
      await iPickTheRole(tester, 'readonly');
      await iRequestDatabaseCredentials(tester);
      await iSeeTheText(tester, 'Password');
      await iSeeTheText(tester, 'database/readonly');
    });
    testWidgets('''Picking another role clears the previous credentials''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theDatabaseCredentialsScreenIsOpen(tester);
      await iPickTheRole(tester, 'readonly');
      await iRequestDatabaseCredentials(tester);
      await iPickTheRole(tester, 'short-lived');
      await iDoNotSeeTheText(tester, 'Password');
      await iSeeTheText(tester, 'Request credentials for short-lived');
    });
    testWidgets(
      '''Picking a role on another mount clears the previous credentials''',
      (tester) async {
        await bddSetUp(tester);
        await theDatabaseMountOffersTheRole(tester, 'cass001', 'operator');
        await theDatabaseCredentialsScreenIsOpen(tester);
        await iPickTheRole(tester, 'readonly');
        await iRequestDatabaseCredentials(tester);
        await iPickTheRole(tester, 'operator');
        await iDoNotSeeTheText(tester, 'Password');
      },
    );
    testWidgets('''Picking the same role again keeps the credentials''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theDatabaseCredentialsScreenIsOpen(tester);
      await iPickTheRole(tester, 'readonly');
      await iRequestDatabaseCredentials(tester);
      await iPickTheRole(tester, 'readonly');
      await iSeeTheText(tester, 'Password');
    });
    testWidgets('''Clearing credentials removes them from the screen''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theDatabaseCredentialsScreenIsOpen(tester);
      await iPickTheRole(tester, 'readonly');
      await iRequestDatabaseCredentials(tester);
      await iClearTheCredentialsFromTheScreen(tester);
      await iDoNotSeeTheText(tester, 'Password');
    });
    testWidgets('''Roles are grouped by mount''', (tester) async {
      await bddSetUp(tester);
      await theDatabaseMountOffersTheRole(tester, 'cass001', 'operator');
      await theDatabaseCredentialsScreenIsOpen(tester);
      await iPickTheRole(tester, 'operator');
      await iSeeTheText(tester, 'cass001');
      await iSeeTheText(tester, 'Request credentials for cass001/operator');
    });
    testWidgets(
      '''A mount that refuses to list its roles does not hide the others''',
      (tester) async {
        await bddSetUp(tester);
        await theDatabaseMountRefusesToListItsRoles(tester, 'locked');
        await theDatabaseCredentialsScreenIsOpen(tester);
        await iSeeTheText(tester, 'Permission denied.');
        await iSeeTheText(tester, 'readonly');
      },
    );
    testWidgets('''The engine is asked for when the server hides it''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theDatabaseCredentialsScreenIsOpen(tester);
      await iPickTheRole(tester, 'readonly');
      await iRequestDatabaseCredentials(tester);
      await iSeeTheText(tester, 'MySQL / MariaDB');
      await iSeeTheText(tester, 'psql command');
    });
    testWidgets('''The engine is not asked for when the server reveals it''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theServerRevealsACassandraClusterBehindTheRole(tester, 'readonly');
      await theDatabaseCredentialsScreenIsOpen(tester);
      await iPickTheRole(tester, 'readonly');
      await iRequestDatabaseCredentials(tester);
      await iDoNotSeeTheText(tester, 'MySQL / MariaDB');
      await iSeeTheText(tester, 'cqlsh command');
    });
  });
}

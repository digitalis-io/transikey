// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/a_server_that_offers_kubernetes_roles.dart';
import './step/the_kubernetes_access_screen_is_open.dart';
import './step/i_pick_the_role.dart';
import './step/i_request_a_kubernetes_token.dart';
import './step/i_see_the_text.dart';
import './step/the_service_account_is_bound_within_its_namespace.dart';
import './step/i_choose_the_namespace.dart';
import './step/the_token_is_issued_for_the_namespace.dart';
import './step/i_enter_the_namespace.dart';
import './step/the_namespaces_offered_are.dart';
import './step/the_namespace_is_offered_as_used_before.dart';
import './step/the_kubernetes_role_allows_namespaces_labelled.dart';
import './step/i_cannot_request_a_kubernetes_token.dart';
import './step/i_ask_for_a_clusterwide_binding.dart';
import './step/the_service_account_is_bound_clusterwide.dart';
import './step/i_do_not_see_the_text.dart';
import './step/i_set_the_cluster_address_with_the_ca.dart';
import './step/i_copy_the_kubeconfig.dart';
import './step/the_copied_kubeconfig_points_at_with_the_ca.dart';
import './step/the_copied_kubeconfig_holds_the_token_for_the_namespace.dart';
import './step/nothing_has_been_copied.dart';
import './step/i_cannot_copy_the_kubeconfig.dart';
import './step/i_clear_the_credentials_from_the_screen.dart';
import './step/the_kubernetes_mount_offers_the_role.dart';
import './step/the_server_has_no_kubernetes_engine.dart';

void main() {
  group('''Kubernetes credentials''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await aServerThatOffersKubernetesRoles(tester);
    }

    testWidgets('''Requesting a token shows the service account''',
        (tester) async {
      await bddSetUp(tester);
      await theKubernetesAccessScreenIsOpen(tester);
      await iPickTheRole(tester, 'developer');
      await iRequestAKubernetesToken(tester);
      await iSeeTheText(tester, 'kubernetes/developer');
      await iSeeTheText(tester, 'v-demo-developer');
      await iSeeTheText(tester, 'Token');
      await theServiceAccountIsBoundWithinItsNamespace(tester);
    });
    testWidgets('''The namespace is filled in from the role''', (tester) async {
      await bddSetUp(tester);
      await theKubernetesAccessScreenIsOpen(tester);
      await iPickTheRole(tester, 'developer');
      await iSeeTheText(tester, 'team-a');
      await iSeeTheText(tester, 'Allowed: team-a, team-b');
    });
    testWidgets('''One of several allowed namespaces is picked''',
        (tester) async {
      await bddSetUp(tester);
      await theKubernetesAccessScreenIsOpen(tester);
      await iPickTheRole(tester, 'developer');
      await iChooseTheNamespace(tester, 'team-b');
      await iRequestAKubernetesToken(tester);
      await theTokenIsIssuedForTheNamespace(tester, 'team-b');
    });
    testWidgets(
        '''The namespace is filled in again when coming back to a role''',
        (tester) async {
      await bddSetUp(tester);
      await theKubernetesAccessScreenIsOpen(tester);
      await iPickTheRole(tester, 'developer');
      await iPickTheRole(tester, 'viewer');
      await iPickTheRole(tester, 'developer');
      await iSeeTheText(tester, 'team-a');
    });
    testWidgets('''The namespaces offered narrow down as I type''',
        (tester) async {
      await bddSetUp(tester);
      await theKubernetesAccessScreenIsOpen(tester);
      await iPickTheRole(tester, 'developer');
      await iEnterTheNamespace(tester, 'b');
      await theNamespacesOfferedAre(tester, 'team-b');
    });
    testWidgets(
        '''A namespace used before is filled in when the role cannot tell''',
        (tester) async {
      await bddSetUp(tester);
      await theKubernetesAccessScreenIsOpen(tester);
      await iPickTheRole(tester, 'viewer');
      await iEnterTheNamespace(tester, 'team-z');
      await iRequestAKubernetesToken(tester);
      await iPickTheRole(tester, 'developer');
      await iPickTheRole(tester, 'viewer');
      await iSeeTheText(tester, 'team-z');
      await theNamespaceIsOfferedAsUsedBefore(tester, 'team-z');
    });
    testWidgets('''A namespace the server refused is not remembered''',
        (tester) async {
      await bddSetUp(tester);
      await theKubernetesAccessScreenIsOpen(tester);
      await iPickTheRole(tester, 'developer');
      await iEnterTheNamespace(tester, 'default');
      await iRequestAKubernetesToken(tester);
      await iEnterTheNamespace(tester, '');
      await theNamespacesOfferedAre(tester, 'team-a, team-b');
    });
    testWidgets('''A role that allows namespaces by label says so''',
        (tester) async {
      await bddSetUp(tester);
      await theKubernetesRoleAllowsNamespacesLabelled(
          tester, 'payments', 'team=payments');
      await theKubernetesAccessScreenIsOpen(tester);
      await iPickTheRole(tester, 'payments');
      await iSeeTheText(tester, 'Namespaces labelled team=payments');
    });
    testWidgets('''The namespace is typed when the role cannot be read''',
        (tester) async {
      await bddSetUp(tester);
      await theKubernetesAccessScreenIsOpen(tester);
      await iPickTheRole(tester, 'viewer');
      await iSeeTheText(tester, 'Enter the namespace for the service account.');
      await iCannotRequestAKubernetesToken(tester);
    });
    testWidgets('''A cluster-wide binding is asked for on request''',
        (tester) async {
      await bddSetUp(tester);
      await theKubernetesAccessScreenIsOpen(tester);
      await iPickTheRole(tester, 'viewer');
      await iEnterTheNamespace(tester, 'team-b');
      await iAskForAClusterwideBinding(tester);
      await iRequestAKubernetesToken(tester);
      await theServiceAccountIsBoundClusterwide(tester);
    });
    testWidgets('''A namespace the role does not allow is refused''',
        (tester) async {
      await bddSetUp(tester);
      await theKubernetesAccessScreenIsOpen(tester);
      await iPickTheRole(tester, 'developer');
      await iEnterTheNamespace(tester, 'default');
      await iRequestAKubernetesToken(tester);
      await iSeeTheText(tester, 'Namespace default is not allowed.');
      await iDoNotSeeTheText(tester, 'Token');
    });
    testWidgets('''The kubeconfig holds the cluster address, CA and token''',
        (tester) async {
      await bddSetUp(tester);
      await theKubernetesAccessScreenIsOpen(tester);
      await iPickTheRole(tester, 'developer');
      await iRequestAKubernetesToken(tester);
      await iSetTheClusterAddressWithTheCa(
          tester, 'https://k8s.test:6443', '/etc/k8s/ca.crt');
      await iCopyTheKubeconfig(tester);
      await theCopiedKubeconfigPointsAtWithTheCa(
          tester, 'https://k8s.test:6443', '/etc/k8s/ca.crt');
      await theCopiedKubeconfigHoldsTheTokenForTheNamespace(tester, 'team-a');
    });
    testWidgets('''A CA certificate that cannot be read stops the kubeconfig''',
        (tester) async {
      await bddSetUp(tester);
      await theKubernetesAccessScreenIsOpen(tester);
      await iPickTheRole(tester, 'developer');
      await iRequestAKubernetesToken(tester);
      await iSetTheClusterAddressWithTheCa(
          tester, 'https://k8s.test:6443', '/etc/k8s/missing.crt');
      await iCopyTheKubeconfig(tester);
      await iSeeTheText(
          tester, 'Cannot read the CA certificate: /etc/k8s/missing.crt');
      await nothingHasBeenCopied(tester);
    });
    testWidgets('''The kubeconfig cannot be made without a cluster address''',
        (tester) async {
      await bddSetUp(tester);
      await theKubernetesAccessScreenIsOpen(tester);
      await iPickTheRole(tester, 'developer');
      await iRequestAKubernetesToken(tester);
      await iSeeTheText(tester, 'Enter the API server URL (https://…) first.');
      await iCannotCopyTheKubeconfig(tester);
    });
    testWidgets(
        '''Picking another role clears the token but keeps the cluster address''',
        (tester) async {
      await bddSetUp(tester);
      await theKubernetesAccessScreenIsOpen(tester);
      await iPickTheRole(tester, 'developer');
      await iRequestAKubernetesToken(tester);
      await iSetTheClusterAddressWithTheCa(
          tester, 'https://k8s.test:6443', '/etc/k8s/ca.crt');
      await iPickTheRole(tester, 'viewer');
      await iDoNotSeeTheText(tester, 'Token');
      await iEnterTheNamespace(tester, 'team-a');
      await iRequestAKubernetesToken(tester);
      await iSeeTheText(tester, 'https://k8s.test:6443');
    });
    testWidgets('''Clearing the token removes it from the screen''',
        (tester) async {
      await bddSetUp(tester);
      await theKubernetesAccessScreenIsOpen(tester);
      await iPickTheRole(tester, 'developer');
      await iRequestAKubernetesToken(tester);
      await iClearTheCredentialsFromTheScreen(tester);
      await iDoNotSeeTheText(tester, 'Token');
    });
    testWidgets('''Roles are grouped by mount''', (tester) async {
      await bddSetUp(tester);
      await theKubernetesMountOffersTheRole(tester, 'k8s-prod', 'deployer');
      await theKubernetesAccessScreenIsOpen(tester);
      await iPickTheRole(tester, 'deployer');
      await iSeeTheText(tester, 'k8s-prod');
      await iSeeTheText(tester, 'Request token for k8s-prod/deployer');
    });
    testWidgets(
        '''A server without the Kubernetes engine shows why there are no roles''',
        (tester) async {
      await bddSetUp(tester);
      await theServerHasNoKubernetesEngine(tester);
      await theKubernetesAccessScreenIsOpen(tester);
      await iSeeTheText(
          tester, 'Not found. Check the mount path and role name.');
      await iDoNotSeeTheText(tester, 'developer');
    });
  });
}

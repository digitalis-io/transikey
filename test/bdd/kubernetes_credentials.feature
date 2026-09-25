Feature: Kubernetes credentials
  Roles come from every Kubernetes mount. A token belongs to one role and
  one namespace, and disappears as soon as another role is picked. The
  cluster address is typed once per mount and remembered.

  Widget level scenarios against a fake server: settings live in an
  in-memory store that dies with the scenario and copies go to a fake
  clipboard, so nothing is persisted outside the test process. No teardown
  beyond disposing the provider container is needed; scenarios are order
  independent and parallel safe. CA files are read from a fake disk. Saving a kubeconfig file and its 0600
  permissions are covered by unit tests: native save dialogs do not run
  under flutter test.

  The server fake has one mount called 'kubernetes' with the roles
  'developer' (readable, allows the namespaces 'team-a' and 'team-b') and 'viewer'
  (a token may not read it, any namespace allowed).

  Background:
    Given a server that offers Kubernetes roles

  Scenario: Requesting a token shows the service account
    Given the Kubernetes access screen is open
    When I pick the role {'developer'}
    And I request a Kubernetes token
    Then I see the text {'kubernetes/developer'}
    And I see the text {'v-demo-developer'}
    And I see the text {'Token'}
    And the service account is bound within its namespace

  Scenario: The namespace is filled in from the role
    Given the Kubernetes access screen is open
    When I pick the role {'developer'}
    Then I see the text {'team-a'}
    And I see the text {'Allowed: team-a, team-b'}

  Scenario: One of several allowed namespaces is picked
    Given the Kubernetes access screen is open
    And I pick the role {'developer'}
    When I choose the namespace {'team-b'}
    And I request a Kubernetes token
    Then the token is issued for the namespace {'team-b'}

  Scenario: The namespace is filled in again when coming back to a role
    Given the Kubernetes access screen is open
    And I pick the role {'developer'}
    And I pick the role {'viewer'}
    When I pick the role {'developer'}
    Then I see the text {'team-a'}

  Scenario: The namespace is typed when the role cannot be read
    Given the Kubernetes access screen is open
    When I pick the role {'viewer'}
    Then I see the text {'Enter the namespace for the service account.'}
    And I cannot request a Kubernetes token

  Scenario: A cluster-wide binding is asked for on request
    Given the Kubernetes access screen is open
    And I pick the role {'viewer'}
    And I enter the namespace {'team-b'}
    When I ask for a cluster-wide binding
    And I request a Kubernetes token
    Then the service account is bound cluster-wide

  Scenario: A namespace the role does not allow is refused
    Given the Kubernetes access screen is open
    And I pick the role {'developer'}
    And I enter the namespace {'default'}
    When I request a Kubernetes token
    Then I see the text {'Namespace default is not allowed.'}
    And I do not see the text {'Token'}

  Scenario: The kubeconfig holds the cluster address, CA and token
    Given the Kubernetes access screen is open
    And I pick the role {'developer'}
    And I request a Kubernetes token
    When I set the cluster address {'https://k8s.test:6443'} with the CA {'/etc/k8s/ca.crt'}
    And I copy the kubeconfig
    Then the copied kubeconfig points at {'https://k8s.test:6443'} with the CA {'/etc/k8s/ca.crt'}
    And the copied kubeconfig holds the token for the namespace {'team-a'}

  Scenario: A CA certificate that cannot be read stops the kubeconfig
    Given the Kubernetes access screen is open
    And I pick the role {'developer'}
    And I request a Kubernetes token
    When I set the cluster address {'https://k8s.test:6443'} with the CA {'/etc/k8s/missing.crt'}
    And I copy the kubeconfig
    Then I see the text {'Cannot read the CA certificate: /etc/k8s/missing.crt'}
    And nothing has been copied

  Scenario: The kubeconfig cannot be made without a cluster address
    Given the Kubernetes access screen is open
    And I pick the role {'developer'}
    When I request a Kubernetes token
    Then I see the text {'Enter the API server URL (https://…) first.'}
    And I cannot copy the kubeconfig

  Scenario: Picking another role clears the token but keeps the cluster address
    Given the Kubernetes access screen is open
    And I pick the role {'developer'}
    And I request a Kubernetes token
    And I set the cluster address {'https://k8s.test:6443'} with the CA {'/etc/k8s/ca.crt'}
    When I pick the role {'viewer'}
    Then I do not see the text {'Token'}
    When I enter the namespace {'team-a'}
    And I request a Kubernetes token
    Then I see the text {'https://k8s.test:6443'}

  Scenario: Clearing the token removes it from the screen
    Given the Kubernetes access screen is open
    And I pick the role {'developer'}
    And I request a Kubernetes token
    When I clear the credentials from the screen
    Then I do not see the text {'Token'}

  Scenario: Roles are grouped by mount
    Given the Kubernetes mount {'k8s-prod'} offers the role {'deployer'}
    And the Kubernetes access screen is open
    When I pick the role {'deployer'}
    Then I see the text {'k8s-prod'}
    And I see the text {'Request token for k8s-prod/deployer'}

  Scenario: A server without the Kubernetes engine shows why there are no roles
    Given the server has no Kubernetes engine
    When the Kubernetes access screen is open
    Then I see the text {'Not found. Check the mount path and role name.'}
    And I do not see the text {'developer'}

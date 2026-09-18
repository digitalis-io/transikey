Feature: Database credentials
  Roles come from every database mount. Credentials belong to one role and
  disappear as soon as another role is picked.

  Widget level scenarios against a fake server: nothing is persisted outside
  the test process (settings live in an in-memory store that dies with the
  scenario), so no teardown beyond disposing the provider container is
  needed and scenarios are order independent and parallel safe.

  The server fake starts as the least-privilege case: one mount called
  'database' with the roles 'readonly' and 'short-lived', and a token that
  may not read what is behind a role. Scenarios change that before the
  screen opens.

  Background:
    Given a server that offers database roles

  Scenario: Requesting credentials shows them for the chosen role
    Given the database credentials screen is open
    When I pick the role {'readonly'}
    And I request database credentials
    Then I see the text {'Password'}
    And I see the text {'database/readonly'}

  Scenario: Picking another role clears the previous credentials
    Given the database credentials screen is open
    And I pick the role {'readonly'}
    And I request database credentials
    When I pick the role {'short-lived'}
    Then I do not see the text {'Password'}
    And I see the text {'Request credentials for short-lived'}

  Scenario: Picking a role on another mount clears the previous credentials
    Given the database mount {'cass001'} offers the role {'operator'}
    And the database credentials screen is open
    And I pick the role {'readonly'}
    And I request database credentials
    When I pick the role {'operator'}
    Then I do not see the text {'Password'}

  Scenario: Picking the same role again keeps the credentials
    Given the database credentials screen is open
    And I pick the role {'readonly'}
    And I request database credentials
    When I pick the role {'readonly'}
    Then I see the text {'Password'}

  Scenario: Clearing credentials removes them from the screen
    Given the database credentials screen is open
    And I pick the role {'readonly'}
    And I request database credentials
    When I clear the credentials from the screen
    Then I do not see the text {'Password'}

  Scenario: Roles are grouped by mount
    Given the database mount {'cass001'} offers the role {'operator'}
    And the database credentials screen is open
    When I pick the role {'operator'}
    Then I see the text {'cass001'}
    And I see the text {'Request credentials for cass001/operator'}

  Scenario: A mount that refuses to list its roles does not hide the others
    Given the database mount {'locked'} refuses to list its roles
    When the database credentials screen is open
    Then I see the text {'Permission denied.'}
    And I see the text {'readonly'}

  Scenario: The engine is asked for when the server hides it
    Given the database credentials screen is open
    When I pick the role {'readonly'}
    And I request database credentials
    Then I see the text {'MySQL / MariaDB'}
    And I see the text {'psql command'}

  Scenario: The engine is not asked for when the server reveals it
    Given the server reveals a Cassandra cluster behind the role {'readonly'}
    And the database credentials screen is open
    When I pick the role {'readonly'}
    And I request database credentials
    Then I do not see the text {'MySQL / MariaDB'}
    And I see the text {'cqlsh command'}

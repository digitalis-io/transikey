Feature: Database credentials
  Credentials belong to one role and disappear as soon as another role is picked.

  Background:
    Given the database credentials screen is open

  Scenario: Requesting credentials shows them for the chosen role
    When I pick the role {'readonly'}
    And I request database credentials
    Then I see the text {'Password'}

  Scenario: Picking another role clears the previous credentials
    Given I pick the role {'readonly'}
    And I request database credentials
    When I pick the role {'short-lived'}
    Then I do not see the text {'Password'}
    And I see the text {'Request credentials for short-lived'}

  Scenario: Picking the same role again keeps the credentials
    Given I pick the role {'readonly'}
    And I request database credentials
    When I pick the role {'readonly'}
    Then I see the text {'Password'}

Feature: Authentication
  Users sign in to a Vault or OpenBao server before they can request secrets.

  Background:
    Given the app is connected to a test server

  Scenario: Sign in with a username and password
    When I sign in with userpass as {'demo'} and password {'good-password'}
    Then I see the message {'Signed in'}
    And I see the message {'demo'}

  Scenario: A wrong password is rejected
    When I sign in with userpass as {'demo'} and password {'bad-password'}
    Then I see the message {'Login failed. Check your credentials.'}
    And I do not see the message {'Signed in'}

  Scenario: The token form refuses an empty token
    When I submit the sign in form without credentials
    Then I see the message {'Required'}
    And I do not see the message {'Signed in'}

  Scenario: Signing out returns to the sign in form
    Given I sign in with userpass as {'demo'} and password {'good-password'}
    When I sign out
    Then I see the message {'Sign in'}
    And I do not see the message {'Signed in'}

Feature: Secret sharing links
  A wrapped secret travels as a one-time link that opens the recipient's app.

  Background:
    Given the secret sharing screen is open

  Scenario: Wrapping a secret offers a share link and a CLI command
    When I wrap the secret {'database password is hunter2'}
    Then I see the button {'Copy share link'}
    And I see the button {'Copy CLI command'}

  Scenario: Wrapping nothing is refused
    When I wrap the secret {''}
    Then I see the text {'Nothing to wrap.'}
    And I do not see the button {'Copy share link'}

  Scenario: Opening a share link prefills the unwrap form without sending anything
    When I open the link {'transikey://unwrap?addr=https%3A%2F%2Fbao.partner.example%3A8200&token=wrapping-token-1'}
    Then the unwrap form targets the server {'https://bao.partner.example:8200'}
    And no secret has been requested

  Scenario: A malformed link is ignored
    When I open the link {'transikey://unwrap?addr=file%3A%2F%2F%2Fetc%2Fpasswd&token=x'}
    Then I see the button {'Wrap secret'}
    And no secret has been requested

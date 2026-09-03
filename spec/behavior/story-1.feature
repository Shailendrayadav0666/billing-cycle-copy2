Feature: Mid-Cycle Subscription Upgrade (Standard -> Premium)

  Background:
    Given a Standard subscriber "priya@example.com" with a $20/month plan
    And her cycle renews in 15 days

  @AC-1
  Scenario: Standard subscriber sees the Upgrade CTA and a dynamic plan badge
    When she views the Billing page
    Then she sees an "Upgrade to Premium" button
    And her plan badge reads "Standard", driven by the API response, not a hardcoded value

  @AC-1
  Scenario: Premium subscriber sees no Upgrade CTA
    Given "devraj@example.com" is already on the Premium plan
    When he views the Billing page
    Then he does not see an "Upgrade to Premium" button

  @AC-2
  Scenario: Proration preview shows the exact server-computed charge
    When she requests the upgrade preview
    Then the response shows current plan "Standard", new plan "Premium"
    And days remaining is 15
    And the prorated charge is $10.00
    And the next renewal price is $40.00

  @AC-3
  Scenario: Cancel leaves everything unchanged
    Given she has opened the upgrade confirmation modal
    When she clicks "Cancel"
    Then no request is sent to the backend
    And her plan remains "Standard"

  @AC-4
  Scenario: Confirming the upgrade with a valid card succeeds
    When she confirms the upgrade
    Then she is charged $10.00
    And her plan becomes "Premium"
    And the response is 200 with plan "Premium" and charge 10.00
    And her billing data shows Premium quotas

  @AC-5
  Scenario: Confirming the upgrade with a declined card fails safely
    Given the subscriber's email is "fail@example.com"
    And she has a $20/month plan with 15 days remaining
    When she confirms the upgrade
    Then the response is 402 with detail "card_declined"
    And her plan remains "Standard"
    And no billing data is mutated

  @AC-5
  Scenario: Already-Premium guard on the preview endpoint
    Given "devraj@example.com" is already on the Premium plan
    When he requests the upgrade preview
    Then the response is 409 with detail "already_premium"

  @AC-5
  Scenario: Already-Premium guard on the upgrade endpoint
    Given "devraj@example.com" is already on the Premium plan
    When he confirms an upgrade
    Then the response is 409 with detail "already_premium"
    And no charge is attempted

  @AC-6
  Scenario: Premium quotas replace Standard quotas after a successful upgrade
    When she completes a successful upgrade
    Then her chat credits total becomes 10000
    And her chatbots total becomes 10
    And her document pages total becomes 5000
    And her on-demand usage notice reads "On-demand credit is available on your Premium plan."

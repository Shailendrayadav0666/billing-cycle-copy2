Feature: Self-Serve Mid-Cycle Upgrade: Standard -> Premium
  As a Standard subscriber
  I want to upgrade to Premium from the Billing page, see the exact prorated charge,
  have it applied through a deterministic dummy payment gateway, and immediately see
  my new plan and quotas
  So that I can move up mid-cycle without leaving the app

  Background:
    Given a Standard subscriber "standard@example.com" with 15 days remaining in the current cycle

  @AC-1
  Scenario: CTA is shown for a Standard subscriber and hidden for a Premium subscriber
    When "standard@example.com" requests their billing summary
    Then the response plan_name is "Standard"
    And the Billing page would show the "Upgrade to Premium" CTA

  @AC-1
  Scenario: CTA is hidden for an already-Premium subscriber
    Given a Premium subscriber "premium@example.com"
    When "premium@example.com" requests their billing summary
    Then the response plan_name is "Premium"
    And the Billing page would NOT show the "Upgrade to Premium" CTA

  @AC-2
  Scenario: Upgrade preview returns the server-side prorated charge
    When "standard@example.com" requests an upgrade preview
    Then the preview shows current plan "Standard" and new plan "Premium"
    And the preview's prorated charge is computed entirely server-side

  @AC-3
  Scenario: Cancelling the upgrade modal makes no backend calls
    Given "standard@example.com" has opened the upgrade preview
    When they cancel the upgrade
    Then no upgrade endpoint is called and no billing state changes

  @AC-4
  Scenario: Successful upgrade flips the plan, quotas and price atomically
    When "standard@example.com" confirms the upgrade
    Then the upgrade response status is "success"
    And "standard@example.com" is now on plan "Premium"
    And "standard@example.com" quotas reflect Premium totals

  @AC-5
  Scenario: Declined payment leaves the subscriber on Standard with no mutation
    Given a Standard subscriber "fail@example.com" with 15 days remaining in the current cycle
    When "fail@example.com" confirms the upgrade
    Then the upgrade response status code is 402
    And "fail@example.com" is still on plan "Standard"
    And no billing_data or users field changed for "fail@example.com"

  @AC-6
  Scenario: Already-Premium guard blocks the preview endpoint
    Given a Premium subscriber "premium@example.com"
    When "premium@example.com" requests an upgrade preview
    Then the response status code is 409
    And the response detail is "already_premium"

  @AC-6
  Scenario: Already-Premium guard blocks the upgrade endpoint
    Given a Premium subscriber "premium@example.com"
    When "premium@example.com" confirms the upgrade
    Then the response status code is 409
    And the response detail is "already_premium"

  @AC-7
  Scenario: renew_at is preserved unchanged through a successful upgrade
    Given "standard@example.com" has opened the upgrade preview
    When "standard@example.com" confirms the upgrade
    Then "standard@example.com" renew_at is unchanged from before the upgrade

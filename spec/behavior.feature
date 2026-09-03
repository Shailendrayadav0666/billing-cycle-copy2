Feature: Mid-Cycle Subscription Upgrade — cycle-level journeys

  # This cycle has a single work unit (Story 1), which owns the entire epic's behaviour.
  # Per common/behavior-spec.md Section 3: a cross-story journey is only meaningful when it
  # spans behaviour owned by two or more separate work units. With one unit, there is no
  # genuine cross-unit seam to test here — recording that explicitly rather than duplicating
  # Story 1's own scenarios (spec/behavior/story-1.feature).
  #
  # B3 (common/behavior-spec.md Section 6) runs Story 1's own feature file plus this file on
  # the last (and only) work unit of the cycle — see Section 6.1, "single-unit cycles".

  @REQ-F-01 @REQ-F-07
  Scenario: End-to-end — Standard subscriber upgrades and the whole page reflects it
    Given a Standard subscriber "priya@example.com" with 15 days remaining in her cycle
    When she completes the self-serve upgrade to Premium
    Then her plan badge, price, and usage quotas across the whole Billing page reflect Premium
    And revisiting the Billing page later still shows Premium with no upgrade CTA

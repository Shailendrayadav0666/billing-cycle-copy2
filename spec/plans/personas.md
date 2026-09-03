# Personas — Mid-Cycle Subscription Upgrade

## Persona 1: Standard Subscriber ("Alex")
- **Role**: Active user on the $20/mo Standard plan
- **Goal**: Move to Premium without leaving the app, understand exactly what will be charged before committing
- **Motivation**: Needs Premium's higher chat-credit/chatbot/document quotas mid-cycle, doesn't want to wait for renewal
- **Pain point today**: The Billing page shows a hardcoded "Standard" badge with no upgrade path at all

## Persona 2: Premium Subscriber ("Priya")
- **Role**: Already on the $40/mo Premium plan
- **Goal**: Confirm her plan/quotas are shown correctly and is never prompted to "upgrade" again
- **Motivation**: Avoid confusion or accidental duplicate charges
- **Pain point today**: N/A today (no upgrade flow exists yet) — this persona exists to define the guard behavior

## Persona 3: Declined-Card Subscriber ("Dana", demo-only trigger persona)
- **Role**: A Standard subscriber whose registered email starts with `fail` (deterministic demo trigger for the dummy gateway's decline path)
- **Goal**: See a clear, actionable error and know her plan was NOT changed
- **Motivation**: Trust that a failed payment leaves her billing state untouched

## Persona → Story Mapping

| Persona | Story |
|---|---|
| Alex (Standard) | 1.1 |
| Priya (Premium) | 1.1 (guard clause) |
| Dana (declined) | 1.1 (failure-path ACs) |

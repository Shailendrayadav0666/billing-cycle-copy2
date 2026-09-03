# Requirements Verification Questions

The Epic (`spec/plans/epic-brief.md`, fetched from Helix solution document 3157) is exceptionally clear and complete — problem statement, goals, out-of-scope, pricing/proration formula with a worked example, dummy payment gateway spec, 5 fully detailed user stories with acceptance criteria, exact backend/frontend technical design (endpoints, Pydantic models, constants, proration logic, hardcoded lines to replace), an epic-level AC checklist, and referenced source paths. No functional clarification is needed.

Two extension opt-in questions are always asked at this stage regardless of requirements clarity:

## Question: Resiliency Extensions
Should the resiliency baseline be applied to this project?

**What this extension is.** Enabling it applies a set of **directional, design-time best practices** for building resilient systems, derived from the **AWS Well-Architected Framework (Reliability Pillar)** and resilience-review guidance. It steers requirements, design, and code toward fault tolerance, high availability, observability, and recoverability — covering 15 practice areas across business goals, change management, observability, high availability, disaster recovery, and continuous improvement.

**What this extension is NOT.** Enabling it does **not** make your workload production-ready, nor does it certify or guarantee any availability, RTO, or RPO target. It is a **starting point** that scaffolds good resiliency decisions early — it is not a substitute for a formal **AWS Well-Architected Review** of the built system.

A) Yes — apply the resiliency baseline as directional best practices and design-time guidance
B) No — skip the resiliency baseline (suitable for PoCs, prototypes, and experimental projects where rapid iteration matters more than reliability)
X) Other (please describe after [Answer]: tag below)

[Answer]: B — No, skip. Small POC/demo billing-upgrade feature with a local in-memory store, not a business-critical production workload.

## Question: Property-Based Testing Extension
Should property-based testing (PBT) rules be enforced for this project?

A) Yes — enforce all PBT rules as blocking constraints
B) Partial — enforce PBT rules only for pure functions and serialization round-trips (e.g. the proration calculation)
C) No — skip all PBT rules (suitable for simple CRUD applications, UI-only projects, or thin integration layers with no significant business logic)
X) Other (please describe after [Answer]: tag below)

[Answer]: C — No, skip PBT entirely.
